import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_run_settings.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/features/chat/widgets/chat_commands_skills_dialog.dart';
import 'package:valhalla/features/chat/widgets/chat_run_settings_dialog.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart';

/// 模型目录 / 独立授权 / 权限确认 / 草稿命令的控件回归。
///
/// 全部由内存替身驱动：不建立 SSH/Agent 连接，不打开真实浏览器，
/// 不触碰任何凭据或远端 RPC。

const _models = [
  ChatSettingOption('gpt-5', 'GPT-5'),
  ChatSettingOption('gpt-5-mini', 'GPT-5 mini'),
];

const _reasoningLevels = [ChatSettingOption('high', 'High')];
const _modes = [ChatSettingOption('plan', 'Plan')];

const _fullCapabilities = AgentRuntimeCapabilities(
  models: _models,
  reasoningLevels: _reasoningLevels,
  modes: _modes,
  supportsStructuredSettings: true,
  currentModelId: 'gpt-5',
  currentReasoningId: 'high',
  currentModeId: 'plan',
);

const _panelCommands = [
  AcpSlashCommand('status', 'Show session status', 'query'),
  AcpSlashCommand('compact', 'Compact the transcript', null),
  AcpSlashCommand(r'$review', 'Review the diff', 'skill'),
];

/// Exact English copy resolved through the same delegate the widget tree uses,
/// so expectations follow legitimate localization changes instead of hardcoding
/// a string that no longer ships.
AppLocalizations enL10n() => lookupAppLocalizations(const Locale('en'));

/// 授权卡与保存按钮都带无限转圈的 [CircularProgressIndicator]，
/// 这些状态下 `pumpAndSettle` 永远等不到「无新帧」，必须按固定帧数推进。
Future<void> pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> openSettings(
  WidgetTester tester, {
  required AgentRuntimeCapabilities capabilities,
  ChatRunSettings initialSettings = const ChatRunSettings(),
  String? modelCatalogError,
  String? serverName,
  String? containerName,
  String? agentUserName,
  Future<AgentRuntimeCapabilities?> Function()? onRefresh,
  ChatRunSettingsMetadata Function()? onFetchMetadata,
  FutureOr<void> Function(ChatRunSettings)? onSave,
  Future<void> Function()? onAuthorize,
  VoidCallback? onCancelAuthorize,
}) async {
  await loadRealTextFonts();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.buildTheme(
        brightness: Brightness.dark,
        seedColor: AppAccentColor.cyberEmerald.color,
      ),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open_settings'),
              onPressed: () => ChatRunSettingsDialog.show(
                context,
                initialSettings: initialSettings,
                capabilities: capabilities,
                isStructuredSend: true,
                modelCatalogError: modelCatalogError,
                serverName: serverName,
                containerName: containerName,
                agentUserName: agentUserName,
                onRefresh: onRefresh,
                onFetchMetadata: onFetchMetadata,
                onSave: onSave ?? (_) {},
                onAuthorize: onAuthorize,
                onCancelAuthorize: onCancelAuthorize,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open_settings')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('chat_run_settings_dialog')), findsOneWidget);
}

Future<void> openAuthorizeConfirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('chat_run_settings_authorize_button')));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
}

Future<void> acceptAuthorize(WidgetTester tester) async {
  expect(find.byType(AlertDialog), findsOneWidget);
  await tester.tap(
    find.byKey(const Key('chat_model_authorize_confirm_button')),
  );
  await pumpFrames(tester);
}

class _ComposerChatNotifier extends FakeAcpChatNotifier {
  _ComposerChatNotifier(super.initialState);

  int prepareComposerCatalogCalls = 0;
  Completer<bool>? prepareRunSettingsGate;

  /// 非 null 时 [prepareComposerCatalog] 挂起在它上面，用于构造
  /// 「面板已关闭、目录查询还没返回」的迟到回调。
  Completer<bool>? composerCatalogGate;

  @override
  Future<bool> prepareComposerCatalog() async {
    prepareComposerCatalogCalls++;
    final gate = composerCatalogGate;
    if (gate != null) return gate.future;
    return true;
  }

  /// 模拟后台协议通知把新的命令清单推给 provider。
  void publishCommands(List<AcpSlashCommand> commands) {
    state = state.copyWith(commands: commands);
  }

  @override
  Future<bool> prepareRunSettings({bool refresh = false}) async {
    prepareRunSettingsCalls++;
    final gate = prepareRunSettingsGate;
    if (gate != null) return gate.future;
    return refreshResult;
  }

  void applyTargetAgent(AgentProfile profile) {
    state = state.copyWith(activeAgentProfile: profile);
  }
}

void main() {
  final otherAgent = AgentProfile(
    id: 'agent-other',
    serverId: harnessServerId,
    name: 'Other ACP Agent',
    description: 'another agent',
    cliCommand: 'other-cli',
    acpCommand: 'other-acp',
  );

  group('模型目录 - 空目录 / 失配当前项 / 刷新', () {
    testWidgets('目录为空时下拉不可用且不触发断言，也绝不回退到缺失的 currentModelId', (tester) async {
      await openSettings(
        tester,
        capabilities: const AgentRuntimeCapabilities(
          reasoningLevels: _reasoningLevels,
          modes: _modes,
          supportsStructuredSettings: true,
          currentModelId: 'gpt-5',
          currentReasoningId: 'high',
          currentModeId: 'plan',
        ),
        initialSettings: const ChatRunSettings(modelId: 'gpt-5'),
      );

      expect(tester.takeException(), isNull);
      final button = tester.widget<DropdownButton<String?>>(
        find.descendant(
          of: find.byKey(const Key('chat_run_settings_model_dropdown')),
          matching: find.byType(DropdownButton<String?>),
        ),
      );
      expect(button.items, isNull);
      expect(button.onChanged, isNull);
      expect(
        find.text(enL10n().chatSettingsIndependentModelUnavailable),
        findsOneWidget,
        reason: '文案已改为说明 CLI 当前目录与手工录入，断言必须跟随实际字符串',
      );
      // 空目录下不得把远端声称的 currentModelId 渲染成已选项
      expect(find.text('gpt-5'), findsNothing);
    });

    testWidgets('目录里没有当前模型时回落到 Default，绝不显示不存在的 id', (tester) async {
      ChatRunSettings? saved;
      await openSettings(
        tester,
        capabilities: const AgentRuntimeCapabilities(
          models: _models,
          reasoningLevels: _reasoningLevels,
          modes: _modes,
          supportsStructuredSettings: true,
          currentModelId: 'ghost-model',
          currentReasoningId: 'high',
          currentModeId: 'plan',
        ),
        initialSettings: const ChatRunSettings(modelId: 'ghost-model'),
        onSave: (settings) {
          saved = settings;
        },
      );

      expect(
        find.byKey(const Key('chat_run_settings_model_dropdown')),
        findsOneWidget,
      );
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('ghost-model'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pumpAndSettle();
      expect(saved?.modelId, isNull);
    });

    testWidgets('刷新后目录仍包含已选项时保留原选择', (tester) async {
      ChatRunSettings? saved;
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        initialSettings: const ChatRunSettings(modelId: 'gpt-5-mini'),
        onRefresh: () async => _fullCapabilities,
        onFetchMetadata: () => const ChatRunSettingsMetadata(),
        onSave: (settings) {
          saved = settings;
        },
      );

      await tester.tap(
        find.byKey(const Key('chat_run_settings_refresh_button')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pumpAndSettle();
      expect(saved?.modelId, 'gpt-5-mini');
    });

    testWidgets('刷新把已选项删掉时回落到 Default，且不自动套用第一项', (tester) async {
      ChatRunSettings? saved;
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        initialSettings: const ChatRunSettings(modelId: 'gpt-5-mini'),
        onRefresh: () async => const AgentRuntimeCapabilities(
          models: [ChatSettingOption('gpt-5', 'GPT-5')],
          reasoningLevels: _reasoningLevels,
          modes: _modes,
          supportsStructuredSettings: true,
          currentModelId: 'gpt-5',
          currentReasoningId: 'high',
          currentModeId: 'plan',
        ),
        onFetchMetadata: () => const ChatRunSettingsMetadata(),
        onSave: (settings) {
          saved = settings;
        },
      );

      await tester.tap(
        find.byKey(const Key('chat_run_settings_refresh_button')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('chat_run_settings_model_dropdown')),
        findsOneWidget,
      );
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('GPT-5 mini'), findsNothing);

      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pumpAndSettle();
      expect(saved?.modelId, isNull);
    });

    testWidgets('刷新未返回时关闭弹窗，迟到结果不会重建已销毁的界面', (tester) async {
      final gate = Completer<AgentRuntimeCapabilities?>();
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        onRefresh: () => gate.future,
        onFetchMetadata: () => const ChatRunSettingsMetadata(),
      );

      await tester.tap(
        find.byKey(const Key('chat_run_settings_refresh_button')),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('chat_run_settings_refresh_button')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      Navigator.of(
        tester.element(find.byKey(const Key('chat_run_settings_dialog'))),
      ).pop();
      await pumpFrames(tester);
      expect(find.byKey(const Key('chat_run_settings_dialog')), findsNothing);

      gate.complete(_fullCapabilities);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('chat_run_settings_dialog')), findsNothing);
    });
  });

  group('模型目录告警与权限控件', () {
    testWidgets('目录告警出现时权限控件仍可选择并保存', (tester) async {
      ChatRunSettings? saved;
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        initialSettings: const ChatRunSettings(modelId: 'gpt-5'),
        modelCatalogError: '403 forbidden for model catalog',
        onSave: (settings) {
          saved = settings;
        },
      );

      expect(
        find.byKey(const Key('chat_run_settings_model_catalog_warning')),
        findsOneWidget,
      );
      expect(find.textContaining('403'), findsOneWidget);

      final safe = find.byKey(const Key('chat_permission_auto_allow_safe'));
      await tester.ensureVisible(safe);
      await tester.pumpAndSettle();
      await tester.tap(safe);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pumpAndSettle();

      expect(saved?.permissionPolicy, OperationPermissionPolicy.autoAllowSafe);
      expect(tester.takeException(), isNull);
    });

    testWidgets('自动允许全部被取消时保持原策略', (tester) async {
      ChatRunSettings? saved;
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        onSave: (settings) {
          saved = settings;
        },
      );

      final allowAll = find.byKey(const Key('chat_permission_auto_allow_all'));
      await tester.ensureVisible(allowAll);
      await tester.pumpAndSettle();
      await tester.tap(allowAll);
      await tester.pumpAndSettle();

      final confirm = find.byKey(
        const Key('chat_permission_auto_allow_all_confirm_button'),
      );
      expect(confirm, findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pumpAndSettle();
      expect(saved?.permissionPolicy, OperationPermissionPolicy.askEveryTime);
    });

    testWidgets('自动允许全部经显式确认后才生效', (tester) async {
      ChatRunSettings? saved;
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        onSave: (settings) {
          saved = settings;
        },
      );

      final allowAll = find.byKey(const Key('chat_permission_auto_allow_all'));
      await tester.ensureVisible(allowAll);
      await tester.pumpAndSettle();
      await tester.tap(allowAll);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('chat_permission_auto_allow_all_confirm_button')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pumpAndSettle();
      expect(saved?.permissionPolicy, OperationPermissionPolicy.autoAllowAll);
    });
  });

  group('独立模型授权 - 确认 / 取消 / 销毁 / 回调错误', () {
    testWidgets('确认框展示目标服务器、容器与用户，确认后才调用授权', (tester) async {
      var authorizeCalls = 0;
      final gate = Completer<void>();
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        serverName: 'Prod Host',
        containerName: 'valhalla-agent',
        agentUserName: 'coder',
        onAuthorize: () async {
          authorizeCalls++;
          await gate.future;
        },
        onRefresh: () async => _fullCapabilities,
        onFetchMetadata: () => const ChatRunSettingsMetadata(),
      );

      await openAuthorizeConfirm(tester);

      expect(
        find.widgetWithText(AlertDialog, 'Authorize Model Catalog'),
        findsOneWidget,
      );
      expect(find.text('Target Server: Prod Host'), findsOneWidget);
      expect(find.text('Target Container: valhalla-agent'), findsOneWidget);
      expect(find.text('Username: coder'), findsOneWidget);
      expect(authorizeCalls, 0);

      await acceptAuthorize(tester);

      expect(authorizeCalls, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.byKey(const Key('chat_run_settings_authorizing_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_run_settings_cancel_auth_button')),
        findsOneWidget,
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('chat_run_settings_authorizing_card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('chat_run_settings_authorize_button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('确认框未打开前不调用授权；拒绝则完全不调用', (tester) async {
      var authorizeCalls = 0;
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        serverName: 'Prod Host',
        onAuthorize: () async {
          authorizeCalls++;
        },
      );

      await tester.tap(
        find.byKey(const Key('chat_run_settings_authorize_button')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(authorizeCalls, 0);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Cancel'),
        ),
      );
      await tester.pumpAndSettle();

      expect(authorizeCalls, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.byKey(const Key('chat_run_settings_authorizing_card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('chat_run_settings_authorize_button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('授权等待中关闭弹窗会触发取消回调', (tester) async {
      var authorizeCalls = 0;
      var cancelCalls = 0;
      final gate = Completer<void>();
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        onAuthorize: () async {
          authorizeCalls++;
          await gate.future;
        },
        onCancelAuthorize: () {
          cancelCalls++;
        },
        onRefresh: () async => _fullCapabilities,
        onFetchMetadata: () => const ChatRunSettingsMetadata(),
      );

      await openAuthorizeConfirm(tester);
      await acceptAuthorize(tester);
      expect(authorizeCalls, 1);
      expect(cancelCalls, 0);
      expect(
        find.byKey(const Key('chat_run_settings_authorizing_card')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('chat_run_settings_cancel_button')),
      );
      await pumpFrames(tester);
      expect(find.byKey(const Key('chat_run_settings_dialog')), findsNothing);
      expect(cancelCalls, 1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('chat_run_settings_dialog')), findsNothing);
    });

    testWidgets('授权回调失败时展示稳定错误码，且不回显回调参数', (tester) async {
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        serverName: 'Prod Host',
        onAuthorize: () async {
          throw StateError('AGENT_MODEL_CALLBACK_INVALID');
        },
        onRefresh: () async => _fullCapabilities,
        onFetchMetadata: () => const ChatRunSettingsMetadata(),
      );

      await openAuthorizeConfirm(tester);
      await acceptAuthorize(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_run_settings_error_banner')),
        findsOneWidget,
      );
      expect(
        find.textContaining('AGENT_MODEL_CALLBACK_INVALID'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_run_settings_authorizing_card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('chat_run_settings_authorize_button')),
        findsOneWidget,
      );

      expect(find.textContaining('access_token'), findsNothing);
      expect(find.textContaining('code='), findsNothing);
      expect(find.textContaining('http://'), findsNothing);
      expect(find.textContaining('https://'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('保存守卫 - await-save / mounted', () {
    testWidgets('保存未返回时禁用保存与取消，弹窗保持打开', (tester) async {
      final gate = Completer<void>();
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        onSave: (_) => gate.future,
      );

      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pump();

      expect(find.byKey(const Key('chat_run_settings_dialog')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('chat_run_settings_save_button')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('chat_run_settings_cancel_button')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('chat_run_settings_save_button')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat_run_settings_dialog')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('保存期间弹窗被外部关闭时迟到结果不会再 pop', (tester) async {
      final gate = Completer<void>();
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        onSave: (_) => gate.future,
      );

      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pump();
      expect(find.byKey(const Key('chat_run_settings_dialog')), findsOneWidget);

      Navigator.of(
        tester.element(find.byKey(const Key('chat_run_settings_dialog'))),
      ).pop();
      await pumpFrames(tester);
      expect(find.byKey(const Key('chat_run_settings_dialog')), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('chat_run_settings_dialog')), findsNothing);
    });
  });

  group(r'草稿命令与 $skills 插入', () {
    testWidgets('草稿态打开命令面板展示命令与客户端动作，且无发送副作用', (tester) async {
      final notifier = _ComposerChatNotifier(
        AiChatState(
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
          commands: _panelCommands,
        ),
      );

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_commands_menu_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_commands_skills_dialog')),
        findsOneWidget,
      );
      expect(notifier.prepareComposerCatalogCalls, 1);
      expect(find.text('Commands (2)'), findsOneWidget);
      expect(find.text('status'), findsOneWidget);
      expect(find.text('compact'), findsOneWidget);
      expect(find.text('Run Settings'), findsOneWidget);

      expect(notifier.sendMessageCalls, 0);
      expect(notifier.prepareRunSettingsCalls, 0);
      expect(notifier.queryAccountStatusCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('命令为空时重试会用回调返回的真实命令刷新面板', (tester) async {
      var retryCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ChatCommandsSkillsDialog(
                  commands: const [],
                  onRetry: () async {
                    retryCalls++;
                    return _panelCommands;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_commands_retry_button')),
        findsOneWidget,
      );
      expect(find.text('status'), findsNothing);

      await tester.tap(find.byKey(const Key('chat_commands_retry_button')));
      await tester.pumpAndSettle();

      expect(retryCalls, 1);
      expect(find.text('Commands (2)'), findsOneWidget);
      expect(find.text('status'), findsOneWidget);
      expect(find.text('compact'), findsOneWidget);
      expect(find.byKey(const Key('chat_commands_retry_button')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('草稿态按光标位置插入命令且不发送', (tester) async {
      final notifier = _ComposerChatNotifier(
        AiChatState(
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
          commands: _panelCommands,
        ),
      );

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      final input = find.byKey(const Key('chatPromptInput'));
      await tester.enterText(input, 'please run this');
      await tester.pumpAndSettle();
      tester
          .widget<EditableText>(
            find.descendant(of: input, matching: find.byType(EditableText)),
          )
          .controller
          .selection = const TextSelection.collapsed(
        offset: 7,
      );

      await tester.tap(find.byKey(const Key('chat_commands_menu_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('status'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(input);
      expect(field.controller?.text, 'please /status run this');
      expect(field.controller?.selection.baseOffset, 15);
      expect(notifier.draftTexts.last, 'please /status run this');
      expect(notifier.sendMessageCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(r'草稿态插入 $skills 前缀且不发送', (tester) async {
      final notifier = _ComposerChatNotifier(
        AiChatState(
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
          commands: _panelCommands,
        ),
      );

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('chatPromptInput')),
        'fix the bug',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_commands_menu_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skills (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r'$review'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('chatPromptInput')),
      );
      expect(field.controller?.text, 'fix the bug\$review ');
      expect(notifier.draftTexts.last, 'fix the bug\$review ');
      expect(notifier.sendMessageCalls, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('命令面板生命周期 - 迟到重试与打开期间的命令更新', () {
    testWidgets('重试挂起时关闭面板，迟到结果不会读取已销毁的 WidgetRef', (tester) async {
      final notifier = _ComposerChatNotifier(
        AiChatState(
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
        ),
      );

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_commands_menu_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('chat_commands_skills_dialog')),
        findsOneWidget,
      );
      expect(notifier.prepareComposerCatalogCalls, 1);

      // 面板已经打开，再挂起重试：菜单打开时的那次查询必须照常完成。
      final gate = Completer<bool>();
      notifier.composerCatalogGate = gate;

      await tester.tap(find.byKey(const Key('chat_commands_retry_button')));
      await tester.pump();
      expect(notifier.prepareComposerCatalogCalls, 2);

      // 关闭面板：父级 AiChatView 仍然存活，只有 Consumer 所在的路由被销毁。
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('chat_commands_skills_dialog')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('chat_commands_skills_dialog')),
        findsNothing,
      );
      expect(find.byKey(const Key('chatPromptInput')), findsOneWidget);

      // 迟到结果到达：onRetry 必须靠 ctx.mounted 提前返回。
      // 少了这个守卫，下面的 ref.read 会抛
      // "Using ref when a widget is about to or has been unmounted is unsafe"。
      gate.complete(true);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('chat_commands_skills_dialog')),
        findsNothing,
      );
      expect(find.byKey(const Key('chatPromptInput')), findsOneWidget);
      expect(notifier.prepareComposerCatalogCalls, 2);
      expect(notifier.sendMessageCalls, 0);
      expect(notifier.draftTexts, isEmpty);
    });

    testWidgets('面板打开期间收到命令更新会立即刷新显示', (tester) async {
      final notifier = _ComposerChatNotifier(
        AiChatState(
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
        ),
      );

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_commands_menu_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('chat_commands_skills_dialog')),
        findsOneWidget,
      );
      expect(find.text('Commands (0)'), findsOneWidget);
      expect(find.text('status'), findsNothing);
      expect(
        find.byKey(const Key('chat_commands_retry_button')),
        findsOneWidget,
      );

      notifier.publishCommands(_panelCommands);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_commands_skills_dialog')),
        findsOneWidget,
      );
      expect(find.text('Commands (2)'), findsOneWidget);
      expect(find.text('Skills (1)'), findsOneWidget);
      expect(find.text('status'), findsOneWidget);
      expect(find.text('compact'), findsOneWidget);
      expect(find.byKey(const Key('chat_commands_retry_button')), findsNothing);

      // 切到技能页：同一份通知也刷新了另一半清单。
      await tester.tap(find.text('Skills (1)'));
      await tester.pumpAndSettle();
      expect(find.text(r'$review'), findsOneWidget);
      expect(find.text('compact'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(notifier.sendMessageCalls, 0);
      expect(notifier.draftTexts, isEmpty);
    });
  });

  group('目标切换守卫', () {
    testWidgets('打开设置途中切换 Agent 时不再弹出设置弹窗', (tester) async {
      final notifier = _ComposerChatNotifier(
        AiChatState(
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
        ),
      );
      notifier.prepareRunSettingsGate = Completer<bool>();

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_run_settings_button')));
      await tester.pump();
      expect(notifier.prepareRunSettingsCalls, 1);
      expect(find.byKey(const Key('chat_run_settings_dialog')), findsNothing);

      notifier.applyTargetAgent(otherAgent);
      await tester.pump();
      notifier.prepareRunSettingsGate!.complete(true);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat_run_settings_dialog')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('目标未变时打开设置弹窗', (tester) async {
      final notifier = _ComposerChatNotifier(
        AiChatState(
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
        ),
      );
      notifier.prepareRunSettingsGate = Completer<bool>();

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_run_settings_button')));
      await tester.pump();
      expect(notifier.prepareRunSettingsCalls, 1);

      notifier.prepareRunSettingsGate!.complete(true);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat_run_settings_dialog')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('手动模型 - 空目录录入 / 校验 / 刷新重开 / 切回列表', () {
    testWidgets('空目录下可手工录入，保存裁剪后的 id 与 customModel:true', (tester) async {
      ChatRunSettings? saved;
      await openSettings(
        tester,
        capabilities: const AgentRuntimeCapabilities(
          models: [],
          reasoningLevels: _reasoningLevels,
          modes: _modes,
          supportsStructuredSettings: true,
          currentReasoningId: 'high',
          currentModeId: 'plan',
        ),
        onSave: (settings) => saved = settings,
      );

      final dropdown = find.descendant(
        of: find.byKey(const Key('chat_run_settings_model_dropdown')),
        matching: find.byType(DropdownButton<String?>),
      );
      expect(tester.widget<DropdownButton<String?>>(dropdown).items, isNull);
      expect(
        tester.widget<DropdownButton<String?>>(dropdown).onChanged,
        isNull,
      );
      expect(
        find.text(enL10n().chatSettingsIndependentModelUnavailable),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_run_settings_custom_model_input')),
        findsNothing,
        reason: '默认仍是目录模式',
      );

      await tester.tap(
        find.byKey(const Key('chat_run_settings_model_source_custom')),
      );
      await tester.pumpAndSettle();

      final input = find.byKey(
        const Key('chat_run_settings_custom_model_input'),
      );
      expect(input, findsOneWidget);
      expect(
        find.text(enL10n().chatRunSettingsCustomModelHint),
        findsOneWidget,
      );
      expect(
        find.text(enL10n().chatRunSettingsCustomModelNotice),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_run_settings_model_dropdown')),
        findsNothing,
      );

      await tester.enterText(input, '   my-manual-model   ');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pumpAndSettle();

      expect(saved, isNotNull, reason: '空目录下手工输入必须能保存');
      expect(saved!.modelId, 'my-manual-model', reason: '必须保存裁剪后的 id');
      expect(saved!.customModel, isTrue);
      expect(saved!.reasoningId, 'high', reason: '手动态只放宽模型，推理等级照常保存');
      expect(saved!.modeId, 'plan', reason: '模式也照常保存');
      expect(
        saved!.permissionPolicy,
        OperationPermissionPolicy.askEveryTime,
        reason: '权限策略照常保存',
      );
      expect(find.byKey(const Key('chat_run_settings_dialog')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('非法手工输入被拦截，不保存并给出本地化错误', (tester) async {
      ChatRunSettings? saved;
      await openSettings(
        tester,
        capabilities: const AgentRuntimeCapabilities(models: []),
        onSave: (settings) => saved = settings,
      );
      await tester.tap(
        find.byKey(const Key('chat_run_settings_model_source_custom')),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(
        const Key('chat_run_settings_custom_model_input'),
      );

      for (final entry in <(String, String)>[
        ('   ', enL10n().chatRunSettingsCustomModelEmptyError),
        ('bad id with space', enL10n().chatRunSettingsCustomModelInvalidError),
        ('x' * 257, enL10n().chatRunSettingsCustomModelInvalidError),
        ('tab\there', enL10n().chatRunSettingsCustomModelInvalidError),
      ]) {
        await tester.enterText(input, entry.$1);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('chat_run_settings_save_button')),
        );
        await tester.pumpAndSettle();

        expect(saved, isNull, reason: '非法输入绝不能被保存：${entry.$1}');
        expect(find.text(entry.$2), findsOneWidget, reason: '必须显示本地化的错误文案');
        expect(
          find.byKey(const Key('chat_run_settings_dialog')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('手工输入跨刷新与重开都保留，且不伪造目录条目', (tester) async {
      ChatRunSettings? saved;
      await openSettings(
        tester,
        capabilities: const AgentRuntimeCapabilities(models: []),
        initialSettings: const ChatRunSettings(
          modelId: 'manual-not-in-catalog',
          customModel: true,
        ),
        onRefresh: () async => const AgentRuntimeCapabilities(models: []),
        onFetchMetadata: () => const ChatRunSettingsMetadata(),
        onSave: (settings) => saved = settings,
      );

      final segmented = find.byKey(
        const Key('chat_run_settings_model_source_segmented'),
      );
      final input = find.byKey(
        const Key('chat_run_settings_custom_model_input'),
      );

      // 重开必须恢复手动态与文本，即使该 id 不在目录里。
      expect(tester.widget<SegmentedButton<bool>>(segmented).selected, {true});
      expect(
        tester.widget<TextField>(input).controller!.text,
        'manual-not-in-catalog',
      );
      expect(
        find.byKey(const Key('chat_run_settings_model_dropdown')),
        findsNothing,
      );
      expect(find.textContaining('manual-not-in-catalog'), findsOneWidget);

      // 手动刷新不得清掉正在输入的手动模型名，也不得切换来源。
      await tester.enterText(input, '  manual-edited  ');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('chat_run_settings_refresh_button')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<TextField>(input).controller!.text,
        '  manual-edited  ',
      );
      expect(tester.widget<SegmentedButton<bool>>(segmented).selected, {true});

      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pumpAndSettle();
      expect(saved?.modelId, 'manual-edited');
      expect(saved?.customModel, isTrue);

      // 用刚保存的结果重开。
      await openSettings(
        tester,
        capabilities: const AgentRuntimeCapabilities(models: []),
        initialSettings: saved!,
        onRefresh: () async => const AgentRuntimeCapabilities(models: []),
        onFetchMetadata: () => const ChatRunSettingsMetadata(),
        onSave: (settings) => saved = settings,
      );
      expect(tester.widget<SegmentedButton<bool>>(segmented).selected, {true});
      expect(tester.widget<TextField>(input).controller!.text, 'manual-edited');
      expect(
        find.byKey(const Key('chat_run_settings_model_dropdown')),
        findsNothing,
      );
      expect(find.textContaining('manual-not-in-catalog'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('切回列表后保存为普通目录选择，customModel 被清掉', (tester) async {
      ChatRunSettings? saved;
      await openSettings(
        tester,
        capabilities: _fullCapabilities,
        initialSettings: const ChatRunSettings(modelId: 'gpt-5'),
        onSave: (settings) => saved = settings,
      );

      final segmented = find.byKey(
        const Key('chat_run_settings_model_source_segmented'),
      );
      final input = find.byKey(
        const Key('chat_run_settings_custom_model_input'),
      );

      await tester.tap(
        find.byKey(const Key('chat_run_settings_model_source_custom')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<bool>>(segmented).selected, {true});
      await tester.enterText(input, 'my-manual-model');
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('chat_run_settings_model_source_catalog')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<bool>>(segmented).selected, {false});
      expect(
        find.byKey(const Key('chat_run_settings_model_dropdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_run_settings_custom_model_input')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.customModel, isFalse, reason: '切回列表必须清掉手动态');
      expect(saved!.modelId, 'gpt-5', reason: '回到列表时恢复原来的目录选择');
      expect(tester.takeException(), isNull);

      // 空目录下切回列表保存为默认（modelId null）。
      saved = null;
      await openSettings(
        tester,
        capabilities: const AgentRuntimeCapabilities(models: []),
        initialSettings: const ChatRunSettings(
          modelId: 'manual-only',
          customModel: true,
        ),
        onSave: (settings) => saved = settings,
      );
      expect(tester.widget<SegmentedButton<bool>>(segmented).selected, {true});
      await tester.tap(
        find.byKey(const Key('chat_run_settings_model_source_catalog')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.modelId, isNull, reason: '空目录下回到列表就是默认');
      expect(saved!.customModel, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('真实 AiChatView 设置弹窗 - 无授权控件', () {
    testWidgets('没有授权/登录控件，刷新与模型控件仍在', (tester) async {
      final notifier = _ComposerChatNotifier(
        AiChatState(
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
          capabilities: _fullCapabilities,
        ),
      );
      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_run_settings_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat_run_settings_dialog')), findsOneWidget);

      expect(
        find.byKey(const Key('chat_run_settings_authorize_button')),
        findsNothing,
        reason: '真实视图不再接线授权回调，绝不渲染授权按钮',
      );
      expect(
        find.byKey(const Key('chat_run_settings_authorizing_card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('chat_run_settings_cancel_auth_button')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('chat_model_authorize_confirm_button')),
        findsNothing,
      );
      expect(find.text('Authorize Model Catalog'), findsNothing);

      expect(
        find.byKey(const Key('chat_run_settings_refresh_button')),
        findsOneWidget,
        reason: '手动刷新必须保留',
      );
      expect(
        find.byKey(const Key('chat_run_settings_model_dropdown')),
        findsOneWidget,
        reason: '目录控件必须保留',
      );
      expect(
        find.byKey(const Key('chat_run_settings_model_source_segmented')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_run_settings_custom_model_input')),
        findsNothing,
        reason: '目录模式下不渲染手工输入框',
      );
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const Key('chat_run_settings_refresh_button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('chat_run_settings_refresh_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_run_settings_authorize_button')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('窄屏', () {
    testWidgets('窄屏下手工模型入口与保存按钮都可用且无溢出异常', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await openSettings(
        tester,
        capabilities: const AgentRuntimeCapabilities(models: []),
        onSave: (_) {},
      );
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const Key('chat_run_settings_model_source_custom')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final input = find.byKey(
        const Key('chat_run_settings_custom_model_input'),
      );
      await tester.ensureVisible(input);
      await tester.pumpAndSettle();
      expect(input, findsOneWidget);
      expect(tester.takeException(), isNull);

      final save = find.byKey(const Key('chat_run_settings_save_button'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
