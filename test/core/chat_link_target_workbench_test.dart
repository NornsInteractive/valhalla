import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/chat_link_target.dart';

void main() {
  const cwd = '/project';

  group('ChatLinkTarget - supported links', () {
    test('http and https links are web targets', () {
      for (final href in [
        'http://example.com/a',
        'https://example.com/b?q=1',
      ]) {
        final target = ChatLinkTarget.parse(href, workingDirectory: cwd);
        expect(target.kind, ChatLinkKind.web, reason: href);
        expect(target.uri.toString(), href);
        expect(target.isRemoteLoopback, isFalse);
      }
    });

    test('mailto links are mail targets', () {
      final target = ChatLinkTarget.parse(
        'mailto:user@example.com',
        workingDirectory: cwd,
      );
      expect(target.kind, ChatLinkKind.mail);
      expect(target.uri?.path, 'user@example.com');
    });

    test('anchors are anchor targets', () {
      final target = ChatLinkTarget.parse('#details', workingDirectory: cwd);
      expect(target.kind, ChatLinkKind.anchor);
      expect(target.path, 'details');
    });

    test('relative path with colon line suffix', () {
      final target = ChatLinkTarget.parse(
        'some/path.dart:42',
        workingDirectory: cwd,
      );
      expect(target.kind, ChatLinkKind.remoteFile);
      expect(target.path, '/project/some/path.dart');
      expect(target.line, 42);
      expect(target.outsideWorkspace, isFalse);
    });

    test('relative path with #L line suffix', () {
      final target = ChatLinkTarget.parse(
        'some/path.dart#L42',
        workingDirectory: cwd,
      );
      expect(target.kind, ChatLinkKind.remoteFile);
      expect(target.path, '/project/some/path.dart');
      expect(target.line, 42);
    });

    test('line range keeps the first line', () {
      final target = ChatLinkTarget.parse(
        'lib/file.dart:42:7',
        workingDirectory: cwd,
      );
      expect(target.kind, ChatLinkKind.remoteFile);
      expect(target.line, 42);
    });

    test('absolute path outside workspace is flagged', () {
      final target = ChatLinkTarget.parse(
        '/other/path.dart:10',
        workingDirectory: cwd,
      );
      expect(target.kind, ChatLinkKind.remoteFile);
      expect(target.path, '/other/path.dart');
      expect(target.line, 10);
      expect(target.outsideWorkspace, isTrue);
    });

    test('file URI is treated as a path', () {
      final target = ChatLinkTarget.parse(
        'file:///project/lib/main.dart',
        workingDirectory: cwd,
      );
      expect(target.kind, ChatLinkKind.remoteFile);
      expect(target.path, '/project/lib/main.dart');
    });
  });

  group('ChatLinkTarget - blocked input', () {
    test('javascript and data schemes are unsupported', () {
      for (final href in [
        'javascript:alert(1)',
        'data:text/html,<b>blocked</b>',
      ]) {
        final target = ChatLinkTarget.parse(href, workingDirectory: cwd);
        expect(target.kind, ChatLinkKind.unsupported, reason: href);
      }
    });

    test(
      'empty, control characters and non-file URI authorities are blocked',
      () {
        for (final href in [
          '',
          '   ',
          '\x00test',
          'http://example.com/\x01',
          'file://host/path',
        ]) {
          final target = ChatLinkTarget.parse(href, workingDirectory: cwd);
          expect(target.kind, ChatLinkKind.unsupported, reason: href);
        }
      },
    );

    test('relative working directory cannot resolve file targets', () {
      final target = ChatLinkTarget.parse(
        'some/path.dart:1',
        workingDirectory: 'project',
      );
      expect(target.kind, ChatLinkKind.unsupported);
    });
  });

  group('ChatLinkTarget - remote loopback', () {
    test('localhost and 127.0.0.1 are flagged for confirmation', () {
      for (final href in [
        'http://localhost:3000',
        'http://127.0.0.1:3000',
        'http://[::1]:3000',
      ]) {
        final target = ChatLinkTarget.parse(href, workingDirectory: cwd);
        expect(target.kind, ChatLinkKind.web, reason: href);
        expect(target.isRemoteLoopback, isTrue, reason: href);
      }
    });

    test('non-loopback host is not flagged', () {
      final target = ChatLinkTarget.parse(
        'http://192.168.1.10:8080',
        workingDirectory: cwd,
      );
      expect(target.kind, ChatLinkKind.web);
      expect(target.isRemoteLoopback, isFalse);
    });
  });
}
