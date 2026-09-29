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
  final String? modeId;
  final Map<String, Object> configValues;

  const ChatRunSettings({
    this.modelId,
    this.reasoningId,
    this.permissionPolicy = OperationPermissionPolicy.askEveryTime,
    this.modeId,
    this.configValues = const {},
  });

  ChatRunSettings copyWith({
    String? modelId,
    bool clearModel = false,
    String? reasoningId,
    bool clearReasoning = false,
    OperationPermissionPolicy? permissionPolicy,
    String? modeId,
    bool clearMode = false,
    Map<String, Object>? configValues,
  }) => ChatRunSettings(
    modelId: clearModel ? null : modelId ?? this.modelId,
    reasoningId: clearReasoning ? null : reasoningId ?? this.reasoningId,
    permissionPolicy: permissionPolicy ?? this.permissionPolicy,
    modeId: clearMode ? null : modeId ?? this.modeId,
    configValues: configValues ?? this.configValues,
  );

  Map<String, dynamic> toJson() => {
    'modelId': modelId,
    'reasoningId': reasoningId,
    'permissionPolicy': permissionPolicy.name,
    'modeId': modeId,
    'configValues': configValues,
  };

  factory ChatRunSettings.fromJson(Map<String, dynamic> json) =>
      ChatRunSettings(
        modelId: json['modelId'] as String?,
        reasoningId: json['reasoningId'] as String?,
        modeId: json['modeId'] as String?,
        configValues: {
          for (final entry in (json['configValues'] as Map? ?? {}).entries)
            if (entry.key is String &&
                (entry.value is String || entry.value is bool))
              entry.key as String: entry.value as Object,
        },
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
  final List<ChatSettingOption> modes;
  final String? currentModelId;
  final String? currentReasoningId;
  final String? currentModeId;
  final List<ChatRuntimeSetting> extraSettings;

  const AgentRuntimeCapabilities({
    this.models = const [],
    this.reasoningLevels = const [],
    this.supportsStructuredSettings = false,
    this.modes = const [],
    this.currentModelId,
    this.currentReasoningId,
    this.currentModeId,
    this.extraSettings = const [],
  });
}

/// Agent-advertised settings which do not belong to a dedicated selector.
class ChatRuntimeSetting {
  final String id;
  final String label;
  final Object currentValue;
  final List<ChatSettingOption> options;
  final bool isBoolean;

  const ChatRuntimeSetting({
    required this.id,
    required this.label,
    required this.currentValue,
    this.options = const [],
    this.isBoolean = false,
  });
}
