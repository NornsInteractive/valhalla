import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/features/files/sftp_file_view.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _RecordingSftpNotifier extends SftpNotifier {
  final SftpState _initial;
  final List<String> pauseCalls = [];
  final List<String> resumeCalls = [];
  final List<String> cancelCalls = [];
  final List<String> removeCalls = [];
  int clearFinishedCalls = 0;

  _RecordingSftpNotifier(this._initial);

  @override
  SftpState build() => _initial;

  @override
  Future<void> pauseTransfer(String id) async {
    pauseCalls.add(id);
    final task = state.transferById(id);
    if (task != null) {
      state = state.withTransfer(
        task.copyWith(status: SftpTransferStatus.paused),
      );
    }
  }

  @override
  Future<void> resumeTransfer(String id) async {
    resumeCalls.add(id);
    final task = state.transferById(id);
    if (task != null) {
      state = state.withTransfer(
        task.copyWith(status: SftpTransferStatus.running),
      );
    }
  }

  @override
  Future<void> cancelTransfer(String id) async {
    cancelCalls.add(id);
    final task = state.transferById(id);
    if (task != null) {
      state = state.withTransfer(
        task.copyWith(status: SftpTransferStatus.canceled),
      );
    }
  }

  @override
  Future<void> removeTransfer(String id) async {
    removeCalls.add(id);
    state = state.withoutTransfer(id);
  }

  @override
  void clearFinishedTransfers() {
    clearFinishedCalls++;
    super.clearFinishedTransfers();
  }

  void updateState(SftpState next) {
    state = next;
  }
}

/// Transfer controls are gated on the connection state, and the real
/// connection notifier needs a live `LocalStorageService` for the SSH client
/// manager. Every case here drives real transfer actions, so it is connected.
class _TestServerConnectionNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.connected);
}

Widget _buildTestApp({
  required _RecordingSftpNotifier notifier,
  Locale locale = const Locale('en'),
  Widget? child,
}) {
  return ProviderScope(
    overrides: [
      sftpProvider.overrideWith(() => notifier),
      serverConnectionProvider.overrideWith(_TestServerConnectionNotifier.new),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child ?? const SftpFileView()),
    ),
  );
}

void main() {
  group('Sftp Transfer List UI', () {
    testWidgets(
      'action bar entry button shows tooltip and badge reflecting pendingTransferCount',
      (tester) async {
        final t1 = const SftpTransfer(
          id: 't-1',
          kind: SftpTransferKind.download,
          remotePath: '/var/www/a.txt',
          localPath: '/tmp/a.txt',
          status: SftpTransferStatus.running,
        );
        final t2 = const SftpTransfer(
          id: 't-2',
          kind: SftpTransferKind.upload,
          remotePath: '/var/www/b.txt',
          localPath: '/tmp/b.txt',
          status: SftpTransferStatus.queued,
        );
        final t3 = const SftpTransfer(
          id: 't-3',
          kind: SftpTransferKind.download,
          remotePath: '/var/www/c.txt',
          localPath: '/tmp/c.txt',
          status: SftpTransferStatus.completed,
        );

        final notifier = _RecordingSftpNotifier(
          SftpState(transfers: [t1, t2, t3]),
        );
        await tester.pumpWidget(_buildTestApp(notifier: notifier));
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Button exists with tooltip
        final btnFinder = find.byKey(const Key('sftpTransferListButton'));
        expect(btnFinder, findsOneWidget);
        final iconBtn = tester.widget<IconButton>(btnFinder);
        expect(iconBtn.tooltip, l10n.transferList);

        // Badge shows pendingTransferCount = 2 (t1 running + t2 queued; t3 is completed)
        expect(find.text('2'), findsOneWidget);

        // Tap button to open sheet
        await tester.tap(btnFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SftpTransferListSheet), findsOneWidget);
      },
    );

    testWidgets(
      'action bar entry button hides badge count when pendingTransferCount is 0',
      (tester) async {
        final t1 = const SftpTransfer(
          id: 't-1',
          kind: SftpTransferKind.download,
          remotePath: '/var/www/a.txt',
          localPath: '/tmp/a.txt',
          status: SftpTransferStatus.completed,
        );

        final notifier = _RecordingSftpNotifier(SftpState(transfers: [t1]));
        await tester.pumpWidget(_buildTestApp(notifier: notifier));
        await tester.pump();

        final badge = tester.widget<Badge>(
          find.descendant(
            of: find.byKey(const Key('sftpTransferListButton')),
            matching: find.byType(Badge),
          ),
        );
        expect(badge.isLabelVisible, isFalse);
      },
    );

    testWidgets('shows empty view when transfers list is empty', (
      tester,
    ) async {
      final notifier = _RecordingSftpNotifier(const SftpState(transfers: []));
      await tester.pumpWidget(
        _buildTestApp(notifier: notifier, child: const SftpTransferListSheet()),
      );
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byKey(const Key('transferEmptyView')), findsOneWidget);
      expect(find.text(l10n.transferEmpty), findsOneWidget);
      expect(find.byKey(const Key('transferListView')), findsNothing);
    });

    testWidgets(
      'clear finished transfers button is enabled only when hasFinishedTransfers is true',
      (tester) async {
        // Initially only running and queued tasks
        final t1 = const SftpTransfer(
          id: 't-1',
          kind: SftpTransferKind.download,
          remotePath: '/var/www/a.txt',
          localPath: '/tmp/a.txt',
          status: SftpTransferStatus.running,
        );
        final notifier = _RecordingSftpNotifier(SftpState(transfers: [t1]));
        await tester.pumpWidget(
          _buildTestApp(
            notifier: notifier,
            child: const SftpTransferListSheet(),
          ),
        );
        await tester.pump();

        final clearBtnFinder = find.byKey(
          const Key('transferClearFinishedButton'),
        );
        expect(clearBtnFinder, findsOneWidget);

        final btnBefore = tester.widget<TextButton>(clearBtnFinder);
        expect(
          btnBefore.onPressed,
          isNull,
          reason: 'No finished transfers -> button must be disabled',
        );

        // Now add a completed task
        final t2 = const SftpTransfer(
          id: 't-2',
          kind: SftpTransferKind.upload,
          remotePath: '/var/www/b.txt',
          localPath: '/tmp/b.txt',
          status: SftpTransferStatus.completed,
        );
        notifier.updateState(SftpState(transfers: [t1, t2]));
        await tester.pump();

        final btnAfter = tester.widget<TextButton>(clearBtnFinder);
        expect(
          btnAfter.onPressed,
          isNotNull,
          reason: 'Has completed transfer -> button must be enabled',
        );

        await tester.tap(clearBtnFinder);
        await tester.pump();

        expect(notifier.clearFinishedCalls, 1);
        expect(notifier.state.transfers, [t1]);
      },
    );

    group('Operation Matrix & Button Presence/Absence for All 6 States', () {
      testWidgets(
        'queued status: pause, cancel, remove PRESENT; resume ABSENT',
        (tester) async {
          const taskId = 'task-queued';
          final task = const SftpTransfer(
            id: taskId,
            kind: SftpTransferKind.download,
            remotePath: '/var/www/file.txt',
            localPath: '/tmp/file.txt',
            status: SftpTransferStatus.queued,
          );

          final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
          await tester.pumpWidget(
            _buildTestApp(
              notifier: notifier,
              child: const SftpTransferListSheet(),
            ),
          );
          await tester.pump();

          // 1. Assert present buttons
          expect(
            find.byKey(const Key('transfer_pause_$taskId')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('transfer_cancel_$taskId')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('transfer_remove_$taskId')),
            findsOneWidget,
          );

          // 2. Assert absent buttons
          expect(
            find.byKey(const Key('transfer_resume_$taskId')),
            findsNothing,
          );

          // 3. Assert pause button is clickable and passes task.id
          await tester.tap(find.byKey(const Key('transfer_pause_$taskId')));
          await tester.pump();
          expect(notifier.pauseCalls, [taskId]);

          // Reset state back to queued
          notifier.updateState(SftpState(transfers: [task]));
          await tester.pump();

          // 4. Assert cancel button is clickable and passes task.id
          await tester.tap(find.byKey(const Key('transfer_cancel_$taskId')));
          await tester.pump();
          expect(notifier.cancelCalls, [taskId]);

          // Reset state back to queued
          notifier.updateState(SftpState(transfers: [task]));
          await tester.pump();

          // 5. Assert remove button is clickable and passes task.id
          await tester.tap(find.byKey(const Key('transfer_remove_$taskId')));
          await tester.pump();
          expect(notifier.removeCalls, [taskId]);
        },
      );

      testWidgets(
        'running status: pause, cancel PRESENT; resume, remove ABSENT',
        (tester) async {
          const taskId = 'task-running';
          final task = const SftpTransfer(
            id: taskId,
            kind: SftpTransferKind.upload,
            remotePath: '/var/www/file.txt',
            localPath: '/tmp/file.txt',
            status: SftpTransferStatus.running,
          );

          final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
          await tester.pumpWidget(
            _buildTestApp(
              notifier: notifier,
              child: const SftpTransferListSheet(),
            ),
          );
          await tester.pump();

          // 1. Assert present buttons
          expect(
            find.byKey(const Key('transfer_pause_$taskId')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('transfer_cancel_$taskId')),
            findsOneWidget,
          );

          // 2. Assert absent buttons
          expect(
            find.byKey(const Key('transfer_resume_$taskId')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('transfer_remove_$taskId')),
            findsNothing,
          );

          // 3. Assert pause button is clickable and passes task.id
          await tester.tap(find.byKey(const Key('transfer_pause_$taskId')));
          await tester.pump();
          expect(notifier.pauseCalls, [taskId]);

          // Reset state back to running
          notifier.updateState(SftpState(transfers: [task]));
          await tester.pump();

          // 4. Assert cancel button is clickable and passes task.id
          await tester.tap(find.byKey(const Key('transfer_cancel_$taskId')));
          await tester.pump();
          expect(notifier.cancelCalls, [taskId]);
        },
      );

      testWidgets(
        'paused status: resume, cancel, remove PRESENT; pause ABSENT',
        (tester) async {
          const taskId = 'task-paused';
          final task = const SftpTransfer(
            id: taskId,
            kind: SftpTransferKind.download,
            remotePath: '/var/www/file.txt',
            localPath: '/tmp/file.txt',
            status: SftpTransferStatus.paused,
          );

          final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
          await tester.pumpWidget(
            _buildTestApp(
              notifier: notifier,
              child: const SftpTransferListSheet(),
            ),
          );
          await tester.pump();

          // 1. Assert present buttons
          expect(
            find.byKey(const Key('transfer_resume_$taskId')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('transfer_cancel_$taskId')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('transfer_remove_$taskId')),
            findsOneWidget,
          );

          // 2. Assert absent buttons
          expect(find.byKey(const Key('transfer_pause_$taskId')), findsNothing);

          // 3. Assert resume button is clickable and passes task.id
          await tester.tap(find.byKey(const Key('transfer_resume_$taskId')));
          await tester.pump();
          expect(notifier.resumeCalls, [taskId]);

          // Reset state back to paused
          notifier.updateState(SftpState(transfers: [task]));
          await tester.pump();

          // 4. Assert cancel button is clickable and passes task.id
          await tester.tap(find.byKey(const Key('transfer_cancel_$taskId')));
          await tester.pump();
          expect(notifier.cancelCalls, [taskId]);

          // Reset state back to paused
          notifier.updateState(SftpState(transfers: [task]));
          await tester.pump();

          // 5. Assert remove button is clickable and passes task.id
          await tester.tap(find.byKey(const Key('transfer_remove_$taskId')));
          await tester.pump();
          expect(notifier.removeCalls, [taskId]);
        },
      );

      testWidgets(
        'completed status: remove PRESENT; pause, resume, cancel ABSENT',
        (tester) async {
          const taskId = 'task-completed';
          final task = const SftpTransfer(
            id: taskId,
            kind: SftpTransferKind.upload,
            remotePath: '/var/www/file.txt',
            localPath: '/tmp/file.txt',
            status: SftpTransferStatus.completed,
          );

          final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
          await tester.pumpWidget(
            _buildTestApp(
              notifier: notifier,
              child: const SftpTransferListSheet(),
            ),
          );
          await tester.pump();

          // 1. Assert present buttons
          expect(
            find.byKey(const Key('transfer_remove_$taskId')),
            findsOneWidget,
          );

          // 2. Assert absent buttons
          expect(find.byKey(const Key('transfer_pause_$taskId')), findsNothing);
          expect(
            find.byKey(const Key('transfer_resume_$taskId')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('transfer_cancel_$taskId')),
            findsNothing,
          );

          // 3. Assert remove button is clickable and passes task.id
          await tester.tap(find.byKey(const Key('transfer_remove_$taskId')));
          await tester.pump();
          expect(notifier.removeCalls, [taskId]);
        },
      );

      testWidgets(
        'failed status: remove PRESENT; pause, resume, cancel ABSENT',
        (tester) async {
          const taskId = 'task-failed';
          final task = const SftpTransfer(
            id: taskId,
            kind: SftpTransferKind.download,
            remotePath: '/var/www/file.txt',
            localPath: '/tmp/file.txt',
            status: SftpTransferStatus.failed,
            errorMessage: SftpNotifier.downloadFailedCode,
          );

          final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
          await tester.pumpWidget(
            _buildTestApp(
              notifier: notifier,
              child: const SftpTransferListSheet(),
            ),
          );
          await tester.pump();

          // 1. Assert present buttons
          expect(
            find.byKey(const Key('transfer_remove_$taskId')),
            findsOneWidget,
          );

          // 2. Assert absent buttons
          expect(find.byKey(const Key('transfer_pause_$taskId')), findsNothing);
          expect(
            find.byKey(const Key('transfer_resume_$taskId')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('transfer_cancel_$taskId')),
            findsNothing,
          );

          // 3. Assert remove button is clickable and passes task.id
          await tester.tap(find.byKey(const Key('transfer_remove_$taskId')));
          await tester.pump();
          expect(notifier.removeCalls, [taskId]);
        },
      );

      testWidgets(
        'canceled status: remove PRESENT; pause, resume, cancel ABSENT',
        (tester) async {
          const taskId = 'task-canceled';
          final task = const SftpTransfer(
            id: taskId,
            kind: SftpTransferKind.download,
            remotePath: '/var/www/file.txt',
            localPath: '/tmp/file.txt',
            status: SftpTransferStatus.canceled,
          );

          final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
          await tester.pumpWidget(
            _buildTestApp(
              notifier: notifier,
              child: const SftpTransferListSheet(),
            ),
          );
          await tester.pump();

          // 1. Assert present buttons
          expect(
            find.byKey(const Key('transfer_remove_$taskId')),
            findsOneWidget,
          );

          // 2. Assert absent buttons
          expect(find.byKey(const Key('transfer_pause_$taskId')), findsNothing);
          expect(
            find.byKey(const Key('transfer_resume_$taskId')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('transfer_cancel_$taskId')),
            findsNothing,
          );

          // 3. Assert remove button is clickable and passes task.id
          await tester.tap(find.byKey(const Key('transfer_remove_$taskId')));
          await tester.pump();
          expect(notifier.removeCalls, [taskId]);
        },
      );
    });

    testWidgets(
      'callbacks receive task.id and distinguish tasks sharing the same remotePath',
      (tester) async {
        const samePath = '/root/a.txt';
        final t1 = const SftpTransfer(
          id: 'task-id-1',
          kind: SftpTransferKind.download,
          remotePath: samePath,
          localPath: '/tmp/a.txt',
          status: SftpTransferStatus.queued,
        );
        final t2 = const SftpTransfer(
          id: 'task-id-2',
          kind: SftpTransferKind.download,
          remotePath: samePath,
          localPath: '/tmp/a-copy.txt',
          status: SftpTransferStatus.paused,
        );

        final notifier = _RecordingSftpNotifier(SftpState(transfers: [t1, t2]));
        await tester.pumpWidget(
          _buildTestApp(
            notifier: notifier,
            child: const SftpTransferListSheet(),
          ),
        );
        await tester.pump();

        // Tap pause on t1
        await tester.tap(find.byKey(const Key('transfer_pause_task-id-1')));
        await tester.pump();
        expect(notifier.pauseCalls, ['task-id-1']);
        expect(
          notifier.pauseCalls.first,
          isNot(equals(samePath)),
          reason: 'Callback must pass task.id, not remotePath',
        );

        // Tap resume on t2
        await tester.tap(find.byKey(const Key('transfer_resume_task-id-2')));
        await tester.pump();
        expect(notifier.resumeCalls, ['task-id-2']);
        expect(
          notifier.resumeCalls.first,
          isNot(equals(samePath)),
          reason: 'Callback must pass task.id, not remotePath',
        );

        // Tap cancel on t1
        await tester.tap(find.byKey(const Key('transfer_cancel_task-id-1')));
        await tester.pump();
        expect(notifier.cancelCalls, ['task-id-1']);

        // Reset t2 back to paused so it has the remove button
        notifier.updateState(SftpState(transfers: [t1, t2]));
        await tester.pump();

        // Tap remove on t2
        await tester.tap(find.byKey(const Key('transfer_remove_task-id-2')));
        await tester.pump();
        expect(notifier.removeCalls, ['task-id-2']);
      },
    );

    group('Progress and Size Display', () {
      testWidgets(
        'when progress is null (totalBytes == 0), displays "Size unknown" and NOT "0%"',
        (tester) async {
          const taskId = 'task-unknown-size';
          final task = const SftpTransfer(
            id: taskId,
            kind: SftpTransferKind.download,
            remotePath: '/var/www/large.iso',
            localPath: '/tmp/large.iso',
            transferredBytes: 0,
            totalBytes: 0, // progress is null
            status: SftpTransferStatus.running,
          );

          final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
          await tester.pumpWidget(
            _buildTestApp(
              notifier: notifier,
              child: const SftpTransferListSheet(),
            ),
          );
          await tester.pump();

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));

          // Must display "Size unknown"
          expect(find.text(l10n.transferSizeUnknown), findsOneWidget);
          // Must NOT display "0%"
          expect(find.textContaining('0%'), findsNothing);
        },
      );

      testWidgets(
        'when totalBytes == 0 and transferredBytes > 0, displays transferred / Size unknown and NOT 0%',
        (tester) async {
          const taskId = 'task-partial-unknown';
          final task = const SftpTransfer(
            id: taskId,
            kind: SftpTransferKind.download,
            remotePath: '/var/www/stream.dat',
            localPath: '/tmp/stream.dat',
            transferredBytes: 1024,
            totalBytes: 0, // progress is null
            status: SftpTransferStatus.running,
          );

          final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
          await tester.pumpWidget(
            _buildTestApp(
              notifier: notifier,
              child: const SftpTransferListSheet(),
            ),
          );
          await tester.pump();

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));

          expect(find.textContaining(l10n.transferSizeUnknown), findsOneWidget);
          expect(find.textContaining('0%'), findsNothing);
        },
      );

      testWidgets(
        'when totalBytes > 0, displays formatted percentage and bytes',
        (tester) async {
          const taskId = 'task-known-size';
          final task = const SftpTransfer(
            id: taskId,
            kind: SftpTransferKind.upload,
            remotePath: '/var/www/image.png',
            localPath: '/tmp/image.png',
            transferredBytes: 50,
            totalBytes: 100,
            status: SftpTransferStatus.running,
          );

          final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
          await tester.pumpWidget(
            _buildTestApp(
              notifier: notifier,
              child: const SftpTransferListSheet(),
            ),
          );
          await tester.pump();

          expect(find.textContaining('50%'), findsOneWidget);
        },
      );

      testWidgets('displays localized Chinese text correctly', (tester) async {
        const taskId = 'task-zh';
        final task = const SftpTransfer(
          id: taskId,
          kind: SftpTransferKind.download,
          remotePath: '/var/www/doc.pdf',
          localPath: '/tmp/doc.pdf',
          transferredBytes: 0,
          totalBytes: 0,
          status: SftpTransferStatus.queued,
        );

        final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
        await tester.pumpWidget(
          _buildTestApp(
            notifier: notifier,
            locale: const Locale('zh'),
            child: const SftpTransferListSheet(),
          ),
        );
        await tester.pump();

        final l10nZh = await AppLocalizations.delegate.load(const Locale('zh'));
        expect(find.text('传输列表'), findsOneWidget);
        expect(find.text(l10nZh.transferSizeUnknown), findsOneWidget);
        expect(
          find.textContaining(l10nZh.transferStatusQueued),
          findsOneWidget,
        );
        expect(find.textContaining(l10nZh.transferDownload), findsOneWidget);
      });
    });

    group('Failure Reason Mapping (errorMessage)', () {
      testWidgets('maps SFTP_UPLOAD_FAILED to localized upload failed text', (
        tester,
      ) async {
        final task = const SftpTransfer(
          id: 't-fail-up',
          kind: SftpTransferKind.upload,
          remotePath: '/var/www/a.txt',
          localPath: '/tmp/a.txt',
          status: SftpTransferStatus.failed,
          errorMessage: SftpNotifier.uploadFailedCode,
        );

        final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
        await tester.pumpWidget(
          _buildTestApp(
            notifier: notifier,
            child: const SftpTransferListSheet(),
          ),
        );
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.transferFailedUpload), findsOneWidget);
        expect(find.text(SftpNotifier.uploadFailedCode), findsNothing);
      });

      testWidgets(
        'maps SFTP_DOWNLOAD_FAILED to localized download failed text',
        (tester) async {
          final task = const SftpTransfer(
            id: 't-fail-down',
            kind: SftpTransferKind.download,
            remotePath: '/var/www/a.txt',
            localPath: '/tmp/a.txt',
            status: SftpTransferStatus.failed,
            errorMessage: SftpNotifier.downloadFailedCode,
          );

          final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
          await tester.pumpWidget(
            _buildTestApp(
              notifier: notifier,
              child: const SftpTransferListSheet(),
            ),
          );
          await tester.pump();

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          expect(find.text(l10n.transferFailedDownload), findsOneWidget);
          expect(find.text(SftpNotifier.downloadFailedCode), findsNothing);
        },
      );

      testWidgets(
        'fallback error code maps to transferStatusFailed, never raw code',
        (tester) async {
          final task = const SftpTransfer(
            id: 't-fail-other',
            kind: SftpTransferKind.upload,
            remotePath: '/var/www/a.txt',
            localPath: '/tmp/a.txt',
            status: SftpTransferStatus.failed,
            errorMessage: 'UNKNOWN_INTERNAL_ERROR',
          );

          final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
          await tester.pumpWidget(
            _buildTestApp(
              notifier: notifier,
              child: const SftpTransferListSheet(),
            ),
          );
          await tester.pump();

          expect(find.text('UNKNOWN_INTERNAL_ERROR'), findsNothing);
        },
      );

      // 上一条用例的 canceled 任务没带 errorMessage，`errorText` 里的
      // `errorMessage != null` 短路会让那条断言恒真 —— 它守的是「null 不渲染」，
      // 而不是「canceled 不渲染」。这里补上带 errorMessage 的形态，
      // 才是真正守住「用户主动取消不算错误」这条规则。
      testWidgets('canceled with an errorMessage still renders no error row', (
        tester,
      ) async {
        final uploadCanceled = const SftpTransfer(
          id: 't-cancel-msg-upload',
          kind: SftpTransferKind.upload,
          remotePath: '/var/www/b.txt',
          localPath: '/tmp/b.txt',
          status: SftpTransferStatus.canceled,
          errorMessage: 'SFTP_UPLOAD_FAILED',
        );
        final downloadCanceled = const SftpTransfer(
          id: 't-cancel-msg-download',
          kind: SftpTransferKind.download,
          remotePath: '/var/www/c.txt',
          localPath: '/tmp/c.txt',
          status: SftpTransferStatus.canceled,
          errorMessage: 'SFTP_DOWNLOAD_FAILED',
        );
        final notifier = _RecordingSftpNotifier(
          SftpState(transfers: [uploadCanceled, downloadCanceled]),
        );
        await tester.pumpWidget(
          _buildTestApp(
            notifier: notifier,
            child: const SftpTransferListSheet(),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('transfer_error_t-cancel-msg-upload')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('transfer_error_t-cancel-msg-download')),
          findsNothing,
        );
      });

      testWidgets('failed with an errorMessage DOES render the error row', (
        tester,
      ) async {
        final failed = const SftpTransfer(
          id: 't-fail-msg',
          kind: SftpTransferKind.upload,
          remotePath: '/var/www/d.txt',
          localPath: '/tmp/d.txt',
          status: SftpTransferStatus.failed,
          errorMessage: 'SFTP_UPLOAD_FAILED',
        );
        final notifier = _RecordingSftpNotifier(SftpState(transfers: [failed]));
        await tester.pumpWidget(
          _buildTestApp(
            notifier: notifier,
            child: const SftpTransferListSheet(),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('transfer_error_t-fail-msg')),
          findsOneWidget,
        );
      });

      testWidgets('canceled status does not show error text', (tester) async {
        final task = const SftpTransfer(
          id: 't-cancel',
          kind: SftpTransferKind.upload,
          remotePath: '/var/www/a.txt',
          localPath: '/tmp/a.txt',
          status: SftpTransferStatus.canceled,
        );

        final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
        await tester.pumpWidget(
          _buildTestApp(
            notifier: notifier,
            child: const SftpTransferListSheet(),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('transfer_error_t-cancel')), findsNothing);
      });
    });

    testWidgets(
      'live state update: running task completes while sheet is open',
      (tester) async {
        final task = const SftpTransfer(
          id: 't-live',
          kind: SftpTransferKind.upload,
          remotePath: '/var/www/a.txt',
          localPath: '/tmp/a.txt',
          status: SftpTransferStatus.running,
        );

        final notifier = _RecordingSftpNotifier(SftpState(transfers: [task]));
        await tester.pumpWidget(
          _buildTestApp(
            notifier: notifier,
            child: const SftpTransferListSheet(),
          ),
        );
        await tester.pump();

        // Running has pause button, no remove button
        expect(find.byKey(const Key('transfer_pause_t-live')), findsOneWidget);
        expect(find.byKey(const Key('transfer_remove_t-live')), findsNothing);

        // Now update notifier to completed
        final completedTask = task.copyWith(
          status: SftpTransferStatus.completed,
        );
        notifier.updateState(SftpState(transfers: [completedTask]));
        await tester.pump();

        // Sheet updates reactively: pause button gone, remove button appeared!
        expect(find.byKey(const Key('transfer_pause_t-live')), findsNothing);
        expect(find.byKey(const Key('transfer_remove_t-live')), findsOneWidget);
      },
    );
  });
}
