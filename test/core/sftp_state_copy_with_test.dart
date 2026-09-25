import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';

SftpFileItem _file(String name) => SftpFileItem(
  name: name,
  path: '/$name',
  isDirectory: false,
  sizeBytes: 1,
  formattedSize: '1 B',
  permissions: '-rw-r--r--',
  modified: '2026-09-16',
);

void main() {
  group('SftpState.copyWith', () {
    test('keeps nullable fields that are not mentioned', () {
      const base = SftpState(
        errorMessage: 'boom',
        editingFilePath: '/etc/nginx.conf',
        editingFileContent: 'server {}',
      );

      // 只改一个不相关的字段。
      final next = base.copyWith(isLoading: true);

      // 这是本 bug 的核心：过去这三个字段会被静默抹成 null，
      // 于是「导航后正在编辑的内容消失」「错误提示一闪就没」。
      expect(next.errorMessage, 'boom');
      expect(next.editingFilePath, '/etc/nginx.conf');
      expect(next.editingFileContent, 'server {}');
    });

    test('overwrites nullable fields when a value is given', () {
      const base = SftpState(
        errorMessage: 'old',
        editingFilePath: '/a',
        editingFileContent: 'A',
      );

      final next = base.copyWith(
        errorMessage: 'new',
        editingFilePath: '/b',
        editingFileContent: 'B',
      );

      expect(next.errorMessage, 'new');
      expect(next.editingFilePath, '/b');
      expect(next.editingFileContent, 'B');
    });

    test('clearError drops only the error', () {
      const base = SftpState(
        errorMessage: 'boom',
        editingFilePath: '/a',
        editingFileContent: 'A',
      );

      final next = base.copyWith(clearError: true);

      expect(next.errorMessage, isNull);
      expect(next.editingFilePath, '/a');
      expect(next.editingFileContent, 'A');
    });

    test('clearEditor drops both editor fields together', () {
      const base = SftpState(
        errorMessage: 'boom',
        editingFilePath: '/a',
        editingFileContent: 'A',
      );

      final next = base.copyWith(clearEditor: true);

      expect(next.editingFilePath, isNull);
      expect(next.editingFileContent, isNull);
      expect(next.errorMessage, 'boom');
    });

    test('clearEditor also drops a value passed in the same call', () {
      const base = SftpState(editingFilePath: '/a', editingFileContent: 'A');

      // 显式清空优先于新值，避免调用方误以为两者能叠加。
      final next = base.copyWith(
        clearEditor: true,
        editingFilePath: '/b',
        editingFileContent: 'B',
      );

      expect(next.editingFilePath, isNull);
      expect(next.editingFileContent, isNull);
    });

    test('keeps non-null fields while navigating', () {
      final base = SftpState(
        currentPath: '/etc',
        files: [_file('nginx.conf')],
        searchQuery: 'ng',
      );

      final next = base.copyWith(currentPath: '/etc/nginx');

      expect(next.currentPath, '/etc/nginx');
      expect(next.files.map((f) => f.name), ['nginx.conf']);
      expect(next.searchQuery, 'ng');
    });
  });
}
