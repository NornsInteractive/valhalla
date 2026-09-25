class HostKeyEntry {
  final String hostPort;
  final String keyType;
  final String fingerprintSha256;
  final DateTime trustedAt;

  const HostKeyEntry({
    required this.hostPort,
    required this.keyType,
    required this.fingerprintSha256,
    required this.trustedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'hostPort': hostPort,
      'keyType': keyType,
      'fingerprintSha256': fingerprintSha256,
      'trustedAt': trustedAt.toIso8601String(),
    };
  }

  factory HostKeyEntry.fromJson(Map<String, dynamic> json) {
    return HostKeyEntry(
      hostPort: json['hostPort'] as String,
      keyType: json['keyType'] as String,
      fingerprintSha256: json['fingerprintSha256'] as String,
      trustedAt: DateTime.parse(json['trustedAt'] as String),
    );
  }
}
