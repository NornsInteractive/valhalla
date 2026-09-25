import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';

/// `isAtRoot` 是「返回键该退出 app 还是回上级」的唯一判据，所以边界要钉死。
void main() {
  group('SftpState.isAtRoot', () {
    test('根目录 / 为真', () {
      expect(const SftpState(currentPath: '/').isAtRoot, isTrue);
    });

    test('空路径视为根（未连接时 build() 的兜底分支可能出现）', () {
      expect(const SftpState(currentPath: '').isAtRoot, isTrue);
    });

    test('一级目录为假', () {
      expect(const SftpState(currentPath: '/etc').isAtRoot, isFalse);
    });

    test('深层目录为假', () {
      expect(
        const SftpState(currentPath: '/etc/nginx/sites').isAtRoot,
        isFalse,
      );
    });

    test('根判定与 pathSegments 一致：在根时没有面包屑片段', () {
      expect(const SftpState(currentPath: '/').pathSegments, isEmpty);
      expect(const SftpState(currentPath: '').pathSegments, isEmpty);
      expect(const SftpState(currentPath: '/etc').pathSegments, ['etc']);
    });
  });
}
