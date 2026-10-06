import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/nas_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/chat/cli_chat_view.dart';
import 'package:valhalla/features/nas/nas_media_view.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/core/design/motion_widgets.dart';

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
  bool enableCli = false,
  bool enableNas = false,
  List<AppSection>? pinnedSections,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final experiments = <String>[if (enableCli) 'cliChat', if (enableNas) 'nas'];
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (experiments.isNotEmpty)
      'valhalla_experimental_features_v1': experiments,
    // Rail 只显示被固定的目的地，所以按需显式写入保存顺序。
    if (pinnedSections != null) ...<String, Object>{
      'valhalla_bottom_navigation_v1': pinnedSections
          .map((s) => s.name)
          .toList(growable: false),
      'valhalla_navigation_acp_v2': true,
    },
  });
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
      await _pumpShell(tester, size: const Size(580, 1000), enableCli: true);

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
      final stack = tester.widget<AnimatedIndexedStack>(
        find.byType(AnimatedIndexedStack),
      );
      expect(stack.index, 8);
      expect(find.byType(CliChatView), findsOneWidget);
    });

    testWidgets('expanded mode navigation rail navigates to CliChatView', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        size: const Size(1200, 800),
        enableCli: true,
        // Rail 只显示显式固定的目的地，CLI 必须被固定才会出现在 rail。
        pinnedSections: const [
          AppSection.dashboard,
          AppSection.aiChat,
          AppSection.docker,
          AppSection.files,
          AppSection.cliChat,
        ],
      );

      // Navigation rail contains forum icon for CLI Chat
      final cliRailDestination = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.forum_outlined),
      );
      expect(cliRailDestination, findsOneWidget);
      await tester.tap(cliRailDestination);
      await tester.pumpAndSettle();

      final stack = tester.widget<AnimatedIndexedStack>(
        find.byType(AnimatedIndexedStack),
      );
      expect(stack.index, 8);
      expect(find.byType(CliChatView), findsOneWidget);
    });
    testWidgets(
      'default off: compact drawer hides CLI tile and offstage CLI view',
      (tester) async {
        final container = await _pumpShell(tester, size: const Size(580, 1000));

        final menuBtn = find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.menu),
        );
        expect(menuBtn, findsOneWidget);
        await tester.tap(menuBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('drawer_cli_chat_tile')), findsNothing);
        expect(find.byType(CliChatView, skipOffstage: false), findsNothing);
        expect(
          find.byKey(
            const Key('cli_chat_disabled_placeholder'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('drawer_nas_tile')), findsNothing);
        expect(find.byType(NasMediaView, skipOffstage: false), findsNothing);
        expect(
          find.byKey(
            const Key('nas_disabled_placeholder'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(container.exists(nasProvider), isFalse);
        expect(container.exists(nasPlaybackProvider), isFalse);
        expect(container.exists(nasMediaPlayerProvider), isFalse);
        expect(container.exists(nasIndexRepositoryProvider), isFalse);
      },
    );

    testWidgets(
      'default off: expanded rail shows pinned sections only; NAS/CLI opt-in flow',
      (tester) async {
        final container = await _pumpShell(tester, size: const Size(1200, 800));

        int destinationCount() => tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .destinations
            .length;

        // 未开启实验特性时：只显示默认固定的 4 项。
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(destinationCount(), 4);
        expect(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.byIcon(Icons.perm_media_outlined),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.byIcon(Icons.forum_outlined),
          ),
          findsNothing,
        );

        final notifier = container.read(settingsProvider.notifier);

        // 先显式固定 NAS 的位置，再开启实验特性。
        await notifier.setBottomNavigationSections([
          ...container.read(settingsProvider).bottomNavigationSections,
          AppSection.nas,
        ]);
        await tester.pumpAndSettle();
        expect(destinationCount(), 4);

        await notifier.setExperimentalFeature(ExperimentalFeature.nas, true);
        await tester.pumpAndSettle();
        expect(destinationCount(), 5);

        final nasIcon = find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byIcon(Icons.perm_media_outlined),
        );
        expect(nasIcon, findsOneWidget);
        await tester.tap(nasIcon);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnimatedIndexedStack>(find.byType(AnimatedIndexedStack))
              .index,
          9,
        );
        expect(find.byType(NasMediaView), findsOneWidget);

        await notifier.setExperimentalFeature(ExperimentalFeature.nas, false);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnimatedIndexedStack>(find.byType(AnimatedIndexedStack))
              .index,
          0,
        );
        // 关闭后条目从 rail 隐藏，但保存的选择仍然保留。
        expect(destinationCount(), 4);
        expect(
          container.read(settingsProvider).bottomNavigationSections,
          contains(AppSection.nas),
        );

        // CLI 同理：固定位置后才会在开启时出现。
        await notifier.setBottomNavigationSections([
          ...container.read(settingsProvider).bottomNavigationSections,
          AppSection.cliChat,
        ]);
        await tester.pumpAndSettle();
        expect(destinationCount(), 4);

        await notifier.setExperimentalFeature(
          ExperimentalFeature.cliChat,
          true,
        );
        await tester.pumpAndSettle();
        expect(destinationCount(), 5);
        final forumIcon = find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byIcon(Icons.forum_outlined),
        );
        expect(forumIcon, findsOneWidget);
        await tester.tap(forumIcon);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnimatedIndexedStack>(find.byType(AnimatedIndexedStack))
              .index,
          8,
        );

        await notifier.setExperimentalFeature(
          ExperimentalFeature.cliChat,
          false,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnimatedIndexedStack>(find.byType(AnimatedIndexedStack))
              .index,
          0,
        );
        expect(destinationCount(), 4);
        expect(
          container.read(settingsProvider).bottomNavigationSections,
          containsAllInOrder([AppSection.nas, AppSection.cliChat]),
        );
        expect(find.byType(CliChatView, skipOffstage: false), findsNothing);
      },
    );
  });
}
