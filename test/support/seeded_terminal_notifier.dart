import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const terminalFixtureServer = ServerProfile(
  id: 'terminal-fixture',
  name: 'Terminal fixture',
  host: '192.0.2.10',
  username: 'dev',
);

/// Seed rendering fixtures through the real workspace lifecycle; toolbar actions
/// still exercise the production close/select implementation.
class SeededTerminalNotifier extends TerminalNotifier {
  SeededTerminalNotifier(this.initial);
  final SshTerminalState initial;
  @override
  SshTerminalState build() {
    final empty = super.build();
    updateShouldNotify(empty, initial);
    return initial;
  }
}

class _Storage implements LocalStorageService {
  @override
  TerminalHistorySnapshot getTerminalHistory(
    String serverId,
    String targetKey,
  ) => const TerminalHistorySnapshot();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Active extends ActiveServerNotifier {
  _Active(this.server);
  final ServerProfile server;
  @override
  ServerProfile build() => server;
}

class _Servers extends ServerListNotifier {
  _Servers(this.server);
  final ServerProfile server;
  @override
  List<ServerProfile> build() => [server];
}

class _Connection extends ServerConnectionNotifier {
  _Connection(this.server);
  final ServerProfile server;
  @override
  ServerConnectionState build() =>
      ServerConnectionState(activeServerId: server.id);
}

List<Override> terminalWorkspaceOverrides({
  ServerProfile server = terminalFixtureServer,
}) => [
  localStorageServiceProvider.overrideWithValue(_Storage()),
  activeServerProvider.overrideWith(() => _Active(server)),
  serverListProvider.overrideWith(() => _Servers(server)),
  serverConnectionProvider.overrideWith(() => _Connection(server)),
];
