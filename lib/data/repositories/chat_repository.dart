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

class ChatSessionPage {
  final List<ChatSession> sessions;
  final bool hasMore;
  final String? warning;
  const ChatSessionPage(this.sessions, this.hasMore, {this.warning});
}

class ChatToolOutputPage {
  final String text;
  final int? nextOffset;
  const ChatToolOutputPage(this.text, this.nextOffset);
}

/// Async, bounded history. The original preferences remain a migration backup.
class ChatRepository {
  final LocalStorageService _localStorage;
  final String? databasePath;
  Future<String>? _ready;
  Future<void> _writes = Future.value();
  ChatRepository(this._localStorage, {this.databasePath});

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

  Future<ChatSession?> loadSession(
    String id, {
    int? before,
    int limit = 50,
  }) async {
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

  Future<void> saveSession(ChatSession session) => _write((db) {
    db.execute('BEGIN IMMEDIATE');
    try {
      _saveChat(db, session);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  });

  /// Merge one bounded replay batch without deleting local history or changing
  /// local IDs (scroll anchors). Ambiguous replay fails closed, never duplicates.
  Future<void> mergeReplayBatch(ChatSession session, String agentId) => _write((
    db,
  ) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final metadata = db.select('SELECT data FROM chat_sessions WHERE id=?', [
        session.id,
      ]).firstOrNull;
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
              status:
                  previous.status == ChatTurnStatus.unknown ||
                      previous.status == ChatTurnStatus.streaming
                  ? ChatTurnStatus.unknown
                  : incoming.status,
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
        _saveChat(db, stored.copyWith(messages: [message], messageOffset: seq));
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  });

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

  Future<void> deleteSession(String id) => _write((db) {
    db.execute('DELETE FROM chat_sessions WHERE id=?', [id]);
  });

  Future<void> renameSession(String id, String title) => _write((db) {
    final rows = db.select('SELECT data FROM chat_sessions WHERE id=?', [id]);
    if (rows.isEmpty) return;
    final data =
        jsonDecode(rows.single['data'] as String) as Map<String, dynamic>;
    data['title'] = title;
    db.execute('UPDATE chat_sessions SET title=?,data=? WHERE id=?', [
      title,
      jsonEncode(data),
      id,
    ]);
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

void _saveChat(Database db, ChatSession session) {
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
  final title = existing?['title'] as String? ?? session.title;
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
