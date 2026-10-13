import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/application_center_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/application_center.dart';
import 'app_center_error_resolver.dart';

class AppLogsDialog extends ConsumerStatefulWidget {
  final ApplicationDeployment deployment;

  const AppLogsDialog({super.key, required this.deployment});

  static Future<void> show(
    BuildContext context, {
    required ApplicationDeployment deployment,
  }) {
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;
    if (isCompact) {
      return Navigator.push<void>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AppLogsDialog(deployment: deployment),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (_) => AppLogsDialog(deployment: deployment),
    );
  }

  @override
  ConsumerState<AppLogsDialog> createState() => _AppLogsDialogState();
}

class _AppLogsDialogState extends ConsumerState<AppLogsDialog> {
  bool _isLoading = true;
  String? _logs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final logs = await ref
          .read(applicationCenterProvider.notifier)
          .logs(widget.deployment);
      if (!mounted ||
          ref.read(activeServerProvider)?.connectionKey != capturedKey) {
        return;
      }
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        setState(() {
          _error = e is ApplicationCenterException
              ? resolveAppCenterErrorMessage(context, e.code, e.detail)
              : e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copyLogs() {
    if (_logs == null || _logs!.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _logs!));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.appCenterLogsCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;

    final header = Row(
      children: [
        Expanded(
          child: Text(
            l10n.appCenterLogsTitle(widget.deployment.name),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          tooltip: l10n.appCenterRefresh,
          onPressed: _isLoading ? null : _fetchLogs,
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 20),
          tooltip: l10n.appCenterCopyLog,
          onPressed: (_logs == null || _logs!.isEmpty) ? null : _copyLogs,
        ),
      ],
    );

    final content = _isLoading
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: context.colorScheme.error),
              ),
            ),
          )
        : (_logs == null || _logs!.trim().isEmpty)
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.appCenterLogsEmpty,
                style: TextStyle(color: context.colorScheme.outline),
              ),
            ),
          )
        : Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(VRadius.card),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _logs!,
                style: monoTextStyle(
                  fontSize: 11,
                  color: const Color(0xFFE2E8F0),
                ),
              ),
            ),
          );

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.appCenterLogsTitle(widget.deployment.name)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.appCenterRefresh,
              onPressed: _isLoading ? null : _fetchLogs,
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: l10n.appCenterCopyLog,
              onPressed: (_logs == null || _logs!.isEmpty) ? null : _copyLogs,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(padding: const EdgeInsets.all(16), child: content),
        ),
      );
    }

    return AlertDialog(
      title: header,
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: 520,
        ),
        child: SizedBox(width: double.maxFinite, child: content),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
