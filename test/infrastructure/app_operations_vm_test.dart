import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/utils/shell_quote.dart';
import 'package:valhalla/core/utils/tmux_session_planner.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/docker/docker_cli_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';
import 'package:valhalla/infrastructure/system/process_service.dart';
import 'package:valhalla/infrastructure/system/service_manager.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:xterm/xterm.dart';

/// Opt-in actual service acceptance against the disposable, pinned VM only.
/// VALHALLA_OPERATIONS_VM_CREDENTIALS=/tmp/valhalla-test-vm/credentials.json
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final credentialsPath =
      Platform.environment['VALHALLA_OPERATIONS_VM_CREDENTIALS'];
  group(
    'real isolated app operations',
    () {
      late SSHClientManager ssh;
      late DockerCliService docker;
      late ServerProfile server;
      final runId = DateTime.now().microsecondsSinceEpoch.toString();
      final name = 'valhalla-test-ops-$runId';
      late String containerId;
      final bridges = <TerminalSessionBridge>[];
      final unit = '$name.service';
      final rule = '/etc/polkit-1/rules.d/49-$name.rules';
      final unitPath = '/etc/systemd/system/$unit';
      int? ownedPid;

      Future<SSHExecutionResult> command(String value) =>
          ssh.executeWithLoginShell(server.id, value);
      Future<void> checked(String value) async {
        final result = await command(value);
        expect(result.isSuccess, true, reason: result.stderr);
      }

      Future<void> waitFor(
        bool Function() predicate, {
        String reason = '',
        String Function()? details,
      }) async {
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (!predicate() && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(predicate(), true, reason: details?.call() ?? reason);
      }

      Future<void> writeRootFile(String path, String contents) => checked(
        'printf %s ${cliShellQuote(base64Encode(utf8.encode(contents)))} | '
        'base64 -d | sudo -n tee ${cliShellQuote(path)} >/dev/null',
      );

      setUpAll(() async {
        final config =
            jsonDecode(await File(credentialsPath!).readAsString())
                as Map<String, dynamic>;
        expect(config['ssh_host'], '127.0.0.1');
        expect(config['ssh_port'], 22023);
        expect(config['ssh_user'], 'valhalla');
        final fingerprints = (config['host_fingerprints'] as List)
            .cast<String>();
        expect(fingerprints, isNotEmpty);
        SharedPreferences.setMockInitialValues({});
        ssh = SSHClientManager(
          SSHHostKeyVerifier(await LocalStorageService.init()),
        );
        server = const ServerProfile(
          id: 'isolated-operations-vm',
          name: 'valhalla-test-vm',
          host: '127.0.0.1',
          port: 22023,
          username: 'valhalla',
        );
        await ssh.getOrCreateClient(
          server,
          password: config['ssh_password'] as String,
          onConfirmHostKey: (_, _, fingerprint) async =>
              fingerprints.contains(fingerprint),
        );
        final identity = await command(
          'hostname; cat /etc/machine-id; test -e ~/fixture-ready',
        );
        expect(identity.isSuccess, true);
        expect(identity.stdout.trim().split('\n'), [
          'valhalla-test-vm',
          config['machine_id'],
        ]);
        docker = DockerCliService(ssh);
        final created = await command(
          'docker run --detach --name ${cliShellQuote(name)} '
          '--label valhalla.fixture=$runId busybox:1.37.0 sh -c '
          '${cliShellQuote('trap "exit 0" TERM; while :; do echo operations-stdout; echo operations-stderr >&2; echo token=fixture-hidden >&2; sleep 1; done')}',
        );
        expect(created.isSuccess, true, reason: created.stderr);
        containerId = created.stdout.trim();
        await writeRootFile(
          unitPath,
          '[Unit]\nDescription=Valhalla isolated operations test\n'
          '[Service]\nUser=valhalla\nExecStart=/bin/sleep infinity\n',
        );
        await checked('sudo -n systemctl daemon-reload');
        // Give only this disposable unit a policy; production hosts are untouched.
        await writeRootFile(
          rule,
          'polkit.addRule(function(action, subject) {\n'
          'if (subject.user == "valhalla" && action.id == "org.freedesktop.systemd1.manage-units" '
          '&& action.lookup("unit") == "$unit") return polkit.Result.YES;\n});\n',
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });

      tearDownAll(() async {
        for (final bridge in bridges) {
          bridge.dispose();
        }
        if (ownedPid != null) {
          await command('kill -15 $ownedPid 2>/dev/null || true');
        }
        await command(
          'tmux -L valhalla kill-session -t ${cliShellQuote(TmuxSessionPlanner.sessionName(server.id, runId))} 2>/dev/null || true',
        );
        final inspected = await docker.inspect(server.id, containerId);
        expect(
          (inspected['Config'] as Map)['Labels']['valhalla.fixture'],
          runId,
        );
        await command(
          'docker unpause ${cliShellQuote(containerId)} >/dev/null 2>&1 || true',
        );
        await command('docker rm --force ${cliShellQuote(containerId)}');
        await command('sudo -n systemctl stop ${cliShellQuote(unit)}');
        await command('sudo -n systemctl reset-failed ${cliShellQuote(unit)}');
        await checked(
          'sudo -n rm -f -- ${cliShellQuote(unitPath)} ${cliShellQuote(rule)} && sudo -n systemctl daemon-reload',
        );
        ssh.dispose();
      });

      test(
        'Docker lists/inspects users and real stdout+stderr; cancelled follower releases session',
        () async {
          final containers = await docker.listContainers(server.id);
          final found = containers.singleWhere(
            (item) => item.id == containerId,
          );
          expect(found.name, name);
          expect(found.state, DockerContainerState.running);
          expect(
            (await docker.listContainerUsers(
              server.id,
              containerId,
            )).any((user) => user.name == 'root'),
            true,
          );
          final output = StringBuffer();
          final subscription = docker
              .streamLogs(server.id, containerId)
              .listen(output.write);
          await waitFor(
            () =>
                output.toString().contains('operations-stdout') &&
                output.toString().contains('operations-stderr'),
          );
          expect(output.toString(), isNot(contains('fixture-hidden')));
          final watch = Stopwatch()..start();
          await subscription.cancel().timeout(const Duration(seconds: 3));
          expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
          await checked(
            'test "\$(pgrep -fc ${cliShellQuote('docker logs -f --tail=100 $containerId')})" -le 1',
          );
          expect(ssh.isConnected(server.id), true);
        },
      );

      test(
        'Docker lifecycle pauses, resumes, restarts, stops and starts only owned container',
        () async {
          for (final step in [
            ('pause', 'Paused', true),
            ('unpause', 'Paused', false),
            ('restart', 'Running', true),
            ('stop', 'Running', false),
            ('start', 'Running', true),
          ]) {
            final result = await docker.lifecycle(
              server.id,
              step.$1,
              containerId,
            );
            expect(
              result.isSuccess,
              true,
              reason: '${step.$1}: ${result.stderr}',
            );
            final inspected = await docker.inspect(server.id, containerId);
            expect((inspected['State'] as Map)[step.$2], step.$3);
          }
          final renamed = '$name-renamed';
          expect(
            (await docker.rename(server.id, containerId, renamed)).isSuccess,
            true,
          );
          expect(
            (await docker.listContainers(
              server.id,
            )).singleWhere((c) => c.id == containerId).name,
            renamed,
          );
        },
      );

      test(
        'Docker PTY automatically falls back from absent bash to sh and executes',
        () async {
          final found = (await docker.listContainers(
            server.id,
          )).singleWhere((item) => item.id == containerId);
          final opened = await docker.openTerminal(
            server.id,
            found,
            server.name,
          );
          bridges.add(opened.bridge);
          expect(opened.shell, DockerTerminalShell.sh);
          await opened.bridge.start();
          expect(opened.bridge.state, TerminalConnectionState.connected);
          opened.bridge.sendCommand("printf '%s%s\\n' OPS-CONTAINER- EXECUTED");
          await waitFor(
            () => opened.bridge.readBufferText().contains(
              'OPS-CONTAINER-EXECUTED',
            ),
          );
          opened.bridge.dispose();
        },
      );

      test(
        'real process list and TERM affect only owned background process',
        () async {
          final created = await command(
            'nohup sleep 600 >/dev/null 2>&1 < /dev/null & echo \$!',
          );
          expect(created.isSuccess, true);
          ownedPid = int.parse(created.stdout.trim());
          final processes = ProcessService(ssh);
          expect(
            (await processes.list(
              server.id,
            )).singleWhere((p) => p.pid == ownedPid).command,
            'sleep',
          );
          expect(
            (await processes.terminate(server.id, ownedPid!)).isSuccess,
            true,
          );
          for (var i = 0; i < 20; i++) {
            if (!(await processes.list(
              server.id,
            )).any((p) => p.pid == ownedPid && !p.state.startsWith('Z'))) {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          expect(
            (await processes.list(
              server.id,
            )).where((p) => p.pid == ownedPid && !p.state.startsWith('Z')),
            isEmpty,
          );
          ownedPid = null;
        },
      );

      test(
        'system service start/list/restart/stop report actual running state',
        () async {
          final services = ServiceManager(ssh);
          final started = await services.action(server.id, unit, 'start');
          expect(started.isSuccess, true, reason: started.stderr);
          final running = (await services.list(
            server.id,
          )).singleWhere((item) => item.name == unit);
          expect(
            running.isRunning,
            true,
            reason: 'systemctl reports state=${running.state}',
          );
          expect(
            (await services.action(server.id, unit, 'restart')).isSuccess,
            true,
          );
          expect(
            (await services.action(server.id, unit, 'stop')).isSuccess,
            true,
          );
          final stopped = (await services.list(
            server.id,
          )).where((item) => item.name == unit);
          expect(stopped.every((item) => !item.isRunning), true);
          await writeRootFile(
            unitPath,
            '[Unit]\nDescription=Valhalla isolated failure test\n'
            '[Service]\nUser=valhalla\nExecStart=/bin/false\n',
          );
          await checked('sudo -n systemctl daemon-reload');
          await services.action(server.id, unit, 'start');
          SystemdServiceInfo? failed;
          for (var attempt = 0; attempt < 20; attempt++) {
            failed = (await services.list(
              server.id,
            )).where((item) => item.name == unit).firstOrNull;
            if (failed?.isFailed == true) break;
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          expect(failed?.isFailed, true);
        },
      );

      test(
        'real plain terminal handles ANSI, resize, split UTF8 and bounded long output',
        () async {
          final bridge = TerminalSessionBridge(
            terminal: Terminal(maxLines: 1500),
            sshClient: ssh.getClient(server.id),
            serverName: server.name,
            serverId: server.id,
          );
          bridges.add(bridge);
          await bridge.start(initialWidth: 90, initialHeight: 30);
          expect(bridge.state, TerminalConnectionState.connected);
          bridge.sendCommand(
            "printf '\\033[31m%s%s\\033[0m\\n' OPS-ANSI- DONE",
          );
          await waitFor(
            () => bridge.readBufferText().contains('OPS-ANSI-DONE'),
          );
          bridge.terminal.resize(100, 40);
          await Future<void>.delayed(const Duration(milliseconds: 150));
          bridge.sendCommand("printf 'SIZE='; stty size");
          await waitFor(() => bridge.readBufferText().contains('SIZE=40 100'));
          bridge.sendCommand(
            'python3 -c ${cliShellQuote('import os,time; os.write(1,b"UTF8-"); [ (os.write(1,bytes([n])),time.sleep(.05)) for n in [230,150,135] ]; os.write(1,b"-DONE\\n")')}',
          );
          await waitFor(
            () => bridge.readBufferText().contains('UTF8-文-DONE'),
            details: bridge.readBufferText,
          );
          bridge.sendCommand(
            'for i in \$(seq 1 1800); do printf "Long-%s\\n" "\$i"; done',
          );
          await waitFor(() => bridge.readBufferText().contains('Long-1800'));
          expect(bridge.terminal.buffer.lines.length, lessThanOrEqualTo(1540));
          bridge.dispose();
        },
      );

      test(
        'tmux detach/reattach preserves actual remote shell state',
        () async {
          TerminalSessionBridge create() => TerminalSessionBridge(
            terminal: Terminal(maxLines: 1500),
            sshClient: ssh.getClient(server.id),
            serverName: server.name,
            serverId: server.id,
            terminalId: runId,
            preferTmux: true,
          );
          final first = create();
          bridges.add(first);
          await first.start();
          expect(first.mode, TerminalSessionMode.tmux);
          first.sendCommand(
            'VALHALLA_TEST_CONTEXT=$runId; printf "%s%s\\n" TMUX- READY',
          );
          await waitFor(() => first.readBufferText().contains('TMUX-READY'));
          first.dispose();
          final next = create();
          bridges.add(next);
          await next.start();
          expect(next.mode, TerminalSessionMode.tmux);
          next.sendCommand('printf "CONTEXT=%s\\n" "\$VALHALLA_TEST_CONTEXT"');
          await waitFor(() => next.readBufferText().contains('CONTEXT=$runId'));
          next.dispose();
        },
      );
    },
    skip: credentialsPath == null
        ? 'Set VALHALLA_OPERATIONS_VM_CREDENTIALS for the disposable VM'
        : false,
  );
}
