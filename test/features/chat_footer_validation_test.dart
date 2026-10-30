// 验证 AgY 在聊天底部操作条（ChatRunSettingsStrip + AiChatView 页脚装配）上的改动：
// 320dp 窄屏、键盘安全区、放大字号下的溢出/动作可见性、以及点按目标尺寸。
// 本文件只做验证与测量，不修改任何 UI 代码；若发现问题，交由 AgY 修正。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_run_settings.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/features/chat/widgets/chat_run_settings_strip.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import '../support/temp_chat_db.dart';

class _FakeAiChatNotifier extends AiChatNotifier {
  final AiChatState _initialState;
  _FakeAiChatNotifier(this._initialState);
  @override
  AiChatState build() => _initialState;
  @override
  Future<bool> prepareRunSettings({bool refresh = false}) async => true;
}

class _TestServerConnectionNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.connected);
}

class _TestActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _TestActiveServerNotifier(this._server);
  @override
  ServerProfile? build() => _server;
}

class _TestAgentRegistryNotifier extends AgentRegistryNotifier {
  final List<AgentProfile> _agents;
  _TestAgentRegistryNotifier(this._agents);
  @override
  AgentRegistryState build() => AgentRegistryState(
        agents: _agents
            .map(
              (a) => AgentRuntimeState(
                profile: a,
                status: AgentEnvironmentStatus(
                  kind: AgentEnvironmentStatusKind.ready,
                  checkedAt: DateTime.utc(2026),
                ),
              ),
            )
            .toList(),
      );
}

Widget _wrap(Widget child, {List<dynamic> overrides = const []}) =>
    ProviderScope(
      overrides: [tempChatRepositoryOverride(), ...overrides.cast()],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

// 构造一个带 leading（工作目录按钮 + 清除按钮）和 trailing（用量/诊断）的 strip 副本，
// 用于隔离验证 AgY 在 ChatRunSettingsStrip 上新增的 leading/trailing 插槽与 40x40 点按目标。
Widget _buildStrip({Widget? leading, Widget? trailing}) {
  return ChatRunSettingsStrip(
    settings: const ChatRunSettings(
      modelId: 'gpt-4',
      permissionPolicy: OperationPermissionPolicy.askEveryTime,
    ),
    capabilities: const AgentRuntimeCapabilities(
      models: [ChatSettingOption('gpt-4', 'GPT-4')],
      reasoningLevels: [ChatSettingOption('low', 'Low')],
    ),
    isBusy: false,
    onOpenSettings: () {},
    onRefreshSettings: () {},
    leading: leading,
    trailing: trailing,
  );
}

Widget _longWorkingDirLeading() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: const Key('chat_working_dir_button'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_outlined, size: 14),
                SizedBox(width: 5),
                SizedBox(
                  width: 160,
                  child: Text(
                    'a-very-long-remote-working-directory-path-that-should-ellipsize',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          onTap: () {},
        ),
        const SizedBox(width: 2),
        IconButton(
          key: const Key('chat_clear_draft_working_dir_button'),
          icon: const Icon(Icons.close, size: 16),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () {},
        ),
      ],
    );

Widget _usageTrailing() => IconButton(
      key: const Key('chat_usage_diagnostics_action_button'),
      icon: const Icon(Icons.analytics_outlined, size: 18),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: () {},
    );

void main() {
  final testServer = ServerProfile(
    id: 'srv-1',
    name: 'Production Server',
    host: '192.168.1.1',
    port: 22,
    username: 'root',
    authType: AuthType.password,
  );
  final testAcpAgent = AgentProfile(
    id: 'agent-acp',
    serverId: 'srv-1',
    name: 'Claude Code ACP',
    description: 'ACP agent',
    cliCommand: 'claude',
    acpCommand: 'claude-acp',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ChatRunSettingsStrip footer validation (AgY edits)', () {
    testWidgets('320dp: no overflow, actions visible, tap targets >= 40',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          _buildStrip(
            leading: _longWorkingDirLeading(),
            trailing: _usageTrailing(),
          ),
        ),
      );
      Object? err;
      try {
        await tester.pumpAndSettle();
      } catch (e) {
        err = e;
      }
      expect(err, isNull, reason: 'horizontal scroll must prevent overflow');

      // 动作可见性
      expect(
        find.byKey(const Key('chat_run_settings_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_run_settings_strip_refresh_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_working_dir_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_usage_diagnostics_action_button')),
        findsOneWidget,
      );

      // 点按目标 >= 40x40（图标按钮）
      final tune = tester.getSize(
        find.byKey(const Key('chat_run_settings_button')),
      );
      final refresh = tester.getSize(
        find.byKey(const Key('chat_run_settings_strip_refresh_button')),
      );
      final usage = tester.getSize(
        find.byKey(const Key('chat_usage_diagnostics_action_button')),
      );
      expect(tune.width, greaterThanOrEqualTo(40));
      expect(tune.height, greaterThanOrEqualTo(40));
      expect(refresh.width, greaterThanOrEqualTo(40));
      expect(refresh.height, greaterThanOrEqualTo(40));
      expect(usage.width, greaterThanOrEqualTo(40));
      expect(usage.height, greaterThanOrEqualTo(40));
    });

    testWidgets('larger text scale (1.5x / 2.0x): no overflow, tap targets held',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final scale in const [1.5, 2.0]) {
        await tester.pumpWidget(
          _wrap(
            MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: _buildStrip(
                leading: _longWorkingDirLeading(),
                trailing: _usageTrailing(),
              ),
            ),
          ),
        );
        Object? err;
        try {
          await tester.pumpAndSettle();
        } catch (e) {
          err = e;
        }
        expect(err, isNull,
            reason: 'text scale $scale must not overflow the strip');

        final tune = tester.getSize(
          find.byKey(const Key('chat_run_settings_button')),
        );
        expect(tune.width, greaterThanOrEqualTo(40),
            reason: 'tap target held at scale $scale');
        expect(tune.height, greaterThanOrEqualTo(40),
            reason: 'tap target held at scale $scale');
      }
    });

    testWidgets('keyboard inset present: footer actions stay reachable, no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: _buildStrip(
              leading: _longWorkingDirLeading(),
              trailing: _usageTrailing(),
            ),
          ),
        ),
      );
      Object? err;
      try {
        await tester.pumpAndSettle();
      } catch (e) {
        err = e;
      }
      expect(err, isNull, reason: 'keyboard inset must not overflow the strip');

      // 即便键盘顶起，动作仍在组件树中且可命中。
      expect(
        find.byKey(const Key('chat_run_settings_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_usage_diagnostics_action_button')),
        findsOneWidget,
      );
    });

    testWidgets('trailing omitted when not provided: usage action absent',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(_buildStrip(leading: _longWorkingDirLeading())),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_usage_diagnostics_action_button')),
        findsNothing,
      );
      // 基础动作仍在
      expect(
        find.byKey(const Key('chat_run_settings_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_working_dir_button')),
        findsOneWidget,
      );
    });
  });

  group('AiChatView footer composition at 320dp (AgY wiring)', () {
    testWidgets(
        'mobile 320dp: strip + working-dir leading + usage trailing present, no overflow',
        (tester) async {
      final local = await LocalStorageService.init();
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final aiNotifier = _FakeAiChatNotifier(
        AiChatState(
          sessions: [
            ChatSession(
              id: 's-1',
              title: 'Session 1',
              serverId: 'srv-1',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              workingDirectory: '/home/user/project-root',
            ),
          ],
          activeSessionId: 's-1',
          activeAgentProfile: testAcpAgent,
          runSettings: const ChatRunSettings(
            modelId: 'gpt-4',
            permissionPolicy: OperationPermissionPolicy.askEveryTime,
          ),
          capabilities: const AgentRuntimeCapabilities(
            models: [ChatSettingOption('gpt-4', 'GPT-4')],
            reasoningLevels: [ChatSettingOption('low', 'Low')],
          ),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          const AiChatView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              _TestServerConnectionNotifier.new,
            ),
            agentRegistryProvider.overrideWith(
              () => _TestAgentRegistryNotifier([testAcpAgent]),
            ),
            aiChatProvider.overrideWith(() => aiNotifier),
          ],
        ),
      );
      Object? err;
      try {
        await tester.pumpAndSettle();
      } catch (e) {
        err = e;
      }
      expect(err, isNull, reason: 'AiChatView footer must not overflow at 320dp');

      // 页脚装配：strip 存在
      expect(
        find.byKey(const Key('chat_run_settings_strip')),
        findsOneWidget,
      );
      // leading 工作目录按钮存在
      expect(
        find.byKey(const Key('chat_working_dir_button')),
        findsOneWidget,
      );
      // trailing 用量/诊断动作存在（activeAgentProfile 触发）
      expect(
        find.byKey(const Key('chat_usage_diagnostics_action_button')),
        findsOneWidget,
      );
    });
  });
}
