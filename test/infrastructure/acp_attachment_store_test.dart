import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:acpd/acpd.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/infrastructure/acp/acp_attachment_store.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

/// 附件内容寻址存储的回归测试：真实临时文件、限额、损坏输入。
///
/// `directory` 显式注入临时目录，测试绝不读写真实应用支持目录。
void main() {
  late Directory dir;
  late AcpAttachmentStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('valhalla_attach_test_');
    store = AcpAttachmentStore(directory: dir.path);
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  File stored(ChatAttachment a) => File(a.localPath!);

  group('save', () {
    test('写入真实文件，id 是内容 sha256，localPath 可读', () async {
      final bytes = Uint8List.fromList(utf8.encode('abc'));
      final attachment = await store.save(
        'note.txt',
        'text/plain',
        bytes,
        uri: 'file:///work/note.txt',
      );

      expect(attachment.sizeBytes, bytes.length);
      expect(attachment.uri, 'file:///work/note.txt');
      expect(attachment.isImage, isFalse);
      expect(
        attachment.id,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        reason: 'id 必须是内容的 sha256（RFC 6234 向量）',
      );
      expect(stored(attachment).existsSync(), isTrue);
      expect(stored(attachment).path.endsWith(attachment.id), isTrue);
      expect(stored(attachment).readAsBytesSync(), bytes);
      expect(
        dir.listSync().whereType<File>().map((f) => f.path.split('/').last),
        isNot(contains(startsWith('.'))),
        reason: '临时 .part 文件不得残留',
      );
    });

    test('相同内容复用同一文件，附件名字不参与寻址', () async {
      final bytes = Uint8List.fromList(utf8.encode('same'));
      final first = await store.save('a.txt', 'text/plain', bytes);
      final second = await store.save('b.txt', 'text/plain', bytes);
      expect(second.id, first.id);
      expect(second.localPath, first.localPath);
      expect(second.name, 'b.txt');
      expect(dir.listSync().whereType<File>(), hasLength(1));
    });

    test('内容不同则 id 不同，即使文件名相同', () async {
      final a = await store.save(
        'x.txt',
        'text/plain',
        Uint8List.fromList(utf8.encode('one')),
      );
      final b = await store.save(
        'x.txt',
        'text/plain',
        Uint8List.fromList(utf8.encode('two')),
      );
      expect(b.id, isNot(a.id));
      expect(stored(b).readAsStringSync(), 'two');
    });

    test('文本附件超过 1MB 直接拒绝且不落盘', () async {
      final bytes = Uint8List(AcpPromptAttachment.maxTextBytes + 1);
      await expectLater(
        store.save('big.txt', 'text/plain', bytes),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_ATTACHMENT_TOO_LARGE',
          ),
        ),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('图片附件使用 20MB 的独立限额', () async {
      final bytes = Uint8List(AcpPromptAttachment.maxImageBytes + 1);
      await expectLater(
        store.save('big.png', 'image/png', bytes),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_ATTACHMENT_TOO_LARGE',
          ),
        ),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('恰好等于限额的附件被接受', () async {
      final bytes = Uint8List(AcpPromptAttachment.maxTextBytes);
      final attachment = await store.save('edge.txt', 'text/plain', bytes);
      expect(attachment.sizeBytes, AcpPromptAttachment.maxTextBytes);
      expect(stored(attachment).lengthSync(), AcpPromptAttachment.maxTextBytes);
    });
  });

  group('fromBlock', () {
    test('图片块解码后按内容寻址落盘', () async {
      final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
      final attachment = await store.fromBlock(
        ImageContent(
          data: base64Encode(bytes),
          mimeType: 'image/png',
          uri: 'file:///tmp/shot.png',
        ),
      );
      expect(attachment.mimeType, 'image/png');
      expect(attachment.sizeBytes, 64);
      expect(attachment.uri, 'file:///tmp/shot.png');
      expect(stored(attachment).readAsBytesSync(), bytes);
      expect(attachment.isImage, isTrue);
    });

    test('超大的 base64 图片在解码前就被拒绝', () async {
      // 用一个声明长度超过 maxImageBytes*4/3+4 的字符串，避免真的分配 28MB。
      final oversized = 'A' * (AcpPromptAttachment.maxImageBytes + 8);
      await expectLater(
        store.fromBlock(
          ImageContent(
            data: base64Encode(oversized.codeUnits),
            mimeType: 'image/png',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_ATTACHMENT_TOO_LARGE',
          ),
        ),
      );
    });

    test('内联文本资源按 URI 取文件名并落盘', () async {
      final attachment = await store.fromBlock(
        const EmbeddedResource(
          resource: TextResourceContents(
            uri: 'file:///work/dir/report.md',
            text: '# report',
            mimeType: 'text/markdown',
          ),
        ),
      );
      expect(attachment.name, 'report.md');
      expect(attachment.mimeType, 'text/markdown');
      expect(stored(attachment).readAsStringSync(), '# report');
      expect(attachment.uri, 'file:///work/dir/report.md');
    });

    test('内联文本资源超过限额时被拒绝', () async {
      final huge = 'x' * (AcpPromptAttachment.maxTextBytes + 1);
      await expectLater(
        store.fromBlock(
          EmbeddedResource(
            resource: TextResourceContents(uri: 'file:///big.txt', text: huge),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_ATTACHMENT_TOO_LARGE',
          ),
        ),
      );
    });

    test('二进制资源与资源链接只登记元数据，不落盘', () async {
      final blob = await store.fromBlock(
        const EmbeddedResource(
          resource: BlobResourceContents(
            uri: 'file:///work/blob.bin',
            blob: 'AAECAw==',
            mimeType: 'application/octet-stream',
          ),
        ),
      );
      expect(blob.localPath, isNull);
      expect(blob.sizeBytes, 0);
      expect(blob.name, 'blob.bin');

      final link = await store.fromBlock(
        const ResourceLink(
          uri: 'file:///work/link.txt',
          name: 'link.txt',
          mimeType: 'text/plain',
          size: 12,
        ),
      );
      expect(link.id, 'file:///work/link.txt');
      expect(link.name, 'link.txt');
      expect(link.sizeBytes, 12);
      expect(link.localPath, isNull);
      expect(dir.listSync(), isEmpty);
    });

    test('未知块退化为占位附件而不是抛错', () async {
      final attachment = await store.fromBlock(
        const TextContentBlock(text: 'hi'),
      );
      expect(attachment.id, 'unsupported');
      expect(attachment.sizeBytes, 0);
    });

    test('损坏的 base64 图片抛稳定的 ACP_ATTACHMENT_CORRUPT', () async {
      await expectLater(
        store.fromBlock(
          const ImageContent(data: 'not-valid-base64!!', mimeType: 'image/png'),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_ATTACHMENT_CORRUPT',
          ),
        ),
      );
      expect(dir.listSync(), isEmpty);
    });
  });
}
