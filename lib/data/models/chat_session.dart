import 'chat_run_settings.dart';

enum AgentType {
  claudeCode('Claude CodeX', 'Anthropic ACP Protocol · High Reasoning'),
  codex('OpenAI Codex', 'OpenAI ACP Agent · Coding & Scripting'),
  openCode('OpenCode ACP', 'Open-Source Native ACP Agent · Multi-model');

  final String displayName;
  final String description;
  const AgentType(this.displayName, this.description);

  static AgentType fromString(String val) {
    for (final type in AgentType.values) {
      if (type.name.toLowerCase() == val.toLowerCase() ||
          type.displayName.toLowerCase() == val.toLowerCase()) {
        return type;
      }
    }
    return AgentType.claudeCode;
  }
}

/// 旧 `agentType` 字符串到稳定 `agentId` 的唯一迁移表。
///
/// 迁移逻辑（模型反序列化与 AgentRepository）必须只依赖此表，避免出现第二份
/// 映射导致行为漂移。键为小写后的历史值。
const Map<String, String> kLegacyAgentTypeToId = {
  'claudecode': 'builtin-claude-code',
  'claude codex': 'builtin-claude-code',
  'claude code': 'builtin-claude-code',
  'codex': 'builtin-codex',
  'openai codex': 'builtin-codex',
  'opencode': 'builtin-opencode',
  'opencode acp': 'builtin-opencode',
  'open-code': 'builtin-opencode',
  'agy': 'builtin-agy',
  'antigravity': 'builtin-agy',
};

enum MessageRole { user, assistant, system }

enum ChatTurnStatus { streaming, completed, interrupted, failed }

enum ToolExecutionStatus { pending, running, completed, failed }

enum PlanStepStatus { pending, inProgress, completed, failed }

class PlanStep {
  final String id;
  final String title;
  final PlanStepStatus status;

  const PlanStep({
    required this.id,
    required this.title,
    this.status = PlanStepStatus.pending,
  });

  PlanStep copyWith({String? id, String? title, PlanStepStatus? status}) {
    return PlanStep(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status.name,
  };

  factory PlanStep.fromJson(Map<String, dynamic> json) => PlanStep(
    id: json['id'] as String,
    title: json['title'] as String,
    status: PlanStepStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => PlanStepStatus.pending,
    ),
  );
}

class ToolExecution {
  final bool hasMoreOutput;
  final int? outputLength;
  final List<String> locations;
  final String id;
  final String name;
  final String command;
  final ToolExecutionStatus status;
  final String? output;
  final int? executionTimeMs;

  const ToolExecution({
    this.hasMoreOutput = false,
    this.outputLength,
    this.locations = const [],
    required this.id,
    required this.name,
    required this.command,
    this.status = ToolExecutionStatus.pending,
    this.output,
    this.executionTimeMs,
  });

  ToolExecution copyWith({
    bool? hasMoreOutput,
    int? outputLength,
    List<String>? locations,
    String? id,
    String? name,
    String? command,
    ToolExecutionStatus? status,
    String? output,
    int? executionTimeMs,
  }) {
    return ToolExecution(
      hasMoreOutput: hasMoreOutput ?? this.hasMoreOutput,
      outputLength: outputLength ?? this.outputLength,
      locations: locations ?? this.locations,
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      status: status ?? this.status,
      output: output ?? this.output,
      executionTimeMs: executionTimeMs ?? this.executionTimeMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'hasMoreOutput': hasMoreOutput,
    'outputLength': outputLength,
    'locations': locations,
    'id': id,
    'name': name,
    'command': command,
    'status': status.name,
    'output': output,
    'executionTimeMs': executionTimeMs,
  };

  factory ToolExecution.fromJson(Map<String, dynamic> json) => ToolExecution(
    hasMoreOutput: json['hasMoreOutput'] as bool? ?? false,
    outputLength: (json['outputLength'] as num?)?.toInt(),
    locations: (json['locations'] as List? ?? const []).cast<String>(),
    id: json['id'] as String,
    name: json['name'] as String,
    command: json['command'] as String,
    status: ToolExecutionStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => ToolExecutionStatus.pending,
    ),
    output: json['output'] as String?,
    executionTimeMs: (json['executionTimeMs'] as num?)?.toInt(),
  );
}

class ChatPermissionOption {
  final String id;
  final String name;
  final String kind;
  const ChatPermissionOption({
    required this.id,
    required this.name,
    required this.kind,
  });
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'kind': kind};
  factory ChatPermissionOption.fromJson(Map<String, dynamic> json) =>
      ChatPermissionOption(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: json['kind'] as String,
      );
}

class PermissionRequest {
  final String id;
  final String toolName;
  final String command;
  final String description;
  final bool isDangerous;
  final List<ChatPermissionOption> options;

  const PermissionRequest({
    required this.id,
    required this.toolName,
    required this.command,
    required this.description,
    this.isDangerous = false,
    this.options = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'toolName': toolName,
    'command': command,
    'description': description,
    'isDangerous': isDangerous,
    'options': options.map((option) => option.toJson()).toList(),
  };

  factory PermissionRequest.fromJson(Map<String, dynamic> json) =>
      PermissionRequest(
        id: json['id'] as String,
        toolName: json['toolName'] as String,
        command: json['command'] as String,
        description: json['description'] as String,
        isDangerous: (json['isDangerous'] as bool?) ?? false,
        options: (json['options'] as List? ?? const [])
            .map(
              (option) => ChatPermissionOption.fromJson(
                Map<String, dynamic>.from(option as Map),
              ),
            )
            .toList(),
      );
}

class ChatAttachment {
  final String id, name, mimeType;
  final int sizeBytes;
  final String? localPath, uri;
  bool get isImage => mimeType.startsWith('image/');
  const ChatAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    this.localPath,
    this.uri,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    'localPath': localPath,
    'uri': uri,
  };
  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
    id: json['id'] is String ? json['id'] as String : '',
    name: json['name'] is String ? json['name'] as String : 'resource',
    mimeType: json['mimeType'] is String
        ? json['mimeType'] as String
        : 'application/octet-stream',
    sizeBytes: json['sizeBytes'] is num
        ? (json['sizeBytes'] as num).toInt().clamp(0, 1 << 53)
        : 0,
    localPath: json['localPath'] is String ? json['localPath'] as String : null,
    uri: json['uri'] is String ? json['uri'] as String : null,
  );
}

class ChatMessage {
  final String? remoteMessageId;
  final List<ChatAttachment> attachments;
  final ChatTurnStatus status;
  final String? agentId;
  final String id;
  final MessageRole role;
  final String content;
  final String? thinking;
  final List<PlanStep> planSteps;
  final List<ToolExecution> toolExecutions;
  final PermissionRequest? pendingPermission;
  final DateTime createdAt;

  const ChatMessage({
    this.remoteMessageId,
    this.attachments = const [],
    this.status = ChatTurnStatus.completed,
    this.agentId,
    required this.id,
    required this.role,
    required this.content,
    this.thinking,
    this.planSteps = const [],
    this.toolExecutions = const [],
    this.pendingPermission,
    required this.createdAt,
  });

  ChatMessage copyWith({
    String? remoteMessageId,
    List<ChatAttachment>? attachments,
    ChatTurnStatus? status,
    String? agentId,
    String? id,
    MessageRole? role,
    String? content,
    String? thinking,
    List<PlanStep>? planSteps,
    List<ToolExecution>? toolExecutions,
    PermissionRequest? pendingPermission,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      remoteMessageId: remoteMessageId ?? this.remoteMessageId,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
      agentId: agentId ?? this.agentId,
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      thinking: thinking ?? this.thinking,
      planSteps: planSteps ?? this.planSteps,
      toolExecutions: toolExecutions ?? this.toolExecutions,
      pendingPermission: pendingPermission,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'remoteMessageId': remoteMessageId,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'status': status.name,
    'agentId': agentId,
    'id': id,
    'role': role.name,
    'content': content,
    'thinking': thinking,
    'planSteps': planSteps.map((e) => e.toJson()).toList(),
    'toolExecutions': toolExecutions.map((e) => e.toJson()).toList(),
    'pendingPermission': pendingPermission?.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    remoteMessageId: json['remoteMessageId'] as String?,
    attachments: (json['attachments'] as List? ?? const [])
        .map(
          (a) => ChatAttachment.fromJson(Map<String, dynamic>.from(a as Map)),
        )
        .toList(),
    status:
        ChatTurnStatus.values
            .where((s) => s.name == json['status'])
            .firstOrNull ??
        ChatTurnStatus.completed,
    agentId: json['agentId'] as String?,
    id: json['id'] as String,
    role: MessageRole.values.firstWhere(
      (e) => e.name == json['role'],
      orElse: () => MessageRole.system,
    ),
    content: json['content'] as String,
    thinking: json['thinking'] as String?,
    planSteps:
        (json['planSteps'] as List<dynamic>?)
            ?.map((e) => PlanStep.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    toolExecutions:
        (json['toolExecutions'] as List<dynamic>?)
            ?.map((e) => ToolExecution.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    pendingPermission: json['pendingPermission'] != null
        ? PermissionRequest.fromJson(
            json['pendingPermission'] as Map<String, dynamic>,
          )
        : null,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class AgentChatContext {
  final String? remoteSessionId;
  final int syncedMessageCount;
  const AgentChatContext({this.remoteSessionId, this.syncedMessageCount = 0});
  Map<String, dynamic> toJson() => {
    'remoteSessionId': remoteSessionId,
    'syncedMessageCount': syncedMessageCount,
  };
  factory AgentChatContext.fromJson(Map<String, dynamic> json) =>
      AgentChatContext(
        remoteSessionId: json['remoteSessionId'] as String?,
        syncedMessageCount: (json['syncedMessageCount'] as num?)?.toInt() ?? 0,
      );
}

class ChatSession {
  final bool historyImportIncomplete;
  final int messageOffset;
  final int totalMessageCount;
  final Map<String, ChatRunSettings> agentRunSettings;
  final Map<String, AgentChatContext> agentContexts;
  final List<String> participantAgentIds;
  bool includesAgent(String id) =>
      agentId == id || participantAgentIds.contains(id);
  AgentChatContext contextFor(String id) =>
      agentContexts[id] ??
      AgentChatContext(
        remoteSessionId: agentId == id ? remoteSessionId : null,
        syncedMessageCount: agentId == id && remoteSessionId != null
            ? messageOffset + messages.length
            : 0,
      );
  final String id;
  final String title;
  final String? serverId;
  final String workingDirectory;
  final String? remoteSessionId;

  /// 稳定 Agent 标识（如 `builtin-codex`）。新会话必须写入此字段。
  final String? agentId;

  /// 旧版本字段，仅在读取历史数据时存在；新会话不再写入。
  final AgentType? agentType;

  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const ChatSession({
    this.historyImportIncomplete = false,
    this.messageOffset = 0,
    this.totalMessageCount = 0,
    this.agentRunSettings = const {},
    this.agentContexts = const {},
    this.participantAgentIds = const [],
    required this.id,
    required this.title,
    this.serverId,
    this.workingDirectory = '/root',
    this.remoteSessionId,
    this.agentId,
    this.agentType,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  ChatSession copyWith({
    bool? historyImportIncomplete,
    int? messageOffset,
    int? totalMessageCount,
    Map<String, ChatRunSettings>? agentRunSettings,
    Map<String, AgentChatContext>? agentContexts,
    List<String>? participantAgentIds,
    String? id,
    String? title,
    String? serverId,
    String? workingDirectory,
    String? remoteSessionId,
    String? agentId,
    AgentType? agentType,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      historyImportIncomplete:
          historyImportIncomplete ?? this.historyImportIncomplete,
      messageOffset: messageOffset ?? this.messageOffset,
      totalMessageCount: totalMessageCount ?? this.totalMessageCount,
      agentRunSettings: agentRunSettings ?? this.agentRunSettings,
      agentContexts: agentContexts ?? this.agentContexts,
      participantAgentIds: participantAgentIds ?? this.participantAgentIds,
      id: id ?? this.id,
      title: title ?? this.title,
      serverId: serverId ?? this.serverId,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      remoteSessionId: remoteSessionId ?? this.remoteSessionId,
      agentId: agentId ?? this.agentId,
      agentType: agentType ?? this.agentType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
    'historyImportIncomplete': historyImportIncomplete,
    'messageOffset': messageOffset,
    'totalMessageCount': totalMessageCount,
    'agentRunSettings': agentRunSettings.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'agentContexts': agentContexts.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'participantAgentIds': participantAgentIds,
    'id': id,
    'title': title,
    'agentId': agentId,
    'serverId': serverId,
    'workingDirectory': workingDirectory,
    'remoteSessionId': remoteSessionId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((e) => e.toJson()).toList(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawAgentId = json['agentId'] as String?;
    final rawAgentType = json['agentType'] as String?;
    final legacy = (rawAgentType == null || rawAgentType.isEmpty)
        ? null
        : kLegacyAgentTypeToId[rawAgentType.toLowerCase()];
    return ChatSession(
      historyImportIncomplete:
          json['historyImportIncomplete'] as bool? ?? false,
      messageOffset: (json['messageOffset'] as num?)?.toInt() ?? 0,
      totalMessageCount:
          (json['totalMessageCount'] as num?)?.toInt() ??
          (json['messages'] as List?)?.length ??
          0,
      agentRunSettings:
          (json['agentRunSettings'] as Map<String, dynamic>? ?? {}).map(
            (key, value) => MapEntry(
              key,
              ChatRunSettings.fromJson(value as Map<String, dynamic>),
            ),
          ),
      agentContexts: (json['agentContexts'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(
          key,
          AgentChatContext.fromJson(value as Map<String, dynamic>),
        ),
      ),
      participantAgentIds: (json['participantAgentIds'] as List<dynamic>? ?? [])
          .cast<String>(),
      id: json['id'] as String,
      title: json['title'] as String,
      serverId: json['serverId'] as String?,
      workingDirectory: json['workingDirectory'] as String? ?? '/root',
      remoteSessionId: json['remoteSessionId'] as String?,
      agentId: (rawAgentId == null || rawAgentId.isEmpty) ? legacy : rawAgentId,
      agentType: rawAgentType == null
          ? null
          : AgentType.fromString(rawAgentType),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      messages:
          (json['messages'] as List<dynamic>?)
              ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
