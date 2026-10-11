/// 全局异常体系
sealed class AppException implements Exception {
  final String message;
  final Object? details;

  const AppException(this.message, [this.details]);

  @override
  String toString() =>
      '$runtimeType: $message${details != null ? ' ($details)' : ''}';
}

/// SSH 连接异常
class SSHConnectionException extends AppException {
  const SSHConnectionException(super.message, [super.details]);
}

/// SSH 鉴权异常 (密码错误或私钥无效)
class SSHAuthException extends AppException {
  const SSHAuthException(super.message, [super.details]);
}

/// 主机公钥指纹不匹配异常 (MITM 风险)
class HostKeyMismatchException extends AppException {
  final String host;
  final String expectedFingerprint;
  final String actualFingerprint;

  const HostKeyMismatchException({
    required this.host,
    required this.expectedFingerprint,
    required this.actualFingerprint,
  }) : super('Host key fingerprint mismatch for $host');
}

/// SFTP 操作异常
class SFTPException extends AppException {
  const SFTPException(super.message, [super.details]);
}

/// ACP 协议交互异常
class ACPException extends AppException {
  const ACPException(super.message, [super.details]);
}

/// Docker CLI execution failure with the remote exit code preserved.
class DockerExecutionException extends AppException {
  final int exitCode;

  const DockerExecutionException(
    String message, {
    required this.exitCode,
    Object? details,
  }) : super(message, details);
}

class SystemExecutionException extends AppException {
  final int exitCode;
  const SystemExecutionException(String message, {
    required this.exitCode, Object? details,
  }) : super(message, details);
}

/// 本地安全存储异常
class StorageException extends AppException {
  const StorageException(super.message, [super.details]);
}

/// 被拒绝的用户命令（对远端执行不安全）。
class ValidationException extends AppException {
  const ValidationException(super.message, [super.details]);
}
