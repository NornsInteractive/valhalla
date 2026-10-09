// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/localization/app_locales.dart';
import '../../../core/providers/settings_provider.dart';

void showAppThemeModeDialog(
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

String localizedLanguageName(BuildContext context, String tag) {
  final l10n = context.l10n;
  switch (tag) {
    case 'system':
      return l10n.langSystem;
    case 'zh':
      return l10n.langZh;
    case 'en':
      return l10n.langEn;
    case 'zh-Hant':
      return l10n.langZhHant;
    case 'ja':
      return l10n.langJa;
    case 'ko':
      return l10n.langKo;
    case 'de':
      return l10n.langDe;
    case 'fr':
      return l10n.langFr;
    case 'es':
      return l10n.langEs;
    case 'pt':
      return l10n.langPt;
    case 'ru':
      return l10n.langRu;
    case 'ar':
      return l10n.langAr;
    case 'hi':
      return l10n.langHi;
    case 'id':
      return l10n.langId;
    case 'it':
      return l10n.langIt;
    case 'tr':
      return l10n.langTr;
    case 'vi':
      return l10n.langVi;
    case 'th':
      return l10n.langTh;
    default:
      return l10n.langSystem;
  }
}

class LanguageSelectionDialog extends StatefulWidget {
  final SettingsState settings;
  final SettingsNotifier notifier;

  const LanguageSelectionDialog({
    super.key,
    required this.settings,
    required this.notifier,
  });

  @override
  State<LanguageSelectionDialog> createState() =>
      _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends State<LanguageSelectionDialog> {
  bool _isSaving = false;
  String? _savingTag;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTag = widget.settings.locale.languageCode == 'system'
        ? 'system'
        : widget.settings.locale.toLanguageTag();

    final choices = <({String tag, Locale locale})>[
      (tag: 'system', locale: const Locale('system')),
      for (final locale in appLanguageLocales)
        (tag: locale.toLanguageTag(), locale: locale),
    ];

    return AlertDialog(
      title: Text(context.l10n.selectLanguageTitle),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          maxWidth: 400,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final choice in choices)
                RadioListTile<String>(
                  key: Key('settings_lang_${choice.tag}'),
                  dense: true,
                  title: Text(
                    localizedLanguageName(context, choice.tag),
                    style: const TextStyle(fontSize: 13),
                    softWrap: true,
                  ),
                  secondary: _isSaving && _savingTag == choice.tag
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  value: choice.tag,
                  groupValue: currentTag,
                  onChanged: _isSaving
                      ? null
                      : (val) async {
                          if (val == null) return;
                          final saveFailedMessage =
                              context.l10n.settingsLanguageSaveFailed;
                          setState(() {
                            _isSaving = true;
                            _savingTag = choice.tag;
                            _errorMessage = null;
                          });
                          try {
                            await widget.notifier.setLocale(choice.locale);
                            if (!mounted) return;
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          } catch (_) {
                            if (mounted) {
                              setState(() {
                                _errorMessage = saveFailedMessage;
                                _isSaving = false;
                                _savingTag = null;
                              });
                            }
                          }
                        },
                ),
            ],
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.error,
                    ),
                    softWrap: true,
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(context.l10n.cancel),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
