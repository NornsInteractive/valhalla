import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/auto_connect_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/main.dart';

ServerProfile _server(String id, {String? name}) => ServerProfile(
  id: id,
  name: name ?? 'server $id',
  host: '$id.example.test',
  username: 'root',
);

AutoConnectSettings _settings(AutoConnectMode mode, {String? fixedId}) =>
    AutoConnectSettings(mode: mode, fixedServerId: fixedId);

String _serversJson(List<ServerProfile> servers) {
  final parts = servers.map(
    (s) =>
        '{"id":"${s.id}","name":"${s.name}","host":"${s.host}",'
        '"port":${s.port},"username":"${s.username}","authType":"password"}',
  );
  return '[${parts.join(',')}]';
}

void main() {
  group('resolveAutoConnectTarget', () {
    final servers = [_server('srv-1'), _server('srv-2')];

    test('lastConnected 模式取最后连接过的那台', () {
      final target = resolveAutoConnectTarget(
        settings: _settings(AutoConnectMode.lastConnected),
        servers: servers,
        lastConnectedServerId: 'srv-2',
      );

      expect(target?.id, 'srv-2');
    });

    test('lastConnected 模式没有记录时不连接', () {
      final target = resolveAutoConnectTarget(
        settings: _settings(AutoConnectMode.lastConnected),
        servers: servers,
        lastConnectedServerId: null,
      );

      expect(target, isNull);
    });

    test('fixed 模式取指定的那台', () {
      final target = resolveAutoConnectTarget(
        settings: _settings(AutoConnectMode.fixed, fixedId: 'srv-1'),
        servers: servers,
        lastConnectedServerId: 'srv-2',
      );

      expect(target?.id, 'srv-1', reason: 'fixed 模式必须无视 lastConnected 记录');
    });

    test('fixed 模式未指定时不连接', () {
      final target = resolveAutoConnectTarget(
        settings: _settings(AutoConnectMode.fixed),
        servers: servers,
        lastConnectedServerId: 'srv-2',
      );

      expect(target, isNull, reason: '未指定固定服务器时不能顺手连 lastConnected 那台');
    });

    test('fixed 模式指向已删除的服务器时不连接，也不回落到第一台', () {
      final target = resolveAutoConnectTarget(
        settings: _settings(AutoConnectMode.fixed, fixedId: 'srv-gone'),
        servers: servers,
        lastConnectedServerId: null,
      );

      // 本组最关键的一条：ActiveServerNotifier 会对找不到的 id 回落到
      // servers.first，所以这里必须自己按 id 找，否则会静默连错服务器。
      expect(target, isNull);
    });

    test('lastConnected 记录已失效时不连接', () {
      final target = resolveAutoConnectTarget(
        settings: _settings(AutoConnectMode.lastConnected),
        servers: [_server('srv-1')],
        lastConnectedServerId: 'srv-2',
      );

      expect(target, isNull);
    });

    test('服务器列表为空时不连接', () {
      final target = resolveAutoConnectTarget(
        settings: _settings(AutoConnectMode.fixed, fixedId: 'srv-1'),
        servers: const [],
        lastConnectedServerId: null,
      );

      expect(target, isNull);
    });
  });

  group('shouldAutoConnect', () {
    test('开启且未尝试过 → 连', () {
      expect(shouldAutoConnect(alreadyAttempted: false, enabled: true), isTrue);
    });

    test('关闭 → 不连，即使没尝试过', () {
      expect(
        shouldAutoConnect(alreadyAttempted: false, enabled: false),
        isFalse,
        reason: '默认关闭是防止测试环境发起真实连接的唯一保险',
      );
    });

    test('已尝试过 → 不连，即使开启', () {
      expect(
        shouldAutoConnect(alreadyAttempted: true, enabled: true),
        isFalse,
        reason: '重复自动连接会多一次 SSH 握手，还可能多弹一次指纹确认',
      );
    });
  });

  group('_LifecycleHost 启动钩子', () {
    /// 只带存储的容器；不覆盖 [autoConnectEnabledProvider]，因为它要跟着
    /// 被测量的行为走。
    Future<LocalStorageService> storageWith({
      List<ServerProfile> servers = const [],
      String? activeId,
      String? lastConnectedId,
      String mode = 'lastConnected',
      String? fixedId,
    }) async {
      SharedPreferences.setMockInitialValues({
        'valhalla_servers_v1': _serversJson(servers),
        'valhalla_auto_connect_mode_v1': mode,
        'valhalla_auto_connect_server_id_v1': ?fixedId,
        'valhalla_last_connected_server_id_v1': ?lastConnectedId,
        'valhalla_active_server_id_v1': ?activeId,
      });
      return LocalStorageService(await SharedPreferences.getInstance());
    }

    /// 把 `_LifecycleHost` 挂进测试树。
    ///
    /// [connectCalls] 用来数真实连接有没有被发起——连接会走
    /// `serverConnectionProvider`，这里整个覆盖掉，避免真去拨 SSH。
    Future<ProviderContainer> pump({
      required WidgetTester tester,
      required LocalStorageService storage,
      required bool enabled,
    }) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          autoConnectEnabledProvider.overrideWithValue(enabled),
          // connect() 不返回错误也不抛，只记一笔调用。
          serverConnectionProvider.overrideWith(_RecordingConnection.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: _HostProbe()),
        ),
      );
      await tester.pump();
      return container;
    }

    testWidgets('开启且能解析出目标时写入 active id 并发起连接', (tester) async {
      final storage = await storageWith(
        servers: [_server('srv-1'), _server('srv-2')],
        lastConnectedId: 'srv-2',
      );
      final container = await pump(
        tester: tester,
        storage: storage,
        enabled: true,
      );
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('valhalla_active_server_id_v1'),
        'srv-2',
        reason: 'connect() 自己读 activeServerProvider，不落盘就会连启动时那台',
      );

      final notifier =
          container.read(serverConnectionProvider.notifier)
              as _RecordingConnection;
      expect(notifier.connectedServerIds, ['srv-2']);
    });

    testWidgets('开关关闭时什么都不做', (tester) async {
      final storage = await storageWith(
        servers: [_server('srv-1')],
        lastConnectedId: 'srv-1',
      );
      final container = await pump(
        tester: tester,
        storage: storage,
        enabled: false,
      );
      await tester.pump();

      final notifier =
          container.read(serverConnectionProvider.notifier)
              as _RecordingConnection;
      expect(
        notifier.connectedServerIds,
        isEmpty,
        reason: '默认关闭是防止测试环境意外发起真实连接的唯一保险',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('valhalla_active_server_id_v1'), isNull);
    });

    testWidgets('有目标但服务器已被删除时不连接、也不改 active id', (tester) async {
      final storage = await storageWith(
        servers: [_server('srv-1')],
        lastConnectedId: 'srv-gone',
      );
      final container = await pump(
        tester: tester,
        storage: storage,
        enabled: true,
      );
      await tester.pump();

      final notifier =
          container.read(serverConnectionProvider.notifier)
              as _RecordingConnection;
      expect(notifier.connectedServerIds, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'valhalla_active_server_id_v1',
        ),
        isNull,
      );
    });

    testWidgets('fixed 模式连指定那台，无视 lastConnected 记录', (tester) async {
      final storage = await storageWith(
        servers: [_server('srv-1'), _server('srv-2')],
        lastConnectedId: 'srv-2',
        mode: 'fixed',
        fixedId: 'srv-1',
      );
      final container = await pump(
        tester: tester,
        storage: storage,
        enabled: true,
      );
      await tester.pump();

      final notifier =
          container.read(serverConnectionProvider.notifier)
              as _RecordingConnection;
      expect(notifier.connectedServerIds, ['srv-1']);
    });

    testWidgets('重建只触发一次连接', (tester) async {
      final storage = await storageWith(
        servers: [_server('srv-1')],
        lastConnectedId: 'srv-1',
      );
      final container = await pump(
        tester: tester,
        storage: storage,
        enabled: true,
      );
      await tester.pump();

      // 重建：State 被复用，initState 不会再跑，因此连接次数不变。
      //
      // 注意这里不能靠「换 key 逼出全新 State」来验证一次性保护——
      // 那个字段就活在 State 上，新 State 自然又是 false，断言必然通过，
      // 是个假绿。真要防的结构性风险是「同一棵树里反复 initState」，
      // 而那只有 State 存活时才有意义，正是下面这个 pumpWidget 覆盖的。
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: _HostProbe()),
        ),
      );
      await tester.pump();

      final notifier =
          container.read(serverConnectionProvider.notifier)
              as _RecordingConnection;
      expect(
        notifier.connectedServerIds.length,
        1,
        reason: '重建不该再连一次：多一次 SSH 握手，还可能多弹一次指纹确认',
      );
    });
  });
}

/// 复现 `main()` 里启动钩子的接线。
///
/// 守卫判定走的是 `lib/main.dart` 里那个 [shouldAutoConnect]，而不是在测试里
/// 重写一份——否则「把开关守丢掉」这种改动就测不出来了。
class _HostProbe extends ConsumerStatefulWidget {
  const _HostProbe();

  @override
  ConsumerState<_HostProbe> createState() => _HostProbeState();
}

class _HostProbeState extends ConsumerState<_HostProbe> {
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    final enabled = ref.read(autoConnectEnabledProvider);
    if (!shouldAutoConnect(alreadyAttempted: _attempted, enabled: enabled)) {
      return;
    }
    _attempted = true;
    runAutoConnect(ref);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// 只记录调用、不真的连接的替身。
class _RecordingConnection extends ServerConnectionNotifier {
  final List<String> connectedServerIds = [];

  @override
  ServerConnectionState build() => const ServerConnectionState();

  @override
  Future<bool> connect({
    String? password,
    String? privateKey,
    Future<bool> Function(String, String, String)? onConfirmHostKey,
  }) async {
    final active = ref.read(activeServerProvider);
    if (active != null) connectedServerIds.add(active.id);
    return true;
  }
}
