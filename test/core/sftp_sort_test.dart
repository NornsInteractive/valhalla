import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';

/// 构造一个测试用条目。
///
/// `modifiedEpoch` 默认给一个非零值，因为 0 表示「服务器没给时间」，
/// 按时间排序时会全部并列，测不出顺序。
SftpFileItem _item(
  String name, {
  bool isDirectory = false,
  int size = 0,
  int modifiedEpoch = 1000,
}) => SftpFileItem(
  name: name,
  path: '/root/$name',
  isDirectory: isDirectory,
  sizeBytes: size,
  formattedSize: '$size B',
  permissions: isDirectory ? 'drwxr-xr-x' : '-rw-r--r--',
  modified: '2026-09-16',
  modifiedEpoch: modifiedEpoch,
);

List<String> _names(List<SftpFileItem> items) =>
    items.map((f) => f.name).toList();

void main() {
  group('SftpState.filteredFiles 排序', () {
    test('根目录隐藏点目录，子目录保留返回上级', () {
      final entries = [
        _item('.', isDirectory: true),
        _item('..', isDirectory: true),
        _item('data', isDirectory: true),
      ];
      expect(
        _names(SftpState(currentPath: '/', files: entries).filteredFiles),
        ['data'],
      );
      expect(
        _names(SftpState(currentPath: '/var', files: entries).filteredFiles),
        ['..', 'data'],
      );
    });
    test('默认按名称升序', () {
      final state = SftpState(
        files: [_item('charlie.txt'), _item('alpha.txt'), _item('bravo.txt')],
      );

      expect(_names(state.filteredFiles), [
        'alpha.txt',
        'bravo.txt',
        'charlie.txt',
      ]);
      expect(state.sortKey, SftpSortKey.name);
      expect(state.sortAscending, isTrue);
    });

    test('名称降序时顺序反转', () {
      final state = SftpState(
        files: [_item('alpha.txt'), _item('bravo.txt'), _item('charlie.txt')],
        sortAscending: false,
      );

      expect(_names(state.filteredFiles), [
        'charlie.txt',
        'bravo.txt',
        'alpha.txt',
      ]);
    });

    test('按大小排序用数值而不是字符串', () {
      // 若按字符串比较，"1000" < "20"，会得出 20 在 1000 后面的错误顺序。
      final state = SftpState(
        files: [
          _item('big.bin', size: 1000),
          _item('small.bin', size: 20),
          _item('mid.bin', size: 300),
        ],
        sortKey: SftpSortKey.size,
      );

      expect(_names(state.filteredFiles), ['small.bin', 'mid.bin', 'big.bin']);
    });

    test('按大小降序', () {
      final state = SftpState(
        files: [
          _item('small.bin', size: 20),
          _item('big.bin', size: 1000),
          _item('mid.bin', size: 300),
        ],
        sortKey: SftpSortKey.size,
        sortAscending: false,
      );

      expect(_names(state.filteredFiles), ['big.bin', 'mid.bin', 'small.bin']);
    });

    test('按时间排序用 modifiedEpoch 而不是预格式化字符串', () {
      final state = SftpState(
        files: [
          _item('newest.txt', modifiedEpoch: 3000),
          _item('oldest.txt', modifiedEpoch: 1000),
          _item('middle.txt', modifiedEpoch: 2000),
        ],
        sortKey: SftpSortKey.date,
      );

      expect(_names(state.filteredFiles), [
        'oldest.txt',
        'middle.txt',
        'newest.txt',
      ]);
    });

    test('目录恒排在文件之前，升序降序都一样', () {
      final ascending = SftpState(
        files: [
          _item('a_file.txt'),
          _item('z_dir', isDirectory: true),
          _item('b_file.txt'),
        ],
      );
      expect(_names(ascending.filteredFiles), [
        'z_dir',
        'a_file.txt',
        'b_file.txt',
      ]);

      // 反向后目录仍应在最前：反转整个列表会让人以为目录跑到最后是 bug。
      final descending = SftpState(
        files: [
          _item('a_file.txt'),
          _item('z_dir', isDirectory: true),
          _item('b_file.txt'),
        ],
        sortAscending: false,
      );
      expect(_names(descending.filteredFiles), [
        'z_dir',
        'b_file.txt',
        'a_file.txt',
      ]);
    });

    test('搜索过滤与排序同时生效', () {
      final state = SftpState(
        files: [
          _item('report_b.txt'),
          _item('other.txt'),
          _item('report_a.txt'),
        ],
        searchQuery: 'REPORT',
        sortKey: SftpSortKey.name,
      );

      expect(_names(state.filteredFiles), ['report_a.txt', 'report_b.txt']);
    });

    test('大小或时间相同时按名字兜底，避免顺序抖动', () {
      final state = SftpState(
        files: [
          _item('charlie.txt', size: 5),
          _item('alpha.txt', size: 5),
          _item('bravo.txt', size: 5),
        ],
        sortKey: SftpSortKey.size,
      );

      expect(_names(state.filteredFiles), [
        'alpha.txt',
        'bravo.txt',
        'charlie.txt',
      ]);
    });

    test('排序不改动原始 files 列表', () {
      final original = [_item('z.txt'), _item('a.txt')];
      final state = SftpState(files: original);

      expect(_names(state.filteredFiles), ['a.txt', 'z.txt']);
      // filteredFiles 若在 files 上原地排序，这里就会看到被改过的顺序。
      expect(_names(original), ['z.txt', 'a.txt']);
    });
  });

  group('sftpSortKeyFromStorage', () {
    test('识别合法的字段名', () {
      expect(sftpSortKeyFromStorage('size'), SftpSortKey.size);
      expect(sftpSortKeyFromStorage('date'), SftpSortKey.date);
      expect(sftpSortKeyFromStorage('name'), SftpSortKey.name);
    });

    test('无法识别的值回落到名称', () {
      expect(sftpSortKeyFromStorage('nonsense'), SftpSortKey.name);
      expect(sftpSortKeyFromStorage(''), SftpSortKey.name);
    });
  });
}
