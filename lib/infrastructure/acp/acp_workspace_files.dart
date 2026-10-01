import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;
import '../../data/models/agent_profile.dart';
import '../../core/utils/shell_quote.dart';
import '../../core/utils/file_preview.dart';
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

  Future<Uint8List> _run(String command, int limit) async {
    if (_closed) throw StateError('ACP_FILE_READ_CANCELLED');
    final session = await client.execute(agentTargetCommand(profile, command));
    if (_closed) {
      session.close();
      throw StateError('ACP_FILE_READ_CANCELLED');
    }
    _commands.add(session);
    final stderr = session.stderr.listen((_) {});
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
      if (session.exitCode != 0) throw StateError('ACP_FILE_READ_FAILED');
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
    final opened = await client.sftp().timeout(const Duration(seconds: 20));
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
    void add(String name, bool directory, int size, int modified) {
      if (name == '.' || name == '..' || name.contains('/')) return;
      result.add(
        SftpFileItem(
          name: name,
          path: p.posix.join(path, name),
          isDirectory: directory,
          sizeBytes: size,
          formattedSize: SftpFileItem.formatBytes(size),
          permissions: '',
          modified: '',
          modifiedEpoch: modified,
        ),
      );
      // ponytail: bound directory metadata at 10k; add remote paging if exceeded.
      if (result.length > 10000) throw StateError('ACP_DIRECTORY_TOO_LARGE');
    }

    if (profile.executionTarget != 'docker') {
      final sftp = await _host();
      await for (final batch
          in sftp.readdir(path).timeout(const Duration(seconds: 20))) {
        if (_closed) throw StateError('ACP_FILE_READ_CANCELLED');
        for (final entry in batch) {
          add(
            entry.filename,
            entry.attr.isDirectory,
            entry.attr.size ?? 0,
            entry.attr.modifyTime ?? 0,
          );
        }
      }
    } else {
      // NUL fields preserve spaces/quotes/newlines. No shell name interpolation.
      final bytes = await _run(
        'test -d ${cliShellQuote(path)} && test -r ${cliShellQuote(path)} && '
        'find ${cliShellQuote(path)} -mindepth 1 -maxdepth 1 -printf \'%f\\0%y\\0%s\\0%T@\\0\'',
        4 * 1024 * 1024,
      );
      final fields = utf8.decode(bytes).split('\u0000');
      for (var i = 0; i + 3 < fields.length; i += 4) {
        add(
          fields[i],
          fields[i + 1] == 'd',
          int.tryParse(fields[i + 2]) ?? 0,
          double.tryParse(fields[i + 3])?.floor() ?? 0,
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
    _sftp?.close();
  }
}
