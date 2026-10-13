import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/application_center_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/application_center.dart';
import 'app_center_error_resolver.dart';

class AppAccessInfoDialog extends ConsumerStatefulWidget {
  final ApplicationDeployment deployment;

  const AppAccessInfoDialog({
    super.key,
    required this.deployment,
  });

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
          builder: (_) => AppAccessInfoDialog(deployment: deployment),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (_) => AppAccessInfoDialog(deployment: deployment),
    );
  }

  @override
  ConsumerState<AppAccessInfoDialog> createState() =>
      _AppAccessInfoDialogState();
}

class _AppAccessInfoDialogState extends ConsumerState<AppAccessInfoDialog> {
  bool _isLoading = false;
  ApplicationAccessInfo? _info;
  String? _errorMessage;
  late final TextEditingController _hostCtrl;
  Object? _capturedServerKey;

  @override
  void initState() {
    super.initState();
    final activeServer = ref.read(activeServerProvider);
    _capturedServerKey = activeServer?.connectionKey;
    var initialHost = activeServer?.host ?? '';
    if (initialHost.isEmpty || initialHost == '0.0.0.0') {
      initialHost = 'localhost';
    }
    _hostCtrl = TextEditingController(text: initialHost);
    _loadDiagnostics();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDiagnostics() async {
    if (_isLoading) return;
    final currentKey = ref.read(activeServerProvider)?.connectionKey;
    if (currentKey != _capturedServerKey) return;
    final isConnected = ref.read(serverConnectionProvider).isConnected;
    if (!isConnected) {
      setState(() {
        _errorMessage = context.l10n.appCenterErrorNotConnected;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(applicationCenterProvider.notifier);
      final info = await notifier.accessInfo(widget.deployment);
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == _capturedServerKey) {
        setState(() => _info = info);
      }
    } catch (e) {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == _capturedServerKey) {
        setState(() {
          _errorMessage = e is ApplicationCenterException
              ? resolveAppCenterErrorMessage(context, e.code, e.detail)
              : e.toString();
        });
      }
    } finally {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == _capturedServerKey) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openViaSsh() async {
    final currentKey = ref.read(activeServerProvider)?.connectionKey;
    if (currentKey != _capturedServerKey) return;
    final isConnected = ref.read(serverConnectionProvider).isConnected;
    if (!isConnected) return;
    try {
      await ref
          .read(applicationCenterProvider.notifier)
          .openApplication(widget.deployment);
    } catch (e) {
      if (mounted) {
        final msg = e is ApplicationCenterException
            ? resolveAppCenterErrorMessage(context, e.code, e.detail)
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: context.vDanger,
          ),
        );
      }
    }
  }

  Future<void> _openUrl(String urlStr) async {
    final currentKey = ref.read(activeServerProvider)?.connectionKey;
    if (currentKey != _capturedServerKey) return;
    final isConnected = ref.read(serverConnectionProvider).isConnected;
    if (!isConnected) return;
    final uri = Uri.tryParse(urlStr);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.appCenterErrorConfigInvalid),
          backgroundColor: context.vDanger,
        ),
      );
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.appCenterErrorOpenFailed),
              backgroundColor: context.vDanger,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.appCenterErrorOpenFailed),
            backgroundColor: context.vDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;

    final activeServer = ref.watch(activeServerProvider);
    final isTargetChanged = activeServer?.connectionKey != _capturedServerKey;

    final content = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header info
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.deployment.name,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 14),
                label: Text(context.appCenterRecheckLabel),
                onPressed: (_isLoading || isTargetChanged) ? null : _loadDiagnostics,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Target changed banner
          if (isTargetChanged) ...[
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.vWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.vWarning.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.vWarning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.appCenterErrorTargetChanged,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.vWarning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Error banner if any
          if (_errorMessage != null) ...[
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.vDanger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.vDanger.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: context.vDanger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(fontSize: 12, color: context.vDanger),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_info != null) ...[
            // Probe Status Card
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            switch (_info!.probeStatus) {
                              ApplicationAccessProbeStatus.reachable =>
                                Icons.check_circle_outline,
                              ApplicationAccessProbeStatus.unavailable =>
                                Icons.warning_amber_rounded,
                              ApplicationAccessProbeStatus.failed =>
                                Icons.error_outline,
                              ApplicationAccessProbeStatus.notApplicable =>
                                Icons.info_outline,
                            },
                            size: 16,
                            color: switch (_info!.probeStatus) {
                              ApplicationAccessProbeStatus.reachable =>
                                context.vSuccess,
                              ApplicationAccessProbeStatus.unavailable =>
                                context.vWarning,
                              ApplicationAccessProbeStatus.failed =>
                                context.vDanger,
                              ApplicationAccessProbeStatus.notApplicable =>
                                context.colorScheme.outline,
                            },
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${context.appCenterProbeLabel}: ${_info!.probeStatus.name.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: switch (_info!.probeStatus) {
                                ApplicationAccessProbeStatus.reachable =>
                                  context.vSuccess,
                                ApplicationAccessProbeStatus.unavailable =>
                                  context.vWarning,
                                ApplicationAccessProbeStatus.failed =>
                                  context.vDanger,
                                ApplicationAccessProbeStatus.notApplicable =>
                                  context.colorScheme.outline,
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_info!.httpStatus != null)
                        Text(
                          'HTTP ${_info!.httpStatus}',
                          style: monoTextStyle(fontSize: 12),
                        ),
                      if (_info!.probeExitCode != null)
                        Text(
                          'Exit ${_info!.probeExitCode}',
                          style: monoTextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${context.appCenterCheckedLabel}: ${_info!.checkedAt.toLocal().toString().split('.').first}',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Access Channels
            Text(
              context.appCenterAccessEndpointsLabel,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // 1. SSH Tunneled Access
            if (_info!.sshEndpoint != null) ...[
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(VRadius.card),
                  border: Border.all(
                    color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isVeryNarrow = constraints.maxWidth < 280;
                    final isTargetValid =
                        ref.watch(activeServerProvider)?.connectionKey ==
                            _capturedServerKey &&
                        ref.watch(serverConnectionProvider).isConnected;

                    final infoCol = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.appCenterSshPortForwardingLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            _info!.sshEndpoint.toString(),
                            style: monoTextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );

                    final openBtn = FilledButton(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: isTargetValid ? _openViaSsh : null,
                      child: Text(l10n.appCenterOpen),
                    );

                    if (isVeryNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.vpn_lock_outlined,
                                size: 16,
                                color: context.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: infoCol),
                            ],
                          ),
                          const SizedBox(height: 8),
                          openBtn,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Icon(
                          Icons.vpn_lock_outlined,
                          size: 16,
                          color: context.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: infoCol),
                        const SizedBox(width: 8),
                        openBtn,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            // 2. External Access Candidate
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.public,
                        size: 16,
                        color: context.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.appCenterExternalAccessCandidateLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _hostCtrl,
                    decoration: InputDecoration(
                      labelText: context.appCenterHostInputLabel,
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (ctx) {
                      final mgmtPort = _info!.managementPort;
                      final isPublicManagement = mgmtPort != null &&
                          mgmtPort.bindAddress != null &&
                          mgmtPort.bindAddress != '127.0.0.1' &&
                          mgmtPort.bindAddress != 'localhost';

                      if (!isPublicManagement) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            context.appCenterSshOnlyNoticeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colorScheme.outline,
                            ),
                          ),
                        );
                      }

                      final host = _hostCtrl.text.trim();
                      if (host.isEmpty || host == '0.0.0.0') {
                        return const SizedBox.shrink();
                      }
                      final baseUri = _info!.sshEndpoint ??
                          Uri(
                            scheme: 'http',
                            host: 'localhost',
                            port: mgmtPort.published,
                          );
                      final formattedHost =
                          (host.contains(':') && !host.startsWith('['))
                              ? '[$host]'
                              : host;
                      final scheme =
                          baseUri.scheme.isNotEmpty ? baseUri.scheme : 'http';
                      final port = mgmtPort.published;
                      final path = baseUri.path;
                      final query =
                          baseUri.hasQuery ? '?${baseUri.query}' : '';
                      final candidateUrl =
                          '$scheme://$formattedHost:$port$path$query';
                      final isTargetValid =
                          ref.watch(activeServerProvider)?.connectionKey ==
                              _capturedServerKey &&
                          ref.watch(serverConnectionProvider).isConnected;

                      return Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              candidateUrl,
                              style: monoTextStyle(fontSize: 11),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14),
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.appCenterCopyLog,
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: candidateUrl),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(context.l10n.appCenterLogsCopied),
                                ),
                              );
                            },
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: isTargetValid
                                ? () => _openUrl(candidateUrl)
                                : null,
                            child: Text(l10n.appCenterOpen),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.appCenterExternalAccessWarningLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Actual Port Bindings
            if (_info!.ports.isNotEmpty) ...[
              Text(
                l10n.appCenterPortMapping,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(VRadius.card),
                ),
                child: Column(
                  children: [
                    for (final port in _info!.ports)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Text(
                              port.service,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                '${port.bindAddress ?? "*"}:${port.published} → ${port.target}/${port.protocol}',
                                style: monoTextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Services health
            if (_info!.services.isNotEmpty) ...[
              Text(
                context.resolveSectionLabel('services'),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(VRadius.card),
                ),
                child: Column(
                  children: [
                    for (final svc in _info!.services)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Text(
                              svc.name,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${resolveServiceHealthLabel(context, svc.health)} (${svc.state})',
                              style: TextStyle(
                                fontSize: 11,
                                color: svc.health.toLowerCase() == 'healthy'
                                    ? context.vSuccess
                                    : svc.health.toLowerCase() == 'unhealthy'
                                        ? context.vDanger
                                        : context.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ] else if (_isLoading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ],
      ),
    );

    final actions = [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.confirm),
      ),
    ];

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.appCenterAccessInfoLabel),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: content,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(context.appCenterAccessInfoLabel),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: 560,
        ),
        child: SizedBox(width: double.maxFinite, child: content),
      ),
      actions: actions,
    );
  }
}
