import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/services/remote_browser_service.dart';
import 'package:valhalla/data/models/remote_browser.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settleNasBrowser(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

class NasBrowserFixture extends RemoteBrowserFactory {
  NasBrowserFixture(super.ref);

  final sources = <RemoteBrowserSource>[];
  final paths = <String>[];

  @override
  RemoteBrowserSource host({
    required String initialPath,
    bool Function()? isCurrent,
  }) {
    final server = ref.read(activeServerProvider)!;
    final source = RemoteBrowserSource(
      targetKey: '${server.connectionKey}',
      label: server.name,
      rootPath: '/',
      initialPath: initialPath,
      isCurrent: () =>
          ref.mounted &&
          (isCurrent?.call() ?? true) &&
          ref.read(activeServerProvider)?.connectionKey == server.connectionKey,
      list: (path, cancelled) async* {
        paths.add(path);
        if (path != '/' && path != '/chosen') {
          throw StateError('ACP_DIRECTORY_NOT_FOUND');
        }
        yield path == '/'
            ? const [
                RemoteBrowserEntry(
                  id: '/chosen',
                  name: 'Chosen directory',
                  isDirectory: true,
                ),
              ]
            : const [];
      },
    );
    sources.add(source);
    return source;
  }
}
