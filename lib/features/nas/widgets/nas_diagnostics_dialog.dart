import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/nas_provider.dart';
import '../../../core/providers/nas_sources_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/nas_media.dart';
import '../../../data/models/nas_source.dart';

class NasDiagnosticsDialog extends ConsumerStatefulWidget {
  final NasSource source;
  const NasDiagnosticsDialog({super.key, required this.source});

  static Future<void> show(BuildContext context, {required NasSource source}) =>
      showDialog<void>(
        context: context,
        builder: (_) => NasDiagnosticsDialog(source: source),
      );

  @override
  ConsumerState<NasDiagnosticsDialog> createState() =>
      _NasDiagnosticsDialogState();
}

class _NasDiagnosticsDialogState extends ConsumerState<NasDiagnosticsDialog> {
  bool _probing = false;
  String? _probeError;
  Object? _sshTarget;

  @override
  void initState() {
    super.initState();
    _sshTarget = _currentSshTarget();
  }

  Object? _currentSshTarget() => widget.source.sshServerId == null
      ? null
      : ref
            .read(serverListProvider)
            .where((server) => server.id == widget.source.sshServerId)
            .firstOrNull
            ?.connectionKey;

  bool _sameSource(NasSourcesState sources) {
    final current = sources.selected;
    return current != null &&
        jsonEncode(current.toJson()) == jsonEncode(widget.source.toJson()) &&
        _currentSshTarget() == _sshTarget;
  }

  Future<void> _probe() async {
    if (_probing || !_sameSource(ref.read(nasSourcesProvider))) return;
    setState(() {
      _probing = true;
      _probeError = null;
    });
    try {
      // Resolve stored secrets inside the provider; never put them in this UI.
      await ref.read(nasSourcesProvider.notifier).probeSaved(widget.source);
    } catch (_) {
      if (mounted && _sameSource(ref.read(nasSourcesProvider))) {
        setState(() => _probeError = context.l10n.nasProbeFailed);
      }
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  String _time(DateTime? time) => time == null
      ? context.l10n.nasDiagnosticsNotChecked
      : time.toLocal().toString().split('.').first;

  String _connectionLabel(NasConnectionStage stage) => switch (stage) {
    NasConnectionStage.credentials => context.l10n.nasDiagnosticsCredentials,
    NasConnectionStage.tunnel => context.l10n.nasUseSshTunnel,
    NasConnectionStage.checking => context.l10n.agentStatusChecking,
    NasConnectionStage.ready => context.l10n.nasProbeSuccess,
    NasConnectionStage.failed => context.l10n.nasProbeFailed,
  };

  String _scanLabel(NasScanStage stage) => switch (stage) {
    NasScanStage.idle => context.l10n.nasNotScanned,
    NasScanStage.connecting => context.l10n.serverConnecting,
    NasScanStage.scanning => context.l10n.nasScanning,
    NasScanStage.finalizing => context.l10n.nasDiagnosticsFinalizing,
    NasScanStage.completed => context.l10n.toolStatusCompleted,
    NasScanStage.cancelled => context.l10n.nasScanCancelled,
    NasScanStage.failed => context.l10n.toolStatusFailed,
  };

  Widget _value(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.textTheme.labelMedium),
        const SizedBox(height: 4),
        SelectableText(value),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(nasSourcesProvider);
    if (widget.source.sshServerId != null) ref.watch(serverListProvider);
    final sameSource = _sameSource(sources);
    final diagnostic = sources.diagnosticFor(widget.source);
    final library = ref.watch(nasProvider);
    final scan = sameSource && library.serverId == widget.source.id
        ? library
        : null;
    final report = [
      if (diagnostic != null) diagnostic.diagnosticText,
      if (scan != null) ...[
        'scanStage: ${scan.scanStage.name}',
        'discovered: ${scan.scannedCount}',
        if (scan.scanUpdatedAt != null)
          'scanUpdatedAt: ${scan.scanUpdatedAt!.toUtc().toIso8601String()}',
        if (scan.lastScan != null)
          'lastSuccessfulScan: ${scan.lastScan!.toUtc().toIso8601String()}',
        if (scan.scanErrorCode != null) 'scanError: ${scan.scanErrorCode}',
      ],
    ].join('\n');
    final l10n = context.l10n;
    return AlertDialog(
      key: const Key('nas_diagnostics_dialog'),
      title: Text(l10n.nasDiagnosticsTitle),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.source.name, style: context.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (!sameSource) ...[
              Text(
                l10n.nasSourceChangedError,
                style: TextStyle(color: context.colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            _value(
              l10n.nasDiagnosticsConnection,
              diagnostic == null
                  ? l10n.nasDiagnosticsNotChecked
                  : _connectionLabel(diagnostic.stage),
            ),
            if (diagnostic != null) ...[
              _value(l10n.chatAccountUpdatedAt, _time(diagnostic.updatedAt)),
              _value(
                l10n.nasDiagnosticsLastSuccess,
                _time(diagnostic.lastSuccess),
              ),
              if (diagnostic.errorCode != null)
                SelectableText(diagnostic.errorCode!),
              if (diagnostic.httpStatus != null)
                SelectableText('HTTP ${diagnostic.httpStatus}'),
            ],
            if (_probeError != null)
              Text(
                _probeError!,
                style: TextStyle(color: context.colorScheme.error),
              ),
            if (_probing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            const Divider(height: 24),
            _value(
              l10n.nasDiagnosticsScan,
              scan == null
                  ? l10n.nasDiagnosticsNotChecked
                  : _scanLabel(scan.scanStage),
            ),
            if (scan != null) ...[
              Text(l10n.nasItemCount('${scan.scannedCount}')),
              if (scan.isScanning)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 12),
              _value(l10n.chatAccountUpdatedAt, _time(scan.scanUpdatedAt)),
              Text(l10n.nasLastScan(_time(scan.lastScan))),
              if (scan.scanErrorCode != null)
                SelectableText(scan.scanErrorCode!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cmdClose),
        ),
        TextButton.icon(
          key: const Key('nas_diagnostics_copy'),
          onPressed: report.isEmpty
              ? null
              : () => Clipboard.setData(ClipboardData(text: report)),
          icon: const Icon(Icons.copy_outlined),
          label: Text(l10n.agentDiagnosticLogCopy),
        ),
        FilledButton.icon(
          key: const Key('nas_diagnostics_probe'),
          onPressed: _probing || !sameSource ? null : _probe,
          icon: const Icon(Icons.network_check),
          label: Text(l10n.nasProbe),
        ),
      ],
    );
  }
}
