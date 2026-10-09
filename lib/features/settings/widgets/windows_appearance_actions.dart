import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/settings_provider.dart';
import 'appearance_dialogs.dart';
import 'theme_accent_color_dialog.dart';

class WindowsAppearanceActions extends ConsumerWidget {
  const WindowsAppearanceActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('windows_accent_button'),
          icon: Icon(
            Icons.palette_outlined,
            color: context.colorScheme.primary,
          ),
          tooltip: context.l10n.accentColorDialogTitle,
          onPressed: () {
            final mode = settings.themeMode == AppThemeMode.system
                ? (Theme.of(context).brightness == Brightness.dark
                      ? AppThemeMode.dark
                      : AppThemeMode.light)
                : settings.themeMode;
            showDialog<void>(
              context: context,
              builder: (_) => ThemeAccentColorDialog(
                settings: settings,
                initialMode: mode,
                notifier: notifier,
              ),
            );
          },
        ),
        IconButton(
          key: const Key('windows_theme_button'),
          icon: const Icon(Icons.brightness_6_outlined),
          tooltip: context.l10n.settingsThemeMode,
          onPressed: () =>
              showAppThemeModeDialog(context, settings.themeMode, notifier),
        ),
        IconButton(
          key: const Key('windows_language_button'),
          icon: const Icon(Icons.translate),
          tooltip: context.l10n.settingsLanguage,
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) =>
                LanguageSelectionDialog(settings: settings, notifier: notifier),
          ),
        ),
      ],
    );
  }
}
