import 'package:flutter/material.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/logging/sanitizer.dart';
import '../../../core/services/app_diagnostics.dart';
import '../../../l10n/app_localizations.dart';
import 'diagnostics_view.dart';

class StartupFailureApp extends StatefulWidget {
  final Future<void> Function() retry;
  final AppDiagnostics diagnostics;

  StartupFailureApp({
    super.key,
    required this.retry,
    AppDiagnostics? diagnostics,
  }) : diagnostics = diagnostics ?? AppDiagnostics.instance;

  @override
  State<StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<StartupFailureApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF0F141C),
      ),
      home: _StartupFailureScreen(
        retry: widget.retry,
        diagnostics: widget.diagnostics,
      ),
    );
  }
}

class _StartupFailureScreen extends StatefulWidget {
  final Future<void> Function() retry;
  final AppDiagnostics diagnostics;

  const _StartupFailureScreen({required this.retry, required this.diagnostics});

  @override
  State<_StartupFailureScreen> createState() => _StartupFailureScreenState();
}

class _StartupFailureScreenState extends State<_StartupFailureScreen> {
  bool _isRetrying = false;
  bool _isExporting = false;
  String? _retryError;

  Future<void> _handleRetry() async {
    if (_isRetrying) return;
    setState(() {
      _isRetrying = true;
      _retryError = null;
    });

    try {
      await widget.retry();
    } catch (e) {
      if (mounted) {
        setState(() {
          _retryError = LogSanitizer.sanitize(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  Future<void> _handleExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final path = await widget.diagnostics.export();
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diagnosticsExportSuccess(path)),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diagnosticsExportFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storageError = widget.diagnostics.storageError;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(
                          alpha: 0.3,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 40,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    context.l10n.startupFailed,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // Description
                  Text(
                    context.l10n.startupFailedDesc,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Storage Error (if storage failed)
                  if (storageError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.diagnosticsStorageError(
                                storageError,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_retryError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _retryError!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons
                  FilledButton.icon(
                    key: const Key('startup_retry_button'),
                    onPressed: _isRetrying ? null : _handleRetry,
                    icon: _isRetrying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(context.l10n.retryStartup),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    key: const Key('startup_view_diagnostics_button'),
                    onPressed: () => DiagnosticsView.show(
                      context,
                      diagnostics: widget.diagnostics,
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text(context.l10n.viewDiagnostics),
                  ),
                  const SizedBox(height: 8),

                  TextButton.icon(
                    key: const Key('startup_export_diagnostics_button'),
                    onPressed: _isExporting ? null : _handleExport,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download_outlined, size: 18),
                    label: Text(context.l10n.exportDiagnostics),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
