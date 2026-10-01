/// Only facts received through the selected ACP connection; never CLI probes.
class AcpAccountInfo {
  final String kind, label;
  final String? email, plan;
  final DateTime updatedAt;
  const AcpAccountInfo({
    required this.kind,
    required this.label,
    this.email,
    this.plan,
    required this.updatedAt,
  });

  static AcpAccountInfo? fromNotification(Object? params) {
    if (params is! Map || params['authStatus'] is! Map) return null;
    final status = params['authStatus'] as Map;
    if (status['kind'] is! String || status['label'] is! String) return null;
    final account = status['account'];
    return AcpAccountInfo(
      kind: status['kind'] as String,
      label: status['label'] as String,
      email: account is Map && account['email'] is String
          ? account['email'] as String
          : null,
      plan: account is Map && account['plan'] is String
          ? account['plan'] as String
          : null,
      updatedAt: DateTime.now(),
    );
  }
}
