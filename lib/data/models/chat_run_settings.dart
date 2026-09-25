enum OperationPermissionPolicy {
  askEveryTime,
  autoAllowSafe,
  autoAllowAll;

  static OperationPermissionPolicy fromStorage(String? value) =>
      values.where((entry) => entry.name == value).firstOrNull ?? askEveryTime;
}

class ChatRunSettings {
  final String? modelId;
  final String? reasoningId;
  final OperationPermissionPolicy permissionPolicy;

  const ChatRunSettings({
    this.modelId,
    this.reasoningId,
    this.permissionPolicy = OperationPermissionPolicy.askEveryTime,
  });

  ChatRunSettings copyWith({
    String? modelId,
    bool clearModel = false,
    String? reasoningId,
    bool clearReasoning = false,
    OperationPermissionPolicy? permissionPolicy,
  }) => ChatRunSettings(
    modelId: clearModel ? null : modelId ?? this.modelId,
    reasoningId: clearReasoning ? null : reasoningId ?? this.reasoningId,
    permissionPolicy: permissionPolicy ?? this.permissionPolicy,
  );

  Map<String, dynamic> toJson() => {
    'modelId': modelId,
    'reasoningId': reasoningId,
    'permissionPolicy': permissionPolicy.name,
  };

  factory ChatRunSettings.fromJson(Map<String, dynamic> json) =>
      ChatRunSettings(
        modelId: json['modelId'] as String?,
        reasoningId: json['reasoningId'] as String?,
        permissionPolicy: OperationPermissionPolicy.fromStorage(
          json['permissionPolicy'] as String?,
        ),
      );
}

class ChatSettingOption {
  final String id;
  final String label;
  final String? description;

  const ChatSettingOption(this.id, this.label, {this.description});
}

class AgentRuntimeCapabilities {
  final List<ChatSettingOption> models;
  final List<ChatSettingOption> reasoningLevels;
  final bool supportsStructuredSettings;

  const AgentRuntimeCapabilities({
    this.models = const [],
    this.reasoningLevels = const [],
    this.supportsStructuredSettings = false,
  });
}
