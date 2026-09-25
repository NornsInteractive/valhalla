import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/file_preview.dart';

void main() {
  group('FilePreview.isTextPreviewable', () {
    test('accepts common source and config files', () {
      for (final name in [
        'nginx.conf',
        'app.dart',
        'main.py',
        'index.html',
        'config.yaml',
        'data.json',
        'deploy.sh',
        'schema.sql',
        'Dockerfile',
        'Makefile',
        'README.md',
      ]) {
        expect(
          FilePreview.isTextPreviewable(name),
          isTrue,
          reason: '$name 应按文本预览',
        );
      }
    });

    test('rejects binary and archive formats', () {
      for (final name in [
        'photo.png',
        'photo.JPG',
        'archive.zip',
        'archive.tar.gz',
        'app.apk',
        'lib.so',
        'video.mp4',
        'report.pdf',
        'doc.docx',
        'sheet.xlsx',
        'font.ttf',
        'data.db',
      ]) {
        expect(
          FilePreview.isTextPreviewable(name),
          isFalse,
          reason: '$name 不应按文本预览',
        );
      }
    });

    test('matches extensions case-insensitively', () {
      expect(FilePreview.isTextPreviewable('README.MD'), isTrue);
      expect(FilePreview.isTextPreviewable('Config.YAML'), isTrue);
      expect(FilePreview.isTextPreviewable('Hero.PNG'), isFalse);
    });

    test('handles extensionless convention files by full name', () {
      expect(FilePreview.isTextPreviewable('Dockerfile'), isTrue);
      expect(FilePreview.isTextPreviewable('.gitignore'), isTrue);
      expect(FilePreview.isTextPreviewable('.env'), isTrue);
      // 点开头但不是已知的约定文件，不能把它当成有扩展名。
      expect(FilePreview.isTextPreviewable('.bashrc.bak2'), isFalse);
    });

    test('treats dotfiles as extensionless, not as an extension', () {
      // `.bashrc` 不应被解析成扩展名 `bashrc`；它靠完整名白名单命中。
      expect(FilePreview.isTextPreviewable('.bashrc'), isTrue);
      // 未知的 dotfile 没有扩展名可言 -> 不支持。
      expect(FilePreview.isTextPreviewable('.mystery'), isFalse);

      // 关键区分样本：`.md` 的「扩展名」恰好落在白名单里。如果实现用
      // lastIndexOf('.') < 0 而不是 <= 0 判断，就会把它误判成 Markdown 文件。
      // 前导点开头的名字一律不算「带扩展名」。
      expect(FilePreview.isTextPreviewable('.md'), isFalse);
      expect(FilePreview.isTextPreviewable('.json'), isFalse);
      expect(FilePreview.isTextPreviewable('.sh'), isFalse);
    });

    test('rejects names without an extension', () {
      expect(FilePreview.isTextPreviewable('binaryblob'), isFalse);
      expect(FilePreview.isTextPreviewable('LICENSE2'), isFalse);
    });

    test('rejects empty and whitespace-only names', () {
      expect(FilePreview.isTextPreviewable(''), isFalse);
      expect(FilePreview.isTextPreviewable('   '), isFalse);
    });

    test('rejects names ending with a bare dot', () {
      expect(FilePreview.isTextPreviewable('notes.'), isFalse);
    });

    test('supports multi-dot names using the last extension', () {
      expect(FilePreview.isTextPreviewable('app.min.js'), isTrue);
      expect(FilePreview.isTextPreviewable('backup.tar.gz'), isFalse);
      expect(FilePreview.isTextPreviewable('nginx.conf.bak'), isFalse);
    });
  });
}
