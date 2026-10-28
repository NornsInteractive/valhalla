import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/workspace/workspace_gateway.dart';
import 'package:valhalla/data/workspace/workspace_session_control.dart';
import 'package:valhalla/infrastructure/workspace/remote_workspace_client.dart';

class _FakeGateway implements WorkspaceGateway {
  _FakeGateway(this.deviceId);

  @override
  final String deviceId;

  final enabled = <String>{'srv-a', 'srv-b'};
  final requests = <({String serverId, Map<String, dynamic> command})>[];
  final changesController = StreamController<WorkspaceChange>.broadcast();

  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>) handler =
      (_, _) async => <String, dynamic>{};

  @override
  bool isEnabled(String serverId) => enabled.contains(serverId);

  @override
  Future<Map<String, dynamic>> request(
    String serverId,
    Map<String, dynamic> command,
  ) {
    requests.add((serverId: serverId, command: command));
    return handler(serverId, command);
  }

  @override
  Future<void> putRecords(
    String serverId,
    List<Map<String, dynamic>> records,
  ) async {}

  @override
  Stream<WorkspaceChange> get changes => changesController.stream;
}

Map<String, dynamic> _lease(
  String token,
  int generation, {
  String owner = 'dev-1',
  Duration ttl = const Duration(seconds: 60),
}) => {
  'ownerDeviceId': owner,
  'token': token,
  'generation': generation,
  'expiresAt': DateTime.now().toUtc().add(ttl).millisecondsSinceEpoch / 1000,
};

void main() {
  group('WorkspaceSessionControl lease', () {
    test('acquire is scoped to the intrinsic server and session', () async {
      final gateway = _FakeGateway('dev-1');
      gateway.handler = (_, _) async => _lease('token-1', 1);
      final control = WorkspaceSessionControl(
        gateway: gateway,
        serverId: 'srv-a',
        sessionId: 'session-a',
        onChanged: () {},
        isForeground: () => true,
      );
      addTearDown(control.dispose);

      expect(await control.acquire(), isTrue);
      expect(control.hasControl, isTrue);
      expect(gateway.requests.single.serverId, 'srv-a');
      expect(gateway.requests.single.command['sessionId'], 'session-a');
      expect(gateway.requests.single.command['action'], 'acquire');
      expect(control.context['workspaceSessionId'], 'session-a');
      expect(control.context['controlToken'], 'token-1');
      expect(control.context['controlGeneration'], 1);
    });

    test('another device holding the lease is never taken over', () async {
      final gateway = _FakeGateway('dev-1');
      gateway.handler = (_, _) async => throw const WorkspaceException(
        'WORKSPACE_CONTROL_HELD',
        {'ownerDeviceId': 'dev-2'},
      );
      final control = WorkspaceSessionControl(
        gateway: gateway,
        serverId: 'srv-a',
        sessionId: 'session-a',
        onChanged: () {},
        isForeground: () => true,
      );
      addTearDown(control.dispose);

      expect(await control.acquire(), isFalse);
      expect(control.hasControl, isFalse);
      expect(control.ownerDeviceId, 'dev-2');
      expect(gateway.requests.map((r) => r.command['action']), ['acquire']);
    });

    test('own restart reclaims the same device UUID with a takeover', () async {
      final gateway = _FakeGateway('dev-1');
      gateway.handler = (_, command) async {
        if (command['action'] == 'takeover') {
          return _lease('token-2', 2);
        }
        throw const WorkspaceException('WORKSPACE_LEASE_INVALID');
      };
      final control = WorkspaceSessionControl(
        gateway: gateway,
        serverId: 'srv-a',
        sessionId: 'session-a',
        onChanged: () {},
        isForeground: () => true,
      );
      addTearDown(control.dispose);

      expect(await control.acquire(), isTrue);
      expect(control.hasControl, isTrue);
      expect(gateway.requests.map((r) => r.command['action']), [
        'acquire',
        'takeover',
      ]);
      expect(gateway.requests.last.command['token'], isNull);
    });

    test('a failed renewal does not takeover a foreign lease', () async {
      final gateway = _FakeGateway('dev-1');
      var calls = 0;
      gateway.handler = (_, command) async {
        calls++;
        if (calls == 1) return _lease('token-1', 1);
        if (command['action'] == 'renew') {
          throw const WorkspaceException('WORKSPACE_LEASE_INVALID');
        }
        if (command['action'] == 'acquire') {
          throw const WorkspaceException('WORKSPACE_CONTROL_HELD', {
            'ownerDeviceId': 'dev-2',
          });
        }
        return _lease('token-3', 3);
      };
      final control = WorkspaceSessionControl(
        gateway: gateway,
        serverId: 'srv-a',
        sessionId: 'session-a',
        onChanged: () {},
        isForeground: () => true,
      );
      addTearDown(control.dispose);

      expect(await control.acquire(), isTrue);
      expect(await control.acquire(), isFalse);
      expect(control.hasControl, isFalse);
      expect(control.ownerDeviceId, 'dev-2');
      expect(gateway.requests.map((r) => r.command['action']), [
        'acquire',
        'renew',
        'acquire',
      ]);
    });

    test('heartbeat renews only while foreground', () {
      fakeAsync((async) {
        final gateway = _FakeGateway('dev-1');
        var generation = 1;
        gateway.handler = (_, _) async => _lease('token-1', generation++);
        var foreground = false;
        final control = WorkspaceSessionControl(
          gateway: gateway,
          serverId: 'srv-a',
          sessionId: 'session-a',
          onChanged: () {},
          isForeground: () => foreground,
        );
        control.acquire();
        async.flushMicrotasks();
        expect(gateway.requests, hasLength(1));

        async.elapse(const Duration(seconds: 40));
        expect(gateway.requests, hasLength(1));

        foreground = true;
        async.elapse(const Duration(seconds: 20));
        expect(gateway.requests, hasLength(2));
        expect(gateway.requests.last.command['action'], 'renew');

        control.dispose();
        async.elapse(const Duration(seconds: 60));
        expect(gateway.requests, hasLength(2));
      });
    });

    test('dispose cancels the heartbeat timer', () {
      fakeAsync((async) {
        final gateway = _FakeGateway('dev-1');
        gateway.handler = (_, _) async => _lease('token-1', 1);
        final control = WorkspaceSessionControl(
          gateway: gateway,
          serverId: 'srv-a',
          sessionId: 'session-a',
          onChanged: () {},
          isForeground: () => true,
        );
        control.acquire();
        async.flushMicrotasks();
        expect(gateway.requests, hasLength(1));
        control.dispose();
        async.elapse(const Duration(minutes: 5));
        expect(gateway.requests, hasLength(1));
        expect(async.pendingTimers, isEmpty);
      });
    });

    test(
      'an unexpected gateway failure still surfaces to the caller',
      () async {
        final gateway = _FakeGateway('dev-1');
        gateway.handler = (_, _) async =>
            throw const WorkspaceException('WORKSPACE_OFFLINE');
        final control = WorkspaceSessionControl(
          gateway: gateway,
          serverId: 'srv-a',
          sessionId: 'session-a',
          onChanged: () {},
          isForeground: () => true,
        );
        addTearDown(control.dispose);

        await expectLater(
          control.acquire(),
          throwsA(
            isA<WorkspaceException>().having(
              (e) => e.code,
              'code',
              'WORKSPACE_OFFLINE',
            ),
          ),
        );
        expect(control.hasControl, isFalse);
      },
    );
  });
}
