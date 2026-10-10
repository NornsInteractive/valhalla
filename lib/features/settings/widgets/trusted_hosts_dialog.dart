import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/security_settings_provider.dart';
import '../../../data/models/host_key_entry.dart';

class TrustedHostsDialog extends ConsumerStatefulWidget {
  const TrustedHostsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const TrustedHostsDialog(),
    );
  }

  @override
  ConsumerState<TrustedHostsDialog> createState() => _TrustedHostsDialogState();
}

class _TrustedHostsDialogState extends ConsumerState<TrustedHostsDialog> {
  final Set<String> _revokingHostPorts = {};

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  Future<void> _confirmRevoke(HostKeyEntry entry) async {
    if (_revokingHostPorts.contains(entry.hostPort)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.settingsHostKeyRevokeConfirmTitle),
        content: SingleChildScrollView(
          child: Text(
            ctx.l10n.settingsHostKeyRevokeConfirmMessage(entry.hostPort),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.vDanger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.settingsHostKeyRevoke),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _revokingHostPorts.add(entry.hostPort));
    try {
      await ref.read(trustedHostsProvider.notifier).revoke(entry.hostPort);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settingsHostKeyRevoked)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: context.vDanger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _revokingHostPorts.remove(entry.hostPort));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(trustedHostsProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.fingerprint, color: context.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.settingsKnownHostsDialogTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: 480,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fingerprint_outlined,
                        size: 48,
                        color: context.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.settingsKnownHostsEmpty,
                        style: TextStyle(color: context.colorScheme.outline),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final entry = entries[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VRadius.card),
                        side: BorderSide(
                          color: context.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.dns_outlined, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          entry.hostPort,
                                          style: monoTextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  key: Key('revoke_host_${entry.hostPort}'),
                                  icon:
                                      _revokingHostPorts.contains(
                                        entry.hostPort,
                                      )
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: context.vDanger,
                                          ),
                                        )
                                      : Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: context.vDanger,
                                        ),
                                  tooltip: context.l10n.settingsHostKeyRevoke,
                                  onPressed:
                                      _revokingHostPorts.contains(
                                        entry.hostPort,
                                      )
                                      ? null
                                      : () => _confirmRevoke(entry),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  VRadius.input,
                                ),
                              ),
                              child: Text(
                                entry.keyType,
                                style: monoTextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.fingerprintSha256,
                                    style: monoTextStyle(
                                      fontSize: 11,
                                      color: context.colorScheme.outline,
                                    ),
                                    softWrap: true,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: context
                                      .l10n
                                      .settingsHostKeyFingerprintCopied,
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: entry.fingerprintSha256,
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context
                                              .l10n
                                              .settingsHostKeyFingerprintCopied,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDateTime(entry.trustedAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: context.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cmdClose),
        ),
      ],
    );
  }
}
