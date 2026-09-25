import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/files/sftp_file_view.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _FakeSftpNotifier extends SftpNotifier {
  @override
  SftpState build() => const SftpState(currentPath: '/', isLoading: false);
}

class _NoActiveServerNotifier extends ActiveServerNotifier {
  @override
  ServerProfile? build() => null;
}

Future<ProviderContainer> _pumpShell(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final local = await LocalStorageService.init();

  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(local),
      activeServerProvider.overrideWith(_NoActiveServerNotifier.new),
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
  return container;
}

void main() {
  group('MainShell downloads channel openTransfers 回归测试', () {
    testWidgets(
      '通过 valhalla/downloads.openTransfers 调用能自动切到文件 tab 并弹出传输列表 Sheet',
      (tester) async {
        await _pumpShell(tester);

        // 初始状态应该在 Dashboard，传输列表 Sheet 不在树上
        expect(find.byType(SftpTransferListSheet), findsNothing);

        // 模拟从原生通知（Linux on_open_transfers_action 或 Windows 通知点击）触发 openTransfers
        final completer = Completer<ByteData?>();
        final message = const StandardMethodCodec().encodeMethodCall(
          const MethodCall('openTransfers'),
        );

        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'valhalla/downloads',
          message,
          (ByteData? data) => completer.complete(data),
        );

        await completer.future;
        await tester.pumpAndSettle();

        // 必须切到文件页并弹出传输列表 Sheet
        expect(find.byType(SftpTransferListSheet), findsOneWidget);
      },
    );

    testWidgets('valhalla/downloads 收到未知方法时抛出异常', (tester) async {
      await _pumpShell(tester);

      final completer = Completer<ByteData?>();
      final message = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('unknownMethod'),
      );

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'valhalla/downloads',
        message,
        (ByteData? data) => completer.complete(data),
      );

      final response = await completer.future;
      // MethodChannel encodes MissingPluginException as a null response in Flutter binary messenger
      expect(response, isNull);
    });
  });
}
