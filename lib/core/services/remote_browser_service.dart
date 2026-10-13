import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/agent_profile.dart';
import '../../data/models/remote_browser.dart';
import '../../infrastructure/acp/acp_workspace_files.dart';
import '../../infrastructure/sftp/sftp_client_service.dart';
import '../providers/server_provider.dart';
import '../providers/sftp_provider.dart';
import '../providers/storage_providers.dart';

final remoteBrowserFactoryProvider = Provider<RemoteBrowserFactory>(
  RemoteBrowserFactory.new,
);

/// UI supplies its draft/selection guard; connection ownership remains here.
class RemoteBrowserFactory {
  final Ref ref;
  RemoteBrowserFactory(this.ref);

  RemoteBrowserSource host({
    required String initialPath,
    bool Function()? isCurrent,
  }) {
    final server = ref.read(activeServerProvider);
    if (server == null || !ref.read(serverConnectionProvider).isConnected) {
      throw StateError('REMOTE_BROWSER_DISCONNECTED');
    }
    final manager = ref.read(sshClientManagerProvider);
    final client = manager.getClient(server.id);
    if (client == null || client.isClosed) {
      throw StateError('REMOTE_BROWSER_DISCONNECTED');
    }
    final operations = ref.read(sftpOperationsProvider);
    bool current() =>
        ref.mounted &&
        (isCurrent?.call() ?? true) &&
        ref.read(activeServerProvider)?.connectionKey == server.connectionKey &&
        ref.read(serverConnectionProvider).isConnected &&
        !client.isClosed &&
        identical(manager.getClient(server.id), client) &&
        identical(ref.read(sftpOperationsProvider), operations);
    return sftpRemoteBrowser(
      operations: operations,
      targetKey: '${server.connectionKey}',
      label: server.name,
      initialPath: initialPath,
      isCurrent: current,
      createRequestOperations: () => SftpClientService(client),
    );
  }

  Future<RemoteBrowserSource> agent({
    required AgentProfile profile,
    required bool Function() isCurrent,
    String? initialPath,
  }) async {
    final server = ref.read(activeServerProvider);
    final manager = ref.read(sshClientManagerProvider);
    final client = manager.getClient(profile.serverId);
    if (server == null ||
        server.id != profile.serverId ||
        client == null ||
        !ref.read(serverConnectionProvider).isConnected) {
      throw StateError('REMOTE_BROWSER_DISCONNECTED');
    }
    return agentRemoteBrowser(
      client: client,
      profile: profile,
      targetKey:
          '${server.connectionKey}::${profile.id}::${profile.executionTarget}::'
          '${profile.containerBinding}::${profile.containerReference}::${profile.containerUser}',
      initialPath: initialPath,
      isCurrent: () =>
          ref.mounted &&
          isCurrent() &&
          ref.read(activeServerProvider)?.connectionKey ==
              server.connectionKey &&
          ref.read(serverConnectionProvider).isConnected &&
          identical(manager.getClient(profile.serverId), client),
    );
  }
}

RemoteBrowserEntry remoteBrowserEntryFromSftp(SftpFileItem item) =>
    RemoteBrowserEntry(
      id: item.path,
      name: item.name,
      isDirectory: item.isDirectory,
      canEnter: item.isDirectory && item.linkTargetErrorCode == null,
      sizeBytes: item.sizeBytes,
      modifiedEpoch: item.modifiedEpoch,
      isSymbolicLink: item.isSymbolicLink,
      linkTargetErrorCode: item.linkTargetErrorCode,
      mimeType: AcpWorkspaceFiles.mimeType(item.name),
    );

/// Adapts existing SFTP operations without taking ownership of the shared service.
RemoteBrowserSource sftpRemoteBrowser({
  required SftpOperations operations,
  required String targetKey,
  required String label,
  required String initialPath,
  required bool Function() isCurrent,
  SftpClientService Function()? createRequestOperations,
}) => RemoteBrowserSource(
  targetKey: targetKey,
  label: label,
  rootPath: '/',
  initialPath: initialPath,
  isCurrent: isCurrent,
  list: (path, cancelled) async* {
    final owned = createRequestOperations?.call();
    final request = owned ?? operations;
    var finished = false;
    unawaited(
      cancelled.then((_) {
        if (!finished) owned?.dispose();
      }),
    );
    try {
      yield (await request.listFiles(path))
          .where((item) => item.name != '.' && item.name != '..')
          .map(remoteBrowserEntryFromSftp)
          .toList();
    } finally {
      finished = true;
      owned?.dispose();
    }
  },
);

/// Owns file channels only; opening it never creates an ACP conversation.
Future<RemoteBrowserSource> agentRemoteBrowser({
  required SSHClient client,
  required AgentProfile profile,
  required String targetKey,
  required bool Function() isCurrent,
  String? initialPath,
}) async {
  final files = AcpWorkspaceFiles(client, profile);
  try {
    if (!isCurrent() || client.isClosed) {
      throw StateError('REMOTE_BROWSER_TARGET_CHANGED');
    }
    final initial = initialPath == null || !initialPath.startsWith('/')
        ? await files.defaultDirectory()
        : AcpWorkspaceFiles.normalize(initialPath);
    if (!isCurrent() || client.isClosed) {
      throw StateError('REMOTE_BROWSER_TARGET_CHANGED');
    }
    return RemoteBrowserSource(
      targetKey: targetKey,
      label: profile.name,
      rootPath: '/',
      initialPath: initial,
      isCurrent: () => !client.isClosed && isCurrent(),
      list: (path, cancelled) async* {
        final request = AcpWorkspaceFiles(client, profile);
        var finished = false;
        unawaited(
          cancelled.then((_) {
            if (!finished) request.close();
          }),
        );
        try {
          yield (await request.list(
            path,
          )).map(remoteBrowserEntryFromSftp).toList();
        } finally {
          finished = true;
          request.close();
        }
      },
      preview: (entry, limit) => files.read(entry.id, limit),
      dispose: files.close,
    );
  } catch (_) {
    files.close();
    rethrow;
  }
}

bool remoteBrowserDirectoryMissing(Object error) =>
    (error is SftpStatusError && error.code == SftpStatusCode.noSuchFile) ||
    (error is StateError && error.message == 'ACP_DIRECTORY_NOT_FOUND');
