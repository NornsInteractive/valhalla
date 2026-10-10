import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/commands_provider.dart';
import '../../../core/providers/security_settings_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/storage_providers.dart';
import '../../../core/providers/terminal_settings_provider.dart';
import '../../../data/models/agent_profile.dart';
import '../../../data/models/quick_command.dart';
import '../../../data/models/server_profile.dart';
import '../../../data/services/configuration_backup_service.dart';

class ConfigurationMigrationManager {
  static bool _isExporting = false;
  static bool _isImporting = false;

  static Future<void> handleExport(BuildContext context, WidgetRef ref) async {
    if (_isExporting) return;
    _isExporting = true;

    try {
      final storage = ref.read(localStorageServiceProvider);
      final backup = ConfigurationBackupService(storage).exportConfiguration();

      if (!context.mounted) return;
      final confirmed = await ConfigExportPreviewDialog.show(
        context,
        backup: backup,
      );
      if (confirmed != true || !context.mounted) return;

      final jsonText = backup.encode();
      final bytes = Uint8List.fromList(utf8.encode(jsonText));

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final fileName = 'valhalla-backup-$dateStr.json';

      final savedPath = await FilePicker.saveFile(
        dialogTitle: context.l10n.configExportDialogTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        mimeType: 'application/json',
        bytes: bytes,
      );

      // File cancel is not an error
      if (savedPath == null) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.configExportSuccess),
            backgroundColor: context.vSuccess,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.configExportError(e.toString())),
            backgroundColor: context.vDanger,
          ),
        );
      }
    } finally {
      _isExporting = false;
    }
  }

  static Future<void> handleImport(BuildContext context, WidgetRef ref) async {
    if (_isImporting) return;
    _isImporting = true;

    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );

      // File cancel is not an error
      if (picked == null) return;

      // Enforce sync length <= ConfigurationBackupService.maxBytes before read if known
      final syncLength = picked.lengthSync();
      if (syncLength != null &&
          syncLength > ConfigurationBackupService.maxBytes) {
        if (context.mounted) {
          await ConfigImportErrorDialog.show(
            context,
            error: const FormatException('CONFIG_TOO_LARGE'),
          );
        }
        return;
      }

      // Stream read with bounded accumulation <= maxBytes
      final builder = BytesBuilder(copy: false);
      var totalBytes = 0;
      try {
        await for (final chunk in picked.readAsByteStream()) {
          totalBytes += chunk.length;
          if (totalBytes > ConfigurationBackupService.maxBytes) {
            throw const FormatException('CONFIG_TOO_LARGE');
          }
          builder.add(chunk);
        }
      } catch (e) {
        if (context.mounted) {
          await ConfigImportErrorDialog.show(context, error: e);
        }
        return;
      }

      final text = utf8.decode(builder.takeBytes());
      final ConfigurationBackup backup;
      try {
        backup = ConfigurationBackupService.decode(text);
      } catch (e) {
        if (context.mounted) {
          await ConfigImportErrorDialog.show(context, error: e);
        }
        return;
      }

      if (!context.mounted) return;
      final imported = await ConfigImportPreviewDialog.show(
        context,
        backup: backup,
      );

      if (imported == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.configImportSuccess),
            backgroundColor: context.vSuccess,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        await ConfigImportErrorDialog.show(context, error: e);
      }
    } finally {
      _isImporting = false;
    }
  }
}

class ConfigExportPreviewDialog extends StatelessWidget {
  final ConfigurationBackup backup;

  const ConfigExportPreviewDialog({super.key, required this.backup});

  static Future<bool?> show(
    BuildContext context, {
    required ConfigurationBackup backup,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ConfigExportPreviewDialog(backup: backup),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = backup;
    final totalBookmarks = b.bookmarks.values.fold(
      0,
      (acc, list) => acc + list.length,
    );

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.shield_outlined, color: context.vWarning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.configExportTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Prominent secret warning callout
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.vWarning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(VRadius.input),
                    border: Border.all(
                      color: context.vWarning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: context.vWarning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.l10n.configImportSecretWarning,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.vWarning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.configExportSubtitle,
                  style: context.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                // Summary badges
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.dns_outlined, size: 14),
                      label: Text(
                        context.l10n.configImportServersCount(b.servers.length),
                      ),
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.smart_toy_outlined, size: 14),
                      label: Text(
                        context.l10n.configImportAgentsCount(b.agents.length),
                      ),
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.terminal_outlined, size: 14),
                      label: Text(
                        context.l10n.configImportCommandsCount(
                          b.commands.length,
                        ),
                      ),
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.bookmark_border, size: 14),
                      label: Text(
                        context.l10n.configImportBookmarksCount(totalBookmarks),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                // Endpoints preview
                _buildServerEndpointsPreview(context, b.servers),
                // Agents preview: startup, install, login command text
                if (b.agents.isNotEmpty) ...[
                  ExpansionTile(
                    title: Text(
                      context.l10n.settingsAgentManagement,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      context.l10n.configImportAgentsCount(b.agents.length),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colorScheme.outline,
                      ),
                    ),
                    children: b.agents.map((a) {
                      return _buildAgentScriptPreview(context, a);
                    }).toList(),
                  ),
                  const Divider(height: 1),
                ],
                // Quick commands preview
                _buildCommandsPreview(context, b.commands),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: Text(context.l10n.configExportTitle),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

Widget _buildServerEndpointsPreview(
  BuildContext context,
  List<ServerProfile> servers,
) {
  if (servers.isEmpty) return const SizedBox.shrink();
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExpansionTile(
        title: Text(
          context.l10n.selectServerTitle,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          context.l10n.configImportServersCount(servers.length),
          style: TextStyle(fontSize: 11, color: context.colorScheme.outline),
        ),
        children: servers.map((s) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.dns, size: 18),
            title: Text(
              s.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${s.username}@${s.host}:${s.port} (${s.authType.name})',
              style: monoTextStyle(fontSize: 11),
            ),
          );
        }).toList(),
      ),
      const Divider(height: 1),
    ],
  );
}

Widget _buildAgentScriptPreview(BuildContext context, AgentProfile a) {
  final scriptEntries = <(String, String)>[];
  if (a.cliCommand.isNotEmpty) {
    scriptEntries.add((context.l10n.agentCliCommandLabel, a.cliCommand));
  }
  if (a.acpCommand != null && a.acpCommand!.trim().isNotEmpty) {
    scriptEntries.add((context.l10n.agentAcpCommandLabel, a.acpCommand!));
  }
  if (a.installCommand != null && a.installCommand!.trim().isNotEmpty) {
    scriptEntries.add((
      context.l10n.agentInstallCommandLabel,
      a.installCommand!,
    ));
  }
  if (a.acpInstallCommand != null && a.acpInstallCommand!.trim().isNotEmpty) {
    scriptEntries.add((
      context.l10n.agentInstallCommandAcpLabel,
      a.acpInstallCommand!,
    ));
  }
  if (a.loginCheckCommand != null && a.loginCheckCommand!.trim().isNotEmpty) {
    scriptEntries.add((
      context.l10n.agentLoginCheckCommandLabel,
      a.loginCheckCommand!,
    ));
  }
  if (a.loginCommand != null && a.loginCommand!.trim().isNotEmpty) {
    scriptEntries.add((context.l10n.agentLoginCommandLabel, a.loginCommand!));
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            const Icon(Icons.smart_toy, size: 16),
            Text(
              a.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(VRadius.pill),
              ),
              child: Text(
                '${context.l10n.agentExecutionTarget}: ${a.executionTarget}',
                style: monoTextStyle(
                  fontSize: 10,
                  color: context.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...scriptEntries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.$1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(VRadius.input),
                  ),
                  child: SelectableText(
                    entry.$2,
                    style: monoTextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildCommandsPreview(
  BuildContext context,
  List<QuickCommand> commands, {
  Key? key,
}) {
  if (commands.isEmpty) return const SizedBox.shrink();
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExpansionTile(
        key: key,
        title: Text(
          context.l10n.navCommands,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          context.l10n.configImportCommandsCount(commands.length),
          style: TextStyle(fontSize: 11, color: context.colorScheme.outline),
        ),
        children: commands.map((c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.code, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(VRadius.input),
                  ),
                  child: SelectableText(
                    c.command,
                    style: monoTextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
      const Divider(height: 1),
    ],
  );
}

class ConfigImportPreviewDialog extends ConsumerStatefulWidget {
  final ConfigurationBackup backup;

  const ConfigImportPreviewDialog({super.key, required this.backup});

  static Future<bool?> show(
    BuildContext context, {
    required ConfigurationBackup backup,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfigImportPreviewDialog(backup: backup),
    );
  }

  @override
  ConsumerState<ConfigImportPreviewDialog> createState() =>
      _ConfigImportPreviewDialogState();
}

class _ConfigImportPreviewDialogState
    extends ConsumerState<ConfigImportPreviewDialog> {
  bool _applyPreferences = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final storage = ref.read(localStorageServiceProvider);
      await ConfigurationBackupService(
        storage,
      ).importConfiguration(widget.backup, applyPreferences: _applyPreferences);

      if (!mounted) return;

      // Invalidate relevant providers after checking mounted
      ref.invalidate(serverListProvider);
      ref.invalidate(commandsProvider);
      ref.invalidate(defaultAgentSettingsProvider);
      if (_applyPreferences) {
        ref.invalidate(settingsProvider);
        ref.invalidate(terminalSettingsProvider);
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.backup;
    final totalBookmarks = b.bookmarks.values.fold(
      0,
      (acc, list) => acc + list.length,
    );

    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.restore_page_rounded,
              color: context.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.configImportPreviewTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.vDanger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(VRadius.input),
                        border: Border.all(
                          color: context.vDanger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: context.vDanger,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.vDanger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Security warning
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.vWarning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(VRadius.input),
                      border: Border.all(
                        color: context.vWarning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: context.vWarning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.configImportSecretWarning,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.vWarning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.configImportPreviewDesc,
                    style: context.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  // Stats badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.dns_outlined, size: 14),
                        label: Text(
                          context.l10n.configImportServersCount(
                            b.servers.length,
                          ),
                        ),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.smart_toy_outlined, size: 14),
                        label: Text(
                          context.l10n.configImportAgentsCount(b.agents.length),
                        ),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.terminal_outlined, size: 14),
                        label: Text(
                          context.l10n.configImportCommandsCount(
                            b.commands.length,
                          ),
                        ),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.bookmark_border, size: 14),
                        label: Text(
                          context.l10n.configImportBookmarksCount(
                            totalBookmarks,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  // Endpoints preview
                  _buildServerEndpointsPreview(context, b.servers),
                  // Agents preview with full script inspection
                  if (b.agents.isNotEmpty) ...[
                    ExpansionTile(
                      title: Text(
                        context.l10n.settingsAgentManagement,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        context.l10n.configImportAgentsCount(b.agents.length),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colorScheme.outline,
                        ),
                      ),
                      children: b.agents.map((a) {
                        return _buildAgentScriptPreview(context, a);
                      }).toList(),
                    ),
                    const Divider(height: 1),
                  ],
                  // Commands preview (Expandable with full command text)
                  _buildCommandsPreview(
                    context,
                    b.commands,
                    key: const Key('config_import_commands_expansion'),
                  ),
                  const SizedBox(height: 8),
                  // Global preferences checkbox (OFF by default)
                  CheckboxListTile(
                    key: const Key('config_import_global_prefs_checkbox'),
                    value: _applyPreferences,
                    onChanged: _isSubmitting
                        ? null
                        : (val) =>
                              setState(() => _applyPreferences = val ?? false),
                    title: Text(
                      context.l10n.configImportGlobalPreferences,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      context.l10n.configImportGlobalPreferencesDesc,
                      style: const TextStyle(fontSize: 11),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('config_import_confirm_button'),
            onPressed: _isSubmitting ? null : _handleSubmit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.configImportConfirmAction),
          ),
        ],
      ),
    );
  }
}

class ConfigImportErrorDialog extends StatelessWidget {
  final Object error;

  const ConfigImportErrorDialog({super.key, required this.error});

  static Future<void> show(BuildContext context, {required Object error}) {
    return showDialog<void>(
      context: context,
      builder: (_) => ConfigImportErrorDialog(error: error),
    );
  }

  static String mapError(BuildContext context, Object error) {
    final message = error.toString();
    if (message.contains('CONFIG_TOO_LARGE')) {
      return context.l10n.configBackupTooLarge;
    }
    if (message.contains('CONFIG_VERSION_UNSUPPORTED')) {
      return context.l10n.configImportErrorUnsupportedVersion;
    }
    if (message.contains('CONFIG_FORMAT_INVALID') ||
        message.contains('FormatException')) {
      return context.l10n.configImportErrorMalformed;
    }
    return context.l10n.configImportErrorGeneric(message);
  }

  @override
  Widget build(BuildContext context) {
    final detailString = error.toString();
    final friendlyMessage = mapError(context, error);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: context.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.configImportErrorTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(friendlyMessage, style: context.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(VRadius.input),
                ),
                child: SelectableText(
                  detailString,
                  style: monoTextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: Text(context.l10n.configImportErrorCopyDetails),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: detailString));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.configImportErrorCopied)),
            );
          },
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cmdClose),
        ),
      ],
    );
  }
}
