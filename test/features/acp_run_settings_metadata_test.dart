import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/data/models/chat_run_settings.dart';
import 'package:valhalla/features/chat/widgets/chat_run_settings_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart';

/// 运行设置弹窗的元信息（Agent 版本 / 获取时间 / 过期标记）回归。
/// 直接驱动对话框，onRefresh/onFetchMetadata 由测试控制，不触碰任何网络。

void main() {
  const longVersion =
      '0.42.0-preview.2026.09.30-nightly+build.abcdef0123456789';

  const baseCapabilities = AgentRuntimeCapabilities(
    models: [
      ChatSettingOption('gpt-5', 'GPT-5'),
      ChatSettingOption('gpt-5-mini', 'GPT-5 mini'),
    ],
    reasoningLevels: [
      ChatSettingOption('high', 'High'),
      ChatSettingOption('low', 'Low'),
    ],
    supportsStructuredSettings: true,
    modes: [ChatSettingOption('plan', 'Plan')],
    currentModelId: 'gpt-5',
    currentReasoningId: 'high',
    currentModeId: 'plan',
  );

  Future<void> openDialog(
    WidgetTester tester, {
    required Future<AgentRuntimeCapabilities?> Function() onRefresh,
    required ChatRunSettingsMetadata Function() onFetchMetadata,
    DateTime? settingsFetchedAt,
    String? agentVersion,
    bool settingsStale = false,
    Size? surfaceSize,
    TextScaler textScaler = TextScaler.noScaling,
    Locale locale = const Locale('en'),
  }) async {
    await loadRealTextFonts();

    // 真正的窄屏必须改视图尺寸：只覆盖 MediaQuery.size 不会收紧布局约束。
    if (surfaceSize != null) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = surfaceSize;
      addTearDown(tester.view.reset);
    }

    await tester.pumpWidget(
      MaterialApp(
        // 必须使用生产主题：默认 MaterialApp 会退回 flutter_test 的等宽方块
        // 测试字体，文字度量与真机差异过大，布局回归结论不可用。
        theme: AppTheme.buildTheme(
          brightness: Brightness.dark,
          seedColor: AppAccentColor.cyberEmerald.color,
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: inner!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => ChatRunSettingsDialog.show(
                  context,
                  initialSettings: const ChatRunSettings(modelId: 'gpt-5'),
                  capabilities: baseCapabilities,
                  isStructuredSend: true,
                  settingsFetchedAt: settingsFetchedAt,
                  agentVersion: agentVersion,
                  settingsStale: settingsStale,
                  onRefresh: onRefresh,
                  onFetchMetadata: onFetchMetadata,
                  onSave: (_) {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat_run_settings_dialog')), findsOneWidget);
  }

  group('设置元信息', () {
    testWidgets('无元信息时不显示元信息行', (tester) async {
      await openDialog(
        tester,
        onRefresh: () async => baseCapabilities,
        onFetchMetadata: () => const ChatRunSettingsMetadata(),
      );

      expect(
        find.byKey(const Key('chat_run_settings_metadata_row')),
        findsNothing,
      );
    });

    testWidgets('刷新成功后更新获取时间、版本与过期标记', (tester) async {
      final fetchedAt = DateTime(2026, 9, 30, 21, 45, 12);
      var metadata = const ChatRunSettingsMetadata(
        settingsFetchedAt: null,
        agentVersion: null,
        settingsStale: true,
      );

      await openDialog(
        tester,
        onRefresh: () async => baseCapabilities,
        onFetchMetadata: () => metadata,
        settingsFetchedAt: DateTime(2026, 9, 30, 8),
        agentVersion: '0.1.0',
        settingsStale: true,
      );

      // 初始：旧版本 + 过期标记
      expect(
        find.byKey(const Key('chat_run_settings_metadata_row')),
        findsOneWidget,
      );
      expect(find.text('v0.1.0'), findsOneWidget);
      expect(find.text('Stale'), findsOneWidget);
      expect(find.text('08:00:00'), findsOneWidget);

      metadata = ChatRunSettingsMetadata(
        settingsFetchedAt: fetchedAt,
        agentVersion: '0.2.0',
        settingsStale: false,
      );

      await tester.tap(
        find.byKey(const Key('chat_run_settings_refresh_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('v0.2.0'), findsOneWidget);
      expect(find.text('21:45:12'), findsOneWidget);
      expect(find.text('Stale'), findsNothing);
    });

    testWidgets('刷新失败时显示错误且保留原有元信息', (tester) async {
      var shouldFail = true;

      await openDialog(
        tester,
        onRefresh: () async {
          if (shouldFail) throw StateError('ACP_SETTINGS_REFRESH_FAILED');
          return baseCapabilities;
        },
        onFetchMetadata: () => const ChatRunSettingsMetadata(
          settingsFetchedAt: null,
          agentVersion: '0.1.0',
          settingsStale: true,
        ),
        agentVersion: '0.1.0',
        settingsStale: true,
      );

      await tester.tap(
        find.byKey(const Key('chat_run_settings_refresh_button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_run_settings_error_banner')),
        findsOneWidget,
      );
      expect(
        find.textContaining('ACP_SETTINGS_REFRESH_FAILED'),
        findsOneWidget,
      );
      // 失败不得清空已显示的元信息
      expect(find.text('v0.1.0'), findsOneWidget);
      expect(find.text('Stale'), findsOneWidget);

      // 再次刷新成功时错误消失
      shouldFail = false;
      await tester.tap(
        find.byKey(const Key('chat_run_settings_refresh_button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_run_settings_error_banner')),
        findsNothing,
      );
    });

    testWidgets('刷新返回 null 时不覆盖既有能力', (tester) async {
      var calls = 0;
      await openDialog(
        tester,
        onRefresh: () async {
          calls++;
          return null;
        },
        onFetchMetadata: () =>
            const ChatRunSettingsMetadata(agentVersion: '0.1.0'),
        agentVersion: '0.1.0',
      );

      await tester.tap(
        find.byKey(const Key('chat_run_settings_refresh_button')),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(
        find.byKey(const Key('chat_run_settings_error_banner')),
        findsNothing,
      );
      // 模型下拉仍来自打开时的能力
      expect(
        find.byKey(const Key('chat_run_settings_model_dropdown')),
        findsOneWidget,
      );
    });
  });

  group('窄屏与大字体', () {
    testWidgets('长版本号在窄屏大字体下仍完整可读且元信息行不溢出', (tester) async {
      await openDialog(
        tester,
        onRefresh: () async => baseCapabilities,
        onFetchMetadata: () => const ChatRunSettingsMetadata(),
        agentVersion: longVersion,
        settingsFetchedAt: DateTime(2026, 9, 30, 7, 5, 9),
        settingsStale: true,
        surfaceSize: const Size(320, 640),
        textScaler: const TextScaler.linear(1.8),
      );

      expect(
        find.byKey(const Key('chat_run_settings_metadata_row')),
        findsOneWidget,
      );
      // 超长版本号被省略显示而不是撑破布局
      expect(find.text('v$longVersion'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const Key('chat_run_settings_metadata_row')))
            .width,
        lessThanOrEqualTo(320.0),
      );
      expect(find.text('Stale'), findsOneWidget);
    });

    // 真实 Inter 字体 + 生产主题下的实测矩阵（暗色/亮色一致）：
    //   320dp / 360dp / 411dp × scale 1.0、1.3、1.8、2.0 —— 全部无布局溢出。
    // 本矩阵曾是缺陷证据，不是误报：scale 2.0 下 mode 下拉折叠项
    // （DropdownMenuItem 内 Column）在生产主题 + 生产字体下溢出 0.4px，
    // 窄屏下设置底部 Cancel/Save Row 也横向溢出；两者均由
    // lib/features/chat/widgets/chat_run_settings_dialog.dart 的
    // selectedItemBuilder 单行折叠态与底部 OverflowBar 修复。
    // scale 2.0 必须留在矩阵内，否则这两处修复没有回归保护。
    for (final width in [320.0, 360.0, 411.0]) {
      for (final scale in [1.0, 1.3, 1.8, 2.0]) {
        testWidgets('${width.toInt()}dp 字体 $scale 无布局溢出', (tester) async {
          await openDialog(
            tester,
            onRefresh: () async => baseCapabilities,
            onFetchMetadata: () => const ChatRunSettingsMetadata(),
            agentVersion: longVersion,
            settingsFetchedAt: DateTime(2026, 9, 30, 7, 5, 9),
            settingsStale: true,
            surfaceSize: Size(width, 640),
            textScaler: TextScaler.linear(scale),
          );

          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('窄屏大字体下英文与中文都不横向溢出', (tester) async {
      for (final locale in const [Locale('en'), Locale('zh')]) {
        await openDialog(
          tester,
          onRefresh: () async => baseCapabilities,
          onFetchMetadata: () => const ChatRunSettingsMetadata(),
          agentVersion: longVersion,
          settingsFetchedAt: DateTime(2026, 9, 30, 7, 5, 9),
          settingsStale: true,
          surfaceSize: const Size(320, 640),
          textScaler: const TextScaler.linear(1.8),
          locale: locale,
        );
        expect(tester.takeException(), isNull, reason: 'locale=$locale');
        await tester.tap(
          find.byKey(const Key('chat_run_settings_cancel_button')),
        );
        await tester.pumpAndSettle();
      }
    });
  });
}
