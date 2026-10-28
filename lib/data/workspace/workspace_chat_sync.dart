import 'dart:async';
import 'dart:convert';

import '../models/chat_session.dart';
import 'workspace_chat_attachments.dart';
import 'workspace_gateway.dart';

/// Backend page cap for `snapshot` / `changes`.
const int kWorkspaceChatPageLimit = 200;

/// Fixed width used for the sequence component of remote message ids.
const int kWorkspaceChatSequenceWidth = 12;

/// Largest number of records accepted by one durable commit.
const int kWorkspaceChatCommitLimit = 500;

class WorkspaceChatSyncException implements Exception {
  final String code;
  const WorkspaceChatSyncException(this.code);
  @override
  String toString() => code;
}

class WorkspaceChatRecord {
  final String kind;
  final String id;
  final Map<String, dynamic>? value;
  final bool deleted;
  final int? version;
  const WorkspaceChatRecord({
    required this.kind,
    required this.id,
    required this.value,
    this.deleted = false,
    this.version,
  });

  static WorkspaceChatRecord? parse(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'];
    final id = raw['id'];
    if (kind is! String || id is! String) return null;
    final rawValue = raw['value'];
    Map<String, dynamic>? value;
    if (rawValue is Map) {
      value = Map<String, dynamic>.from(rawValue);
    } else if (rawValue is String) {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map) value = Map<String, dynamic>.from(decoded);
    }
    return WorkspaceChatRecord(
      kind: kind,
      id: id,
      value: value,
      deleted: raw['deleted'] == true,
      version: (raw['version'] as num?)?.toInt(),
    );
  }
}

class WorkspaceChatPage {
  final List<WorkspaceChatRecord> records;
  final bool hasMore;
  final String? nextCursor;
  final bool unsupported;
  const WorkspaceChatPage(
    this.records, {
    this.hasMore = false,
    this.nextCursor,
    this.unsupported = false,
  });
}

class WorkspaceChatChange {
  final String serverId;
  final List<WorkspaceChatRecord> records;
  final Set<String> sessionIds;
  const WorkspaceChatChange(this.serverId, this.records, this.sessionIds);
}

class WorkspaceChatMigration {
  final String serverId;
  final bool done;
  final String? sessionId;
  final int uploadedSessions;
  final int uploadedMessages;
  final int uploadedTools;
  const WorkspaceChatMigration({
    required this.serverId,
    required this.done,
    required this.sessionId,
    required this.uploadedSessions,
    required this.uploadedMessages,
    required this.uploadedTools,
  });
}

/// A hydrated session's runtime identity, keyed by `persistentRuntimeKey`.
///
/// The root controller uses this after the repository imports another device's
/// session, instead of recomputing a legacy connection hash.
class WorkspaceRuntimeBinding {
  final String sessionId;
  final String agentId;
  final AgentChatContext context;
  const WorkspaceRuntimeBinding({
    required this.sessionId,
    required this.agentId,
    required this.context,
  });
}

/// Control/runtime metadata mirrored from `runtime_catalog`.
///
/// `sessionId` is the workspace chat-session id (also the canonical remote
/// record id for a freshly staged session), and `agentId` identifies the agent
/// that owns the runtime. `meta` carries the bounded, portable bootstrap
/// metadata a new device needs to reconstruct a local view without guessing.
class WorkspaceRuntimeInfo {
  final String runtimeKey;
  final String? deviceId;
  final String? sessionId;
  final String? scope;
  final String? agentId;
  final Map<String, dynamic> meta;
  const WorkspaceRuntimeInfo({
    required this.runtimeKey,
    this.deviceId,
    this.sessionId,
    this.scope,
    this.agentId,
    this.meta = const {},
  });

  static WorkspaceRuntimeInfo? parse(Object? raw) {
    if (raw is! Map) return null;
    final runtimeKey = raw['runtimeKey'];
    if (runtimeKey is! String) return null;
    final meta = raw['meta'];
    final metaMap = meta is Map
        ? Map<String, dynamic>.from(meta)
        : const <String, dynamic>{};
    // Prefer the explicit top-level field, fall back to meta for older brokers.
    final agentId = raw['agentId'] as String? ?? metaMap['agentId'] as String?;
    return WorkspaceRuntimeInfo(
      runtimeKey: runtimeKey,
      deviceId: raw['deviceId'] as String?,
      sessionId: raw['sessionId'] as String?,
      scope: raw['scope'] as String?,
      agentId: agentId,
      meta: metaMap,
    );
  }

  /// Chat-session remote id used for exact hydration on a new device.
  String? get chatSessionRemoteId => sessionId;

  /// ACP agent runtime session id, when the broker has learned it.
  String? get acpRemoteSessionId => meta['remoteSessionId'] as String?;

  /// Working directory advertised by the owning device, enough to open an
  /// observer stream when no chat metadata checkpoint exists yet.
  String? get workingDirectory => meta['workingDirectory'] as String?;

  /// Optional human title for a reconstructed session.
  String? get title => meta['title'] as String?;
}

/// Server-backed chat transport: bounded paging, record encoding, and blob
/// attachments. It never downloads a complete transcript.
class WorkspaceChatSync {
  final WorkspaceGateway gateway;
  final WorkspaceChatAttachments attachments;

  WorkspaceChatSync({
    required this.gateway,
    WorkspaceChatAttachments? attachments,
  }) : attachments = attachments ?? WorkspaceChatAttachments(gateway: gateway);

  bool enabled(String serverId) => gateway.isEnabled(serverId);

  static String padSequence(int sequence) =>
      sequence.toString().padLeft(kWorkspaceChatSequenceWidth, '0');

  static String messageRecordId(
    String sessionId,
    int sequence,
    String messageId,
  ) => '$sessionId/${padSequence(sequence)}/$messageId';

  static String toolRecordId(
    String sessionId,
    int sequence,
    String messageId,
    String toolId,
  ) => '${messageRecordId(sessionId, sequence, messageId)}/$toolId';

  /// Parses `<sessionId>/<seq>/<messageId>` without assuming a slash-free id.
  static ({String sessionId, int sequence, String messageId})? parseMessageId(
    String id,
  ) {
    final last = id.lastIndexOf('/');
    if (last <= 0) return null;
    final beforeMessage = id.lastIndexOf('/', last - 1);
    if (beforeMessage <= 0) return null;
    final sequence = int.tryParse(id.substring(beforeMessage + 1, last));
    if (sequence == null || sequence < 0) return null;
    return (
      sessionId: id.substring(0, beforeMessage),
      sequence: sequence,
      messageId: id.substring(last + 1),
    );
  }

  /// Parses `<sessionId>/<seq>/<messageId>/<toolId>`.
  static ({String sessionId, int sequence, String messageId, String toolId})?
  parseToolId(String id) {
    final last = id.lastIndexOf('/');
    if (last <= 0) return null;
    final message = parseMessageId(id.substring(0, last));
    if (message == null) return null;
    return (
      sessionId: message.sessionId,
      sequence: message.sequence,
      messageId: message.messageId,
      toolId: id.substring(last + 1),
    );
  }

  Future<Map<String, dynamic>> _request(
    String serverId,
    Map<String, dynamic> command,
  ) async {
    if (!enabled(serverId)) {
      throw const WorkspaceChatSyncException('WORKSPACE_CHAT_DISABLED');
    }
    final response = await gateway.request(serverId, command);
    if (response['ok'] == false) {
      throw WorkspaceChatSyncException(
        response['error'] as String? ?? 'WORKSPACE_CHAT_FAILED',
      );
    }
    return response;
  }

  static WorkspaceChatPage _page(Map<String, dynamic> response) {
    final rawRecords = response['records'];
    final records = rawRecords is List
        ? rawRecords
              .map(WorkspaceChatRecord.parse)
              .whereType<WorkspaceChatRecord>()
              .toList(growable: false)
        : const <WorkspaceChatRecord>[];
    return WorkspaceChatPage(
      records,
      hasMore: response['hasMore'] == true,
      nextCursor: response['nextCursor'] as String?,
    );
  }

  /// One bounded metadata page. Never loops over every page.
  Future<WorkspaceChatPage> fetchSessionCatalog(
    String serverId, {
    int limit = kWorkspaceChatPageLimit,
    String? cursor,
    String? agentId,
    String query = '',
  }) async {
    final response = await _request(serverId, {
      'op': 'chat_catalog',
      'limit': limit.clamp(1, kWorkspaceChatPageLimit),
      'cursor': ?cursor,
      'agentId': ?agentId,
      'query': query,
    });
    return _page(response);
  }

  Future<List<WorkspaceChatRecord>> fetchSessionMetadata(
    String serverId, {
    int limit = kWorkspaceChatPageLimit,
    String? afterId,
  }) async {
    final response = await _request(serverId, {
      'op': 'snapshot',
      'kind': 'chat_session',
      'limit': limit.clamp(1, kWorkspaceChatPageLimit),
      'afterId': ?afterId,
    });
    return _page(response).records;
  }

  Future<WorkspaceChatRecord?> fetchSession(
    String serverId,
    String sessionId,
  ) async {
    try {
      final response = await _request(serverId, {
        'op': 'snapshot',
        'kind': 'chat_session',
        'id': sessionId,
        'limit': 1,
      });
      final page = _page(response);
      for (final record in page.records) {
        if (record.id == sessionId) return record;
      }
    } on WorkspaceChatSyncException catch (error) {
      if (error.code != 'WORKSPACE_OP_UNKNOWN' &&
          error.code != 'WORKSPACE_OP_INVALID' &&
          error.code != 'WORKSPACE_REQUEST_INVALID') {
        rethrow;
      }
    }
    // Backends without exact-id lookup fall back to a bounded prefix probe.
    final response = await _request(serverId, {
      'op': 'snapshot',
      'kind': 'chat_session',
      'prefix': sessionId,
      'limit': 2,
    });
    for (final record in _page(response).records) {
      if (record.id == sessionId) return record;
    }
    return null;
  }

  /// Newest [limit] messages of one session, ascending.
  ///
  /// Uses the requested descending snapshot extension. If the backend does not
  /// support it, returns an empty unsupported page instead of reading all
  /// history.
  Future<WorkspaceChatPage> fetchMessageTail(
    String serverId,
    String sessionId, {
    int limit = 50,
  }) => _fetchMessages(serverId, sessionId, limit: limit);

  /// Messages with `sequence < beforeSequence`, ascending, at most [limit].
  Future<WorkspaceChatPage> fetchMessagesBefore(
    String serverId,
    String sessionId,
    int beforeSequence, {
    int limit = 50,
  }) => _fetchMessages(
    serverId,
    sessionId,
    limit: limit,
    beforeSequence: beforeSequence,
  );

  Future<WorkspaceChatPage> _fetchMessages(
    String serverId,
    String sessionId, {
    required int limit,
    int? beforeSequence,
  }) async {
    final bounded = limit.clamp(1, kWorkspaceChatPageLimit);
    final command = <String, dynamic>{
      'op': 'snapshot',
      'kind': 'chat_message',
      'prefix': '$sessionId/',
      'limit': bounded,
      'descending': true,
      if (beforeSequence != null)
        'beforeId': '$sessionId/${padSequence(beforeSequence)}/',
    };
    Map<String, dynamic> response;
    try {
      response = await _request(serverId, command);
    } on WorkspaceChatSyncException catch (error) {
      if (error.code == 'WORKSPACE_OP_UNKNOWN' ||
          error.code == 'WORKSPACE_OP_INVALID' ||
          error.code == 'WORKSPACE_REQUEST_INVALID') {
        return const WorkspaceChatPage([], unsupported: true);
      }
      rethrow;
    }
    final page = _page(response);
    final ordered = page.records.reversed.toList(growable: false);
    return WorkspaceChatPage(
      ordered,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }

  Future<List<WorkspaceChatRecord>> fetchTools(
    String serverId,
    String sessionId,
    int sequence,
    String messageId, {
    int limit = kWorkspaceChatPageLimit,
  }) async {
    final response = await _request(serverId, {
      'op': 'snapshot',
      'kind': 'chat_tool',
      'prefix': '$sessionId/${padSequence(sequence)}/$messageId/',
      'limit': limit.clamp(1, kWorkspaceChatPageLimit),
    });
    return _page(response).records;
  }

  Future<List<WorkspaceRuntimeInfo>> fetchRuntimeCatalog(
    String serverId, {
    String? runtimeKey,
  }) async {
    final response = await _request(serverId, {
      'op': 'runtime_catalog',
      'runtimeKey': ?runtimeKey,
    });
    final runtimes = response['runtimes'];
    if (runtimes is! List) return const [];
    return runtimes
        .map(WorkspaceRuntimeInfo.parse)
        .whereType<WorkspaceRuntimeInfo>()
        .toList(growable: false);
  }

  /// Queues durable CAS writes. Batches stay below the backend commit cap.
  Future<void> stage(
    String serverId,
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) return;
    if (!enabled(serverId)) {
      throw const WorkspaceChatSyncException('WORKSPACE_CHAT_DISABLED');
    }
    for (
      var start = 0;
      start < records.length;
      start += kWorkspaceChatCommitLimit
    ) {
      final end = (start + kWorkspaceChatCommitLimit).clamp(0, records.length);
      await gateway.putRecords(serverId, records.sublist(start, end));
    }
  }

  /// Session metadata value. `serverId` is canonicalised only for the wire.
  static Map<String, dynamic> sessionValue(
    ChatSession session, {
    required bool remote,
  }) {
    final value = session
        .copyWith(messages: const [], messageOffset: 0)
        .toJson();
    value['messages'] = const [];
    value['messageOffset'] = 0;
    value['serverId'] = remote ? '@server' : session.serverId;
    return value;
  }

  static Map<String, dynamic> record(
    String kind,
    String id,
    Map<String, dynamic> value, {
    bool deleted = false,
  }) => {
    'kind': kind,
    'id': id,
    'value': deleted ? null : value,
    'deleted': deleted,
  };

  static Map<String, dynamic> _messageValue(ChatMessage message) {
    final preview = message.copyWith(
      toolExecutions: message.toolExecutions.map(_previewTool).toList(),
    );
    return preview.toJson();
  }

  static ToolExecution _previewTool(ToolExecution tool) {
    final output = tool.output;
    if (tool.hasMoreOutput || output == null || output.length <= 16384) {
      return tool;
    }
    return tool.copyWith(
      output: output.substring(output.length - 4096),
      hasMoreOutput: true,
      outputLength: output.length,
    );
  }

  /// Builds the bounded remote records for one local save.
  ///
  /// Attachments with a local file are uploaded first; the stored message only
  /// carries the content hash, never the device path.
  Future<List<Map<String, dynamic>>> encodeSaveRecords(
    String serverId,
    ChatSession session, {
    required String remoteSessionId,
    bool includeSession = true,
  }) async {
    final records = <Map<String, dynamic>>[];
    if (includeSession) {
      records.add(
        record(
          'chat_session',
          remoteSessionId,
          sessionValue(session, remote: true),
        ),
      );
    }
    for (var i = 0; i < session.messages.length; i++) {
      final sequence = session.messageOffset + i;
      final message = session.messages[i];
      final attachments = <ChatAttachment>[];
      for (final attachment in message.attachments) {
        attachments.add(
          await this.attachments.prepareOutgoing(serverId, attachment),
        );
      }
      final portable = message.copyWith(attachments: attachments);
      records.add(
        record(
          'chat_message',
          messageRecordId(remoteSessionId, sequence, message.id),
          _messageValue(portable),
        ),
      );
      for (final tool in message.toolExecutions) {
        records.add(
          record(
            'chat_tool',
            toolRecordId(remoteSessionId, sequence, message.id, tool.id),
            tool.toJson(),
          ),
        );
      }
    }
    return records;
  }

  static ChatSession decodeSession(
    WorkspaceChatRecord record,
    String serverId,
  ) {
    final value = Map<String, dynamic>.from(record.value ?? const {});
    value['id'] = record.id;
    value['serverId'] = serverId;
    value['messages'] = const [];
    final total =
        (value['totalMessageCount'] as num?)?.toInt() ??
        (value['messageOffset'] as num?)?.toInt() ??
        0;
    value['totalMessageCount'] = total;
    value['messageOffset'] = total;
    return ChatSession.fromJson(value);
  }

  static ChatMessage decodeMessage(WorkspaceChatRecord record) =>
      ChatMessage.fromJson(Map<String, dynamic>.from(record.value ?? const {}));

  static ChatMessage mergeTools(
    ChatMessage message,
    List<WorkspaceChatRecord> toolRecords,
  ) {
    if (toolRecords.isEmpty) return message;
    final byId = <String, ToolExecution>{
      for (final tool in message.toolExecutions) tool.id: tool,
    };
    for (final record in toolRecords) {
      if (record.deleted) {
        byId.remove(record.id.substring(record.id.lastIndexOf('/') + 1));
        continue;
      }
      final value = record.value;
      if (value == null) continue;
      try {
        final tool = ToolExecution.fromJson(value);
        byId[tool.id] = tool;
      } on Object {
        // A malformed tool must not drop the message text.
      }
    }
    // Preserve the message's first-seen tool order, then append stragglers.
    final ordered = <ToolExecution>[];
    final seen = <String>{};
    for (final tool in message.toolExecutions) {
      final current = byId[tool.id];
      if (current != null && seen.add(tool.id)) ordered.add(current);
    }
    for (final tool in byId.values) {
      if (seen.add(tool.id)) ordered.add(tool);
    }
    return message.copyWith(toolExecutions: ordered);
  }
}
