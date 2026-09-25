import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/nas_source.dart';
import '../../infrastructure/nas/nas_media_server_adapter.dart';
import '../../infrastructure/nas/nas_sftp_adapter.dart';
import '../../infrastructure/nas/nas_smb_adapter.dart';
import '../../infrastructure/nas/nas_webdav_adapter.dart';
import '../../infrastructure/nas/nas_ssh_tunnel_service.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';
import 'infrastructure_providers.dart';
import 'server_provider.dart';
import 'storage_providers.dart';

class NasSourcesState {
  final List<NasSource> sources;
  final String? selectedId;
  const NasSourcesState({this.sources = const [], this.selectedId});
  NasSource? get selected =>
      sources.where((s) => s.id == selectedId).firstOrNull;
}

final nasSourcesProvider =
    NotifierProvider<NasSourcesNotifier, NasSourcesState>(
      NasSourcesNotifier.new,
    );

class NasSourcesNotifier extends Notifier<NasSourcesState> {
  Future<void> _mutations = Future.value();
  Future<void> _mutate(Future<void> Function() action) {
    final next = _mutations.then((_) => action());
    _mutations = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  @override
  NasSourcesState build() {
    final storage = ref.watch(localStorageServiceProvider);
    final sources = storage.getNasSources();
    final selected = storage.getNasSelectedSourceId();
    return NasSourcesState(
      sources: sources,
      selectedId: sources.any((s) => s.id == selected)
          ? selected
          : sources.firstOrNull?.id,
    );
  }

  Future<void> select(String id) => _mutate(() => _select(id));
  Future<void> _select(String id) async {
    if (!state.sources.any((s) => s.id == id)) {
      throw ArgumentError('NAS_SOURCE_NOT_FOUND');
    }
    await ref.read(localStorageServiceProvider).saveNasSelectedSourceId(id);
    state = NasSourcesState(sources: state.sources, selectedId: id);
  }

  Future<void> save(
    NasSource source,
    NasCredentials credentials, {
    bool probe = true,
    bool keepEmptySecrets = false,
  }) => _mutate(
    () => _save(
      source,
      credentials,
      probe: probe,
      keepEmptySecrets: keepEmptySecrets,
    ),
  );

  Future<void> _save(
    NasSource source,
    NasCredentials credentials, {
    required bool probe,
    required bool keepEmptySecrets,
  }) async {
    if (source.id.isEmpty || source.name.trim().isEmpty) {
      throw const FormatException('NAS_SOURCE_NAME_REQUIRED');
    }
    if (source.type != NasSourceType.sftp) {
      final uri = Uri.tryParse(source.endpoint);
      final schemes = source.type == NasSourceType.smb
          ? ['smb']
          : ['http', 'https'];
      if (uri == null ||
          !schemes.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment) {
        throw const FormatException('NAS_INVALID_ENDPOINT');
      }
    }
    credentials = await _credentials(source, credentials, keepEmptySecrets);
    if (probe) await this.probe(source, credentials);
    if (source.type != NasSourceType.sftp) {
      await ref
          .read(secureStorageServiceProvider)
          .saveNasCredentials(source.id, credentials);
    }
    // A fresh snapshot also refreshes the adapter when only credentials changed.
    final saved = NasSource.fromJson(source.toJson());
    final sources = [...state.sources.where((s) => s.id != source.id), saved];
    await ref.read(localStorageServiceProvider).saveNasSources(sources);
    await ref
        .read(localStorageServiceProvider)
        .saveNasSelectedSourceId(source.id);
    state = NasSourcesState(sources: sources, selectedId: source.id);
  }

  Future<NasCredentials> _credentials(
    NasSource source,
    NasCredentials credentials,
    bool keepEmptySecrets,
  ) async {
    if (keepEmptySecrets &&
        source.type != NasSourceType.sftp &&
        state.sources.any((s) => s.id == source.id)) {
      final old = await ref
          .read(secureStorageServiceProvider)
          .getNasCredentials(source.id);
      credentials = NasCredentials(
        password: credentials.password.isEmpty
            ? old.password
            : credentials.password,
        token: credentials.token.isEmpty ? old.token : credentials.token,
        domain: credentials.domain,
      );
    }
    return credentials;
  }

  /// Tests connectivity without persisting or selecting a temporary source.
  Future<void> probe(
    NasSource source,
    NasCredentials credentials, {
    bool keepEmptySecrets = false,
  }) async {
    credentials = await _credentials(source, credentials, keepEmptySecrets);
    final ssh = ref.read(sshCommandExecutorProvider);
    final tunnel = NasSshTunnelService(ssh);
    NasSourceAdapter? adapter;
    try {
      adapter = _createAdapter(
        await _forwardSource(source, tunnel),
        credentials,
        ssh,
      );
      await adapter.probe();
    } finally {
      await adapter?.dispose();
      await tunnel.dispose();
    }
  }

  Future<void> remove(String id) => _mutate(() => _remove(id));
  Future<void> _remove(String id) async {
    final sources = state.sources.where((s) => s.id != id).toList();
    await ref.read(localStorageServiceProvider).saveNasSources(sources);
    await ref.read(secureStorageServiceProvider).deleteNasCredentials(id);
    final selected = state.selectedId == id
        ? sources.firstOrNull?.id
        : state.selectedId;
    if (selected != null) {
      await ref
          .read(localStorageServiceProvider)
          .saveNasSelectedSourceId(selected);
    }
    state = NasSourcesState(sources: sources, selectedId: selected);
  }

  Future<({String userId, NasCredentials credentials})> authenticate(
    NasSource source,
    String password,
  ) async {
    final tunnel = NasSshTunnelService(ref.read(sshCommandExecutorProvider));
    try {
      return await NasMediaServerAdapter.authenticate(
        await _forwardSource(source, tunnel),
        password,
      );
    } finally {
      await tunnel.dispose();
    }
  }
}

Future<NasSource> _forwardSource(
  NasSource source,
  NasSshTunnelService tunnel,
) async {
  if (source.sshServerId == null ||
      source.type == NasSourceType.sftp ||
      source.type == NasSourceType.smb) {
    return source;
  }
  final uri = await tunnel.forward(source);
  return NasSource(
    id: source.id,
    name: source.name,
    type: source.type,
    endpoint: uri.toString(),
    sshServerId: source.sshServerId,
    username: source.username,
    userId: source.userId,
    rootPath: source.rootPath,
    forwardedHost: Uri.parse(source.endpoint).authority,
  );
}

NasSourceAdapter _createAdapter(
  NasSource source,
  NasCredentials credentials,
  SshCommandExecutor ssh,
) => switch (source.type) {
  NasSourceType.sftp => NasSftpAdapter(source, ssh),
  NasSourceType.webdav => NasWebDavAdapter(source, credentials),
  NasSourceType.smb => NasSmbAdapter(source: source, credentials: credentials),
  NasSourceType.jellyfin ||
  NasSourceType.emby => NasMediaServerAdapter(source, credentials),
};

final nasSourceAdapterProvider = FutureProvider.family<NasSourceAdapter, String>(
  (ref, id) async {
    final source = ref.watch(
      nasSourcesProvider.select(
        (s) => s.sources.where((source) => source.id == id).firstOrNull,
      ),
    );
    if (source == null) throw StateError('NAS_SOURCE_NOT_FOUND');
    final ssh = ref.watch(sshCommandExecutorProvider);
    final tunnelServerId = source.sshServerId;
    if (tunnelServerId != null &&
        source.type != NasSourceType.sftp &&
        source.type != NasSourceType.smb) {
      // Initial authentication and reconnects publish connection state. Track
      // this source's actual client, not the currently selected server/status:
      // an early failed Future or a closed tunnel must not remain cached.
      ref.watch(
        serverConnectionProvider.select((_) {
          final client = ssh.getClient(tunnelServerId);
          return client?.isClosed == false ? client : null;
        }),
      );
    }
    final tunnel = NasSshTunnelService(ssh);
    NasSourceAdapter? adapter;
    ref.onDispose(() async {
      await adapter?.dispose();
      await tunnel.dispose();
    });
    final credentials = source.type == NasSourceType.sftp
        ? const NasCredentials()
        : await ref.read(secureStorageServiceProvider).getNasCredentials(id);
    try {
      adapter = _createAdapter(
        await _forwardSource(source, tunnel),
        credentials,
        ssh,
      );
      if (!ref.mounted) {
        await adapter.dispose();
        throw StateError('NAS_SOURCE_CLOSED');
      }
    } catch (_) {
      await tunnel.dispose();
      rethrow;
    }
    return adapter;
  },
);
