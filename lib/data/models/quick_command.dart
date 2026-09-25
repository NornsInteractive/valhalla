class QuickCommand {
  final String id;
  final String title;
  final String command;
  final String category;
  final String description;
  final String iconName;
  final bool isDangerous;
  final bool requiresSudo;
  final String? paramPlaceholder;

  const QuickCommand({
    required this.id,
    required this.title,
    required this.command,
    required this.category,
    required this.description,
    this.iconName = 'terminal',
    this.isDangerous = false,
    this.requiresSudo = false,
    this.paramPlaceholder,
  });

  /// 提取指令中的动态模板参数列表，如 {{container_id}}
  List<String> extractParams() {
    final regex = RegExp(r'\{\{([a-zA-Z0-9_-]+)\}\}');
    final matches = regex.allMatches(command);
    return matches.map((m) => m.group(1)!).toSet().toList();
  }

  /// 填充模板参数并返回最终执行命令
  String applyParams(Map<String, String> values) {
    var result = command;
    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  QuickCommand copyWith({
    String? id,
    String? title,
    String? command,
    String? category,
    String? description,
    String? iconName,
    bool? isDangerous,
    bool? requiresSudo,
    String? paramPlaceholder,
  }) {
    return QuickCommand(
      id: id ?? this.id,
      title: title ?? this.title,
      command: command ?? this.command,
      category: category ?? this.category,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      isDangerous: isDangerous ?? this.isDangerous,
      requiresSudo: requiresSudo ?? this.requiresSudo,
      paramPlaceholder: paramPlaceholder ?? this.paramPlaceholder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'command': command,
      'category': category,
      'description': description,
      'iconName': iconName,
      'isDangerous': isDangerous,
      'requiresSudo': requiresSudo,
      'paramPlaceholder': paramPlaceholder,
    };
  }

  factory QuickCommand.fromJson(Map<String, dynamic> json) {
    return QuickCommand(
      id: json['id'] as String,
      title: json['title'] as String,
      command: json['command'] as String,
      category: (json['category'] as String?) ?? 'System',
      description: (json['description'] as String?) ?? '',
      iconName: (json['iconName'] as String?) ?? 'terminal',
      isDangerous: (json['isDangerous'] as bool?) ?? false,
      requiresSudo: (json['requiresSudo'] as bool?) ?? false,
      paramPlaceholder: json['paramPlaceholder'] as String?,
    );
  }
}
