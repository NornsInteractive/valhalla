import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/repositories/server_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';

typedef _HostConfirmFn =
    Future<bool> Function(String host, String type, String fp);

class _FakeServerRepository implements ServerRepository {
  @override
  Future<String?> getPassword(String id) async => 'secret123';
  @override
  Future<String?> getPrivateKey(String id) async => null;
  @override
  List<ServerProfile> getAllServers() => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _FakeActiveServerNotifier(this._server);
  @override
  ServerProfile? build() => _server;
}

class _FakeServerListNotifier extends ServerListNotifier {
  final List<ServerProfile> _servers;
  _FakeServerListNotifier(this._servers);
  @override
  List<ServerProfile> build() => _servers;
}

class _FakeServerConnectionNotifier extends ServerConnectionNotifier {
  final Future<bool> Function({
    String? password,
    String? privateKey,
    _HostConfirmFn? onConfirmHostKey,
  })
  onConnect;

  _FakeServerConnectionNotifier(this.onConnect);

  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.disconnected);

  @override
  Future<bool> connect({
    String? password,
    String? privateKey,
    _HostConfirmFn? onConfirmHostKey,
  }) async {
    return onConnect(
      password: password,
      privateKey: privateKey,
      onConfirmHostKey: onConfirmHostKey,
    );
  }
}

class _FakeSftpNotifier extends SftpNotifier {
  @override
  SftpState build() => const SftpState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testServer = const ServerProfile(
    id: 'srv-prod',
    name: 'Production Server',
    host: '192.168.1.100',
    port: 22,
    username: 'admin',
    authType: AuthType.password,
  );

  group('MainShell Host Fingerprint Confirmation Regression Tests', () {
    testWidgets(
      'renders host, type, and fingerprint in exact positions in English and Chinese',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();

        const testHost = '192.168.1.100:22';
        const testType = 'ssh-ed25519';
        const testFp = 'SHA256:4uO7N5y8Z3+fakeFingerprintTestValue=';

        final connectionNotifier = _FakeServerConnectionNotifier(({
          password,
          privateKey,
          onConfirmHostKey,
        }) async {
          if (onConfirmHostKey != null) {
            return onConfirmHostKey(testHost, testType, testFp);
          }
          return true;
        });

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            serverRepositoryProvider.overrideWithValue(_FakeServerRepository()),
            activeServerProvider.overrideWith(
              () => _FakeActiveServerNotifier(testServer),
            ),
            serverListProvider.overrideWith(
              () => _FakeServerListNotifier([testServer]),
            ),
            serverConnectionProvider.overrideWith(() => connectionNotifier),
            sftpProvider.overrideWith(_FakeSftpNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        // 1. English Locale
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MainShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap top bar connect button
        final connectBtn = find.byIcon(Icons.link).first;
        expect(connectBtn, findsOneWidget);
        await tester.tap(connectBtn);
        await tester.pumpAndSettle();

        // Dialog should be displayed
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Trust Host Fingerprint?'), findsOneWidget);

        // Extract dialog content text
        final dialogFinder = find.byType(AlertDialog);
        final alertDialog = tester.widget<AlertDialog>(dialogFinder);
        final contentText = (alertDialog.content as Text).data!;

        // Assert exact order and positioning:
        // "Connecting to 192.168.1.100:22 (ssh-ed25519) for the first time."
        // "SHA-256 Fingerprint:\nSHA256:4uO7N5y8Z3+fakeFingerprintTestValue="
        expect(
          contentText,
          contains('Connecting to $testHost ($testType) for the first time.'),
        );
        expect(contentText, contains('SHA-256 Fingerprint:\n$testFp'));

        // Negative assertions to prevent argument transposition regressions
        expect(
          contentText,
          isNot(contains('Connecting to $testType')),
          reason: 'Host must not be replaced by key type',
        );
        expect(
          contentText,
          isNot(contains('Connecting to $testFp')),
          reason: 'Host must not be replaced by fingerprint',
        );
        expect(
          contentText,
          isNot(contains('SHA-256 Fingerprint:\n$testHost')),
          reason: 'Fingerprint label must not contain host IP',
        );
        expect(
          contentText,
          isNot(contains('SHA-256 Fingerprint:\n$testType')),
          reason: 'Fingerprint label must not contain key type',
        );

        // Tap Trust & Connect
        await tester.tap(find.text('Trust & Connect'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets(
      'renders host, type, and fingerprint in exact positions in Chinese locale',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();

        const testHost = '10.0.0.1:22023';
        const testType = 'ssh-ed25519';
        const testFp = 'SHA256:AbCdEfGhIjKlMnOpQrStUvWxYz0123456789=';

        final connectionNotifier = _FakeServerConnectionNotifier(({
          password,
          privateKey,
          onConfirmHostKey,
        }) async {
          if (onConfirmHostKey != null) {
            return onConfirmHostKey(testHost, testType, testFp);
          }
          return true;
        });

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            serverRepositoryProvider.overrideWithValue(_FakeServerRepository()),
            activeServerProvider.overrideWith(
              () => _FakeActiveServerNotifier(testServer),
            ),
            serverListProvider.overrideWith(
              () => _FakeServerListNotifier([testServer]),
            ),
            serverConnectionProvider.overrideWith(() => connectionNotifier),
            sftpProvider.overrideWith(_FakeSftpNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        // Chinese Locale
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MainShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final connectBtn = find.byIcon(Icons.link).first;
        expect(connectBtn, findsOneWidget);
        await tester.tap(connectBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('信任主机公钥指纹？'), findsOneWidget);

        final dialogFinder = find.byType(AlertDialog);
        final alertDialog = tester.widget<AlertDialog>(dialogFinder);
        final contentText = (alertDialog.content as Text).data!;

        // "首次连接到 10.0.0.1:22023 (ssh-ed25519)\n\nSHA-256 指纹:\nSHA256:AbCdEfGhIjKlMnOpQrStUvWxYz0123456789=\n\n是否信任该指纹并继续连接？"
        expect(contentText, contains('首次连接到 $testHost ($testType)'));
        expect(contentText, contains('SHA-256 指纹:\n$testFp'));

        // Proves release issue is fixed: host must not appear as fingerprint
        expect(
          contentText,
          isNot(contains('首次连接到 $testType ($testFp)')),
          reason: 'Fingerprint and host must not be transposed',
        );
        expect(
          contentText,
          isNot(contains('SHA-256 指纹:\n$testHost')),
          reason: 'Fingerprint section must not show host string',
        );

        await tester.tap(find.text('信任并连接'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  });
}
