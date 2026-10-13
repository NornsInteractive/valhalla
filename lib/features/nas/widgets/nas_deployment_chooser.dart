import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/application_center_provider.dart';
import '../../../core/providers/nas_install_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/application_center.dart';
import '../../app_center/widgets/app_details_dialog.dart';
import 'nas_native_install_dialog.dart';
import 'nas_install_dialog.dart';

class NasDeploymentChooser extends ConsumerStatefulWidget {
  const NasDeploymentChooser({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const NasDeploymentChooser(),
  );

  @override
  ConsumerState<NasDeploymentChooser> createState() =>
      _NasDeploymentChooserState();
}

class _NasDeploymentChooserState extends ConsumerState<NasDeploymentChooser> {
  Object? _connectionKey;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connectionKey = ref.read(activeServerProvider)?.connectionKey;
  }

  bool _sameTarget() =>
      mounted &&
      _connectionKey != null &&
      ref.read(activeServerProvider)?.connectionKey == _connectionKey &&
      ref.read(serverConnectionProvider).isConnected;

  bool _canAct() =>
      _sameTarget() && (ModalRoute.of(context)?.isCurrent ?? true);

  Future<void> _openDocker() async {
    if (_busy || !_canAct()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var state = ref.read(applicationCenterProvider);
      bool officialEnabled(ApplicationCenterState value) => value.sources.any(
        (source) =>
            source.id == ApplicationSource.official.id &&
            source.url == ApplicationSource.official.url &&
            source.enabled,
      );
      CatalogApplication? entry(ApplicationCenterState value) => value.catalog
          .where(
            (app) =>
                app.sourceId == ApplicationSource.official.id &&
                app.id == 'org.icewhale.jellyfin',
          )
          .firstOrNull;
      if (!officialEnabled(state)) {
        setState(() => _error = context.l10n.nasDeployCatalogUnavailable);
        return;
      }
      var application = entry(state);
      if (application == null) {
        await ref
            .read(applicationCenterProvider.notifier)
            .refreshCatalog(sourceId: ApplicationSource.official.id);
        if (!_canAct()) return;
        state = ref.read(applicationCenterProvider);
        application = entry(state);
        if (!officialEnabled(state) ||
            state.sourceErrors.containsKey(ApplicationSource.official.id)) {
          application = null;
        }
      }
      if (application == null) {
        setState(() => _error = context.l10n.nasDeployCatalogUnavailable);
        return;
      }
      if (!mounted || !_canAct()) return;
      await AppDetailsDialog.show(context, application: application);
    } catch (_) {
      if (_canAct()) {
        setState(() => _error = context.l10n.nasDeployCatalogUnavailable);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openNative() async {
    if (_busy || !_canAct()) return;
    setState(() => _busy = true);
    try {
      await NasNativeInstallDialog.show(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLegacyTask() async {
    if (_busy || !_canAct()) return;
    setState(() => _busy = true);
    try {
      await NasInstallDialog.show(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(activeServerProvider);
    ref.watch(serverConnectionProvider.select((state) => state.isConnected));
    final enabled = _sameTarget() && !_busy;
    final l10n = context.l10n;
    final legacyTask = ref.watch(nasInstallTaskProvider).asData?.value;
    return AlertDialog(
      title: Text(l10n.nasInstallTitle),
      scrollable: true,
      content: SizedBox(
        width: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (server != null && server.connectionKey == _connectionKey) ...[
              Text(server.name, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
            ],
            if (!_sameTarget()) ...[
              Text(
                l10n.appCenterErrorNotConnected,
                style: TextStyle(color: context.colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            _option(
              icon: Icons.inventory_2_outlined,
              title: l10n.nasDeployDockerTitle,
              description: l10n.nasDeployDockerDesc,
              onPressed: enabled ? _openDocker : null,
            ),
            const SizedBox(height: 12),
            _option(
              icon: Icons.dns_outlined,
              title: l10n.nasNativeInstallTitle,
              description: l10n.nasDeployNativeDesc,
              onPressed: enabled ? _openNative : null,
            ),
            if (legacyTask != null &&
                legacyTask.request.serverId == server?.id) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: enabled ? _openLegacyTask : null,
                icon: const Icon(Icons.history),
                label: Text(l10n.nasInstallTaskTitle),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: context.colorScheme.error)),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: enabled ? _openDocker : null,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.appCenterRetry),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback? onPressed,
  }) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.all(16),
    ),
    onPressed: onPressed,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(description),
            ],
          ),
        ),
      ],
    ),
  );
}
