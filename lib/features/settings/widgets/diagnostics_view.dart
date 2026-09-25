import 'package:flutter/material.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/services/app_diagnostics.dart';

class DiagnosticsView extends StatefulWidget {
  final AppDiagnostics diagnostics;
  final bool isDialog;

  DiagnosticsView({
    super.key,
    AppDiagnostics? diagnostics,
    this.isDialog = false,
  }) : diagnostics = diagnostics ?? AppDiagnostics.instance;

  static Future<void> show(
    BuildContext context, {
    AppDiagnostics? diagnostics,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 650),
          child: DiagnosticsView(diagnostics: diagnostics, isDialog: true),
        ),
      ),
    );
  }

  @override
  State<DiagnosticsView> createState() => _DiagnosticsViewState();
}

class _DiagnosticsViewState extends State<DiagnosticsView> {
  bool _loading = true;
  String? _logs;
  String? _error;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final text = await widget.diagnostics.read();
      if (!mounted) return;
      setState(() {
        _logs = text;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _exportLogs() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final path = await widget.diagnostics.export();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (path != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.diagnosticsExportSuccess(path)),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diagnosticsExportFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storageError = widget.diagnostics.storageError;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title Bar (shown in dialog mode)
        if (widget.isDialog) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Icon(
                  Icons.bug_report_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.diagnosticsTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  key: const Key('diagnostics_refresh_button'),
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: context.l10n.diagnosticsRefresh,
                  onPressed: _loading ? null : _loadLogs,
                ),
                IconButton(
                  key: const Key('diagnostics_export_button'),
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download_outlined, size: 20),
                  tooltip: context.l10n.exportDiagnostics,
                  onPressed: _exporting ? null : _exportLogs,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],

        // Storage Error Banner (if any)
        if (storageError != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.errorContainer,
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.diagnosticsStorageError(storageError),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Main Log Area
        Expanded(
          child: Container(
            color: const Color(0xFF0F141C),
            padding: const EdgeInsets.all(12),
            child: _buildLogBody(theme),
          ),
        ),
      ],
    );

    if (widget.isDialog) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diagnosticsTitle),
        actions: [
          IconButton(
            key: const Key('diagnostics_refresh_button'),
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.diagnosticsRefresh,
            onPressed: _loading ? null : _loadLogs,
          ),
          IconButton(
            key: const Key('diagnostics_export_button'),
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            tooltip: context.l10n.exportDiagnostics,
            onPressed: _exporting ? null : _exportLogs,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildLogBody(ThemeData theme) {
    if (_loading && _logs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadLogs,
              child: Text(context.l10n.stateRetry),
            ),
          ],
        ),
      );
    }

    final text = _logs ?? '';
    if (text.trim().isEmpty) {
      return Center(
        child: Text(
          context.l10n.diagnosticsEmpty,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
      );
    }

    return SingleChildScrollView(
      reverse: true, // auto-scroll to end of logs
      child: SelectableText(
        text,
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          height: 1.4,
          color: Color(0xFFE2E8F0),
        ),
      ),
    );
  }
}
