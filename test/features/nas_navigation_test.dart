import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/nas/nas_media_view.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/core/design/motion_widgets.dart';

class _FakeSftpNotifier extends SftpNotifier {
  @override
  SftpState build() => const SftpState(currentPath: '/', isLoading: false);
}

class _TestServerListNotifier extends ServerListNotifier {
  @override
  List<ServerProfile> build() => const [];
}

class _TestActiveServerNotifier extends ActiveServerNotifier {
  @override
  ServerProfile? build() => null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppSection.nas Navigation Mapping Tests', () {
    test('AppSection.nas index, icon and name mapping contracts', () {
      expect(appSectionToViewIndex(AppSection.nas), 9);
      expect(viewIndexToAppSection(9), AppSection.nas);
      expect(
        appSectionIcon(AppSection.nas, selected: false),
        Icons.perm_media_outlined,
      );
      expect(appSectionIcon(AppSection.nas, selected: true), Icons.perm_media);
    });

    testWidgets(
      'navigating to NAS from drawer switches shell index to 9 and renders NasMediaView',
      (tester) async {
        tester.view.physicalSize = const Size(500, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final local = await LocalStorageService.init();

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            serverListProvider.overrideWith(_TestServerListNotifier.new),
            activeServerProvider.overrideWith(_TestActiveServerNotifier.new),
            sftpProvider.overrideWith(_FakeSftpNotifier.new),
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

        // Open drawer
        await tester.tap(find.byIcon(Icons.menu).first);
        await tester.pumpAndSettle();

        expect(find.byType(Drawer), findsOneWidget);

        // Tap NAS in drawer
        final nasDrawerTile = find.byKey(const Key('drawer_nas_tile'));
        expect(nasDrawerTile, findsOneWidget);
        await tester.tap(nasDrawerTile);
        await tester.pumpAndSettle();

        final stack = tester.widget<AnimatedIndexedStack>(
          find.byType(AnimatedIndexedStack).first,
        );
        expect(stack.index, 9);
        expect(find.byType(NasMediaView), findsOneWidget);
      },
    );
  });
}
