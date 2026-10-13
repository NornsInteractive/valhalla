import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/application_center_provider.dart';
import '../../../core/providers/nas_sources_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/services/application_deployment_service.dart';
import '../../../data/models/application_center.dart';
import '../../../data/models/nas_source.dart';
import '../../../data/models/server_profile.dart';
import 'nas_source_dialog.dart';

/// Only the exact successful task may supply the new source's remote endpoint.
ApplicationDeployment? jellyfinDeploymentForTask(
  ApplicationTask? task,
  Iterable<ApplicationDeployment> deployments,
  ServerProfile server,
) {
  final key = ApplicationDeploymentService.serverKey(server);
  if (task == null ||
      task.stage != ApplicationTaskStage.succeeded ||
      task.serverKey != key ||
      task.serverId != server.id ||
      task.operation != ApplicationOperation.install) {
    return null;
  }
  return deployments
      .where(
        (deployment) =>
            deployment.id == task.deploymentId &&
            deployment.serverId == server.id &&
            deployment.serverKey == key &&
            deployment.sourceId == ApplicationSource.official.id &&
            deployment.appId == 'org.icewhale.jellyfin' &&
            deployment.status == 'running' &&
            deployment.endpoint != null,
      )
      .firstOrNull;
}

/// An unsaved source draft. The shared tunnel outlives an external setup browser.
class JellyfinSourceActions extends ConsumerStatefulWidget {
  const JellyfinSourceActions({
    super.key,
    required this.server,
    required this.endpoint,
    this.name = 'Jellyfin',
    this.showSetup = true,
    this.showSuccessSummary = true,
  });

  final ServerProfile server;
  final Uri endpoint;
  final String name;
  final bool showSetup;
  final bool showSuccessSummary;

  @override
  ConsumerState<JellyfinSourceActions> createState() =>
      _JellyfinSourceActionsState();
}

class _JellyfinSourceActionsState extends ConsumerState<JellyfinSourceActions> {
  late NasSource _draft;
  bool _opening = false;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createDraft();
  }

  void _createDraft() {
    _draft = NasSource(
      id: const Uuid().v4(),
      name: widget.name,
      type: NasSourceType.jellyfin,
      endpoint: widget.endpoint.toString(),
      sshServerId: widget.server.id,
    );
  }

  @override
  void didUpdateWidget(JellyfinSourceActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.server.connectionKey != oldWidget.server.connectionKey ||
        widget.endpoint != oldWidget.endpoint) {
      _createDraft();
      _error = null;
    }
  }

  bool _sameTarget() =>
      mounted &&
      ref.read(activeServerProvider)?.connectionKey ==
          widget.server.connectionKey &&
      ref.read(serverConnectionProvider).isConnected;

  bool _canAct() =>
      _sameTarget() && (ModalRoute.of(context)?.isCurrent ?? true);

  Future<void> _openSetup() async {
    if (!_canAct() || _opening || _adding) return;
    final draft = _draft;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final forwarded = await ref
          .read(applicationAccessServiceProvider)
          .forward(draft);
      if (!_canAct() || _draft.id != draft.id) return;
      final opened = await launchUrl(
        forwarded,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && _canAct() && _draft.id == draft.id) {
        setState(() => _error = context.l10n.appCenterErrorOpenFailed);
      }
    } catch (_) {
      if (_canAct() && _draft.id == draft.id) {
        setState(() => _error = context.l10n.appCenterErrorOpenFailed);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _addSource() async {
    if (!_canAct() || _opening || _adding) return;
    // A completed add must never be reopened as a blank-credential overwrite.
    if (ref
        .read(nasSourcesProvider)
        .sources
        .any((source) => source.id == _draft.id)) {
      _createDraft();
    }
    setState(() => _adding = true);
    try {
      await NasSourceDialog.show(context, initialDraft: _draft);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(activeServerProvider);
    ref.watch(serverConnectionProvider.select((state) => state.isConnected));
    final enabled = _sameTarget() && !_opening && !_adding;
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSuccessSummary) ...[
          Text(context.l10n.nasInstallSuccessDesc),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.showSetup)
              OutlinedButton.icon(
                style: buttonStyle,
                onPressed: enabled ? _openSetup : null,
                icon: _opening
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new),
                label: Text(context.l10n.appCenterOpen),
              ),
            FilledButton.icon(
              style: buttonStyle,
              onPressed: enabled ? _addSource : null,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.nasAddSource),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: context.colorScheme.error)),
        ],
      ],
    );
  }
}
