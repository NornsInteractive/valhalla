// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/auto_connect_provider.dart';
import '../../core/providers/reconnect_provider.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/diagnostics_provider.dart';
import '../../core/providers/terminal_settings_provider.dart';
import '../../data/models/server_profile.dart';
import '../agents/agent_management_view.dart';
import 'widgets/diagnostics_view.dart';
import 'widgets/theme_accent_color_dialog.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Entrance(
          index: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(
                context,
                context.l10n.settingsAppearance,
                Icons.palette,
              ),
              _buildThemeModeCard(context, settings, notifier),
              const SizedBox(height: 12),
              _buildAccentColorCard(context, settings, notifier),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Entrance(
          index: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(
                context,
                context.l10n.settingsLanguage,
                Icons.translate,
              ),
              _buildLanguageCard(context, settings, notifier),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Entrance(
          index: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(
                context,
                context.l10n.settingsAiOps,
                Icons.psychology,
              ),
              _buildAiOpsCard(context, settings, notifier),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Entrance(
          index: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(
                context,
                context.l10n.settingsSecurity,
                Icons.security,
              ),
              _buildSecurityCard(context, ref),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Entrance(
          index: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(
                context,
                context.l10n.settingsAutoConnect,
                Icons.power_settings_new,
              ),
              const _AutoConnectCard(),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Entrance(
          index: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(
                context,
                context.l10n.settingsNavigation,
                Icons.navigation_outlined,
              ),
              _buildNavigationCard(context, settings, notifier),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Entrance(
          index: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(
                context,
                context.l10n.settingsDiagnostics,
                Icons.bug_report_outlined,
              ),
              _buildDiagnosticsCard(context, ref),
            ],
          ),
        ),
        const SizedBox(height: 32),

        Entrance(
          index: 7,
          child: Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text(context.l10n.settingsResetDefault),
              onPressed: () {
                notifier.resetDefaults();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.settingsResetSuccess)),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Valhalla v1.0.0-stable · Antigravity AI',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticsCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final diagnostics = ref.watch(diagnosticsServiceProvider);

    return Card(
      key: const Key('settings_diagnostics_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.settingsDiagnostics,
                        style: context.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.settingsDiagnosticsDesc,
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('settings_view_diagnostics_button'),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(context.l10n.viewDiagnostics),
                  onPressed: () =>
                      DiagnosticsView.show(context, diagnostics: diagnostics),
                ),
                FilledButton.tonalIcon(
                  key: const Key('settings_export_diagnostics_button'),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: Text(context.l10n.exportDiagnostics),
                  onPressed: () async {
                    try {
                      final path = await diagnostics.export();
                      if (context.mounted && path != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.diagnosticsExportSuccess(path),
                            ),
                            backgroundColor: context.vSuccess,
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.diagnosticsExportFailed),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: context.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeCard(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    final mode = settings.themeMode;
    final (title, icon) = switch (mode) {
      AppThemeMode.system => (context.l10n.themeSystem, Icons.brightness_auto),
      AppThemeMode.light => (context.l10n.themeLight, Icons.light_mode),
      AppThemeMode.dark => (context.l10n.themeDark, Icons.dark_mode),
      AppThemeMode.amoled => (context.l10n.themeAmoled, Icons.contrast),
    };

    return Card(
      child: ListTile(
        key: const Key('settings_theme_mode_tile'),
        leading: Icon(icon, color: context.colorScheme.primary),
        title: Text(
          context.l10n.settingsThemeMode,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(title, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showThemeModeDialog(context, mode, notifier),
      ),
    );
  }

  void _showThemeModeDialog(
    BuildContext context,
    AppThemeMode currentMode,
    SettingsNotifier notifier,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(context.l10n.selectThemeModeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<AppThemeMode>(
                key: const Key('settings_theme_mode_system'),
                dense: true,
                secondary: const Icon(Icons.brightness_auto),
                title: Text(
                  context.l10n.themeSystem,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  context.l10n.themeSystemDesc,
                  style: const TextStyle(fontSize: 11),
                ),
                value: AppThemeMode.system,
                groupValue: currentMode,
                onChanged: (val) {
                  if (val != null) {
                    notifier.setThemeMode(val);
                    Navigator.of(dialogCtx).pop();
                  }
                },
              ),
              RadioListTile<AppThemeMode>(
                key: const Key('settings_theme_mode_light'),
                dense: true,
                secondary: const Icon(Icons.light_mode),
                title: Text(
                  context.l10n.themeLight,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  context.l10n.themeLightDesc,
                  style: const TextStyle(fontSize: 11),
                ),
                value: AppThemeMode.light,
                groupValue: currentMode,
                onChanged: (val) {
                  if (val != null) {
                    notifier.setThemeMode(val);
                    Navigator.of(dialogCtx).pop();
                  }
                },
              ),
              RadioListTile<AppThemeMode>(
                key: const Key('settings_theme_mode_dark'),
                dense: true,
                secondary: const Icon(Icons.dark_mode),
                title: Text(
                  context.l10n.themeDark,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  context.l10n.themeDarkDesc,
                  style: const TextStyle(fontSize: 11),
                ),
                value: AppThemeMode.dark,
                groupValue: currentMode,
                onChanged: (val) {
                  if (val != null) {
                    notifier.setThemeMode(val);
                    Navigator.of(dialogCtx).pop();
                  }
                },
              ),
              RadioListTile<AppThemeMode>(
                key: const Key('settings_theme_mode_amoled'),
                dense: true,
                secondary: const Icon(Icons.contrast),
                title: Text(
                  context.l10n.themeAmoled,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  context.l10n.themeAmoledDesc,
                  style: const TextStyle(fontSize: 11),
                ),
                value: AppThemeMode.amoled,
                groupValue: currentMode,
                onChanged: (val) {
                  if (val != null) {
                    notifier.setThemeMode(val);
                    Navigator.of(dialogCtx).pop();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(context.l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccentColorCard(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

    return Card(
      child: ListTile(
        key: const Key('settings_accent_color_tile'),
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: settings.colorForTheme(
              settings.themeMode == AppThemeMode.system
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? AppThemeMode.dark
                        : AppThemeMode.light)
                  : settings.themeMode,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: context.colorScheme.outline, width: 1.5),
          ),
        ),
        title: Text(
          context.l10n.settingsAccentColor,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildMiniColorBadge(
                label: 'L',
                color: settings.lightAccentColor,
                hexText: hex(settings.lightAccentColor),
              ),
              _buildMiniColorBadge(
                label: 'D',
                color: settings.darkAccentColor,
                hexText: hex(settings.darkAccentColor),
              ),
              _buildMiniColorBadge(
                label: 'A',
                color: settings.amoledAccentColor,
                hexText: hex(settings.amoledAccentColor),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final systemSlot = Theme.of(context).brightness == Brightness.dark
              ? AppThemeMode.dark
              : AppThemeMode.light;
          final initialMode = settings.themeMode == AppThemeMode.system
              ? systemSlot
              : settings.themeMode;
          showDialog<void>(
            context: context,
            builder: (_) => ThemeAccentColorDialog(
              settings: settings,
              notifier: notifier,
              initialMode: initialMode,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniColorBadge({
    required String label,
    required Color color,
    required String hexText,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          '$label: $hexText',
          style: monoTextStyle(fontSize: 10, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }

  Widget _buildLanguageCard(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    final langCode = settings.locale.languageCode;
    final langText = switch (langCode) {
      'zh' => context.l10n.langZh,
      'en' => context.l10n.langEn,
      _ => context.l10n.langSystem,
    };

    return Card(
      child: ListTile(
        key: const Key('settings_language_tile'),
        leading: Icon(Icons.translate, color: context.colorScheme.primary),
        title: Text(
          context.l10n.settingsLanguage,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(langText, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showLanguageDialog(context, langCode, notifier),
      ),
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    String currentCode,
    SettingsNotifier notifier,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(context.l10n.selectLanguageTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                key: const Key('settings_lang_system'),
                dense: true,
                title: Text(
                  context.l10n.langSystem,
                  style: const TextStyle(fontSize: 13),
                ),
                value: 'system',
                groupValue: currentCode,
                onChanged: (val) {
                  if (val != null) {
                    notifier.setLocale(Locale(val));
                    Navigator.of(dialogCtx).pop();
                  }
                },
              ),
              RadioListTile<String>(
                key: const Key('settings_lang_zh'),
                dense: true,
                title: Text(
                  context.l10n.langZh,
                  style: const TextStyle(fontSize: 13),
                ),
                value: 'zh',
                groupValue: currentCode,
                onChanged: (val) {
                  if (val != null) {
                    notifier.setLocale(Locale(val));
                    Navigator.of(dialogCtx).pop();
                  }
                },
              ),
              RadioListTile<String>(
                key: const Key('settings_lang_en'),
                dense: true,
                title: Text(
                  context.l10n.langEn,
                  style: const TextStyle(fontSize: 13),
                ),
                value: 'en',
                groupValue: currentCode,
                onChanged: (val) {
                  if (val != null) {
                    notifier.setLocale(Locale(val));
                    Navigator.of(dialogCtx).pop();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(context.l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAiOpsCard(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.smart_toy_outlined),
            title: Text(
              context.l10n.settingsAgentManagement,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.l10n.settingsAgentManagementSubtitle,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AgentManagementView()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('settings_cli_history_page_size_tile'),
            dense: true,
            leading: const Icon(Icons.history_toggle_off),
            title: Text(
              context.l10n.settingsCliHistoryPageSize,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.l10n.settingsCliHistoryPageSizeDesc,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${settings.cliHistoryPageSize}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _showCliHistoryPageSizeDialog(
              context,
              settings.cliHistoryPageSize,
              notifier,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.psychology),
            title: const Text('默认 AI 运维引擎', style: TextStyle(fontSize: 13)),
            subtitle: const Text(
              'Claude CodeX (Anthropic ACP)',
              style: TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.cable),
            title: const Text('ACP 协议管道标准', style: TextStyle(fontSize: 13)),
            subtitle: const Text(
              'Agent Client Protocol v1.0 (stdio over SSH)',
              style: TextStyle(fontSize: 11),
            ),
            trailing: Icon(Icons.check, color: context.vSuccess),
          ),
        ],
      ),
    );
  }

  void _showCliHistoryPageSizeDialog(
    BuildContext context,
    int currentValue,
    SettingsNotifier notifier,
  ) {
    final pageSizes = List.generate(20, (i) => (i + 1) * 5); // 5, 10, ..., 100

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(context.l10n.settingsCliHistoryPageSizeTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: pageSizes.map((size) {
                return RadioListTile<int>(
                  key: Key('settings_cli_history_page_size_radio_$size'),
                  dense: true,
                  title: Text('$size', style: const TextStyle(fontSize: 13)),
                  value: size,
                  groupValue: currentValue,
                  onChanged: (val) {
                    if (val != null) {
                      notifier.setCliHistoryPageSize(val);
                      Navigator.of(dialogCtx).pop();
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(context.l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecurityCard(BuildContext context, WidgetRef ref) {
    final keepAlive = ref.watch(keepAliveCoordinatorProvider);
    final count = keepAlive.activeCount;
    final hasActive = keepAlive.hasActiveSessions;
    final terminalSettings = ref.watch(terminalSettingsProvider);

    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(
              context.l10n.sshKeepAliveNotificationTitle,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.l10n.sshKeepAliveNotificationBody(hasActive ? count : 0),
              style: const TextStyle(fontSize: 11),
            ),
            trailing: hasActive
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.vSuccess.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(VRadius.input),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: context.vSuccess,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          const Divider(height: 1),
          SwitchListTile(
            key: const Key('settingsTerminalUseTmuxSwitch'),
            secondary: const Icon(Icons.terminal),
            dense: true,
            title: Text(
              context.l10n.settingsTerminalUseTmux,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.settingsTerminalUseTmuxSubtitle,
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.settingsTerminalUseTmuxDescription,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            value: terminalSettings.useTmux,
            onChanged: (val) =>
                ref.read(terminalSettingsProvider.notifier).setUseTmux(val),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('settingsTerminalFontSizeRow'),
            dense: true,
            leading: const Icon(Icons.format_size),
            title: Text(
              context.l10n.settingsTerminalFontSize,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.l10n.settingsTerminalFontSizeSubtitle,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Text(
              '${terminalSettings.fontSize}',
              key: const Key('settingsTerminalFontSizeValue'),
              style: monoTextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colorScheme.primary,
              ),
            ),
            onTap: () => _showTerminalFontSizeDialog(context),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.fingerprint),
            title: Text(
              context.l10n.settingsKnownHosts,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              '2 个受信任的远程服务器指纹',
              style: TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.lock_reset),
            title: Text(
              context.l10n.settingsClearStorage,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              '清除平台安全存储中的私钥与会话密码',
              style: TextStyle(fontSize: 11),
            ),
            trailing: Icon(Icons.delete_outline, color: context.vDanger),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  /// 终端字体大小调节弹窗。
  ///
  /// 滑块 onChanged 直接写入 `terminalSettingsProvider`：弹窗内的预览与
  /// 页面背后已打开的终端都实时跟随（画布 watch 该 provider）；onChangeEnd
  /// 再落一次盘确保最终值被持久化（setFontSize 本身即写存储）。
  void _showTerminalFontSizeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(context.l10n.settingsTerminalFontSize),
          content: Consumer(
            builder: (ctx, dialogRef, _) {
              final fontSize = dialogRef
                  .watch(terminalSettingsProvider)
                  .fontSize;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 终端风格预览面板：黑底等宽，随字号实时缩放。
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.symmetric(
                      horizontal: VSpace.md,
                      vertical: VSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(VRadius.input),
                      border: Border.all(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      'Aa  \$ ls -la ~/valhalla',
                      style: monoTextStyle(
                        fontSize: fontSize.toDouble(),
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Slider(
                    key: const Key('settingsTerminalFontSizeSlider'),
                    value: fontSize.toDouble(),
                    min: 9,
                    max: 24,
                    divisions: 15,
                    label: '$fontSize',
                    onChanged: (value) => dialogRef
                        .read(terminalSettingsProvider.notifier)
                        .setFontSize(value.round()),
                    onChangeEnd: (value) => dialogRef
                        .read(terminalSettingsProvider.notifier)
                        .setFontSize(value.round()),
                  ),
                  Center(
                    child: Text(
                      '$fontSize',
                      style: monoTextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(context.l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavigationCard(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Startup Page (Single-select tile + Dialog)
            ListTile(
              key: const Key('settings_startup_page_tile'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _getAppSectionIcon(settings.startupSection),
                color: context.colorScheme.primary,
              ),
              title: Text(
                context.l10n.settingsStartupPage,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                _getLocalizedSectionName(context, settings.startupSection),
                style: const TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showStartupPageDialog(
                context,
                settings.startupSection,
                notifier,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),

            // 2. Dashboard Quick Actions (Demand 4)
            Text(
              context.l10n.settingsDashboardQuickActions,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.settingsDashboardQuickActionsDesc,
              style: TextStyle(
                fontSize: 11,
                color: context.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),

            if (settings.dashboardQuickSections.isNotEmpty) ...[
              Text(
                context.l10n.settingsDashboardQuickActionsOrderTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              ReorderableListView.builder(
                key: const Key('settings_dashboard_quick_reorder_list'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: settings.dashboardQuickSections.length,
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final items = List<AppSection>.from(
                    settings.dashboardQuickSections,
                  );
                  final item = items.removeAt(oldIndex);
                  items.insert(newIndex, item);
                  notifier.setDashboardQuickSections(items);
                },
                itemBuilder: (context, index) {
                  final sec = settings.dashboardQuickSections[index];
                  return ListTile(
                    key: ValueKey('settings_quick_reorder_${sec.name}'),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(_getAppSectionIcon(sec), size: 18),
                    title: Text(_getLocalizedSectionName(context, sec)),
                    trailing: const Icon(Icons.drag_handle, size: 20),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Divider(),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  context.l10n.settingsDashboardQuickActionsEmpty,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: context.colorScheme.outline,
                  ),
                ),
              ),
              const Divider(),
            ],

            Text(
              context.l10n.settingsDashboardQuickActionsCandidates,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 4),
            ...AppSection.values
                .where((sec) => sec != AppSection.dashboard)
                .map((sec) {
                  final isChecked = settings.dashboardQuickSections.contains(
                    sec,
                  );
                  return CheckboxListTile(
                    key: Key('settings_dashboard_quick_checkbox_${sec.name}'),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Row(
                      children: [
                        Icon(
                          _getAppSectionIcon(sec),
                          size: 18,
                          color: isChecked ? context.colorScheme.primary : null,
                        ),
                        const SizedBox(width: 8),
                        Text(_getLocalizedSectionName(context, sec)),
                      ],
                    ),
                    value: isChecked,
                    onChanged: (bool? checked) {
                      final current = List<AppSection>.from(
                        settings.dashboardQuickSections,
                      );
                      if (checked == true) {
                        if (!current.contains(sec)) {
                          current.add(sec);
                        }
                      } else {
                        current.remove(sec);
                      }
                      notifier.setDashboardQuickSections(current);
                    },
                  );
                }),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // 3. Bottom Navigation (Multi-select and reorder)
            Text(
              context.l10n.settingsBottomNav,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.settingsBottomNavDesc,
              style: TextStyle(
                fontSize: 12,
                color: context.colorScheme.outline,
              ),
            ),
            if (settings.bottomNavigationSections.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                context.l10n.settingsBottomNavOrderTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              ReorderableListView.builder(
                key: const Key('settings_bottom_nav_reorder_list'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: settings.bottomNavigationSections.length,
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final items = List<AppSection>.from(
                    settings.bottomNavigationSections,
                  );
                  final item = items.removeAt(oldIndex);
                  items.insert(newIndex, item);
                  notifier.setBottomNavigationSections(items);
                },
                itemBuilder: (context, index) {
                  final sec = settings.bottomNavigationSections[index];
                  return ListTile(
                    key: ValueKey('settings_reorder_${sec.name}'),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(_getAppSectionIcon(sec), size: 18),
                    title: Text(_getLocalizedSectionName(context, sec)),
                    trailing: const Icon(Icons.drag_handle, size: 20),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Divider(),
            ],
            const SizedBox(height: 8),
            ...AppSection.values.map((sec) {
              final isChecked = settings.bottomNavigationSections.contains(sec);
              return CheckboxListTile(
                key: Key('settings_bottom_nav_checkbox_${sec.name}'),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Row(
                  children: [
                    Icon(
                      _getAppSectionIcon(sec),
                      size: 18,
                      color: isChecked ? context.colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(_getLocalizedSectionName(context, sec)),
                  ],
                ),
                value: isChecked,
                onChanged: (bool? checked) {
                  final current = List<AppSection>.from(
                    settings.bottomNavigationSections,
                  );
                  if (checked == true) {
                    if (!current.contains(sec)) {
                      current.add(sec);
                    }
                  } else {
                    current.remove(sec);
                  }
                  notifier.setBottomNavigationSections(current);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showStartupPageDialog(
    BuildContext context,
    AppSection currentSection,
    SettingsNotifier notifier,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(context.l10n.selectStartupPageTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: AppSection.values.map((sec) {
                final isSelected = sec == currentSection;
                return RadioListTile<AppSection>(
                  key: Key('settings_startup_page_radio_${sec.name}'),
                  dense: true,
                  secondary: Icon(
                    _getAppSectionIcon(sec),
                    color: isSelected ? context.colorScheme.primary : null,
                  ),
                  title: Text(_getLocalizedSectionName(context, sec)),
                  value: sec,
                  groupValue: currentSection,
                  onChanged: (val) {
                    if (val != null) {
                      notifier.setStartupSection(val);
                      Navigator.of(dialogCtx).pop();
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(context.l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  IconData _getAppSectionIcon(AppSection section) {
    return switch (section) {
      AppSection.dashboard => Icons.dashboard_outlined,
      AppSection.aiChat => Icons.smart_toy_outlined,
      AppSection.terminal => Icons.terminal_outlined,
      AppSection.files => Icons.folder_outlined,
      AppSection.docker => Icons.directions_boat_outlined,
      AppSection.system => Icons.memory_outlined,
      AppSection.commands => Icons.bolt_outlined,
      AppSection.settings => Icons.settings_outlined,
      AppSection.cliChat => Icons.forum_outlined,
      AppSection.nas => Icons.perm_media_outlined,
    };
  }

  String _getLocalizedSectionName(BuildContext context, AppSection section) {
    return switch (section) {
      AppSection.dashboard => context.l10n.navDashboard,
      AppSection.aiChat => context.l10n.navAiChat,
      AppSection.terminal => context.l10n.navTerminal,
      AppSection.files => context.l10n.navFiles,
      AppSection.docker => context.l10n.navDocker,
      AppSection.system => context.l10n.navSystem,
      AppSection.commands => context.l10n.navCommands,
      AppSection.settings => context.l10n.navSettings,
      AppSection.cliChat => context.l10n.navCliChat,
      AppSection.nas => context.l10n.navNas,
    };
  }
}

class _AutoConnectCard extends ConsumerStatefulWidget {
  const _AutoConnectCard();

  @override
  ConsumerState<_AutoConnectCard> createState() => _AutoConnectCardState();
}

class _AutoConnectCardState extends ConsumerState<_AutoConnectCard> {
  void _showModeDialog(BuildContext context, AutoConnectMode currentMode) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(context.l10n.selectAutoConnectModeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<AutoConnectMode>(
                key: const Key('settingsAutoConnectFixedRadio'),
                dense: true,
                title: Text(
                  context.l10n.settingsAutoConnectFixed,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  context.l10n.settingsAutoConnectFixedDesc,
                  style: const TextStyle(fontSize: 11),
                ),
                value: AutoConnectMode.fixed,
                groupValue: currentMode,
                onChanged: (val) async {
                  if (val != null) {
                    await ref
                        .read(autoConnectSettingsProvider.notifier)
                        .setMode(val);
                    if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                    if (mounted) setState(() {});
                  }
                },
              ),
              RadioListTile<AutoConnectMode>(
                key: const Key('settingsAutoConnectLastRadio'),
                dense: true,
                title: Text(
                  context.l10n.settingsAutoConnectLast,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  context.l10n.settingsAutoConnectLastDesc,
                  style: const TextStyle(fontSize: 11),
                ),
                value: AutoConnectMode.lastConnected,
                groupValue: currentMode,
                onChanged: (val) async {
                  if (val != null) {
                    await ref
                        .read(autoConnectSettingsProvider.notifier)
                        .setMode(val);
                    if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                    if (mounted) setState(() {});
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(context.l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  void _showServerPicker(
    BuildContext context,
    List<ServerProfile> servers,
    String? fixedServerId,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.settingsAutoConnectPickServer),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: servers.length,
              itemBuilder: (context, index) {
                final server = servers[index];
                final isSelected = server.id == fixedServerId;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.dns_outlined,
                    color: isSelected ? context.colorScheme.primary : null,
                  ),
                  title: Text(
                    server.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${server.username}@${server.host}:${server.port}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: context.colorScheme.primary)
                      : null,
                  onTap: () async {
                    await ref
                        .read(autoConnectSettingsProvider.notifier)
                        .setFixedServerId(server.id);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    if (mounted) {
                      setState(() {});
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.read(autoConnectSettingsProvider);
    final mode = settings.mode;
    final fixedServerId = settings.fixedServerId;
    final servers = ref.watch(serverListProvider);

    final matchingServer = servers.cast<ServerProfile?>().firstWhere(
      (s) => s?.id == fixedServerId,
      orElse: () => null,
    );
    final serverDisplayName =
        matchingServer?.name ?? context.l10n.settingsAutoConnectNoServer;

    final summaryText = switch (mode) {
      AutoConnectMode.fixed =>
        '${context.l10n.settingsAutoConnectFixed} ($serverDisplayName)',
      AutoConnectMode.lastConnected => context.l10n.settingsAutoConnectLast,
    };

    return Card(
      child: Column(
        children: [
          ListTile(
            key: const Key('settings_auto_connect_mode_tile'),
            leading: Icon(
              Icons.power_settings_new,
              color: context.colorScheme.primary,
            ),
            title: Text(
              context.l10n.settingsAutoConnect,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(summaryText, style: const TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showModeDialog(context, mode),
          ),
          if (mode == AutoConnectMode.fixed && servers.isNotEmpty) ...[
            const Divider(height: 1),
            ListTile(
              key: const Key('settingsAutoConnectServerTile'),
              dense: true,
              leading: const Icon(Icons.dns_outlined),
              title: Text(
                context.l10n.settingsAutoConnectPickServer,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                serverDisplayName,
                style: const TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showServerPicker(context, servers, fixedServerId),
            ),
          ],
        ],
      ),
    );
  }
}
