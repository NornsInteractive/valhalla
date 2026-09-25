enum AuthType {
  password,
  privateKey;

  static AuthType fromString(String value) {
    return AuthType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AuthType.password,
    );
  }
}

class ServerProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final AuthType authType;
  final String? privateKeyPath;
  final List<String> tags;
  final DateTime? lastConnectedAt;

  const ServerProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.authType = AuthType.password,
    this.privateKeyPath,
    this.tags = const [],
    this.lastConnectedAt,
  });

  /// Fields that identify the remote SSH endpoint and authentication mode.
  bool hasSameConnectionSettings(ServerProfile other) =>
      id == other.id &&
      host == other.host &&
      port == other.port &&
      username == other.username &&
      authType == other.authType &&
      privateKeyPath == other.privateKeyPath;

  ServerProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    AuthType? authType,
    String? privateKeyPath,
    List<String>? tags,
    DateTime? lastConnectedAt,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      privateKeyPath: privateKeyPath ?? this.privateKeyPath,
      tags: tags ?? this.tags,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'authType': authType.name,
      'privateKeyPath': privateKeyPath,
      'tags': tags,
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    };
  }

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    return ServerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: (json['port'] as num?)?.toInt() ?? 22,
      username: json['username'] as String,
      authType: AuthType.fromString(
        (json['authType'] as String?) ?? 'password',
      ),
      privateKeyPath: json['privateKeyPath'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.tryParse(json['lastConnectedAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
