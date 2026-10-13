import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;
import '../../data/models/agent_profile.dart';
import '../../core/utils/shell_quote.dart';
import '../../core/utils/file_preview.dart';
import '../../core/services/app_diagnostics.dart';
import '../cli/agent_execution_target.dart';
import '../sftp/sftp_client_service.dart';

/// The selected agent's filesystem, never the host filesystem for containers.
class AcpWorkspaceFiles {
  final SSHClient client;
  final AgentProfile profile;
  final Set<SSHSession> _commands = {};
  SftpClient? _sftp;
  bool _closed = false;
  AcpWorkspaceFiles(this.client, this.profile);
  static String normalize(String path) {
    if (!path.startsWith('/') ||
        path.contains('\u0000') ||
        path.contains('\n')) {
      throw ArgumentError('ACP_FILE_PATH_INVALID');
    }
    return p.posix.normalize(path);
  }

  static String? mimeType(String name) {
    final ext = p.posix.extension(name).toLowerCase();
    const images = {
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.webp': 'image/webp',
      '.gif': 'image/gif',
      '.bmp': 'image/bmp',
    };
    return images[ext] ??
        (FilePreview.isTextPreviewable(name) ? 'text/plain' : null);
  }

  Future<Uint8List> _run(
    String command,
    int limit, {
    bool directoryListing = false,
  }) async {
    if (_closed) throw StateError('ACP_FILE_READ_CANCELLED');
    final session = await client.execute(agentTargetCommand(profile, command));
    if (_closed) {
      session.close();
      throw StateError('ACP_FILE_READ_CANCELLED');
    }
    _commands.add(session);
    final errors = BytesBuilder(copy: false);
    final stderr = session.stderr.listen((chunk) {
      final remaining = 8192 - errors.length;
      if (remaining > 0) errors.add(chunk.take(remaining).toList());
    });
    try {
      final builder = BytesBuilder(copy: false);
      await (() async {
        await for (final chunk in session.stdout) {
          if (builder.length + chunk.length > limit) {
            throw StateError('ACP_ATTACHMENT_TOO_LARGE');
          }
          builder.add(chunk);
        }
        await session.done;
      })().timeout(const Duration(seconds: 20));
      if (_closed) throw StateError('ACP_FILE_READ_CANCELLED');
      if (session.exitCode != 0) {
        if (directoryListing) {
          final message = utf8.decode(errors.toBytes(), allowMalformed: true);
          if (message.contains('Permission denied')) {
            throw StateError('ACP_DIRECTORY_PERMISSION_DENIED');
          }
          if (message.contains('No such file or directory')) {
            throw StateError('ACP_DIRECTORY_NOT_FOUND');
          }
        }
        throw StateError('ACP_FILE_READ_FAILED');
      }
      return builder.takeBytes();
    } finally {
      session.close();
      _commands.remove(session);
      await stderr.cancel();
    }
  }

  Future<SftpClient> _host() async {
    if (_closed) throw StateError('ACP_FILE_READ_CANCELLED');
    final existing = _sftp;
    if (existing != null) return existing;
    final opened = await client
        .sftp()
        .then((value) async {
          if (_closed) {
            await value.close();
            throw StateError('ACP_FILE_READ_CANCELLED');
          }
          return value;
        })
        .timeout(const Duration(seconds: 20));
    if (_closed) {
      opened.close();
      throw StateError('ACP_FILE_READ_CANCELLED');
    }
    if (_sftp != null) {
      opened.close();
      return _sftp!;
    }
    return _sftp = opened;
  }

  Future<String> defaultDirectory() async {
    final path = utf8.decode(await _run('pwd -P', 16384)).trim();
    return normalize(path);
  }

  Future<List<SftpFileItem>> list(String path) async {
    path = normalize(path);
    final result = <SftpFileItem>[];
    void add(
      String name,
      bool directory,
      int size,
      int modified, {
      bool symbolicLink = false,
      String? linkError,
    }) {
      if (name.isEmpty || name == '.' || name == '..' || name.contains('/')) {
        return;
      }
      result.add(
        SftpFileItem(
          name: name,
          path: p.posix.join(path, name),
          isDirectory: directory,
          isSymbolicLink: symbolicLink,
          linkTargetErrorCode: linkError,
          sizeBytes: size,
          formattedSize: SftpFileItem.formatBytes(size),
          permissions: '',
          modified: '',
          modifiedEpoch: modified,
        ),
      );
      // shortcut: bound directory metadata at 10k; add remote paging if exceeded.
      if (result.length > 10000) throw StateError('ACP_DIRECTORY_TOO_LARGE');
    }

    if (profile.executionTarget != 'docker') {
      final sftp = await _host();
      await for (final batch
          in sftp.readdir(path).timeout(const Duration(seconds: 20))) {
        if (_closed) throw StateError('ACP_FILE_READ_CANCELLED');
        var index = 0;
        Future<void> resolveEntries() async {
          while (index < batch.length) {
            final entry = batch[index++];
            if (entry.filename == '.' || entry.filename == '..') continue;
            var attrs = entry.attr;
            String? linkError;
            if (attrs.isSymbolicLink) {
              try {
                attrs = await sftp
                    .stat(p.posix.join(path, entry.filename))
                    .timeout(const Duration(seconds: 20));
                if (attrs.isSymbolicLink ||
                    attrs.type == SftpFileType.unknown) {
                  linkError = SftpFileItem.linkTargetUnavailableCode;
                }
              } on SftpStatusError catch (error) {
                if (error.code == SftpStatusCode.noConnection ||
                    error.code == SftpStatusCode.connectionLost ||
                    error.code == SftpStatusCode.badMessage) {
                  rethrow;
                }
                linkError = error.code == SftpStatusCode.permissionDenied
                    ? SftpFileItem.linkTargetPermissionDeniedCode
                    : SftpFileItem.linkTargetUnavailableCode;
              }
            }
            if (_closed) throw StateError('ACP_FILE_READ_CANCELLED');
            add(
              entry.filename,
              linkError == null && attrs.isDirectory,
              attrs.size ?? 0,
              attrs.modifyTime ?? 0,
              symbolicLink: entry.attr.isSymbolicLink,
              linkError: linkError,
            );
          }
        }

        await Future.wait(
          List.generate(
            batch.length < 4 ? batch.length : 4,
            (_) => resolveEntries(),
          ),
        );
      }
    } else {
      // NUL fields preserve spaces/quotes/newlines. No shell name interpolation.
      final bytes = await _run(
        'test -d ${cliShellQuote(path)} || { LC_ALL=C ls -d -- ${cliShellQuote(path)} >&2; exit 1; }; '
        'test -r ${cliShellQuote(path)} || { printf \'Permission denied\\n\' >&2; exit 1; }; '
        'LC_ALL=C find -H ${cliShellQuote(path)} -mindepth 1 -maxdepth 1 -printf \'%f\\0%y%Y\\0%s\\0%T@\\0\'',
        4 * 1024 * 1024,
        directoryListing: true,
      );
      final fields = utf8.decode(bytes).split('\u0000');
      for (var i = 0; i + 3 < fields.length; i += 4) {
        final type = fields[i + 1];
        final symbolicLink = type.startsWith('l');
        final targetType = type.isEmpty ? '' : type.substring(type.length - 1);
        final linkError = symbolicLink && targetType != 'd' && targetType != 'f'
            ? SftpFileItem.linkTargetUnavailableCode
            : null;
        add(
          fields[i],
          targetType == 'd',
          int.tryParse(fields[i + 2]) ?? 0,
          double.tryParse(fields[i + 3])?.floor() ?? 0,
          symbolicLink: symbolicLink,
          linkError: linkError,
        );
      }
    }
    result.sort(
      (a, b) => a.isDirectory != b.isDirectory
          ? (a.isDirectory ? -1 : 1)
          : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return result;
  }

  Future<Uint8List> read(String path, int limit) async {
    path = normalize(path);
    if (profile.executionTarget == 'docker') {
      final bytes = await _run(
        'test -f ${cliShellQuote(path)} && head -c ${limit + 1} -- ${cliShellQuote(path)}',
        limit + 1,
      );
      if (bytes.length > limit) throw StateError('ACP_ATTACHMENT_TOO_LARGE');
      return bytes;
    }
    final sftp = await _host();
    final attrs = await sftp.stat(path).timeout(const Duration(seconds: 20));
    if (!attrs.isFile) throw StateError('ACP_FILE_READ_FAILED');
    if ((attrs.size ?? 0) > limit) throw StateError('ACP_ATTACHMENT_TOO_LARGE');
    final file = await sftp.open(path).timeout(const Duration(seconds: 20));
    try {
      final bytes = await file
          .readBytes(length: limit + 1)
          .timeout(const Duration(seconds: 20));
      if (bytes.length > limit) throw StateError('ACP_ATTACHMENT_TOO_LARGE');
      return bytes;
    } finally {
      await file.close();
    }
  }

  void close() {
    _closed = true;
    for (final session in _commands) {
      session.close();
    }
    _commands.clear();
    final sftp = _sftp;
    _sftp = null;
    if (sftp != null) {
      unawaited(
        sftp.close().catchError((Object error, StackTrace stack) {
          unawaited(
            AppDiagnostics.instance.record('acp.files.close', error, stack),
          );
        }),
      );
    }
  }
}
