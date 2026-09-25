import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/chat/cli_chat_view.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _FakeSftpNotifier extends SftpNotifier {
  @override
  SftpState build() => const SftpState(currentPath: '/', isLoading: false);
}

class _TestActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _TestActiveServerNotifier([this._server]);

  @override
  ServerProfile? build() => _server;
}

class _TestServerListNotifier extends ServerListNotifier {
  final List<ServerProfile> _servers;
  _TestServerListNotifier([this._servers = const []]);

  @override
  List<ServerProfile> build() => _servers;
}

class _FakeCliChatNotifier extends CliChatNotifier {
  @override
  CliChatState build() => const CliChatState(serverId: 'srv-1', agents: []);
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  Size size = const Size(500, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final local = await LocalStorageService.init();

  const server = ServerProfile(
    id: 'srv-1',
    name: 'Dev Server',
    host: '10.0.0.1',
    port: 22,
    username: 'root',
  );

  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(local),
      serverListProvider.overrideWith(() => _TestServerListNotifier([server])),
      activeServerProvider.overrideWith(
        () => _TestActiveServerNotifier(server),
      ),
      sftpProvider.overrideWith(_FakeSftpNotifier.new),
      cliChatProvider.overrideWith(_FakeCliChatNotifier.new),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MainShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('MainShell CLI Chat Navigation Tests', () {
    testWidgets('compact mode drawer navigates to CliChatView at index 8', (
      tester,
    ) async {
      await _pumpShell(tester, size: const Size(580, 1000));

      // Open drawer
      final menuBtn = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.menu),
      );
      expect(menuBtn, findsOneWidget);
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      // Tap CLI Chat tile in drawer
      final cliTile = find.byKey(const Key('drawer_cli_chat_tile'));
      expect(cliTile, findsOneWidget);
      await tester.tap(cliTile);
      await tester.pumpAndSettle();

      // Drawer closed, index is 8, CliChatView rendered
      expect(find.byType(Drawer), findsNothing);
      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 8);
      expect(find.byType(CliChatView), findsOneWidget);
    });

    testWidgets('expanded mode navigation rail navigates to CliChatView', (
      tester,
    ) async {
      await _pumpShell(tester, size: const Size(1200, 800));

      // Navigation rail contains forum icon for CLI Chat
      final cliRailDestination = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.forum_outlined),
      );
      expect(cliRailDestination, findsOneWidget);
      await tester.tap(cliRailDestination);
      await tester.pumpAndSettle();

      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 8);
      expect(find.byType(CliChatView), findsOneWidget);
    });
  });
}
