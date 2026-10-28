import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import '../models/chat_session.dart';
import '../storage/local_storage_service.dart';
import '../workspace/workspace_chat_attachments.dart';
import '../workspace/workspace_chat_sync.dart';
import '../workspace/workspace_gateway.dart';
import '../../infrastructure/acp/acp_attachment_store.dart';

class ChatSessionPage {
  final List<ChatSession> sessions;
  final bool hasMore;
  final String? cursor;
  final String? warning;
  const ChatSessionPage(
    this.sessions,
    this.hasMore, {
    this.cursor,
    this.warning,
  });
}

class ChatToolOutputPage {
  final String text;
  final int? nextOffset;
  const ChatToolOutputPage(this.text, this.nextOffset);
}

class ChatSearchHit {
  final String sessionId, messageId, title, source, excerpt;
  final MessageRole role;
  final int sequence, matchOffset;
  final DateTime createdAt;
  final String? toolId;
  const ChatSearchHit({
    required this.sessionId,
    required this.messageId,
    required this.title,
    required this.role,
    required this.sequence,
    required this.createdAt,
    required this.matchOffset,
    required this.source,
    required this.excerpt,
    this.toolId,
  });
}

class ChatSearchPage {
  final List<ChatSearchHit> hits;
  final String? nextCursor;
  const ChatSearchPage(this.hits, this.nextCursor);
}

class _DeletedChatSession {
  final String? serverId;
  final String remoteId;
  final List<({int sequence, String messageId})> messages;
  final List<({int sequence, String messageId, String toolId})> tools;
  const _DeletedChatSession(
    this.serverId,
    this.remoteId,
    this.messages,
    this.tools,
  );
}

class _MigrationCursor {
  final String? sessionId;
  final int sequence;
  const _MigrationCursor(this.sessionId, this.sequence);
}

/// Async, bounded history. The original preferences remain a migration backup.
class ChatRepository {
  final LocalStorageService _localStorage;
  final String? databasePath;
  final AcpAttachmentStore? _attachmentStore;
  final WorkspaceChatSync? _workspaceOverride;
  WorkspaceChatSync? _workspace;
  Future<String>? _ready;
  Future<void> _writes = Future.value();
  final StreamController<WorkspaceChatChange> _remoteChanges =
      StreamController<WorkspaceChatChange>.broadcast();
  final StreamController<Object> _workspaceErrors =
      StreamController<Object>.broadcast();
  StreamSubscription<WorkspaceChange>? _changeSubscription;
  Object? _lastWorkspaceError;

  ChatRepository(
    this._localStorage, {
    this.databasePath,
    AcpAttachmentStore? attachmentStore,
    WorkspaceChatSync? workspaceSync,
  }) : _attachmentStore = attachmentStore,
       _workspaceOverride = workspaceSync;

  Future<void> dispose() async {
    await _changeSubscription?.cancel();
    _changeSubscription = null;
    await _writes;
    await Future.wait([_remoteChanges.close(), _workspaceErrors.close()]);
  }

  /// Null when no workspace gateway is attached or it is disabled.
  WorkspaceChatSync? get workspaceSync => _workspaceOrNull();

  /// Errors from deferred remote writes/migrations. Local history is kept.
  Stream<Object> get workspaceErrors => _workspaceErrors.stream;
  Object? get lastWorkspaceError => _lastWorkspaceError;

  /// Hot-refresh signal for the AI notifier. It never resets the open session.
  Stream<WorkspaceChatChange> get remoteChanges {
    _ensureWorkspaceSubscribed();
    return _remoteChanges.stream;
  }

  WorkspaceChatSync? _workspaceOrNull() {
    final existing = _workspace ?? _workspaceOverride;
    if (existing != null) {
      _ensureWorkspaceSubscribed();
      return existing;
    }
    final gateway = _localStorage.workspaceGateway;
    if (gateway == null) return null;
    final created = WorkspaceChatSync(
      gateway: gateway,
      attachments: WorkspaceChatAttachments(
        gateway: gateway,
        store: _attachmentStore,
      ),
    );
    _workspace = created;
    _ensureWorkspaceSubscribed();
    return created;
  }

  void _ensureWorkspaceSubscribed() {
    if (_changeSubscription != null) return;
    final gateway =
        _workspaceOverride?.gateway ?? _localStorage.workspaceGateway;
    if (gateway == null) return;
    _changeSubscription = gateway.changes.listen(
      (change) => unawaited(
        _handleWorkspaceChange(change).catchError(_reportWorkspaceError),
      ),
      onError: _reportWorkspaceError,
    );
  }

  void _reportWorkspaceError(Object error) {
    _lastWorkspaceError = error;
    if (!_workspaceErrors.isClosed) _workspaceErrors.add(error);
  }

  Future<void> _handleWorkspaceChange(WorkspaceChange change) async {
    final workspace = _workspaceOrNull();
    if (workspace == null || !workspace.enabled(change.serverId)) return;
    final records = change.records
        .map(WorkspaceChatRecord.parse)
        .whereType<WorkspaceChatRecord>()
        .where(
          (record) =>
              record.kind == 'chat_session' ||
              record.kind == 'chat_message' ||
              record.kind == 'chat_tool',
        )
        .toList(growable: false);
    if (records.isEmpty) return;
    try {
      await _applyRemoteRecords(change.serverId, records);
    } catch (error) {
      _reportWorkspaceError(error);
    }
    final sessionIds = <String>{};
    for (final record in records) {
      if (record.kind == 'chat_session') {
        sessionIds.add(record.id);
      } else if (record.kind == 'chat_message') {
        final parsed = WorkspaceChatSync.parseMessageId(record.id);
        if (parsed != null) sessionIds.add(parsed.sessionId);
      } else {
        final parsed = WorkspaceChatSync.parseToolId(record.id);
        if (parsed != null) sessionIds.add(parsed.sessionId);
      }
    }
    if (!_remoteChanges.isClosed) {
      _remoteChanges.add(
        WorkspaceChatChange(change.serverId, records, sessionIds),
      );
    }
  }

  Future<String> _initialize() async {
    final file =
        databasePath ??
        path.join(
          (await getApplicationSupportDirectory()).path,
          'valhalla_chat.sqlite3',
        );
    final raw = _localStorage.rawChatSessions;
    final legacyOwner = _localStorage.legacyOwnershipServerId;
    await _chatDb(file, (db) {
      db.execute('PRAGMA journal_mode = WAL');
      db.execute(
        'CREATE TABLE IF NOT EXISTS chat_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      db.execute(
        'CREATE TABLE IF NOT EXISTS chat_sessions (id TEXT PRIMARY KEY, server_id TEXT, agent_id TEXT, title TEXT NOT NULL, updated TEXT NOT NULL, data TEXT NOT NULL)',
      );
      db.execute(
        'CREATE TABLE IF NOT EXISTS chat_messages (session_id TEXT NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE, seq INTEGER NOT NULL, id TEXT NOT NULL, data TEXT NOT NULL, PRIMARY KEY(session_id,seq), UNIQUE(session_id,id))',
      );
      db.execute(
        'CREATE TABLE IF NOT EXISTS chat_tools (session_id TEXT NOT NULL, message_id TEXT NOT NULL, tool_id TEXT NOT NULL, data TEXT NOT NULL, PRIMARY KEY(session_id,message_id,tool_id), FOREIGN KEY(session_id,message_id) REFERENCES chat_messages(session_id,id) ON DELETE CASCADE)',
      );
      // Workspace bookkeeping only. The chat tables remain the local cache and
      // are never cleared by a sync reset.
      db.execute(
        'CREATE TABLE IF NOT EXISTS chat_workspace_map (server_id TEXT NOT NULL, kind TEXT NOT NULL, remote_id TEXT NOT NULL, local_id TEXT NOT NULL, PRIMARY KEY(server_id,kind,remote_id))',
      );
      db.execute(
        'CREATE TABLE IF NOT EXISTS chat_workspace_seen (server_id TEXT NOT NULL, kind TEXT NOT NULL, id TEXT NOT NULL, version INTEGER NOT NULL, PRIMARY KEY(server_id,kind,id))',
      );
      db.execute(
        'CREATE TABLE IF NOT EXISTS chat_workspace_meta (server_id TEXT PRIMARY KEY, data TEXT NOT NULL)',
      );
      db.execute(
        'CREATE TABLE IF NOT EXISTS chat_workspace_migration (server_id TEXT PRIMARY KEY, data TEXT NOT NULL)',
      );
      db.execute(
        'CREATE INDEX IF NOT EXISTS chat_sessions_server ON chat_sessions(server_id,updated DESC,id)',
      );
      db.execute(
        "CREATE INDEX IF NOT EXISTS chat_messages_remote ON chat_messages(session_id,json_extract(data,'\$.agentId'),json_extract(data,'\$.remoteMessageId'))",
      );
      if (db
          .select("SELECT 1 FROM chat_meta WHERE key='legacy_imported'")
          .isNotEmpty) {
        db.execute(
          "UPDATE chat_messages SET data=json_set(data,'\$.status','interrupted') WHERE json_extract(data,'\$.status')='streaming'",
        );
        return;
      }
      // A malformed source fails visibly, never as a successful empty import.
      final sessions = (jsonDecode(raw) as List).map((item) {
        final session = ChatSession.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
        return session.serverId == null
            ? session.copyWith(serverId: legacyOwner)
            : session;
      }).toList();
      db.execute('BEGIN IMMEDIATE');
      try {
        for (final session in sessions) {
          _saveChat(db, session.copyWith(messageOffset: 0));
          final count = db.select(
            'SELECT COUNT(*) AS n FROM chat_messages WHERE session_id=?',
            [session.id],
          ).single['n'];
          if (count != session.messages.length) {
            throw StateError('CHAT_MIGRATION_COUNT_MISMATCH');
          }
          final owner = db.select(
            'SELECT server_id,agent_id FROM chat_sessions WHERE id=?',
            [session.id],
          ).single;
          if (owner['server_id'] != session.serverId ||
              owner['agent_id'] != session.agentId) {
            throw StateError('CHAT_MIGRATION_OWNER_MISMATCH');
          }
        }
        db.execute(
          "INSERT INTO chat_meta(key,value) VALUES('legacy_imported','1')",
        );
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    });
    return file;
  }

  Future<String> _path() => _ready ??= _initialize().catchError((Object error) {
    _ready = null;
    throw error;
  });

  Future<T> _write<T>(T Function(Database) action) {
    final next = _writes.then((_) async => _chatDb(await _path(), action));
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<ChatSessionPage> listSessions(
    String serverId, {
    String? agentId,
    String query = '',
    int offset = 0,
    int limit = 30,
  }) async {
    _localStorage.claimLegacyOwnership(serverId);
    final workspace = _workspaceOrNull();
    if (workspace != null && workspace.enabled(serverId)) {
      await _refreshRemoteSessions(
        serverId,
        offset: offset,
        limit: limit,
        agentId: agentId,
        query: query,
      );
    }
    final ownsLegacy = _localStorage.legacyOwnershipServerId == serverId;
    await _writes;
    String file;
    try {
      file = await _path();
    } catch (error) {
      final sessions =
          (await _legacySessions())
              .where(
                (s) =>
                    s.serverId == serverId &&
                    (agentId == null || s.includesAgent(agentId)) &&
                    s.title.toLowerCase().contains(query.toLowerCase()),
              )
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final page = sessions
          .skip(offset)
          .take(limit)
          .map(
            (s) => s.copyWith(
              totalMessageCount: s.messages.length,
              messageOffset: s.messages.length,
              messages: const [],
            ),
          )
          .toList();
      return ChatSessionPage(
        page,
        sessions.length > offset + limit,
        warning: 'CHAT_MIGRATION_FAILED: $error',
      );
    }
    return _chatDb(file, (db) {
      final rows = db.select(
        '''SELECT data,(SELECT COUNT(*) FROM chat_messages WHERE session_id=chat_sessions.id) AS count
        FROM chat_sessions WHERE (server_id=? OR (server_id IS NULL AND ?=1))
        AND (? IS NULL OR agent_id=? OR EXISTS(SELECT 1 FROM json_each(chat_sessions.data,'\$.participantAgentIds') WHERE value=?))
        AND (?='' OR instr(lower(title),lower(?))>0)
        ORDER BY updated DESC,id LIMIT ? OFFSET ?''',
        [
          serverId,
          ownsLegacy ? 1 : 0,
          agentId,
          agentId,
          agentId,
          query,
          query,
          limit + 1,
          offset,
        ],
      );
      return ChatSessionPage(
        rows
            .take(limit)
            .map(
              (row) =>
                  ChatSession.fromJson(
                    jsonDecode(row['data'] as String) as Map<String, dynamic>,
                  ).copyWith(
                    totalMessageCount: row['count'] as int,
                    messageOffset: row['count'] as int,
                  ),
            )
            .toList(),
        rows.length > limit,
      );
    });
  }

  /// One bounded remote metadata refresh. Never pages the whole store.
  Future<void> _refreshRemoteSessions(
    String serverId, {
    int offset = 0,
    int limit = 30,
    String? agentId,
    String query = '',
  }) async {
    final workspace = _workspaceOrNull();
    if (workspace == null || !workspace.enabled(serverId)) return;
    try {
      final target = offset + limit + 1;
      String? cursor;
      while (true) {
        final page = await workspace.fetchSessionCatalog(
          serverId,
          limit: kWorkspaceChatPageLimit,
          cursor: cursor,
          agentId: agentId,
          query: query,
        );
        if (page.records.isNotEmpty) {
          await _applyRemoteRecords(serverId, page.records);
        }
        if (!page.hasMore || page.nextCursor == null) break;
        final localCount = await _countMatchingSessions(
          serverId,
          agentId: agentId,
          query: query,
        );
        if (localCount >= target) break;
        cursor = page.nextCursor;
      }
    } catch (error) {
      _reportWorkspaceError(error);
    }
  }

  Future<int> _countMatchingSessions(
    String serverId, {
    String? agentId,
    String query = '',
  }) async {
    try {
      final file = await _path();
      return _chatDb(file, (db) {
        final ownsLegacy = _localStorage.legacyOwnershipServerId == serverId;
        final rows = db.select(
          '''SELECT COUNT(*) AS n FROM chat_sessions
             WHERE (server_id=? OR (server_id IS NULL AND ?=1))
             AND (? IS NULL OR agent_id=? OR EXISTS(SELECT 1 FROM json_each(chat_sessions.data,'\$.participantAgentIds') WHERE value=?))
             AND (?='' OR instr(lower(title),lower(?))>0)''',
          [
            serverId,
            ownsLegacy ? 1 : 0,
            agentId,
            agentId,
            agentId,
            query,
            query,
          ],
        );
        return rows.single['n'] as int;
      });
    } catch (_) {
      return 0;
    }
  }

  Future<void> _syncRemoteSession(
    String id, {
    int? before,
    int limit = 50,
  }) async {
    final workspace = _workspaceOrNull();
    if (workspace == null) return;
    await _writes;
    String? serverId;
    try {
      serverId = await _chatDb(
        await _path(),
        (db) =>
            db.select('SELECT server_id FROM chat_sessions WHERE id=?', [
                  id,
                ]).firstOrNull?['server_id']
                as String?,
      );
    } catch (error) {
      _reportWorkspaceError(error);
      return;
    }
    if (serverId == null || !workspace.enabled(serverId)) return;
    try {
      final metadata = await workspace.fetchSession(serverId, id);
      if (metadata == null) return;
      await _applyRemoteRecords(serverId, [metadata]);
      final remoteId = metadata.id;
      final page = before == null
          ? await workspace.fetchMessageTail(serverId, remoteId, limit: limit)
          : await workspace.fetchMessagesBefore(
              serverId,
              remoteId,
              before,
              limit: limit,
            );
      if (page.unsupported || page.records.isEmpty) return;
      final enriched = <WorkspaceChatRecord>[];
      for (final record in page.records) {
        final parsed = WorkspaceChatSync.parseMessageId(record.id);
        if (parsed == null) continue;
        enriched.add(record);
        final tools = await workspace.fetchTools(
          serverId,
          remoteId,
          parsed.sequence,
          parsed.messageId,
        );
        enriched.addAll(tools);
      }
      await _applyRemoteRecords(serverId, enriched);
    } catch (error) {
      _reportWorkspaceError(error);
    }
  }

  Future<void> _applyRemoteRecords(
    String serverId,
    List<WorkspaceChatRecord> records,
  ) => _write((db) {
    db.execute('BEGIN IMMEDIATE');
    try {
      for (final record in records) {
        final seen = db.select(
          'SELECT version FROM chat_workspace_seen WHERE server_id=? AND kind=? AND id=?',
          [serverId, record.kind, record.id],
        ).firstOrNull;
        if (seen != null &&
            record.version != null &&
            (seen['version'] as int) >= record.version!) {
          continue;
        }
        switch (record.kind) {
          case 'chat_session':
            _applyRemoteSession(db, serverId, record);
          case 'chat_message':
            _applyRemoteMessage(db, serverId, record);
          case 'chat_tool':
            _applyRemoteTool(db, serverId, record);
        }
        if (record.version != null) {
          db.execute(
            'INSERT OR REPLACE INTO chat_workspace_seen(server_id,kind,id,version) VALUES(?,?,?,?)',
            [serverId, record.kind, record.id, record.version],
          );
        }
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  });

  static String? _localSessionId(
    Database db,
    String serverId,
    String remoteId, {
    required bool create,
  }) {
    final mapped = db.select(
      'SELECT local_id FROM chat_workspace_map WHERE server_id=? AND kind=? AND remote_id=?',
      [serverId, 'chat_session', remoteId],
    ).firstOrNull;
    if (mapped != null) return mapped['local_id'] as String;
    final existing = db.select(
      'SELECT id,server_id FROM chat_sessions WHERE id=?',
      [remoteId],
    ).firstOrNull;
    var localId = remoteId;
    if (existing != null &&
        existing['server_id'] != null &&
        existing['server_id'] != serverId) {
      // A local id from another server must not be stolen by this workspace.
      localId = '$remoteId::$serverId';
    }
    if (create) {
      db.execute(
        'INSERT OR REPLACE INTO chat_workspace_map(server_id,kind,remote_id,local_id) VALUES(?,?,?,?)',
        [serverId, 'chat_session', remoteId, localId],
      );
    }
    return localId;
  }

  static String _remoteSessionId(Database db, String serverId, String localId) {
    final mapped = db.select(
      'SELECT remote_id FROM chat_workspace_map WHERE server_id=? AND kind=? AND local_id=?',
      [serverId, 'chat_session', localId],
    ).firstOrNull;
    if (mapped != null) return mapped['remote_id'] as String;
    db.execute(
      'INSERT OR REPLACE INTO chat_workspace_map(server_id,kind,remote_id,local_id) VALUES(?,?,?,?)',
      [serverId, 'chat_session', localId, localId],
    );
    return localId;
  }

  static void _applyRemoteSession(
    Database db,
    String serverId,
    WorkspaceChatRecord record,
  ) {
    final localId = _localSessionId(
      db,
      serverId,
      record.id,
      create: !record.deleted,
    );
    if (record.deleted) {
      if (localId != null) {
        db.execute('DELETE FROM chat_sessions WHERE id=?', [localId]);
      }
      db.execute(
        'DELETE FROM chat_workspace_map WHERE server_id=? AND kind=? AND remote_id=?',
        [serverId, 'chat_session', record.id],
      );
      return;
    }
    final value = record.value;
    if (value == null || localId == null) return;
    var incoming = WorkspaceChatSync.decodeSession(record, serverId);
    final existing = db.select('SELECT data FROM chat_sessions WHERE id=?', [
      localId,
    ]).firstOrNull;
    if (existing != null) {
      final local = ChatSession.fromJson(
        jsonDecode(existing['data'] as String) as Map<String, dynamic>,
      );
      // A local rename/checkpoint that has not reached the server yet must not
      // be replaced by older remote metadata.
      if (local.updatedAt.isAfter(incoming.updatedAt)) {
        incoming = incoming.copyWith(
          title: local.title,
          updatedAt: local.updatedAt,
        );
      }
      final contexts = <String, AgentChatContext>{...local.agentContexts};
      for (final entry in incoming.agentContexts.entries) {
        final remote = entry.value;
        final current = contexts[entry.key];
        contexts[entry.key] = current == null
            ? remote
            : remote.copyWith(
                persistentRuntimeKey:
                    remote.persistentRuntimeKey ?? current.persistentRuntimeKey,
                runtimeCursor: remote.runtimeCursor != 0
                    ? remote.runtimeCursor
                    : current.runtimeCursor,
                runtimeGeneration: remote.runtimeGeneration != 0
                    ? remote.runtimeGeneration
                    : current.runtimeGeneration,
                runtimeRestartPending:
                    remote.runtimeRestartPending ||
                    current.runtimeRestartPending,
              );
      }
      incoming = incoming.copyWith(
        id: localId,
        agentContexts: contexts,
        participantAgentIds: {
          ...local.participantAgentIds,
          ...incoming.participantAgentIds,
        }.toList(growable: false),
      );
    } else {
      incoming = incoming.copyWith(id: localId);
    }
    _saveChat(db, incoming, preserveTitle: false);
  }

  static void _applyRemoteMessage(
    Database db,
    String serverId,
    WorkspaceChatRecord record,
  ) {
    final parsed = WorkspaceChatSync.parseMessageId(record.id);
    if (parsed == null) return;
    final localSessionId = _localSessionId(
      db,
      serverId,
      parsed.sessionId,
      create: false,
    );
    if (localSessionId == null) return;
    final metadata = db.select('SELECT data FROM chat_sessions WHERE id=?', [
      localSessionId,
    ]).firstOrNull;
    if (metadata == null) return;
    if (record.deleted) {
      db.execute('DELETE FROM chat_messages WHERE session_id=? AND id=?', [
        localSessionId,
        parsed.messageId,
      ]);
      return;
    }
    final value = record.value;
    if (value == null) return;
    var message = WorkspaceChatSync.decodeMessage(record);
    final tools = db.select(
      'SELECT data FROM chat_tools WHERE session_id=? AND message_id=?',
      [localSessionId, parsed.messageId],
    );
    if (tools.isNotEmpty) {
      message = WorkspaceChatSync.mergeTools(message, [
        for (final row in tools)
          WorkspaceChatRecord(
            kind: 'chat_tool',
            id: '',
            value: jsonDecode(row['data'] as String) as Map<String, dynamic>,
          ),
      ]);
    }
    final existing = db.select(
      'SELECT id,data FROM chat_messages WHERE session_id=? AND seq=?',
      [localSessionId, parsed.sequence],
    ).firstOrNull;
    if (existing != null) {
      if (existing['id'] != parsed.messageId) return;
      final previous = ChatMessage.fromJson(
        jsonDecode(existing['data'] as String) as Map<String, dynamic>,
      );
      if (previous.content.length > message.content.length) return;
      message = message.copyWith(
        contentBlocks: message.contentBlocks.isEmpty
            ? previous.contentBlocks
            : message.contentBlocks,
        toolExecutions: {
          for (final tool in previous.toolExecutions) tool.id: tool,
          for (final tool in message.toolExecutions) tool.id: tool,
        }.values.toList(growable: false),
        // Remote attachment refs are content hashes; a local id for the same
        // bytes must not be kept as a second attachment.
        attachments: message.attachments.isEmpty
            ? previous.attachments
            : message.attachments,
      );
    }
    final session = ChatSession.fromJson(
      jsonDecode(metadata['data'] as String) as Map<String, dynamic>,
    );
    _saveChat(
      db,
      session.copyWith(messages: [message], messageOffset: parsed.sequence),
      preserveTitle: true,
    );
  }

  static void _applyRemoteTool(
    Database db,
    String serverId,
    WorkspaceChatRecord record,
  ) {
    final parsed = WorkspaceChatSync.parseToolId(record.id);
    if (parsed == null) return;
    final localSessionId = _localSessionId(
      db,
      serverId,
      parsed.sessionId,
      create: false,
    );
    if (localSessionId == null) return;
    final exists = db.select(
      'SELECT 1 FROM chat_messages WHERE session_id=? AND id=?',
      [localSessionId, parsed.messageId],
    ).isNotEmpty;
    if (!exists) return;
    if (record.deleted) {
      db.execute(
        'DELETE FROM chat_tools WHERE session_id=? AND message_id=? AND tool_id=?',
        [localSessionId, parsed.messageId, parsed.toolId],
      );
      return;
    }
    final value = record.value;
    if (value == null) return;
    db.execute(
      'INSERT OR REPLACE INTO chat_tools(session_id,message_id,tool_id,data) VALUES(?,?,?,?)',
      [localSessionId, parsed.messageId, parsed.toolId, jsonEncode(value)],
    );
  }

  Future<ChatSearchPage> searchMessages(
    String serverId, {
    String? sessionId,
    String? agentId,
    required String query,
    String? cursor,
    int limit = 30,
  }) async {
    final term = query.trim().toLowerCase();
    if (limit < 1 || limit > 100 || term.length > 512) {
      throw ArgumentError('CHAT_SEARCH_INVALID_QUERY');
    }
    if (term.isEmpty) return const ChatSearchPage([], null);
    List<dynamic>? after;
    if (cursor != null) {
      try {
        if (cursor.length > 2048) throw const FormatException();
        after = jsonDecode(cursor) as List;
        if (after.length != 5 ||
            after[0] is! num ||
            after[1] is! String ||
            after[2] is! int ||
            after[3] is! int ||
            after[4] is! String) {
          throw const FormatException();
        }
      } catch (_) {
        throw ArgumentError('CHAT_SEARCH_INVALID_CURSOR');
      }
    }
    await _writes;
    final file = await _path();
    final ownsLegacy = _localStorage.legacyOwnershipServerId == serverId;
    return _chatDb(file, (db) {
      db.createFunction(
        functionName: 'chat_fold',
        argumentCount: const AllowedArgumentCount(1),
        deterministic: true,
        function: (args) => (args[0] as String? ?? '').toLowerCase(),
      );
      final pagination = after == null
          ? ''
          : '''
        AND (stamp < ? OR (stamp = ? AND sid > ?)
          OR (stamp = ? AND sid = ? AND seq < ?)
          OR (stamp = ? AND sid = ? AND seq = ? AND kind > ?)
          OR (stamp = ? AND sid = ? AND seq = ? AND kind = ? AND tool_id > ?))''';
      final params = <Object?>[
        serverId,
        ownsLegacy ? 1 : 0,
        sessionId,
        sessionId,
        agentId,
        agentId,
        agentId,
        term,
        if (after != null) ...[
          after[0],
          after[0],
          after[1],
          after[0],
          after[1],
          after[2],
          after[0],
          after[1],
          after[2],
          after[3],
          after[0],
          after[1],
          after[2],
          after[3],
          after[4],
        ],
        limit + 1,
      ];
      final rows = db.select('''
        WITH scoped AS (
          SELECT s.id sid,s.title,m.id mid,m.seq,m.data payload,
            json_extract(m.data,'\$.role') role,
            json_extract(m.data,'\$.createdAt') created,
            COALESCE(julianday(json_extract(m.data,'\$.createdAt')),0) stamp
          FROM chat_messages m JOIN chat_sessions s ON s.id=m.session_id
          WHERE (s.server_id=? OR (s.server_id IS NULL AND ?=1))
            AND (? IS NULL OR s.id=?)
            AND (? IS NULL OR s.agent_id=? OR EXISTS (
              SELECT 1 FROM json_each(s.data,'\$.participantAgentIds') WHERE value=?))
        ), contents AS (
          SELECT sid,title,mid,seq,role,created,stamp,0 kind,'' tool_id,
            COALESCE(json_extract(payload,'\$.content'),'') text FROM scoped
          UNION ALL
          SELECT c.sid,c.title,c.mid,c.seq,c.role,c.created,c.stamp,1,
            json_extract(j.value,'\$.id'),
            COALESCE(json_extract(t.data,'\$.output'),json_extract(j.value,'\$.output'),'')
          FROM scoped c JOIN json_each(c.payload,'\$.toolExecutions') j
          LEFT JOIN chat_tools t ON t.session_id=c.sid AND t.message_id=c.mid
            AND t.tool_id=json_extract(j.value,'\$.id')
        ), matches AS (
          SELECT *,instr(chat_fold(text),?) pos FROM contents
        ) SELECT sid,title,mid,seq,role,created,stamp,kind,tool_id,pos,
            substr(text,MAX(1,pos-60),240) excerpt
          FROM matches WHERE pos>0 $pagination
          ORDER BY stamp DESC,sid,seq DESC,kind,tool_id LIMIT ?
      ''', params);
      final page = rows.take(limit).toList();
      final last = page.lastOrNull;
      return ChatSearchPage(
        page
            .map(
              (row) => ChatSearchHit(
                sessionId: row['sid'] as String,
                messageId: row['mid'] as String,
                title: row['title'] as String,
                role: MessageRole.values.byName(row['role'] as String),
                sequence: row['seq'] as int,
                matchOffset: (row['pos'] as int) - 1,
                createdAt: DateTime.parse(row['created'] as String),
                source: row['kind'] == 0 ? 'message' : 'tool',
                toolId: row['kind'] == 0 ? null : row['tool_id'] as String,
                excerpt: row['excerpt'] as String,
              ),
            )
            .toList(growable: false),
        rows.length <= limit || last == null
            ? null
            : jsonEncode([
                last['stamp'],
                last['sid'],
                last['seq'],
                last['kind'],
                last['tool_id'],
              ]),
      );
    });
  }

  Future<ChatSession?> loadMessageWindow(
    String sessionId,
    String messageId, {
    int radius = 15,
  }) async {
    if (radius < 0 || radius > 50) {
      throw ArgumentError('CHAT_SEARCH_INVALID_WINDOW');
    }
    await _writes;
    final file = await _path();
    final sequence = await _chatDb(
      file,
      (db) =>
          db.select(
                'SELECT seq FROM chat_messages WHERE session_id=? AND id=?',
                [sessionId, messageId],
              ).firstOrNull?['seq']
              as int?,
    );
    if (sequence == null) return null;
    final session = await loadSession(
      sessionId,
      before: sequence + radius + 1,
      limit: radius * 2 + 1,
    );
    if (session == null) return null;
    final skip = (sequence - radius - session.messageOffset).clamp(
      0,
      session.messages.length,
    );
    return session.copyWith(
      messages: session.messages.skip(skip).toList(growable: false),
      messageOffset: session.messageOffset + skip,
    );
  }

  Future<ChatSession?> loadSession(
    String id, {
    int? before,
    int limit = 50,
  }) async {
    await _syncRemoteSession(id, before: before, limit: limit);
    await _writes;
    String file;
    try {
      file = await _path();
    } catch (_) {
      final session = (await _legacySessions())
          .where((s) => s.id == id)
          .firstOrNull;
      if (session == null) return null;
      final end = (before ?? session.messages.length).clamp(
        0,
        session.messages.length,
      );
      final start = (end - limit).clamp(0, end);
      return session.copyWith(
        messages: session.messages.sublist(start, end),
        messageOffset: start,
        totalMessageCount: session.messages.length,
      );
    }
    return _chatDb(file, (db) {
      final rows = db.select('SELECT data FROM chat_sessions WHERE id=?', [id]);
      if (rows.isEmpty) return null;
      final count =
          db.select(
                'SELECT COALESCE(MAX(seq)+1,0) AS n FROM chat_messages WHERE session_id=?',
                [id],
              ).single['n']
              as int;
      final messages = db.select(
        'SELECT seq,data FROM chat_messages WHERE session_id=? AND seq<? ORDER BY seq DESC LIMIT ?',
        [id, before ?? count, limit],
      );
      return ChatSession.fromJson(
        jsonDecode(rows.single['data'] as String) as Map<String, dynamic>,
      ).copyWith(
        messages: messages.reversed
            .map(
              (row) => ChatMessage.fromJson(
                jsonDecode(row['data'] as String) as Map<String, dynamic>,
              ),
            )
            .toList(),
        messageOffset: messages.isEmpty
            ? before ?? count
            : messages.last['seq'] as int,
        totalMessageCount: count,
      );
    });
  }

  Future<void> saveSession(ChatSession session) async {
    await _write((db) {
      db.execute('BEGIN IMMEDIATE');
      try {
        _saveChat(db, session);
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    });
    await _stageSession(session);
  }

  Future<void> _stageSession(ChatSession session) async {
    final serverId = session.serverId;
    if (serverId == null) return;
    final workspace = _workspaceOrNull();
    if (workspace == null || !workspace.enabled(serverId)) return;
    try {
      final snapshot = await _write((db) {
        final remoteId = _remoteSessionId(db, serverId, session.id);
        final count =
            db.select(
                  'SELECT COALESCE(MAX(seq)+1,0) AS n FROM chat_messages WHERE session_id=?',
                  [session.id],
                ).single['n']
                as int;
        return (remoteId, count);
      });
      final remoteId = snapshot.$1;
      final total = snapshot.$2;
      final metadata = session.copyWith(
        totalMessageCount: total > session.totalMessageCount
            ? total
            : session.totalMessageCount,
      );
      final records = await workspace.encodeSaveRecords(
        serverId,
        metadata,
        remoteSessionId: remoteId,
      );
      await workspace.stage(serverId, records);
    } catch (error) {
      // The local write already succeeded; surface the deferred remote failure
      // instead of deleting local history or pretending it synced.
      _reportWorkspaceError(error);
    }
  }

  /// Merge one bounded replay batch without deleting local history or changing
  /// local IDs (scroll anchors). Ambiguous replay fails closed, never duplicates.
  Future<void> mergeReplayBatch(ChatSession session, String agentId) async {
    await _write((db) {
      db.execute('BEGIN IMMEDIATE');
      try {
        final metadata = db.select(
          'SELECT data FROM chat_sessions WHERE id=?',
          [session.id],
        ).firstOrNull;
        if (metadata == null) throw StateError('CHAT_SESSION_NOT_FOUND');
        final stored = ChatSession.fromJson(
          jsonDecode(metadata['data'] as String) as Map<String, dynamic>,
        );
        if (stored.serverId != session.serverId ||
            !stored.includesAgent(agentId)) {
          throw StateError('CHAT_SESSION_IDENTITY_MISMATCH');
        }
        // Shared sessions may interleave agents: ordinal fallback is unsafe there.
        final shared =
            stored.agentId != agentId ||
            stored.participantAgentIds.any((id) => id != agentId) ||
            stored.agentContexts.keys.any((id) => id != agentId);
        var count =
            db.select(
                  'SELECT COALESCE(MAX(seq)+1,0) AS n FROM chat_messages WHERE session_id=?',
                  [session.id],
                ).single['n']
                as int;
        for (var i = 0; i < session.messages.length; i++) {
          final incoming = session.messages[i];
          if (incoming.agentId != null && incoming.agentId != agentId) {
            throw StateError('CHAT_SESSION_IDENTITY_MISMATCH');
          }
          var row = incoming.remoteMessageId == null
              ? null
              : db.select(
                  "SELECT seq,data FROM chat_messages WHERE session_id=? AND json_extract(data,'\$.agentId')=? AND json_extract(data,'\$.remoteMessageId')=?",
                  [session.id, agentId, incoming.remoteMessageId],
                ).firstOrNull;
          final ordinal = session.messageOffset + i;
          if (row == null && !shared && ordinal < count) {
            row = db.select(
              'SELECT seq,data FROM chat_messages WHERE session_id=? AND seq=?',
              [session.id, ordinal],
            ).firstOrNull;
          }
          var message = incoming;
          final int seq;
          if (row != null) {
            final previous = ChatMessage.fromJson(
              jsonDecode(row['data'] as String) as Map<String, dynamic>,
            );
            final sameId =
                incoming.remoteMessageId != null &&
                incoming.remoteMessageId == previous.remoteMessageId;
            if (previous.role != incoming.role ||
                (previous.agentId != null && previous.agentId != agentId) ||
                (!sameId &&
                    ((previous.remoteMessageId != null &&
                            incoming.remoteMessageId != null) ||
                        !incoming.content.startsWith(previous.content) ||
                        (previous.content.isEmpty &&
                            previous.attachments.isNotEmpty)))) {
              throw StateError('ACP_HISTORY_REPLAY_AMBIGUOUS');
            }
            seq = row['seq'] as int;
            // A shorter snapshot must not erase already received output.
            if (previous.content.length > incoming.content.length) {
              throw StateError('ACP_HISTORY_REPLAY_AMBIGUOUS');
            } else {
              message = incoming.copyWith(
                id: previous.id,
                // A history snapshot proves received content, not that a lost
                // running turn finished. Only a live terminal event can prove it.
                status: incoming.failureCode != null
                    ? incoming.status
                    : previous.failureCode != null
                    ? previous.status
                    : previous.status == ChatTurnStatus.unknown ||
                          previous.status == ChatTurnStatus.streaming
                    ? ChatTurnStatus.unknown
                    : incoming.status,
                failureCode: incoming.failureCode ?? previous.failureCode,
                createdAt: previous.createdAt,
                thinking: incoming.thinking ?? previous.thinking,
                contentBlocks:
                    incoming.contentBlocks.isEmpty &&
                        previous.content == incoming.content
                    ? previous.contentBlocks
                    : incoming.contentBlocks,
                planSteps: incoming.planSteps.isEmpty
                    ? previous.planSteps
                    : incoming.planSteps,
                toolExecutions: {
                  for (final tool in previous.toolExecutions) tool.id: tool,
                  for (final tool in incoming.toolExecutions) tool.id: tool,
                }.values.toList(),
                attachments: {
                  for (final attachment in previous.attachments)
                    attachment.id: attachment,
                  for (final attachment in incoming.attachments)
                    attachment.id: attachment,
                }.values.toList(),
              );
            }
          } else {
            if (shared || ordinal != count) {
              throw StateError('ACP_HISTORY_REPLAY_AMBIGUOUS');
            }
            seq = count++;
          }
          _saveChat(
            db,
            stored.copyWith(messages: [message], messageOffset: seq),
          );
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    });
    await _stageSession(session);
  }

  Future<List<ChatSession>> _legacySessions() {
    final raw = _localStorage.rawChatSessions;
    final owner = _localStorage.legacyOwnershipServerId;
    return Isolate.run(
      () => (jsonDecode(raw) as List).map((item) {
        final session = ChatSession.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
        return session.serverId == null
            ? session.copyWith(serverId: owner)
            : session;
      }).toList(),
    );
  }

  Future<void> deleteSession(String id) async {
    final deleted = await _write<_DeletedChatSession?>((db) {
      final row = db.select('SELECT server_id FROM chat_sessions WHERE id=?', [
        id,
      ]).firstOrNull;
      if (row == null) return null;
      final serverId = row['server_id'] as String?;
      final remoteId = serverId == null
          ? id
          : _remoteSessionId(db, serverId, id);
      final messages = db
          .select('SELECT seq,id FROM chat_messages WHERE session_id=?', [id])
          .map(
            (row) =>
                (sequence: row['seq'] as int, messageId: row['id'] as String),
          )
          .toList(growable: false);
      final tools = db
          .select(
            'SELECT m.seq AS seq,m.id AS message_id,t.tool_id AS tool_id '
            'FROM chat_tools t JOIN chat_messages m '
            'ON m.session_id=t.session_id AND m.id=t.message_id '
            'WHERE t.session_id=?',
            [id],
          )
          .map(
            (row) => (
              sequence: row['seq'] as int,
              messageId: row['message_id'] as String,
              toolId: row['tool_id'] as String,
            ),
          )
          .toList(growable: false);
      db.execute('DELETE FROM chat_sessions WHERE id=?', [id]);
      if (serverId != null) {
        db.execute(
          'DELETE FROM chat_workspace_map WHERE server_id=? AND kind=? AND local_id=?',
          [serverId, 'chat_session', id],
        );
      }
      return _DeletedChatSession(serverId, remoteId, messages, tools);
    });
    final serverId = deleted?.serverId;
    if (deleted == null || serverId == null) return;
    final workspace = _workspaceOrNull();
    if (workspace == null || !workspace.enabled(serverId)) return;
    final records = <Map<String, dynamic>>[
      WorkspaceChatSync.record(
        'chat_session',
        deleted.remoteId,
        const {},
        deleted: true,
      ),
      for (final message in deleted.messages)
        WorkspaceChatSync.record(
          'chat_message',
          WorkspaceChatSync.messageRecordId(
            deleted.remoteId,
            message.sequence,
            message.messageId,
          ),
          const {},
          deleted: true,
        ),
      for (final tool in deleted.tools)
        WorkspaceChatSync.record(
          'chat_tool',
          WorkspaceChatSync.toolRecordId(
            deleted.remoteId,
            tool.sequence,
            tool.messageId,
            tool.toolId,
          ),
          const {},
          deleted: true,
        ),
    ];
    try {
      await workspace.stage(serverId, records);
    } catch (error) {
      _reportWorkspaceError(error);
    }
  }

  Future<void> renameSession(String id, String title) async {
    final session = await _write<ChatSession?>((db) {
      final rows = db.select('SELECT data FROM chat_sessions WHERE id=?', [id]);
      if (rows.isEmpty) return null;
      final data =
          jsonDecode(rows.single['data'] as String) as Map<String, dynamic>;
      final now = DateTime.now();
      data['title'] = title;
      data['updatedAt'] = now.toIso8601String();
      db.execute(
        'UPDATE chat_sessions SET title=?,updated=?,data=? WHERE id=?',
        [title, now.toIso8601String(), jsonEncode(data), id],
      );
      return ChatSession.fromJson(
        data,
      ).copyWith(messages: const [], messageOffset: 0);
    });
    if (session != null) await _stageSession(session);
  }

  /// Explicit, resumable upload of this device's existing local history.
  ///
  /// Never called at startup. Each call uploads at most [messageBudget] messages
  /// from at most [sessionBudget] sessions and persists a cursor in SQLite, so
  /// an interrupted migration resumes exactly where it stopped.
  Future<WorkspaceChatMigration> migrateWorkspace(
    String serverId, {
    int messageBudget = 200,
    int sessionBudget = 10,
  }) async {
    final workspace = _workspaceOrNull();
    if (workspace == null || !workspace.enabled(serverId)) {
      throw const WorkspaceChatSyncException('WORKSPACE_CHAT_DISABLED');
    }
    if (messageBudget < 1 || messageBudget > 500) {
      throw ArgumentError('CHAT_MIGRATION_BUDGET_INVALID');
    }
    if (sessionBudget < 1 || sessionBudget > 100) {
      throw ArgumentError('CHAT_MIGRATION_BUDGET_INVALID');
    }
    var cursor = await _write((db) => _readMigrationCursor(db, serverId));
    var uploadedSessions = 0;
    var uploadedMessages = 0;
    var uploadedTools = 0;
    var sessionsVisited = 0;
    String? lastSessionId;
    var done = false;
    while (sessionsVisited < sessionBudget) {
      final next = await _write<(String, Map<String, dynamic>, int, int)?>((
        db,
      ) {
        final query = cursor.sessionId == null
            ? db.select(
                'SELECT id,data FROM chat_sessions WHERE server_id=? ORDER BY id LIMIT 1',
                [serverId],
              )
            : db.select(
                'SELECT id,data FROM chat_sessions WHERE server_id=? AND id>=? ORDER BY id LIMIT 1',
                [serverId, cursor.sessionId],
              );
        if (query.isEmpty) return null;
        final id = query.single['id'] as String;
        final metadata =
            jsonDecode(query.single['data'] as String) as Map<String, dynamic>;
        final count =
            db.select(
                  'SELECT COALESCE(MAX(seq)+1,0) AS n FROM chat_messages WHERE session_id=?',
                  [id],
                ).single['n']
                as int;
        final sequence = id == cursor.sessionId ? cursor.sequence : 0;
        if (sequence >= count && id == cursor.sessionId) {
          // This session is complete; advance to the next id.
          final after = db.select(
            'SELECT id,data FROM chat_sessions WHERE server_id=? AND id>? ORDER BY id LIMIT 1',
            [serverId, id],
          );
          if (after.isEmpty) return null;
          final nextId = after.single['id'] as String;
          return (
            nextId,
            jsonDecode(after.single['data'] as String) as Map<String, dynamic>,
            db.select(
                  'SELECT COALESCE(MAX(seq)+1,0) AS n FROM chat_messages WHERE session_id=?',
                  [nextId],
                ).single['n']
                as int,
            0,
          );
        }
        return (id, metadata, count, sequence);
      });
      if (next == null) {
        done = true;
        break;
      }
      final (sessionId, metadata, count, sequence) = next;
      lastSessionId = sessionId;
      final messages = await _write((db) {
        final rows = db.select(
          'SELECT seq,data FROM chat_messages WHERE session_id=? AND seq>=? ORDER BY seq LIMIT ?',
          [sessionId, sequence, messageBudget],
        );
        return rows
            .map(
              (row) => ChatMessage.fromJson(
                _expandChatMessage(db, sessionId, row['data'] as String),
              ),
            )
            .toList(growable: false);
      });
      final session = ChatSession.fromJson(metadata).copyWith(
        messages: messages,
        messageOffset: sequence,
        totalMessageCount: count,
      );
      final remoteId = await _write(
        (db) => _remoteSessionId(db, serverId, sessionId),
      );
      final records = await workspace.encodeSaveRecords(
        serverId,
        session,
        remoteSessionId: remoteId,
      );
      await workspace.stage(serverId, records);
      uploadedSessions += sequence == 0 ? 1 : 0;
      uploadedMessages += messages.length;
      uploadedTools += messages.fold<int>(
        0,
        (total, message) => total + message.toolExecutions.length,
      );
      sessionsVisited += sequence == 0 ? 1 : 0;
      final nextSequence = sequence + messages.length;
      cursor = _MigrationCursor(sessionId, nextSequence);
      await _write((db) => _writeMigrationCursor(db, serverId, cursor));
      if (nextSequence >= count) {
        sessionsVisited = sessionsVisited == 0 ? 1 : sessionsVisited;
        // The next loop iteration advances past this completed session.
        cursor = _MigrationCursor(sessionId, count);
      }
      // One bounded batch per call; the persisted cursor resumes exactly here.
      if (messages.length >= messageBudget) break;
    }
    return WorkspaceChatMigration(
      serverId: serverId,
      done: done,
      sessionId: lastSessionId,
      uploadedSessions: uploadedSessions,
      uploadedMessages: uploadedMessages,
      uploadedTools: uploadedTools,
    );
  }

  static _MigrationCursor _readMigrationCursor(Database db, String serverId) {
    final row = db.select(
      'SELECT data FROM chat_workspace_migration WHERE server_id=?',
      [serverId],
    ).firstOrNull;
    if (row == null) return const _MigrationCursor(null, 0);
    final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
    return _MigrationCursor(
      data['sessionId'] as String?,
      (data['sequence'] as num?)?.toInt() ?? 0,
    );
  }

  static void _writeMigrationCursor(
    Database db,
    String serverId,
    _MigrationCursor cursor,
  ) {
    db.execute(
      'INSERT OR REPLACE INTO chat_workspace_migration(server_id,data) VALUES(?,?)',
      [
        serverId,
        jsonEncode({
          'sessionId': cursor.sessionId,
          'sequence': cursor.sequence,
        }),
      ],
    );
  }

  /// Uploads one attachment (local file -> content hash) through `blob_put`.
  Future<ChatAttachment> uploadWorkspaceAttachment(
    String serverId,
    ChatAttachment attachment,
  ) async {
    final workspace = _workspaceOrNull();
    if (workspace == null || !workspace.enabled(serverId)) {
      throw const WorkspaceChatSyncException('WORKSPACE_CHAT_DISABLED');
    }
    return workspace.attachments.prepareOutgoing(serverId, attachment);
  }

  /// Downloads and materialises a remote attachment on demand.
  Future<ChatAttachment> hydrateWorkspaceAttachment(
    String serverId,
    ChatAttachment attachment,
  ) async {
    final workspace = _workspaceOrNull();
    if (workspace == null || !workspace.enabled(serverId)) {
      throw const WorkspaceChatSyncException('WORKSPACE_CHAT_DISABLED');
    }
    return workspace.attachments.hydrate(serverId, attachment);
  }

  Future<List<WorkspaceRuntimeInfo>> workspaceRuntimeCatalog(
    String serverId, {
    String? runtimeKey,
  }) async {
    final workspace = _workspaceOrNull();
    if (workspace == null || !workspace.enabled(serverId)) return const [];
    return workspace.fetchRuntimeCatalog(serverId, runtimeKey: runtimeKey);
  }

  /// Runtime identities hydrated from the local cache, for the root controller.
  Future<Map<String, WorkspaceRuntimeBinding>> workspaceRuntimeBindings(
    String serverId,
  ) async {
    await _writes;
    final file = await _path();
    return _chatDb(file, (db) {
      final bindings = <String, WorkspaceRuntimeBinding>{};
      for (final row in db.select(
        'SELECT id,agent_id,data FROM chat_sessions WHERE server_id=?',
        [serverId],
      )) {
        final session = ChatSession.fromJson(
          jsonDecode(row['data'] as String) as Map<String, dynamic>,
        );
        for (final entry in session.agentContexts.entries) {
          final key = entry.value.persistentRuntimeKey;
          if (key == null || key.isEmpty) continue;
          bindings[key] = WorkspaceRuntimeBinding(
            sessionId: row['id'] as String,
            agentId: entry.key,
            context: entry.value,
          );
        }
      }
      return bindings;
    });
  }

  /// Clears workspace bookkeeping only. Local chat history and SSH config stay.
  Future<void> clearWorkspaceCache(String serverId) => _write((db) {
    for (final table in [
      'chat_workspace_map',
      'chat_workspace_seen',
      'chat_workspace_meta',
      'chat_workspace_migration',
    ]) {
      db.execute('DELETE FROM $table WHERE server_id=?', [serverId]);
    }
  });

  Future<ChatSession?> findRemoteSession(
    String serverId,
    String agentId,
    String remoteId,
  ) async {
    await _writes;
    final id = await _chatDb(
      await _path(),
      (db) =>
          db.select(
                "SELECT id FROM chat_sessions WHERE server_id=? AND agent_id=? AND json_extract(data,'\$.remoteSessionId')=? ORDER BY updated DESC,id DESC LIMIT 1",
                [serverId, agentId, remoteId],
              ).firstOrNull?['id']
              as String?,
    );
    return id == null ? null : loadSession(id);
  }

  Future<ChatSession?> findRuntimeSession(
    String serverId,
    String runtimeKey,
  ) async {
    await _writes;
    final id = await _chatDb(
      await _path(),
      (db) =>
          db.select(
                "SELECT s.id FROM chat_sessions s, json_each(s.data,'\$.agentContexts') c "
                "WHERE s.server_id=? AND json_extract(c.value,'\$.persistentRuntimeKey')=? "
                'ORDER BY s.updated DESC LIMIT 1',
                [serverId, runtimeKey],
              ).firstOrNull?['id']
              as String?,
    );
    return id == null ? null : loadSession(id);
  }

  /// Hydrates the exact chat session behind a shared runtime from the workspace
  /// store, using only the registry's `sessionId` (no local checkpoint needed).
  ///
  /// Returns `null` when the owning device has not yet committed the
  /// `chat_session` metadata record, in which case the caller should fall back
  /// to a bounded local reconstruction from bootstrap metadata.
  Future<ChatSession?> hydrateRemoteSession(
    String serverId,
    String remoteChatSessionId,
  ) async {
    final workspace = _workspaceOrNull();
    if (workspace == null || !workspace.enabled(serverId)) return null;
    try {
      final record = await workspace.fetchSession(
        serverId,
        remoteChatSessionId,
      );
      if (record == null) return null;
      await _applyRemoteRecords(serverId, [record]);
      return loadSession(remoteChatSessionId);
    } on Object {
      // A transient workspace read must not masquerade as a missing session.
      return null;
    }
  }

  /// Persists a chat session to the local SQLite store only, without staging
  /// any remote write. Used by read-only observers that have discovered a
  /// shared runtime they do not control: merely viewing must not mutate the
  /// authoritative server copy.
  Future<void> persistLocalRuntimeSession(ChatSession session) => _write((db) {
    _saveChat(db, session, preserveTitle: false);
  });

  Future<void> markRuntimesForRestart(String serverId, Set<String> agentIds) =>
      _write((db) {
        db.execute('BEGIN IMMEDIATE');
        try {
          for (final row in db.select(
            'SELECT id,data FROM chat_sessions WHERE server_id=?',
            [serverId],
          )) {
            final data =
                jsonDecode(row['data'] as String) as Map<String, dynamic>;
            final contexts = data['agentContexts'];
            if (contexts is! Map) continue;
            var changed = false;
            for (final id in agentIds) {
              final context = contexts[id];
              if (context is Map && context['persistentRuntimeKey'] != null) {
                context['runtimeRestartPending'] = true;
                changed = true;
              }
            }
            if (changed) {
              db.execute('UPDATE chat_sessions SET data=? WHERE id=?', [
                jsonEncode(data),
                row['id'],
              ]);
            }
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });

  Future<String> exportSession(String id) async {
    await _writes;
    return _chatDb(await _path(), (db) {
      final rows = db.select('SELECT title FROM chat_sessions WHERE id=?', [
        id,
      ]);
      if (rows.isEmpty) throw StateError('CHAT_SESSION_NOT_FOUND');
      final text = StringBuffer('# ${rows.single['title']}\n');
      for (final row in db.select(
        'SELECT data FROM chat_messages WHERE session_id=? ORDER BY seq',
        [id],
      )) {
        final message = ChatMessage.fromJson(
          _expandChatMessage(db, id, row['data'] as String),
        );
        text.write('\n## ${message.role.name}\n\n${message.content}\n');
        for (final attachment in message.attachments) {
          text.writeln(
            '\n- ${attachment.name} (${attachment.mimeType}, ${attachment.sizeBytes} bytes)',
          );
        }
        for (final tool in message.toolExecutions) {
          text.write(
            '\n### ${tool.name}\n\n${tool.command}\n\n${tool.output ?? ""}\n',
          );
        }
      }
      return text.toString();
    });
  }

  Future<String> exportAll() async {
    await _writes;
    return _chatDb(
      await _path(),
      (db) => jsonEncode(
        db.select('SELECT id,data FROM chat_sessions ORDER BY id').map((row) {
          final data =
              jsonDecode(row['data'] as String) as Map<String, dynamic>;
          data['messages'] = db
              .select(
                'SELECT data FROM chat_messages WHERE session_id=? ORDER BY seq',
                [row['id']],
              )
              .map(
                (m) => _expandChatMessage(
                  db,
                  row['id'] as String,
                  m['data'] as String,
                ),
              )
              .toList();
          data['messageOffset'] = 0;
          return data;
        }).toList(),
      ),
    );
  }

  Future<ChatToolOutputPage> loadToolOutput(
    String sessionId,
    String messageId,
    String toolId, {
    int offset = 0,
    int limit = 16384,
  }) async {
    if (offset < 0 || limit < 1 || limit > 65536) {
      throw ArgumentError('CHAT_OUTPUT_PAGE_INVALID');
    }
    await _writes;
    return _chatDb(await _path(), (db) {
      final rows = db.select(
        "SELECT substr(json_extract(data,'\$.output'),?,?) AS text,length(json_extract(data,'\$.output')) AS count FROM chat_tools WHERE session_id=? AND message_id=? AND tool_id=?",
        [offset + 1, limit, sessionId, messageId, toolId],
      );
      if (rows.isEmpty) throw StateError('CHAT_TOOL_OUTPUT_NOT_FOUND');
      final count = rows.single['count'] as int;
      return ChatToolOutputPage(
        rows.single['text'] as String,
        offset + limit < count ? offset + limit : null,
      );
    });
  }
}

Map<String, dynamic> _expandChatMessage(
  Database db,
  String sessionId,
  String raw,
) {
  final data = jsonDecode(raw) as Map<String, dynamic>;
  data['toolExecutions'] = (data['toolExecutions'] as List? ?? const []).map((
    value,
  ) {
    final tool = value as Map<String, dynamic>;
    if (tool['hasMoreOutput'] != true) return tool;
    final row = db.select(
      'SELECT data FROM chat_tools WHERE session_id=? AND message_id=? AND tool_id=?',
      [sessionId, data['id'], tool['id']],
    ).firstOrNull;
    if (row == null) throw StateError('CHAT_TOOL_OUTPUT_NOT_FOUND');
    return jsonDecode(row['data'] as String);
  }).toList();
  return data;
}

void _saveChat(Database db, ChatSession session, {bool preserveTitle = true}) {
  final existing = db.select(
    'SELECT server_id,agent_id,title FROM chat_sessions WHERE id=?',
    [session.id],
  ).firstOrNull;
  if (existing != null &&
      ((existing['server_id'] != null &&
              existing['server_id'] != session.serverId) ||
          (existing['agent_id'] != null &&
              existing['agent_id'] != session.agentId))) {
    throw StateError('CHAT_SESSION_IDENTITY_MISMATCH');
  }
  final metadata = session
      .copyWith(messages: const [], messageOffset: 0)
      .toJson();
  // Renaming owns title changes; an older queued streaming checkpoint must not
  // overwrite a title which the user has just edited.
  final title = preserveTitle
      ? (existing?['title'] as String?) ?? session.title
      : session.title;
  metadata['title'] = title;
  db.execute(
    '''INSERT INTO chat_sessions(id,server_id,agent_id,title,updated,data) VALUES(?,?,?,?,?,?)
    ON CONFLICT(id) DO UPDATE SET server_id=excluded.server_id,agent_id=excluded.agent_id,title=excluded.title,updated=excluded.updated,data=excluded.data''',
    [
      session.id,
      session.serverId,
      session.agentId,
      title,
      session.updatedAt.toIso8601String(),
      jsonEncode(metadata),
    ],
  );
  final statement = db.prepare(
    '''INSERT INTO chat_messages(session_id,seq,id,data) VALUES(?,?,?,?)
    ON CONFLICT(session_id,seq) DO UPDATE SET data=excluded.data WHERE chat_messages.id=excluded.id''',
  );
  try {
    for (var i = 0; i < session.messages.length; i++) {
      final message = session.messages[i];
      final preview = message.copyWith(
        toolExecutions: message.toolExecutions.map((tool) {
          final output = tool.output;
          if (tool.hasMoreOutput || output == null || output.length <= 16384) {
            return tool;
          }
          return tool.copyWith(
            output: output.substring(output.length - 4096),
            hasMoreOutput: true,
            outputLength: output.length,
          );
        }).toList(),
      );
      statement.execute([
        session.id,
        session.messageOffset + i,
        message.id,
        jsonEncode(preview.toJson()),
      ]);
      if (db.updatedRows != 1) {
        throw StateError('CHAT_MESSAGE_SEQUENCE_CONFLICT');
      }
      for (final tool in message.toolExecutions) {
        if (tool.hasMoreOutput) continue;
        if ((tool.output?.length ?? 0) > 16384) {
          db.execute(
            'INSERT INTO chat_tools(session_id,message_id,tool_id,data) VALUES(?,?,?,?) ON CONFLICT(session_id,message_id,tool_id) DO UPDATE SET data=excluded.data',
            [session.id, message.id, tool.id, jsonEncode(tool.toJson())],
          );
        } else {
          db.execute(
            'DELETE FROM chat_tools WHERE session_id=? AND message_id=? AND tool_id=?',
            [session.id, message.id, tool.id],
          );
        }
      }
    }
  } finally {
    statement.dispose();
  }
}

Future<T> _chatDb<T>(String file, T Function(Database) operation) =>
    Isolate.run(() {
      Database db;
      try {
        db = sqlite3.open(file);
      } on ArgumentError {
        if (!Platform.isLinux) rethrow;
        open.overrideFor(
          OperatingSystem.linux,
          () => DynamicLibrary.open('libsqlite3.so.0'),
        );
        db = sqlite3.open(file);
      }
      try {
        db.execute('PRAGMA foreign_keys = ON');
        db.execute('PRAGMA busy_timeout = 5000');
        return operation(db);
      } finally {
        db.dispose();
      }
    });
