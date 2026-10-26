import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:valhalla/infrastructure/acp/acp_workspace_editor_script.dart';

class _EditorResult {
  final int exitCode;
  final Map<String, dynamic> body;

  const _EditorResult(this.exitCode, this.body);
}

Future<_EditorResult> _run(Map<String, dynamic> request) async {
  final process = await Process.start('python3', [
    '-c',
    acpWorkspaceEditorScript,
  ]);
  process.stdin.write(jsonEncode(request));
  await process.stdin.close();
  final stdoutText = await process.stdout.transform(utf8.decoder).join();
  final stderrText = await process.stderr.transform(utf8.decoder).join();
  final exitCode = await process.exitCode;
  expect(stderrText, isEmpty, reason: 'editor script stderr');
  return _EditorResult(
    exitCode,
    Map<String, dynamic>.from(jsonDecode(stdoutText.trim()) as Map),
  );
}

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('valhalla_acp_editor_');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  File createFile(String name, [List<int>? bytes]) {
    final file = File(p.join(temp.path, name));
    file.writeAsBytesSync(bytes ?? const []);
    return file;
  }

  group('ACP workspace editor script', () {
    test('read returns content, target path and revision', () async {
      final file = createFile('read.txt', utf8.encode('hello world'));

      final result = await _run({'path': file.path, 'operation': 'read'});

      expect(result.exitCode, 0);
      expect(result.body['path'], file.path);
      expect(result.body['targetPath'], file.path);
      expect(result.body['content'], 'hello world');
      expect(result.body['revision'], isA<String>());
    });

    test('save writes content when revision and target match', () async {
      final file = createFile('save.txt', utf8.encode('original content'));
      final snapshot = await _run({'path': file.path, 'operation': 'read'});
      expect(snapshot.exitCode, 0);

      final result = await _run({
        'path': file.path,
        'operation': 'save',
        'revision': snapshot.body['revision'],
        'targetPath': snapshot.body['targetPath'],
        'content': 'updated content',
      });

      expect(result.exitCode, 0);
      expect(result.body, {'saved': true});
      expect(file.readAsStringSync(), 'updated content');
    });

    test('save rejects a stale revision without overwriting', () async {
      final file = createFile('conflict.txt', utf8.encode('original content'));
      final snapshot = await _run({'path': file.path, 'operation': 'read'});
      file.writeAsStringSync('external edit');

      final result = await _run({
        'path': file.path,
        'operation': 'save',
        'revision': snapshot.body['revision'],
        'targetPath': snapshot.body['targetPath'],
        'content': 'draft content',
      });

      expect(result.exitCode, 1);
      expect(result.body['error'], 'ACP_FILE_EDIT_CONFLICT');
      expect(file.readAsStringSync(), 'external edit');
    });

    test('read and save follow a symlink to its target', () async {
      final target = createFile('target.txt', utf8.encode('target content'));
      final link = Link(p.join(temp.path, 'link.txt'));
      link.createSync(target.path);

      final snapshot = await _run({'path': link.path, 'operation': 'read'});
      expect(snapshot.exitCode, 0);
      expect(snapshot.body['path'], link.path);
      expect(snapshot.body['targetPath'], target.resolveSymbolicLinksSync());
      expect(snapshot.body['content'], 'target content');

      final result = await _run({
        'path': link.path,
        'operation': 'save',
        'revision': snapshot.body['revision'],
        'targetPath': snapshot.body['targetPath'],
        'content': 'updated through link',
      });

      expect(result.exitCode, 0);
      expect(result.body, {'saved': true});
      expect(target.readAsStringSync(), 'updated through link');
      expect(FileSystemEntity.isLinkSync(link.path), isTrue);
    });

    test('save rejects content over the 1 MiB limit', () async {
      final file = createFile('large.txt', utf8.encode('small'));
      final snapshot = await _run({'path': file.path, 'operation': 'read'});
      final oversized = 'x' * (1024 * 1024 + 1);

      final result = await _run({
        'path': file.path,
        'operation': 'save',
        'revision': snapshot.body['revision'],
        'targetPath': snapshot.body['targetPath'],
        'content': oversized,
      });

      expect(result.exitCode, 1);
      expect(result.body['error'], 'ACP_FILE_NOT_EDITABLE');
      expect(file.readAsStringSync(), 'small');
    });

    test('read rejects invalid UTF-8', () async {
      final file = createFile('invalid.txt', [0xFF, 0xFE]);

      final result = await _run({'path': file.path, 'operation': 'read'});

      expect(result.exitCode, 1);
      expect(result.body['error'], 'ACP_FILE_EDITOR_UNAVAILABLE');
    });

    test('read rejects a relative path', () async {
      final result = await _run({
        'path': 'relative/path.txt',
        'operation': 'read',
      });

      expect(result.exitCode, 1);
      expect(result.body['error'], 'ACP_FILE_PATH_INVALID');
    });
  });
}
