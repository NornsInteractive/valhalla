import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';

/// Stable reason codes for download failures. Every code here is consumed by
/// the file view's mapper, so a silent change breaks the UI text.
void main() {
  const failed = SftpNotifier.downloadFailedCode;

  Object? code(Object error) => SftpNotifier.downloadErrorCode(error);

  group('SftpNotifier.downloadErrorCode', () {
    test('timeout errors are distinguishable from a dropped link', () {
      expect(code(TimeoutException('read')), 'SFTP_DOWNLOAD_TIMEOUT');
      expect(
        code(const SFTPException('SFTP operation timed out')),
        'SFTP_DOWNLOAD_TIMEOUT',
      );
    });

    test('link failures map to DISCONNECTED', () {
      expect(
        code(const SSHConnectionException('SSH_DISCONNECTED')),
        'SFTP_DOWNLOAD_DISCONNECTED',
      );
      expect(
        code(SSHStateError('server closed')),
        'SFTP_DOWNLOAD_DISCONNECTED',
      );
      expect(
        code(const SocketException('Connection reset by peer')),
        'SFTP_DOWNLOAD_DISCONNECTED',
      );
      expect(code(SftpAbortError('aborted')), 'SFTP_DOWNLOAD_DISCONNECTED');
      expect(
        code(SftpStatusError(SftpStatusCode.connectionLost, 'lost')),
        'SFTP_DOWNLOAD_DISCONNECTED',
      );
      expect(
        code(SftpStatusError(SftpStatusCode.noConnection, 'gone')),
        'SFTP_DOWNLOAD_DISCONNECTED',
      );
    });

    test('server status codes keep their own meaning', () {
      expect(
        code(SftpStatusError(SftpStatusCode.permissionDenied, 'denied')),
        'SFTP_DOWNLOAD_PERMISSION_DENIED',
      );
      expect(
        code(SftpStatusError(SftpStatusCode.noSuchFile, 'missing')),
        'SFTP_DOWNLOAD_NOT_FOUND',
      );
      expect(
        code(SftpStatusError(SftpStatusCode.failure, 'generic')),
        failed,
        reason: 'an unclassified server status must not look like a drop',
      );
    });

    test('local write problems are separated by whether the disk is full', () {
      expect(
        code(
          FileSystemException(
            'write',
            '/data/app.apk',
            const OSError('No space left on device', 28),
          ),
        ),
        'SFTP_DOWNLOAD_LOCAL_SPACE',
      );
      expect(
        code(
          FileSystemException(
            'write',
            '/data/app.apk',
            const OSError('Permission denied', 13),
          ),
        ),
        'SFTP_DOWNLOAD_LOCAL_IO',
      );
      expect(
        code(const FileSystemException('write', '/data/app.apk')),
        'SFTP_DOWNLOAD_LOCAL_IO',
        reason: 'an error without osError is still a local failure',
      );
    });

    test('a truncated transfer reports INCOMPLETE, not a generic failure', () {
      expect(
        code(const SFTPException('SFTP_DOWNLOAD_INCOMPLETE')),
        'SFTP_DOWNLOAD_INCOMPLETE',
        reason: 'early EOF is not a timeout even though it is an SFTPException',
      );
      expect(code(const SFTPException('some other problem')), failed);
    });

    test('unknown errors fall back to the download failure code', () {
      expect(code(StateError('boom')), failed);
      expect(code('plain string'), failed);
      expect(failed, 'SFTP_DOWNLOAD_FAILED');
    });

    test('classification never swallows the error object', () {
      final error = SftpStatusError(SftpStatusCode.permissionDenied, 'denied');
      expect(code(error), 'SFTP_DOWNLOAD_PERMISSION_DENIED');
      expect(error.code, SftpStatusCode.permissionDenied);
    });

    test('retryable codes are exactly the timeout and disconnect pair', () {
      const retryable = {'SFTP_DOWNLOAD_TIMEOUT', 'SFTP_DOWNLOAD_DISCONNECTED'};
      expect(retryable, contains('SFTP_DOWNLOAD_TIMEOUT'));
      expect(retryable, contains('SFTP_DOWNLOAD_DISCONNECTED'));
      // Everything else is a permanent condition and must never be retried.
      expect(
        code(SftpStatusError(SftpStatusCode.permissionDenied, 'denied')),
        isNot(anyOf(isIn(retryable))),
      );
      expect(
        code(const SFTPException('SFTP_DOWNLOAD_INCOMPLETE')),
        isNot(anyOf(isIn(retryable))),
      );
      expect(
        code(
          const FileSystemException(
            'write',
            '/p',
            OSError('No space left on device', 28),
          ),
        ),
        isNot(anyOf(isIn(retryable))),
      );
      expect(code(StateError('x')), isNot(anyOf(isIn(retryable))));
    });
  });
}
