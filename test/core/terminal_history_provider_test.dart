import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/core/utils/tmux_session_planner.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/services/configuration_backup_service.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

const _server = ServerProfile(
  id: 'fixture',
  name: 'Fixture',
  host: '192.0.2.1',
  username: 'dev',
);
const _second = ServerProfile(
  id: 'second',
  name: 'Other',
  host: '192.0.2.2',
  username: 'dev',
);

class _Active extends ActiveServerNotifier {
  _Active(this.initial);
  final ServerProfile initial;
  @override
  ServerProfile build() => initial;
  void select(ServerProfile next) => state = next;
}

class _Servers extends ServerListNotifier {
  @override
  List<ServerProfile> build() => [_server, _second];
}

class _Connection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'fixture',
  );
  void set(bool connected, String serverId) => state = ServerConnectionState(
    status: connected
        ? ConnectionStateEnum.connected
        : ConnectionStateEnum.disconnected,
    activeServerId: serverId,
  );
}

class _Storage extends LocalStorageService {
  _Storage(super.prefs);
  bool failSave = false;
  Completer<void>? saveGate;
  @override
  Future<void> saveTerminalHistory(
    String serverId,
    String targetKey,
    TerminalHistorySnapshot snapshot,
  ) async {
    await saveGate?.future;
    if (failSave) throw StateError('fixture save failure');
    await super.saveTerminalHistory(serverId, targetKey, snapshot);
  }
}

class _OptimisticPreferences implements SharedPreferences {
  final native = <String, Object>{};
  final cache = <String, Object>{};
  bool shouldThrow = false;
  bool shouldFail = false;
  @override
  Set<String> getKeys() => cache.keys.toSet();
  @override
  String? getString(String key) => cache[key] as String?;
  @override
  Future<bool> setString(String key, String value) async {
    cache[key] = value;
    if (shouldThrow) throw StateError('fixture platform error');
    if (shouldFail) return false;
    native[key] = value;
    return true;
  }

  @override
  Future<void> reload() async {
    cache
      ..clear()
      ..addAll(native);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Manager implements SSHClientManager {
  _Manager(this.clients);
  final Map<String, _Client> clients;
  @override
  SSHClient? getClient(String serverId) => clients[serverId];
  @override
  bool isConnected(String serverId) => clients[serverId]?.isClosed == false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements SSHClient {
  final remoteNames = <String>{};
  final commands = <String>[];
  final ptys = <_Session>[];
  bool closed = false;
  bool failQuery = false;
  bool failAttach = false;
  Completer<void>? checkGate;
  String? gatedName;
  @override
  bool get isClosed => closed;
  @override
  Future<Uint8List> run(
    String command, {
    bool runInPty = false,
    bool stdout = true,
    bool stderr = true,
    Map<String, String>? environment,
  }) async => Uint8List.fromList(utf8.encode('/usr/bin/tmux\n'));
  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    commands.add(command);
    if (pty == null) {
      if (failQuery) throw StateError('fixture offline query');
      if (command.contains('command -v tmux')) {
        return _Session.result('/usr/bin/tmux\n');
      }
      if (command.contains('has-session')) {
        final name = RegExp("-t '=?([^']+)'").firstMatch(command)!.group(1)!;
        if (gatedName == null || gatedName == name) await checkGate?.future;
        return remoteNames.contains(name)
            ? _Session.result('')
            : _Session.result('', error: "can't find session: $name", code: 1);
      }
      if (command.contains('list-sessions')) {
        return _Session.result(
          remoteNames.map((name) => '$name\t1730000000\t0\n').join(),
        );
      }
      throw StateError('Unexpected query: $command');
    }
    if (command.contains('new-session')) {
      final name = RegExp("-s '([^']+)'").firstMatch(command)!.group(1)!;
      if (!remoteNames.add(name)) throw StateError('Duplicate tmux create');
    }
    if (failAttach && command.contains('attach-session')) {
      throw StateError('fixture attach failure');
    }
    final session = _Session.live();
    ptys.add(session);
    return session;
  }

  @override
  Future<SSHSession> shell({
    SSHPtyConfig? pty = const SSHPtyConfig(),
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    commands.add('SHELL');
    final session = _Session.live();
    ptys.add(session);
    return session;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session implements SSHSession {
  _Session.live()
    : _out = StreamController<Uint8List>(),
      _err = StreamController<Uint8List>(),
      _done = Completer<void>();
  _Session.result(String output, {String error = '', int code = 0})
    : _out = StreamController<Uint8List>(),
      _err = StreamController<Uint8List>(),
      _done = Completer<void>() {
    _out.add(Uint8List.fromList(utf8.encode(output)));
    _err.add(Uint8List.fromList(utf8.encode(error)));
    exit = code;
    close();
  }
  final StreamController<Uint8List> _out;
  final StreamController<Uint8List> _err;
  final Completer<void> _done;
  final input = _Sink();
  int exit = 0;
  bool closed = false;
  @override
  int? get exitCode => exit;
  @override
  Stream<Uint8List> get stdout => _out.stream;
  @override
  Stream<Uint8List> get stderr => _err.stream;
  @override
  StreamSink<Uint8List> get stdin => input;
  @override
  SSHChannel get channel => _Channel(this);
  @override
  Future<void> get done => _done.future;
  @override
  void close() {
    if (closed) return;
    closed = true;
    unawaited(_out.close());
    unawaited(_err.close());
    _done.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Channel implements SSHChannel {
  _Channel(this.session);
  final _Session session;
  @override
  void destroy([Object? error, StackTrace? stack]) => session.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements StreamSink<Uint8List> {
  final bytes = <int>[];
  @override
  void add(Uint8List value) => bytes.addAll(value);
  @override
  void addError(Object error, [StackTrace? stack]) {}
  @override
  Future<void> addStream(Stream<Uint8List> stream) async {
    await for (final value in stream) {
      add(value);
    }
  }

  @override
  Future<void> close() async {}
  @override
  Future<void> get done async {}
}

class _Harness {
  _Harness(this.container, this.storage, this.client, this.manager);
  final ProviderContainer container;
  final _Storage storage;
  final _Client client;
  final _Manager manager;
  TerminalNotifier get notifier => container.read(terminalProvider.notifier);
  SshTerminalState get state => container.read(terminalProvider);
  Future<void> drain() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  static Future<_Harness> create({
    bool tmux = true,
    _Storage? storage,
    _Client? client,
  }) async {
    storage ??= _Storage(await SharedPreferences.getInstance());
    await storage.setUseTmuxForTerminal(tmux);
    client ??= _Client();
    final manager = _Manager({'fixture': client, 'second': _Client()});
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        activeServerProvider.overrideWith(() => _Active(_server)),
        serverListProvider.overrideWith(_Servers.new),
        serverConnectionProvider.overrideWith(_Connection.new),
        sshClientManagerProvider.overrideWithValue(manager),
      ],
    );
    addTearDown(container.dispose);
    return _Harness(container, storage, client, manager);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a replacement arriving during live rebind is applied after the stale attempt',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      await h.drain();
      final record = h.state.history.single;
      final connection =
          h.container.read(serverConnectionProvider.notifier) as _Connection;
      connection.set(false, _server.id);
      final delayed = _Client()
        ..remoteNames.add(record.remoteSessionName)
        ..checkGate = Completer<void>();
      h.manager.clients[_server.id] = delayed;
      connection.set(true, _server.id);
      await h.drain();
      connection.set(false, _server.id);
      final latest = _Client()..remoteNames.add(record.remoteSessionName);
      h.manager.clients[_server.id] = latest;
      connection.set(true, _server.id);
      delayed.checkGate!.complete();
      await h.drain();
      expect(h.state.activeTab!.bridge.sshClient, same(latest));
      expect(
        latest.commands.any((command) => command.contains('attach-session')),
        isTrue,
      );
      expect(
        latest.commands.any((command) => command.contains('new-session')),
        isFalse,
      );
    },
  );

  test(
    'a default ending during its disk write is not retained as the default',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      await h.drain();
      final record = h.state.history.single;
      h.storage.saveGate = Completer<void>();
      final selecting = expectLater(
        h.notifier.setDefaultHistory(record.id),
        throwsStateError,
      );
      await h.drain();
      h.client.remoteNames.remove(record.remoteSessionName);
      h.client.ptys.single.close();
      await h.drain();
      expect(h.state.historyStatuses[record.id], TerminalHistoryStatus.ended);
      h.storage.saveGate!.complete();
      await selecting;
      expect(h.state.defaultHistoryId, isNull);
      expect(
        h.storage
            .getTerminalHistory(
              _server.id,
              TerminalHistoryRecord.targetFor(_server),
            )
            .defaultRecordId,
        isNull,
      );
    },
  );

  test(
    'settings and portable configuration never initialize or export terminal histories',
    () async {
      final h = await _Harness.create();
      h.container.read(settingsProvider);
      expect(h.container.read(terminalSettingsProvider).useTmux, isTrue);
      h.container.read(terminalProvider);
      final backup = ConfigurationBackupService(
        h.storage,
      ).exportConfiguration();
      await h.drain();
      expect(h.client.commands, isEmpty);
      expect(backup.preferences['valhalla_terminal_use_tmux_v1'], isTrue);
      for (final key in [
        'valhalla_terminal_history_v1::fixture::target',
        'valhalla_terminal_legacy_target_v1::fixture',
      ]) {
        final payload = backup.toJson();
        payload['preferences'] = {...backup.preferences, key: '{}'};
        expect(
          () => ConfigurationBackupService.decode(jsonEncode(payload)),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'queued default selection rechecks an ended session before committing',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      await h.notifier.addNewTab();
      await h.drain();
      final first = h.state.history.first;
      final second = h.state.history.last;
      h.storage.saveGate = Completer<void>();
      final renaming = h.notifier.renameHistory(first.id, 'Name');
      final selecting = expectLater(
        h.notifier.setDefaultHistory(second.id),
        throwsStateError,
      );
      h.client.remoteNames.remove(second.remoteSessionName);
      await h.notifier.refreshHistory();
      expect(h.state.historyStatuses[second.id], TerminalHistoryStatus.ended);
      h.storage.saveGate!.complete();
      await Future.wait([renaming, selecting]);
      expect(h.state.defaultHistoryId, isNull);
    },
  );

  test(
    'legacy target failure does not leave an optimistic claim in cache',
    () async {
      for (final throwing in [false, true]) {
        final prefs = _OptimisticPreferences()
          ..shouldFail = !throwing
          ..shouldThrow = throwing;
        final storage = LocalStorageService(prefs);
        await expectLater(
          storage.claimLegacyTerminalTarget(
            _server.id,
            TerminalHistoryRecord.targetFor(_server),
          ),
          throwsA(anything),
        );
        expect(prefs.cache, isEmpty);
        prefs.shouldFail = false;
        prefs.shouldThrow = false;
        final changed = TerminalHistoryRecord.targetFor(
          _server.copyWith(host: '192.0.2.50'),
        );
        expect(
          await storage.claimLegacyTerminalTarget(_server.id, changed),
          isTrue,
        );
      }
    },
  );

  test(
    'failed metadata writes restore preference cache for false and thrown platform errors',
    () async {
      for (final throwing in [false, true]) {
        final prefs = _OptimisticPreferences();
        final storage = LocalStorageService(prefs);
        final target = TerminalHistoryRecord.targetFor(_server);
        await storage.saveTerminalHistory(
          _server.id,
          target,
          const TerminalHistorySnapshot(),
        );
        prefs.shouldFail = !throwing;
        prefs.shouldThrow = throwing;
        await expectLater(
          storage.saveTerminalHistory(
            _server.id,
            target,
            const TerminalHistorySnapshot(defaultRecordId: 'unsaved'),
          ),
          throwsA(anything),
        );
        expect(
          storage.getTerminalHistory(_server.id, target).defaultRecordId,
          isNull,
        );
        expect(prefs.cache, prefs.native);
      }
    },
  );

  test(
    'queued writes to two workspaces keep target-local title and default',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      await h.drain();
      final a = h.state.history.single;
      h.storage.saveGate = Completer<void>();
      final saveA = h.notifier.renameHistory(a.id, 'Target A');
      final defaultA = h.notifier.setDefaultHistory(a.id);
      final connection =
          h.container.read(serverConnectionProvider.notifier) as _Connection;
      final active = h.container.read(activeServerProvider.notifier) as _Active;
      connection.set(false, _server.id);
      active.select(_second);
      connection.set(true, _second.id);
      await h.notifier.ensureInitialized();
      final bId = h.state.activeTab!.id;
      h.storage.saveGate!.complete();
      await Future.wait([saveA, defaultA]);
      await h.drain();
      await h.notifier.renameHistory(bId, 'Target B');
      await h.notifier.setDefaultHistory(bId);
      final storedA = h.storage.getTerminalHistory(
        _server.id,
        TerminalHistoryRecord.targetFor(_server),
      );
      final storedB = h.storage.getTerminalHistory(
        _second.id,
        TerminalHistoryRecord.targetFor(_second),
      );
      expect(storedA.records.single.title, 'Target A');
      expect(storedA.defaultRecordId, a.id);
      expect(storedB.records.single.title, 'Target B');
      expect(storedB.defaultRecordId, bId);
      expect(h.state.history.single.title, 'Target B');
    },
  );

  test(
    'retrying an already-open failed history reuses its terminal and exact session',
    () async {
      final first = await _Harness.create();
      await first.notifier.ensureInitialized();
      await first.drain();
      final record = first.state.history.single;
      await first.notifier.setDefaultHistory(record.id);
      first.container.dispose();
      final h = await _Harness.create(
        storage: first.storage,
        client: first.client,
      );
      h.client.failAttach = true;
      await h.notifier.ensureInitialized();
      final terminal = h.state.activeTab!.terminal;
      expect(h.state.errorCode, 'TERMINAL_RESTORE_FAILED');
      h.client.failAttach = false;
      await h.notifier.restoreHistory(record.id);
      await h.drain();
      expect(h.state.tabs, hasLength(1));
      expect(h.state.activeTab!.terminal, same(terminal));
      expect(h.state.errorCode, isNull);
      expect(h.client.remoteNames, hasLength(1));
    },
  );

  test(
    'replacement transport retries a pending default probe without creating',
    () async {
      final first = await _Harness.create();
      await first.notifier.ensureInitialized();
      await first.drain();
      final record = first.state.history.single;
      await first.notifier.setDefaultHistory(record.id);
      first.container.dispose();
      final h = await _Harness.create(
        storage: first.storage,
        client: first.client,
      );
      h.client.checkGate = Completer<void>();
      final opening = h.notifier.ensureInitialized();
      await h.drain();
      final connection =
          h.container.read(serverConnectionProvider.notifier) as _Connection;
      connection.set(false, _server.id);
      final replacement = _Client()..remoteNames.add(record.remoteSessionName);
      h.manager.clients[_server.id] = replacement;
      connection.set(true, _server.id);
      h.client.checkGate!.complete();
      await opening;
      await h.drain();
      expect(h.state.activeTab!.id, record.id);
      expect(h.state.activeTab!.bridge.sshClient, same(replacement));
      expect(
        replacement.commands.any((command) => command.contains('new-session')),
        isFalse,
      );
    },
  );

  test('read-only observation does not allocate any terminal', () async {
    final h = await _Harness.create();
    expect(h.state.tabs, isEmpty);
    await h.drain();
    expect(h.client.commands, isEmpty);
    expect(h.state.isInitialized, isFalse);
  });

  test(
    'new tabs use unique scoped identities even after closing earlier tabs',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      await h.notifier.addNewTab('same');
      final old = h.state.tabs.last;
      h.notifier.closeTab(1);
      await h.notifier.addNewTab('same');
      await h.drain();
      expect(h.state.tabs.last.id, isNot(old.id));
      expect(h.state.tabs.last.terminal, isNot(same(old.terminal)));
      expect(h.client.remoteNames, hasLength(3));
      expect(
        h.client.remoteNames.every(
          (name) => name.contains(TerminalHistoryRecord.targetFor(_server)),
        ),
        isTrue,
      );
      expect(
        h.client.commands.any((command) => command.contains(' -A ')),
        isFalse,
      );
      expect(h.state.history, hasLength(3));
    },
  );

  test('explicit plus does not attach the selected default', () async {
    final h = await _Harness.create();
    await h.notifier.ensureInitialized();
    await h.drain();
    final first = h.state.history.single;
    await h.notifier.setDefaultHistory(first.id);
    await h.notifier.addNewTab();
    expect(h.state.activeTab!.id, isNot(first.id));
    expect(
      h.client.commands.where((cmd) => cmd.contains('attach-session')),
      isEmpty,
    );
  });

  test(
    'cold entry restores default while tmux creation switch is off',
    () async {
      final first = await _Harness.create();
      await first.notifier.ensureInitialized();
      await first.drain();
      final record = first.state.history.single;
      await first.notifier.setDefaultHistory(record.id);
      first.container.dispose();
      first.client.commands.clear();
      final h = await _Harness.create(
        tmux: false,
        storage: first.storage,
        client: first.client,
      );
      expect(h.state.tabs, isEmpty);
      await h.notifier.ensureInitialized();
      await h.drain();
      expect(h.state.activeTab!.id, record.id);
      expect(
        h.client.commands.any((cmd) => cmd.contains('attach-session')),
        isTrue,
      );
      expect(
        h.client.commands.any(
          (cmd) => cmd.contains('new-session') || cmd == 'SHELL',
        ),
        isFalse,
      );
    },
  );

  test('no default means a new terminal after app restart', () async {
    final first = await _Harness.create();
    await first.notifier.ensureInitialized();
    await first.drain();
    final id = first.state.activeTab!.id;
    first.container.dispose();
    final h = await _Harness.create(
      storage: first.storage,
      client: first.client,
    );
    await h.notifier.ensureInitialized();
    expect(h.state.activeTab!.id, isNot(id));
    expect(h.client.remoteNames, hasLength(2));
  });

  test(
    'confirmed missing default is cleared and replaced by a fresh terminal',
    () async {
      final first = await _Harness.create();
      await first.notifier.ensureInitialized();
      await first.drain();
      final record = first.state.history.single;
      await first.notifier.setDefaultHistory(record.id);
      first.container.dispose();
      first.client.remoteNames.clear();
      final h = await _Harness.create(
        storage: first.storage,
        client: first.client,
      );
      await h.notifier.ensureInitialized();
      await h.drain();
      expect(h.state.defaultHistoryId, isNull);
      expect(h.state.noticeCode, 'TERMINAL_DEFAULT_MISSING');
      expect(h.state.activeTab!.id, isNot(record.id));
      expect(h.state.historyStatuses[record.id], TerminalHistoryStatus.ended);
    },
  );

  test(
    'failed query preserves default and never silently creates replacement',
    () async {
      final first = await _Harness.create();
      await first.notifier.ensureInitialized();
      await first.drain();
      final id = first.state.history.single.id;
      await first.notifier.setDefaultHistory(id);
      first.container.dispose();
      first.client.failQuery = true;
      final h = await _Harness.create(
        storage: first.storage,
        client: first.client,
      );
      await h.notifier.ensureInitialized();
      expect(h.state.defaultHistoryId, id);
      expect(h.state.tabs, isEmpty);
      expect(h.client.remoteNames, hasLength(1));
      expect(h.state.errorCode, 'TERMINAL_START_FAILED');
    },
  );

  test(
    'concurrent restore clicks produce one tab and no new remote process',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      await h.drain();
      final record = h.state.history.single;
      await h.notifier.addNewTab();
      h.notifier.closeTab(0);
      h.client.checkGate = Completer<void>();
      final a = h.notifier.restoreHistory(record.id);
      final b = h.notifier.restoreHistory(record.id);
      await h.drain();
      h.client.checkGate!.complete();
      await Future.wait([a, b]);
      expect(h.state.tabs.where((tab) => tab.id == record.id), hasLength(1));
      expect(h.client.remoteNames, hasLength(2));
    },
  );

  test(
    'rename is atomic with first pending history save and survives restart',
    () async {
      final h = await _Harness.create();
      h.storage.saveGate = Completer<void>();
      await h.notifier.ensureInitialized();
      final id = h.state.activeTab!.id;
      final renaming = h.notifier.renameTab(id, '工作 👩‍💻');
      await h.drain();
      h.storage.saveGate!.complete();
      await renaming;
      await h.drain();
      expect(h.state.activeTab!.title, '工作 👩‍💻');
      expect(h.state.history.single.title, '工作 👩‍💻');
      expect(
        h.storage
            .getTerminalHistory(
              _server.id,
              TerminalHistoryRecord.targetFor(_server),
            )
            .records
            .single
            .title,
        '工作 👩‍💻',
      );
    },
  );

  test(
    'explicit plus wins while cold default existence check is pending',
    () async {
      final first = await _Harness.create();
      await first.notifier.ensureInitialized();
      await first.drain();
      final record = first.state.history.single;
      await first.notifier.setDefaultHistory(record.id);
      first.container.dispose();
      final h = await _Harness.create(
        storage: first.storage,
        client: first.client,
      );
      h.client.checkGate = Completer<void>();
      h.client.gatedName = record.remoteSessionName;
      final initial = h.notifier.ensureInitialized();
      await h.drain();
      await h.notifier.addNewTab('Explicit new');
      final newId = h.state.activeTab!.id;
      h.client.checkGate!.complete();
      await initial;
      expect(h.state.tabs, hasLength(1));
      expect(h.state.activeTab!.id, newId);
      expect(newId, isNot(record.id));
    },
  );

  test(
    'confirmed late termination clears default without creating a replacement',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      await h.drain();
      final record = h.state.history.single;
      await h.notifier.setDefaultHistory(record.id);
      h.client.remoteNames.remove(record.remoteSessionName);
      h.client.ptys.single.close();
      await h.drain();
      expect(h.state.defaultHistoryId, isNull);
      expect(h.state.historyStatuses[record.id], TerminalHistoryStatus.ended);
      expect(h.state.tabs, hasLength(1));
      expect(h.client.remoteNames, isEmpty);
    },
  );

  test(
    'an explicitly queued command cannot follow a changed selected tab',
    () async {
      final h = await _Harness.create(tmux: false);
      await h.notifier.ensureInitialized();
      await h.notifier.addNewTab();
      h.notifier.sendCommand('must-not-move');
      h.notifier.selectTab(0);
      await h.drain();
      expect(
        h.client.ptys.every((session) => session.input.bytes.isEmpty),
        isTrue,
      );
    },
  );

  test(
    'endpoint edits isolate history even when the server id is unchanged',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      await h.drain();
      final record = h.state.history.single;
      await h.notifier.setDefaultHistory(record.id);
      final connection =
          h.container.read(serverConnectionProvider.notifier) as _Connection;
      connection.set(false, _server.id);
      (h.container.read(activeServerProvider.notifier) as _Active).select(
        _server.copyWith(host: '192.0.2.3'),
      );
      expect(h.state.tabs, isEmpty);
      expect(h.state.history, isEmpty);
      expect(h.state.defaultHistoryId, isNull);
      expect(
        h.storage
            .getTerminalHistory(
              _server.id,
              TerminalHistoryRecord.targetFor(_server),
            )
            .defaultRecordId,
        record.id,
      );
    },
  );

  test(
    'storage rejects cross-target records and preserves corrupt data',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      await h.drain();
      final record = h.state.history.single;
      await expectLater(
        h.storage.saveTerminalHistory(
          _second.id,
          TerminalHistoryRecord.targetFor(_second),
          TerminalHistorySnapshot(records: [record]),
        ),
        throwsFormatException,
      );
      final prefs = await SharedPreferences.getInstance();
      final key =
          'valhalla_terminal_history_v1::${_server.id}::${TerminalHistoryRecord.targetFor(_server)}';
      await prefs.setString(key, '{broken');
      final restarted = await _Harness.create(
        storage: h.storage,
        client: h.client,
      );
      expect(restarted.state.errorCode, 'TERMINAL_HISTORY_LOAD_FAILED');
      await restarted.notifier.ensureInitialized();
      await restarted.drain();
      expect(prefs.getString(key), '{broken');
      expect(restarted.state.errorCode, 'TERMINAL_HISTORY_SAVE_FAILED');
    },
  );

  test('failed rename and default writes leave old values intact', () async {
    final h = await _Harness.create();
    await h.notifier.ensureInitialized();
    await h.drain();
    final record = h.state.history.single;
    h.storage.failSave = true;
    await expectLater(
      h.notifier.renameHistory(record.id, 'Changed'),
      throwsStateError,
    );
    await expectLater(
      h.notifier.setDefaultHistory(record.id),
      throwsStateError,
    );
    expect(h.state.activeTab!.title, record.title);
    expect(h.state.history.single.title, record.title);
    expect(h.state.defaultHistoryId, isNull);
  });

  test(
    'ordinary terminal uses runtime-only names and remains out of history',
    () async {
      final h = await _Harness.create(tmux: false);
      await h.notifier.ensureInitialized();
      final tab = h.state.activeTab!;
      await h.notifier.renameTab(tab.id, 'Temporary');
      expect(h.state.activeTab!.title, 'Temporary');
      expect(h.state.history, isEmpty);
      expect(h.client.commands, ['SHELL']);
    },
  );

  test(
    'workspace switching retains terminal buffers and isolates target history',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      await h.drain();
      final original = h.state.activeTab!;
      original.terminal.write('keep output');
      final connection =
          h.container.read(serverConnectionProvider.notifier) as _Connection;
      final active = h.container.read(activeServerProvider.notifier) as _Active;
      connection.set(false, _server.id);
      active.select(_second);
      connection.set(true, _second.id);
      await h.notifier.ensureInitialized();
      expect(h.state.tabs.any((tab) => tab.id == original.id), isFalse);
      connection.set(false, _second.id);
      active.select(_server);
      connection.set(true, _server.id);
      await h.drain();
      expect(h.state.activeTab!.terminal, same(original.terminal));
      expect(
        h.state.activeTab!.terminal.buffer.getText(),
        contains('keep output'),
      );
      expect(
        h.state.history.every((record) => record.serverId == _server.id),
        isTrue,
      );
    },
  );

  test(
    'discovery only offers current target UUIDs and explicit legacy records',
    () async {
      final h = await _Harness.create();
      final target = TerminalHistoryRecord.targetFor(_server);
      const id = 'ab64f471-7df7-49da-bfb4-b6c4499b80d4';
      h.client.remoteNames.addAll([
        TmuxSessionPlanner.sessionName(_server.id, '${target}_$id'),
        TmuxSessionPlanner.sessionName(_server.id, 'other_$id'),
        TmuxSessionPlanner.sessionName(_server.id, '0'),
        'personal-terminal',
      ]);
      await h.notifier.refreshHistory();
      expect(h.state.tabs, isEmpty);
      expect(h.state.history, hasLength(2));
      expect(h.state.history.every((record) => record.isLegacy), isTrue);
      expect(h.storage.getTerminalHistory(_server.id, target).records, isEmpty);
      await h.notifier.restoreHistory(id);
      await h.drain();
      expect(
        h.storage.getTerminalHistory(_server.id, target).records.single.id,
        id,
      );
    },
  );

  test(
    'metadata does not persist screen, commands or enter configuration export',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      h.state.activeTab!.terminal.write('secret output');
      h.notifier.sendCommand('private-command');
      await h.drain();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs
          .getKeys()
          .where((key) => key.startsWith('valhalla_terminal_history'))
          .map(prefs.getString)
          .join();
      expect(saved, isNot(contains('secret output')));
      expect(saved, isNot(contains('private-command')));
      expect(
        h.storage.exportConfigurationPreferences().keys.any(
          (key) => key.contains('history'),
        ),
        isFalse,
      );
      expect(
        utf8.decode(h.client.ptys.single.input.bytes),
        'private-command\n',
      );
    },
  );

  test(
    'title validation counts graphemes and rejects controls including edge newlines',
    () {
      expect(TerminalHistoryRecord.validateTitle(' 👩‍💻 '), '👩‍💻');
      expect(
        TerminalHistoryRecord.validateTitle(
          List.filled(64, '👩‍💻').join(),
        ).isNotEmpty,
        isTrue,
      );
      for (final value in [
        '',
        '  ',
        'x\n',
        'x\u0000y',
        List.filled(65, '👩‍💻').join(),
      ]) {
        expect(
          () => TerminalHistoryRecord.validateTitle(value),
          throwsFormatException,
        );
      }
    },
  );
}
