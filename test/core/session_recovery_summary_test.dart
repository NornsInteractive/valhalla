import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/session_recovery_summary.dart';
import 'package:valhalla/data/models/session_recovery_status.dart';

/// 状态优先级：数值越小越靠前；reconnecting 与 syncing 同级；idle 永不入列。
int _rank(SessionRecoveryStatus status) => switch (status) {
  SessionRecoveryStatus.failed => 0,
  SessionRecoveryStatus.incomplete => 1,
  SessionRecoveryStatus.reconnecting || SessionRecoveryStatus.syncing => 2,
  SessionRecoveryStatus.idle => 3,
};

SessionRecoveryStatus _statusOf(
  SessionRecoveryMode mode,
  SessionRecoveryStatus acp,
  SessionRecoveryStatus cli,
) => mode == SessionRecoveryMode.acp ? acp : cli;

void main() {
  const statuses = SessionRecoveryStatus.values;
  const preferredOptions = <SessionRecoveryMode?>[
    null,
    SessionRecoveryMode.acp,
    SessionRecoveryMode.cli,
  ];

  const idle = SessionRecoveryStatus.idle;
  const reconnecting = SessionRecoveryStatus.reconnecting;
  const syncing = SessionRecoveryStatus.syncing;
  const incomplete = SessionRecoveryStatus.incomplete;
  const failed = SessionRecoveryStatus.failed;
  const acpMode = SessionRecoveryMode.acp;
  const cliMode = SessionRecoveryMode.cli;

  group('5×5×3 状态组合回归', () {
    for (final acp in statuses) {
      for (final cli in statuses) {
        for (final preferred in preferredOptions) {
          final label =
              'acp=${acp.name} cli=${cli.name} '
              'preferred=${preferred?.name ?? 'null'}';
          test(label, () {
            final entries = sessionRecoveryEntries(
              acp: acp,
              cli: cli,
              preferredMode: preferred,
            );

            // 非 idle 无遗漏、无重复。
            final actualModes = entries.map((e) => e.mode.name).toList()
              ..sort();
            final expectedModes = <String>[
              if (acp != idle) acpMode.name,
              if (cli != idle) cliMode.name,
            ]..sort();
            expect(actualModes, expectedModes, reason: '非 idle 无遗漏无重复');
            expect(entries.length, expectedModes.length);

            // 每项状态必须来自对应页面，不许串到另一侧。
            for (final entry in entries) {
              expect(entry.status, _statusOf(entry.mode, acp, cli));
            }

            // 首选非 idle 必须第一；idle 的首选造不出恢复对象。
            final preferredStatus = preferred == null
                ? idle
                : _statusOf(preferred, acp, cli);
            if (preferred != null && preferredStatus != idle) {
              expect(entries.first.mode, preferred, reason: '首选非 idle 必须第一');
            }

            // 其余按 failed → incomplete → syncing/reconnecting 排；
            // 同级固定 ACP 在前、CLI 在后。
            final rest = List<SessionRecoveryEntry>.of(entries);
            if (rest.isNotEmpty && rest.first.mode == preferred) {
              rest.removeAt(0);
            }
            for (var i = 1; i < rest.length; i++) {
              final previous = rest[i - 1];
              final current = rest[i];
              expect(
                _rank(previous.status) <= _rank(current.status),
                isTrue,
                reason: '状态优先级必须 failed > incomplete > 同级恢复中',
              );
              if (_rank(previous.status) == _rank(current.status)) {
                expect(
                  previous.mode.index < current.mode.index,
                  isTrue,
                  reason: '同级固定 ACP 在前、CLI 在后',
                );
              }
            }
          });
        }
      }
    }
  });

  group('文档显式用例', () {
    test('ACP syncing + CLI failed：其他页面 CLI 第一，ACP 页面 ACP 第一', () {
      final elsewhere = sessionRecoveryEntries(acp: syncing, cli: failed);
      expect(elsewhere.map((e) => e.mode), [cliMode, acpMode]);
      expect(elsewhere.map((e) => e.status), [failed, syncing]);

      final onAcp = sessionRecoveryEntries(
        acp: syncing,
        cli: failed,
        preferredMode: acpMode,
      );
      expect(onAcp.map((e) => e.mode), [acpMode, cliMode]);
      expect(onAcp.map((e) => e.status), [syncing, failed]);
    });

    test('ACP incomplete + CLI failed：failed 压过 incomplete，首选仍能排第一', () {
      final elsewhere = sessionRecoveryEntries(acp: incomplete, cli: failed);
      expect(elsewhere.map((e) => e.mode), [cliMode, acpMode]);
      expect(elsewhere.map((e) => e.status), [failed, incomplete]);

      final onAcp = sessionRecoveryEntries(
        acp: incomplete,
        cli: failed,
        preferredMode: acpMode,
      );
      expect(onAcp.map((e) => e.mode), [acpMode, cliMode]);
      expect(onAcp.map((e) => e.status), [incomplete, failed]);

      final onCli = sessionRecoveryEntries(
        acp: incomplete,
        cli: failed,
        preferredMode: cliMode,
      );
      expect(onCli.map((e) => e.mode), [cliMode, acpMode]);
      expect(onCli.map((e) => e.status), [failed, incomplete]);
    });

    test('idle 首选不遮蔽另一对象', () {
      final acpIdle = sessionRecoveryEntries(
        acp: idle,
        cli: failed,
        preferredMode: acpMode,
      );
      expect(acpIdle.map((e) => e.mode), [cliMode]);
      expect(acpIdle.map((e) => e.status), [failed]);

      final cliIdle = sessionRecoveryEntries(
        acp: reconnecting,
        cli: idle,
        preferredMode: cliMode,
      );
      expect(cliIdle.map((e) => e.mode), [acpMode]);
      expect(cliIdle.map((e) => e.status), [reconnecting]);
    });

    test('全 idle 时三种首选都返回空列表', () {
      for (final preferred in preferredOptions) {
        expect(
          sessionRecoveryEntries(
            acp: idle,
            cli: idle,
            preferredMode: preferred,
          ),
          isEmpty,
          reason: 'idle 的当前页面不制造恢复对象',
        );
      }
    });

    test('同级顺序稳定：ACP 永远在 CLI 之前', () {
      final reconnectingFirst = sessionRecoveryEntries(
        acp: reconnecting,
        cli: syncing,
      );
      expect(reconnectingFirst.map((e) => e.mode), [acpMode, cliMode]);

      final syncingFirst = sessionRecoveryEntries(
        acp: syncing,
        cli: reconnecting,
      );
      expect(syncingFirst.map((e) => e.mode), [acpMode, cliMode]);
      expect(
        sessionRecoveryEntries(acp: syncing, cli: reconnecting).toList(),
        syncingFirst.toList(),
        reason: '同样的输入必须给出同样的顺序',
      );
    });

    test('只有一个非 idle 时只返回该项，首选也造不出第二个', () {
      final onlyAcp = sessionRecoveryEntries(
        acp: failed,
        cli: idle,
        preferredMode: cliMode,
      );
      expect(onlyAcp.map((e) => e.mode), [acpMode]);
      expect(onlyAcp.map((e) => e.status), [failed]);

      final onlyCli = sessionRecoveryEntries(
        acp: idle,
        cli: syncing,
        preferredMode: acpMode,
      );
      expect(onlyCli.map((e) => e.mode), [cliMode]);
      expect(onlyCli.map((e) => e.status), [syncing]);
    });

    test('优先级总序 failed > incomplete > syncing/reconnecting', () {
      final failedVsIncomplete = sessionRecoveryEntries(
        acp: failed,
        cli: incomplete,
      );
      expect(failedVsIncomplete.map((e) => e.status), [failed, incomplete]);

      final incompleteVsReconnecting = sessionRecoveryEntries(
        acp: incomplete,
        cli: reconnecting,
      );
      expect(incompleteVsReconnecting.map((e) => e.status), [
        incomplete,
        reconnecting,
      ]);

      final sameLevel = sessionRecoveryEntries(acp: syncing, cli: reconnecting);
      expect(sameLevel.map((e) => e.mode), [acpMode, cliMode]);
    });
  });
}
