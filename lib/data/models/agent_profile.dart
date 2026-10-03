class AgentProfile {
  final String id;
  final String serverId;
  final String name;
  final String description;
  final String cliCommand;

  /// `host` or `docker`; old profiles default to the SSH host.
  final String executionTarget;

  /// `id` pins a container, `name` follows a recreated container.
  final String containerBinding;
  final String? containerReference;

  /// Optional user/UID (or user:group/UID:GID) used by Docker exec.
  /// Null preserves the image's configured default user.
  final String? containerUser;

  /// ACP 启动命令。为 null 表示该 Agent 没有可用的 ACP 模式，仅作 CLI 使用。
  final String? acpCommand;
  final String? installCommand;

  /// 安装 ACP 组件的命令。仅当 ACP 与 CLI 来自不同包时才需要；
  /// 为空表示 ACP 组件随 [installCommand] 一并安装。
  final String? acpInstallCommand;
  final String? loginCheckCommand;
  final String? loginCommand;
  final DateTime createdAt;
  final DateTime updatedAt;

  AgentProfile({
    required this.id,
    required this.serverId,
    required this.name,
    required this.description,
    required this.cliCommand,
    this.executionTarget = 'host',
    this.containerBinding = 'name',
    this.containerReference,
    this.containerUser,
    this.acpCommand,
    this.installCommand,
    this.acpInstallCommand,
    this.loginCheckCommand,
    this.loginCommand,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  AgentProfile copyWith({
    String? name,
    String? description,
    String? cliCommand,
    String? executionTarget,
    String? containerBinding,
    String? containerReference,
    String? containerUser,
    String? acpCommand,
    String? installCommand,
    String? acpInstallCommand,
    String? loginCheckCommand,
    String? loginCommand,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AgentProfile(
    id: id,
    serverId: serverId,
    name: name ?? this.name,
    description: description ?? this.description,
    cliCommand: cliCommand ?? this.cliCommand,
    executionTarget: executionTarget ?? this.executionTarget,
    containerBinding: containerBinding ?? this.containerBinding,
    containerReference: containerReference ?? this.containerReference,
    containerUser: containerUser ?? this.containerUser,
    acpCommand: acpCommand ?? this.acpCommand,
    installCommand: installCommand ?? this.installCommand,
    acpInstallCommand: acpInstallCommand ?? this.acpInstallCommand,
    loginCheckCommand: loginCheckCommand ?? this.loginCheckCommand,
    loginCommand: loginCommand ?? this.loginCommand,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'serverId': serverId,
    'name': name,
    'description': description,
    'cliCommand': cliCommand,
    'executionTarget': executionTarget,
    'containerBinding': containerBinding,
    'containerReference': containerReference,
    'containerUser': containerUser,
    'acpCommand': acpCommand,
    'installCommand': installCommand,
    'acpInstallCommand': acpInstallCommand,
    'loginCheckCommand': loginCheckCommand,
    'loginCommand': loginCommand,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AgentProfile.fromJson(Map<String, dynamic> json) => AgentProfile(
    id: json['id'] as String,
    serverId: json['serverId'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    cliCommand: json['cliCommand'] as String,
    executionTarget: json['executionTarget'] as String? ?? 'host',
    // Preserve legacy ID bindings; only newly created profiles default to name.
    containerBinding: json['containerBinding'] as String? ?? 'id',
    containerReference: json['containerReference'] as String?,
    containerUser: json['containerUser'] as String?,
    // 为 null 或缺失时表示该配置仅用于 CLI。
    acpCommand: json['acpCommand'] as String?,
    installCommand: json['installCommand'] as String?,
    // 向后兼容：旧版本 JSON 没有该键，读取时为 null。
    acpInstallCommand: json['acpInstallCommand'] as String?,
    loginCheckCommand: json['loginCheckCommand'] as String?,
    loginCommand: json['loginCommand'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      other is AgentProfile &&
      id == other.id &&
      serverId == other.serverId &&
      name == other.name &&
      description == other.description &&
      cliCommand == other.cliCommand &&
      executionTarget == other.executionTarget &&
      containerBinding == other.containerBinding &&
      containerReference == other.containerReference &&
      containerUser == other.containerUser &&
      acpCommand == other.acpCommand &&
      installCommand == other.installCommand &&
      acpInstallCommand == other.acpInstallCommand &&
      loginCheckCommand == other.loginCheckCommand &&
      loginCommand == other.loginCommand &&
      createdAt == other.createdAt &&
      updatedAt == other.updatedAt;
  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    name,
    createdAt,
    updatedAt,
    executionTarget,
    containerBinding,
    containerReference,
    containerUser,
  );
}
