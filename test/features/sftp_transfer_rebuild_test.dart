import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/design/motion_widgets.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/files/sftp_file_view.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/features/terminal/terminal_view.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/remote_browser_view.dart';

class _TestSftpNotifier extends SftpNotifier {
  _TestSftpNotifier(this._initial);

  final SftpState _initial;

  @override
  SftpState build() => _initial;

  void emitState(SftpState next) {
    state = next;
  }

  SftpState get current => state;
}

class _NoActiveServerNotifier extends ActiveServerNotifier {
  @override
  ServerProfile? build() => null;
}

class _ConnectedServerNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.connected);
}

class _ActiveServerWithProfile extends ActiveServerNotifier {
  final ServerProfile _server;
  _ActiveServerWithProfile(this._server);

  @override
  ServerProfile? build() => _server;
}

const _kTestServer = ServerProfile(
  id: 'srv-1',
  name: 'Test Server',
  host: '10.0.0.1',
  port: 22,
  username: 'root',
  authType: AuthType.password,
);

late final LocalStorageService _storage;

Future<ProviderContainer> _pumpMainShell(
  WidgetTester tester, {
  required _TestSftpNotifier notifier,
}) async {
  SharedPreferences.setMockInitialValues({});
  final local = await LocalStorageService.init();

  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(local),
      activeServerProvider.overrideWith(_NoActiveServerNotifier.new),
      sftpProvider.overrideWith(() => notifier),
      serverConnectionProvider.overrideWith(_ConnectedServerNotifier.new),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MainShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Widget _buildSftpFileViewApp({
  required _TestSftpNotifier notifier,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_storage),
      activeServerProvider.overrideWith(
        () => _ActiveServerWithProfile(_kTestServer),
      ),
      sftpProvider.overrideWith(() => notifier),
      serverConnectionProvider.overrideWith(_ConnectedServerNotifier.new),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SftpFileView()),
    ),
  );
}

Widget _buildTransferListSheetApp({
  required _TestSftpNotifier notifier,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_storage),
      activeServerProvider.overrideWith(
        () => _ActiveServerWithProfile(_kTestServer),
      ),
      sftpProvider.overrideWith(() => notifier),
      serverConnectionProvider.overrideWith(_ConnectedServerNotifier.new),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SftpTransferListSheet()),
    ),
  );
}

SftpTransfer _makeDownloadTransfer({
  required String id,
  required String remotePath,
  int transferredBytes = 0,
  int totalBytes = 0,
  SftpTransferStatus status = SftpTransferStatus.queued,
  double bytesPerSecond = 0,
  SftpTransferPhase phase = SftpTransferPhase.transferring,
  int phaseProcessedBytes = 0,
  int phaseTotalBytes = 0,
}) {
  return SftpTransfer(
    id: id,
    kind: SftpTransferKind.download,
    remotePath: remotePath,
    localPath: '/tmp/${remotePath.split('/').last}',
    transferredBytes: transferredBytes,
    totalBytes: totalBytes,
    status: status,
    bytesPerSecond: bytesPerSecond,
    phase: phase,
    phaseProcessedBytes: phaseProcessedBytes,
    phaseTotalBytes: phaseTotalBytes,
  );
}

SftpFileItem _makeFileItem(
  String name, {
  bool isDirectory = false,
  int size = 100,
}) {
  return SftpFileItem(
    name: name,
    path: '/var/www/$name',
    isDirectory: isDirectory,
    sizeBytes: size,
    formattedSize: '$size B',
    permissions: isDirectory ? 'drwxr-xr-x' : '-rw-r--r--',
    modified: '2026-09-16 12:00',
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _storage = await LocalStorageService.init();
  });

  group('Sftp Transfer Rebuild Tests', () {
    testWidgets(
      'MainShell terminal widget identity preserved across transfer emissions',
      (tester) async {
        final notifier = _TestSftpNotifier(
          const SftpState(currentPath: '/', transfers: []),
        );
        await _pumpMainShell(tester, notifier: notifier);

        final terminalBefore = tester.widget<SshTerminalView>(
          find.byType(SshTerminalView, skipOffstage: false),
        );

        // Emit 4-8 transfer-only state updates: small 1024 B then 64 KiB task
        final t1 = _makeDownloadTransfer(
          id: 'task-1',
          remotePath: '/var/www/small.txt',
          totalBytes: 1024,
          status: SftpTransferStatus.running,
        );
        notifier.emitState(notifier.current.copyWith(transfers: [t1]));
        await tester.pump();

        final t1p = t1.copyWith(transferredBytes: 512);
        notifier.emitState(notifier.current.withTransfer(t1p));
        await tester.pump();

        final t1p2 = t1.copyWith(
          transferredBytes: 1024,
          status: SftpTransferStatus.completed,
        );
        notifier.emitState(notifier.current.withTransfer(t1p2));
        await tester.pump();

        final t2 = _makeDownloadTransfer(
          id: 'task-2',
          remotePath: '/var/www/large.bin',
          totalBytes: 65536,
          status: SftpTransferStatus.running,
        );
        notifier.emitState(notifier.current.copyWith(transfers: [t1p2, t2]));
        await tester.pump();

        final t2p = t2.copyWith(transferredBytes: 32768);
        notifier.emitState(notifier.current.withTransfer(t2p));
        await tester.pump();

        final t2p2 = t2.copyWith(
          transferredBytes: 65536,
          status: SftpTransferStatus.completed,
        );
        notifier.emitState(notifier.current.withTransfer(t2p2));
        await tester.pump();

        final t2p3 = t2.copyWith(
          transferredBytes: 65536,
          status: SftpTransferStatus.completed,
          bytesPerSecond: 0,
        );
        notifier.emitState(notifier.current.withTransfer(t2p3));
        await tester.pump();

        final terminalAfter = tester.widget<SshTerminalView>(
          find.byType(SshTerminalView, skipOffstage: false),
        );

        expect(
          identical(terminalBefore, terminalAfter),
          isTrue,
          reason:
              'SshTerminalView widget instance must be identical across transfer emissions',
        );
      },
    );

    testWidgets(
      'SftpFileView RemoteBrowserEntriesView and RemoteBrowserEntryTile identity preserved during transfer progress',
      (tester) async {
        for (final totalBytes in [1024, 65536]) {
          final initialState = SftpState(
            currentPath: '/var/www',
            files: [_makeFileItem('alpha.txt', size: totalBytes)],
            transfers: [
              _makeDownloadTransfer(
                id: 'task-alpha',
                remotePath: '/var/www/alpha.txt',
                totalBytes: totalBytes,
                transferredBytes: totalBytes ~/ 4, // 25%
                status: SftpTransferStatus.running,
              ),
            ],
          );
          final notifier = _TestSftpNotifier(initialState);

          await tester.pumpWidget(_buildSftpFileViewApp(notifier: notifier));
          await tester.pumpAndSettle();

          // Snapshot the list and entry tile widgets before any progress updates
          final entriesViewBefore = tester.widget<RemoteBrowserEntriesView>(
            find.byType(RemoteBrowserEntriesView),
          );
          final entryTileBefore = tester.widget<RemoteBrowserEntryTile>(
            find.byType(RemoteBrowserEntryTile).first,
          );

          // Verify banner shows 25% (percentage only, no byte count text)
          final percentText25 = find.descendant(
            of: find.byKey(const Key('sftpTransferBanner')),
            matching: find.text('25%'),
          );
          expect(
            percentText25,
            findsOneWidget,
            reason: 'Transfer banner should show 25%',
          );

          // Update to 75%
          final t1p = _makeDownloadTransfer(
            id: 'task-alpha',
            remotePath: '/var/www/alpha.txt',
            totalBytes: totalBytes,
            transferredBytes: (totalBytes * 3) ~/ 4, // 75%
            status: SftpTransferStatus.running,
          );
          notifier.emitState(notifier.current.withTransfer(t1p));
          await tester.pump();

          // Verify widget identity preserved
          final entriesViewAfter75 = tester.widget<RemoteBrowserEntriesView>(
            find.byType(RemoteBrowserEntriesView),
          );
          final entryTileAfter75 = tester.widget<RemoteBrowserEntryTile>(
            find.byType(RemoteBrowserEntryTile).first,
          );

          expect(
            identical(entriesViewBefore, entriesViewAfter75),
            isTrue,
            reason: 'RemoteBrowserEntriesView widget must remain identical',
          );
          expect(
            identical(entryTileBefore, entryTileAfter75),
            isTrue,
            reason: 'RemoteBrowserEntryTile widget must remain identical',
          );

          // Verify banner shows 75%
          final percentText75 = find.descendant(
            of: find.byKey(const Key('sftpTransferBanner')),
            matching: find.text('75%'),
          );
          expect(
            percentText75,
            findsOneWidget,
            reason: 'Transfer banner should show 75%',
          );

          // Assert AnimatedProgressBar.value = 0.75 as extra actualUI proof
          final progressBar = tester.widget<AnimatedProgressBar>(
            find.descendant(
              of: find.byKey(const Key('sftpTransferBanner')),
              matching: find.byType(AnimatedProgressBar),
            ),
          );
          expect(
            progressBar.value,
            closeTo(0.75, 0.01),
            reason: 'AnimatedProgressBar should show 75% progress',
          );

          // Complete transfer (100%) - banner should be removed (activeTransfer=null)
          final t1done = _makeDownloadTransfer(
            id: 'task-alpha',
            remotePath: '/var/www/alpha.txt',
            totalBytes: totalBytes,
            transferredBytes: totalBytes,
            status: SftpTransferStatus.completed,
          );
          notifier.emitState(notifier.current.withTransfer(t1done));
          await tester.pump();

          // Banner should be gone (no active transfer)
          expect(
            find.byKey(const Key('sftpTransferBanner')),
            findsNothing,
            reason: 'Transfer banner should be removed when transfer completes',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      },
    );

    testWidgets(
      'SftpTransferListSheet task b widget identity preserved while task a updates',
      (tester) async {
        final taskA = _makeDownloadTransfer(
          id: 'a',
          remotePath: '/var/www/a.txt',
          totalBytes: 1024,
          status: SftpTransferStatus.running,
        );
        final taskB = _makeDownloadTransfer(
          id: 'b',
          remotePath: '/var/www/b.txt',
          totalBytes: 65536,
          status: SftpTransferStatus.queued,
        );

        final notifier = _TestSftpNotifier(
          SftpState(transfers: [taskA, taskB]),
        );

        await tester.pumpWidget(_buildTransferListSheetApp(notifier: notifier));
        await tester.pumpAndSettle();

        expect(find.textContaining(taskB.remotePath), findsNothing);
        await tester.tap(find.byKey(const Key('transfer_toggle_details_b')));
        await tester.pump();
        expect(find.textContaining(taskB.remotePath), findsOneWidget);

        // Snapshot task b's SftpTransferListItem widget AND one rendered descendant
        final taskBItemBefore = tester.widget<SftpTransferListItem>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('transfer_item_b')),
                matching: find.byType(SftpTransferListItem),
              )
              .first,
        );
        final taskBDescendantBefore = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('transfer_item_b')),
            matching: find.text('b.txt'),
          ),
        );

        // Emit progress only for task a
        final taskAProgress = taskA.copyWith(transferredBytes: 512); // 50%
        notifier.emitState(notifier.current.withTransfer(taskAProgress));
        await tester.pump();

        final taskBItemAfter = tester.widget<SftpTransferListItem>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('transfer_item_b')),
                matching: find.byType(SftpTransferListItem),
              )
              .first,
        );
        final taskBDescendantAfter = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('transfer_item_b')),
            matching: find.text('b.txt'),
          ),
        );

        expect(
          identical(taskBItemBefore, taskBItemAfter),
          isTrue,
          reason: 'Task b SftpTransferListItem widget must remain identical',
        );
        expect(
          identical(taskBDescendantBefore, taskBDescendantAfter),
          isTrue,
          reason: 'Task b descendant widget must remain identical',
        );
        expect(
          find.textContaining(taskB.remotePath),
          findsOneWidget,
          reason: 'Sibling progress must preserve the expanded task details',
        );
        expect(find.textContaining(taskA.remotePath), findsNothing);

        // Verify task a shows updated percent
        final taskAPercent = find.descendant(
          of: find.byKey(const ValueKey('transfer_item_a')),
          matching: find.textContaining('(50%)'),
        );
        expect(
          taskAPercent,
          findsOneWidget,
          reason: 'Task a should show 50% progress',
        );

        // Add third task via state copy
        final taskC = _makeDownloadTransfer(
          id: 'c',
          remotePath: '/var/www/c.txt',
          totalBytes: 2048,
          status: SftpTransferStatus.queued,
        );
        notifier.emitState(
          notifier.current.copyWith(transfers: [taskAProgress, taskB, taskC]),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('transfer_item_c')),
          findsOneWidget,
          reason: 'Third task c row should be visible',
        );

        // Remove task a via withoutTransfer
        notifier.emitState(notifier.current.withoutTransfer('a'));
        await tester.pump();

        expect(
          find.byKey(const ValueKey('transfer_item_a')),
          findsNothing,
          reason: 'Task a row should be gone',
        );
        expect(
          find.byKey(const ValueKey('transfer_item_b')),
          findsOneWidget,
          reason: 'Task b row should remain',
        );
        expect(
          find.byKey(const ValueKey('transfer_item_c')),
          findsOneWidget,
          reason: 'Task c row should remain',
        );

        // Complete task b
        final taskBDone = taskB.copyWith(
          transferredBytes: 65536,
          status: SftpTransferStatus.completed,
        );
        notifier.emitState(notifier.current.withTransfer(taskBDone));
        await tester.pump();

        final taskBStatus = find.descendant(
          of: find.byKey(const ValueKey('transfer_row_b')),
          matching: find.textContaining('Completed'),
        );
        expect(
          taskBStatus,
          findsOneWidget,
          reason: 'Completed task b should show Completed status',
        );

        // Clear finished transfers
        await tester.tap(find.byKey(const Key('transferClearFinishedButton')));
        await tester.pump();

        expect(
          find.byKey(const ValueKey('transfer_item_b')),
          findsNothing,
          reason: 'Cleared finished task b should be gone',
        );
        expect(
          find.byKey(const ValueKey('transfer_item_c')),
          findsOneWidget,
          reason: 'Queued task c should remain after clear',
        );
      },
    );
  });
}
