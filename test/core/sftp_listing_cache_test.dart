import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';

SftpFileItem item(String name, {bool directory = false}) => SftpFileItem(
  name: name,
  path: '/data/$name',
  isDirectory: directory,
  sizeBytes: name.length,
  formattedSize: '',
  permissions: '',
  modified: '',
);

void main() {
  test('records uncached equivalent and cached directory projection timings', () {
    for (final size in [1000, 10000]) {
      final files = List.generate(size, (i) => item('file-${size - i}'));
      final state = SftpState(currentPath: '/data', files: files);
      List<SftpFileItem> baseline() =>
          files
              .where(
                (file) =>
                    file.name != '.' &&
                    (file.name == '..' || !file.name.startsWith('.')),
              )
              .toList()
            ..sort((a, b) {
              if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
      for (var i = 0; i < 3; i++) {
        baseline();
        state.filteredFiles;
      }
      final cold = Stopwatch()..start();
      for (var i = 0; i < 20; i++) {
        baseline();
      }
      cold.stop();
      final hot = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        state.filteredFiles;
      }
      hot.stop();
      expect(
        state.filteredFiles.map((f) => f.name),
        baseline().map((f) => f.name),
      );
      // Shared-host timings are evidence, not a portable pass/fail threshold.
      // ignore: avoid_print
      print(
        'sftp projection entries=$size uncachedUs/read=${cold.elapsedMicroseconds / 20} cachedUs/read=${hot.elapsedMicroseconds / 200}',
      );
    }
  });
  final entries = [
    item('z.txt'),
    item('..', directory: true),
    item('.', directory: true),
    item('.secret'),
    item('alpha'),
    item('folder', directory: true),
  ];

  test(
    'repeated reads and unrelated state updates reuse an immutable listing',
    () {
      final state = SftpState(currentPath: '/data', files: entries);
      final visible = state.filteredFiles;
      expect(state.filteredFiles, same(visible));
      final progress = state.copyWith(
        isLoading: true,
        errorMessage: 'temporary',
        viewMode: SftpViewMode.grid,
        transfers: const [],
        editingFileContent: 'draft',
      );
      expect(progress.filteredFiles, same(visible));
      expect(() => visible.clear(), throwsUnsupportedError);
      expect(entries.map((e) => e.name), [
        'z.txt',
        '..',
        '.',
        '.secret',
        'alpha',
        'folder',
      ]);
    },
  );

  test(
    'search, hidden preference, sorting and replaced entries invalidate',
    () {
      final state = SftpState(currentPath: '/data', files: entries);
      expect(state.filteredFiles.map((e) => e.name), [
        '..',
        'folder',
        'alpha',
        'z.txt',
      ]);
      final searched = state.copyWith(searchQuery: ' ALPHA ');
      final results = searched.filteredFiles;
      expect(results.map((e) => e.name), ['alpha']);
      expect(
        searched.copyWith(searchQuery: 'alpha').filteredFiles,
        same(results),
      );
      expect(
        state.copyWith(showHiddenFiles: true).filteredFiles.map((e) => e.name),
        ['..', 'folder', '.secret', 'alpha', 'z.txt'],
      );
      expect(
        state.copyWith(sortAscending: false).filteredFiles.map((e) => e.name),
        ['folder', '..', 'z.txt', 'alpha'],
      );
      expect(
        state.copyWith(files: [item('new')]).filteredFiles.single.name,
        'new',
      );
    },
  );

  test(
    'root hides parent while non-root navigation reuses the same projection',
    () {
      final state = SftpState(currentPath: '/data', files: entries);
      final visible = state.filteredFiles;
      expect(
        state.copyWith(currentPath: '/other').filteredFiles,
        same(visible),
      );
      expect(
        state.copyWith(currentPath: '/').filteredFiles.map((e) => e.name),
        ['folder', 'alpha', 'z.txt'],
      );
      expect(state.filteredFiles.map((e) => e.name), [
        '..',
        'folder',
        'alpha',
        'z.txt',
      ]);
    },
  );

  for (final size in [1000, 10000]) {
    test('$size entries: progress does not trigger another projection', () {
      final files = List.generate(size, (i) => item('file-${size - i}'));
      final state = SftpState(currentPath: '/data', files: files);
      final results = state.filteredFiles;
      expect(results, hasLength(size));
      for (var i = 0; i < 100; i++) {
        expect(state.copyWith(errorMessage: '$i').filteredFiles, same(results));
      }
      expect(
        state.copyWith(sortKey: SftpSortKey.size).filteredFiles,
        isNot(same(results)),
      );
      expect(
        state
            .copyWith(searchQuery: 'file-10')
            .filteredFiles
            .every((file) => file.name.contains('file-10')),
        isTrue,
      );
    });
  }
}
