import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/builtin_agent_preset.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/agents/agent_management_view.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/temp_chat_db.dart';

/// AgY ACP sign-in must leave the management route immediately: the remote
/// method discovery keeps running in the background, so the user is never
/// parked on a screen that cannot finish until a network round trip returns.
void main() {
  final testServer = ServerProfile(
    id: 'srv-test-1',
    name: 'Production US',
    host: '192.168.1.100',
    port: 22,
    username: 'admin',
    authType: AuthType.password,
  );

  final agyProfile = AgentProfile(
    id: 'builtin-agy',
    serverId: 'srv-test-1',
    name: 'Antigravity',
    description: 'Official ACP agent',
    cliCommand: 'agy',
    acpCommand: 'agy_acp_server.par',
    loginCommand: 'agy',
    loginCheckCommand: kAntigravityLoginCheckCommand,
  );

  AgentRuntimeState agyRuntime() => AgentRuntimeState(
    profile: agyProfile,
    status: AgentEnvironmentStatus(
      kind: AgentEnvironmentStatusKind.ready,
      detail: 'AGY_ACP_SIGN_IN_REQUIRED',
      checkedAt: DateTime.now(),
      authentication: AgentAuthenticationStatus.unauthenticated,
    ),
  );

  Widget app({
    required VoidCallback? onNavigateToChat,
    required _RecordingAiChatNotifier chat,
    required LocalStorageService storage,
  }) {
    return ProviderScope(
      overrides: [
        tempChatRepositoryOverride(),
        localStorageServiceProvider.overrideWithValue(storage),
        activeServerProvider.overrideWith(() => _FixedServer(testServer)),
        serverConnectionProvider.overrideWith(
          () => _FixedConnection(testServer.id),
        ),
        agentRegistryProvider.overrideWith(
          () => _FixedRegistry(
            AgentRegistryState(serverId: 'srv-test-1', agents: [agyRuntime()]),
          ),
        ),
        aiChatProvider.overrideWith(() => chat),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AgentManagementView(onNavigateToChat: onNavigateToChat),
      ),
    );
  }

  late LocalStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
  });

  testWidgets('ACP 登录立即离开管理页，不等远端方法发现返回', (tester) async {
    final chat = _RecordingAiChatNotifier();
    var navigations = 0;

    await tester.pumpWidget(
      app(onNavigateToChat: () => navigations++, chat: chat, storage: storage),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('agent_acp_callout_login_builtin-agy'));
    expect(button, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(button);
    // 一帧之内必须已经发出请求并完成跳转：远端调用仍然挂着。
    await tester.pump();

    expect(chat.authRequests, [
      ('srv-test-1', 'builtin-agy'),
    ], reason: '只发起方法发现，不建会话不发文本');
    expect(navigations, 1, reason: '跳转不得 await 远端初始化');
    expect(chat.pendingAuth, isTrue, reason: '远端调用仍未返回');

    // 认证还在进行时再点一次：不能重复发起。
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    expect(chat.authRequests, hasLength(1));
    expect(navigations, 1);
  });

  testWidgets('管理页是首页时跳转仍然发生，不依赖 pop', (tester) async {
    final chat = _RecordingAiChatNotifier();
    var navigations = 0;

    await tester.pumpWidget(
      app(onNavigateToChat: () => navigations++, chat: chat, storage: storage),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('agent_acp_callout_login_builtin-agy')),
    );
    await tester.pump();

    expect(navigations, 1, reason: 'canPop()==false 时也要走回调');
    expect(tester.takeException(), isNull);
  });

  testWidgets('360px 窄屏：ACP 登录入口可见、可点且不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chat = _RecordingAiChatNotifier();
    var navigations = 0;

    await tester.pumpWidget(
      app(onNavigateToChat: () => navigations++, chat: chat, storage: storage),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('agent_acp_callout_login_builtin-agy'));
    expect(button, findsOneWidget, reason: '窄屏也必须保留 ACP 登录入口');
    expect(tester.takeException(), isNull, reason: '不得有布局溢出');

    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    expect(chat.authRequests, [('srv-test-1', 'builtin-agy')]);
    expect(navigations, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px 最小支持宽度：ACP 登录入口可见、可点且不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final chat = _RecordingAiChatNotifier();
    var navigations = 0;

    await tester.pumpWidget(
      app(onNavigateToChat: () => navigations++, chat: chat, storage: storage),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('agent_acp_callout_login_builtin-agy'));
    expect(button, findsOneWidget, reason: '最小宽度下也不能把入口挤掉');
    expect(tester.takeException(), isNull, reason: '不得有布局溢出');

    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    expect(chat.authRequests, [('srv-test-1', 'builtin-agy')]);
    expect(navigations, 1);
    expect(tester.takeException(), isNull);
  });
}

/// Records the method-discovery call and never completes it, so the view's
/// "navigate immediately" contract is observable.
class _RecordingAiChatNotifier extends AiChatNotifier {
  final List<(String, String)> authRequests = [];
  bool pendingAuth = false;

  @override
  AiChatState build() => const AiChatState();

  @override
  Future<void> requestAuthenticationForAgent(
    String serverId,
    String agentId,
  ) async {
    authRequests.add((serverId, agentId));
    pendingAuth = true;
    // 永不完成：远端方法发现可能挂着很久，跳转不能等它。
    await Completer<void>().future;
  }
}

class _FixedServer extends ActiveServerNotifier {
  _FixedServer(this._server);
  final ServerProfile _server;

  @override
  ServerProfile? build() => _server;
}

class _FixedConnection extends ServerConnectionNotifier {
  _FixedConnection(this._serverId);
  final String _serverId;

  @override
  ServerConnectionState build() => ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: _serverId,
  );
}

class _FixedRegistry extends AgentRegistryNotifier {
  _FixedRegistry(this._state);
  final AgentRegistryState _state;

  @override
  AgentRegistryState build() => _state;
}
