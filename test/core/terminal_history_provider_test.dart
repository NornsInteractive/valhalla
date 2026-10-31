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
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';

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
  final defaultNames = <String>{};

  /// 额外来源（`-L <name>` / `-S <path>`）下的会话名。
  final extraNames = <String, Set<String>>{};
  final commands = <String>[];
  final ptys = <_Session>[];

  /// 仅让这些 socket 的 `list-sessions` 查询失败，其它来源照常返回。
  ///
  /// 通过现有的来源路由解析 socket id，因此不需要重写整块假实现。
  final failingSocketIds = <String>{};
  bool closed = false;
  bool failQuery = false;
  bool failAttach = false;
  bool failKill = false;

  /// 按 socket id 追加到外部 `list-sessions` 输出末尾的原始行，用于模拟
  /// 「部分可解析」的畸形响应（必须恰好 6 个字段，避免被续行合并逻辑吞掉）。
  final Map<String, String> malformedLines = <String, String>{};
  Completer<void>? checkGate;
  String? gatedName;
  final Map<String, int> _sessionIds = <String, int>{};
  final Map<int, String> _namesById = <int, String>{};
  int _nextSessionId = 0;

  /// 查询某个会话名当前被分配的数字 session id。
  int? sessionIdFor(String name) => _sessionIds[name];

  /// 把会话名固定到指定的数字 session id（tmux 形式为 `$N`）。
  ///
  /// 替换传输时远端守护进程里的会话 id 不会改变，必须在解析数字目标之前
  /// 预先登记映射，否则 `$N` 无法再指向同一个远端会话。
  void seedSession(String name, int id) {
    _sessionIds[name] = id;
    _namesById[id] = name;
    if (id >= _nextSessionId) _nextSessionId = id + 1;
  }

  /// 继承另一个传输客户端的会话 id 映射。
  void adoptSessionsFrom(_Client source) {
    source._sessionIds.forEach(seedSession);
  }

  /// 为会话名分配稳定的数字 session id（tmux 形式为 `$N`）。
  int _idFor(String name) {
    final existing = _sessionIds[name];
    if (existing != null) return existing;
    final id = _nextSessionId++;
    _sessionIds[name] = id;
    _namesById[id] = name;
    return id;
  }

  /// 将 `-t` 的目标解析为会话名：支持 `=name` 与 `$N` 两种形式。
  String? _resolveName(String target) {
    var value = target;
    if (value.startsWith('=')) value = value.substring(1);
    if (value.startsWith(r'$')) {
      final id = int.tryParse(value.substring(1));
      return id == null ? null : _namesById[id];
    }
    return value;
  }

  String _label(String target) =>
      target.startsWith('=') ? target.substring(1) : target;

  /// 解析命令使用的 socket 来源；null 表示 App 专用 socket。
  String? _socketIdFor(String command) {
    final named = RegExp(r"-L '?([A-Za-z0-9_.-]+)'?").firstMatch(command);
    if (named != null) {
      final name = named.group(1)!;
      if (name == TmuxSessionPlanner.socketName) return TmuxSocketSource.app.id;
      if (name == 'default') return TmuxSocketSource.standard.id;
      return TmuxSocketSource.named(name).id;
    }
    final path = RegExp(r"-S '([^']*)'").firstMatch(command);
    if (path != null) return TmuxSocketSource.path(path.group(1)!).id;
    return null;
  }

  /// 该 socket 下的会话名集合。
  Set<String> _namesFor(String? socketId) {
    if (socketId == null || socketId == TmuxSocketSource.app.id) {
      return remoteNames;
    }
    if (socketId == TmuxSocketSource.standard.id) return defaultNames;
    return extraNames.putIfAbsent(socketId, () => <String>{});
  }

  /// 该 socket 的远端路径。
  ///
  /// 不同 socket 必须给出不同路径，否则同名会话在不同来源下会得到同一个
  /// 身份，远端真相就分不开了。
  String _socketPathFor(String? socketId) {
    if (socketId == null || socketId == TmuxSocketSource.app.id) {
      return '/tmp/tmux-fixture/valhalla';
    }
    if (socketId == TmuxSocketSource.standard.id) {
      return '/tmp/tmux-fixture/default';
    }
    if (socketId.startsWith('named:')) {
      return '/tmp/tmux-fixture/${socketId.substring('named:'.length)}';
    }
    return socketId.substring('path:'.length);
  }

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
        final target = RegExp("-t '([^']+)'").firstMatch(command)!.group(1)!;
        final name = _resolveName(target);
        final socketId = _socketIdFor(command);
        if (gatedName == null || gatedName == name) await checkGate?.future;
        if (name != null && _namesFor(socketId).contains(name)) {
          return _Session.result('');
        }
        return _Session.result(
          '',
          error: "can't find session: ${_label(target)}",
          code: 1,
        );
      }
      if (command.contains('display-message')) {
        final target = RegExp("-t '([^']+)'").firstMatch(command)!.group(1)!;
        final name = _resolveName(target);
        final socketId = _socketIdFor(command);
        if (gatedName == null || gatedName == name) await checkGate?.future;
        if (name != null && _namesFor(socketId).contains(name)) {
          final id = _idFor(name);
          return _Session.result(
            '\$$id${TmuxSessionPlanner.fieldSeparator}1730000000'
            '${TmuxSessionPlanner.fieldSeparator}12345'
            '${TmuxSessionPlanner.fieldSeparator}${_socketPathFor(socketId)}\n',
          );
        }
        return _Session.result(
          '',
          error: "can't find session: ${_label(target)}",
          code: 1,
        );
      }
      if (command.contains('list-sessions')) {
        final socketId = _socketIdFor(command);
        if (socketId != null && failingSocketIds.contains(socketId)) {
          throw StateError('fixture socket query failure');
        }
        final names = _namesFor(socketId);
        if (command.contains('#{session_id}')) {
          final malformed = malformedLines[socketId];
          return _Session.result(
            names
                    .map(
                      (name) =>
                          '\$${_idFor(name)}'
                          '${TmuxSessionPlanner.fieldSeparator}1730000000'
                          '${TmuxSessionPlanner.fieldSeparator}0'
                          '${TmuxSessionPlanner.fieldSeparator}12345'
                          '${TmuxSessionPlanner.fieldSeparator}'
                          '${_socketPathFor(socketId)}'
                          '${TmuxSessionPlanner.fieldSeparator}$name\n',
                    )
                    .join() +
                (malformed == null ? '' : '$malformed\n'),
          );
        }
        return _Session.result(
          names.map((name) => '$name\t1730000000\t0\n').join(),
        );
      }
      if (command.contains('kill-session')) {
        final target = RegExp("-t '([^']+)'").firstMatch(command)!.group(1)!;
        if (failKill) {
          return _Session.result('', error: 'fixture kill refused', code: 1);
        }
        final name = _resolveName(target);
        if (name == null) {
          return _Session.result(
            '',
            error: "can't find session: ${_label(target)}",
            code: 1,
          );
        }
        _namesFor(_socketIdFor(command)).remove(name);
        return _Session.result('');
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

/// 构造一个替换传输客户端：继承源客户端的会话 id 映射，并预置远端会话名。
///
/// 没有先前发现过程时，数字目标 `$N` 必须仍然指向同一个远端会话。
_Client _replacementClient(_Client source, List<String> names) {
  final client = _Client()..adoptSessionsFrom(source);
  for (final name in names) {
    client.remoteNames.add(name);
    final id = source.sessionIdFor(name);
    if (id != null) client.seedSession(name, id);
  }
  return client;
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
    bool? tmux = true,
    _Storage? storage,
    _Client? client,
  }) async {
    storage ??= _Storage(await SharedPreferences.getInstance());
    if (tmux != null) await storage.setUseTmuxForTerminal(tmux);
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
    'absent preference opens plain shells with no recoverable history',
    () async {
      final h = await _Harness.create(tmux: null);
      await h.notifier.ensureInitialized();
      await h.notifier.addNewTab();
      await h.drain();
      expect(h.container.read(terminalSettingsProvider).useTmux, isFalse);
      expect(h.state.tabs, hasLength(2));
      expect(
        h.state.tabs.map((tab) => tab.bridge.mode),
        everyElement(TerminalSessionMode.plain),
      );
      expect(h.state.history, isEmpty);
      expect(h.client.commands, ['SHELL', 'SHELL']);
      expect(h.client.remoteNames, isEmpty);
      final firstSession = h.client.ptys.first;
      h.notifier.closeTab(0);
      expect(firstSession.closed, isTrue);
    },
  );

  test(
    'automatic entry stays plain while manual creation honors tmux preference',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      await h.drain();
      final first = h.state.tabs.single;
      first.terminal.write('keep automatic output');
      expect(first.bridge.mode, TerminalSessionMode.plain);
      expect(h.client.commands, ['SHELL']);
      expect(h.client.remoteNames, isEmpty);
      expect(h.state.history, isEmpty);

      await h.notifier.ensureInitialized();
      expect(h.state.tabs.single, same(first));
      expect(h.client.commands, ['SHELL']);

      await h.notifier.addNewTab();
      await h.drain();
      final manual = h.state.tabs.last;
      expect(manual.bridge.mode, TerminalSessionMode.tmux);
      expect(h.state.history.single.id, manual.id);
      expect(h.state.tabs.first, same(first));
      expect(
        first.terminal.buffer.getText(),
        contains('keep automatic output'),
      );

      h.notifier.closeTab(1);
      await h.notifier.ensureInitialized();
      await h.drain();
      expect(h.state.tabs.single, same(first));
      expect(h.state.tabs.single.bridge.mode, TerminalSessionMode.plain);
      expect(h.state.history.single.id, manual.id);
      expect(h.client.remoteNames, {manual.bridge.activeTmuxSessionName});
      expect(h.client.commands.where((cmd) => cmd == 'SHELL'), hasLength(1));
    },
  );

  test(
    'automatic plain terminal stays plain on transport replacement with tmux enabled',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      final tab = h.state.activeTab!;
      tab.terminal.write('keep output across reconnect');
      final connection =
          h.container.read(serverConnectionProvider.notifier) as _Connection;
      connection.set(false, _server.id);
      final replacement = _Client();
      h.manager.clients[_server.id] = replacement;
      connection.set(true, _server.id);
      await h.drain();
      expect(h.state.activeTab!.id, tab.id);
      expect(h.state.activeTab!.terminal, same(tab.terminal));
      expect(
        tab.terminal.buffer.getText(),
        contains('keep output across reconnect'),
      );
      expect(h.state.activeTab!.bridge.mode, TerminalSessionMode.plain);
      expect(
        h.state.activeTab!.bridge.state,
        TerminalConnectionState.connected,
      );
      expect(replacement.commands, ['SHELL']);
      expect(replacement.remoteNames, isEmpty);
      expect(h.state.history, isEmpty);
    },
  );

  test(
    'new-terminal mode changes only subsequent tabs without losing output',
    () async {
      final h = await _Harness.create(tmux: null);
      await h.notifier.ensureInitialized();
      final first = h.state.tabs.single;
      first.terminal.write('keep this plain terminal');
      await h.container
          .read(terminalSettingsProvider.notifier)
          .setUseTmux(true);
      await h.notifier.addNewTab();
      await h.drain();
      final tmux = h.state.tabs.last;
      expect(tmux.bridge.mode, TerminalSessionMode.tmux);
      expect(h.state.history.single.id, tmux.id);
      expect(h.state.tabs.first, same(first));
      expect(
        first.terminal.buffer.getText(),
        contains('keep this plain terminal'),
      );
      await h.container
          .read(terminalSettingsProvider.notifier)
          .setUseTmux(false);
      await h.notifier.addNewTab();
      await h.drain();
      expect(h.state.tabs.last.bridge.mode, TerminalSessionMode.plain);
      expect(h.state.history.single.id, tmux.id);
      expect(h.client.remoteNames, {tmux.bridge.activeTmuxSessionName});
    },
  );

  test(
    'local history deletion hides the record, clears default and keeps output',
    () async {
      final h = await _Harness.create();
      await h.notifier.addNewTab();
      await h.drain();
      final record = h.state.history.single;
      h.state.activeTab!.terminal.write('kept output');
      await h.notifier.setDefaultHistory(record.id);
      final commands = h.client.commands.length;
      await h.notifier.deleteHistory(
        record.id,
        expectedTargetKey: record.targetKey,
      );
      expect(h.client.commands.length, commands);
      expect(h.state.history.single.id, record.id);
      expect(h.state.hiddenRecordIds, contains(record.id));
      expect(h.state.defaultHistoryId, isNull);
      expect(h.state.tabs, hasLength(1));
      expect(
        h.state.activeTab!.terminal.buffer.getText(),
        contains('kept output'),
      );
      expect(h.client.remoteNames, contains(record.remoteSessionName));
      await h.notifier.refreshHistory();
      expect(h.state.history.single.id, record.id);
      expect(h.state.hiddenRecordIds, contains(record.id));
      final stored = h.storage.getTerminalHistory(_server.id, record.targetKey);
      expect(stored.records.single.id, record.id);
      expect(stored.forgottenSessionNames, isEmpty);
      expect(stored.hiddenRecordIds, contains(record.id));
      expect(stored.defaultRecordId, isNull);
    },
  );

  test(
    'confirmed termination targets only the exact dedicated-socket session',
    () async {
      final h = await _Harness.create();
      await h.notifier.addNewTab();
      await h.drain();
      final record = h.state.history.single;
      h.state.activeTab!.terminal.write('kept output');
      h.client.remoteNames.add('unrelated');
      await h.notifier.deleteHistory(
        record.id,
        terminateRemote: true,
        expectedTargetKey: record.targetKey,
      );
      final kill = h.client.commands.singleWhere(
        (c) => c.contains('kill-session'),
      );
      expect(kill, contains('-L valhalla'));
      expect(kill, contains("-t '${record.identity!.sessionId}'"));
      expect(h.client.remoteNames, {'unrelated'});
      expect(h.state.history.single.id, record.id);
      expect(h.state.historyStatuses[record.id], TerminalHistoryStatus.ended);
      expect(
        h.state.activeTab!.terminal.buffer.getText(),
        contains('kept output'),
      );
      expect(h.state.hiddenRecordIds, isNot(contains(record.id)));
    },
  );

  test('failed termination preserves history and live tab', () async {
    final h = await _Harness.create();
    await h.notifier.addNewTab();
    await h.drain();
    final record = h.state.history.single;
    h.client.failKill = true;
    await expectLater(
      h.notifier.deleteHistory(
        record.id,
        terminateRemote: true,
        expectedTargetKey: record.targetKey,
      ),
      throwsA(anything),
    );
    expect(h.state.history.single.id, record.id);
    expect(h.state.tabs, hasLength(1));
    expect(h.client.remoteNames, contains(record.remoteSessionName));
  });

  test('stale dialog target cannot delete or terminate history', () async {
    final h = await _Harness.create();
    await h.notifier.addNewTab();
    await h.drain();
    final record = h.state.history.single;
    final commands = h.client.commands.length;
    await expectLater(
      h.notifier.deleteHistory(
        record.id,
        terminateRemote: true,
        expectedTargetKey: 'not-current',
      ),
      throwsA(isA<StateError>()),
    );
    expect(h.state.history.single.id, record.id);
    expect(h.client.commands.length, commands);
  });

  test('server switch during existence query aborts before kill', () async {
    final h = await _Harness.create();
    await h.notifier.addNewTab();
    await h.drain();
    final record = h.state.history.single;
    h.client.checkGate = Completer<void>();
    final deleting = h.notifier.deleteHistory(
      record.id,
      terminateRemote: true,
      expectedTargetKey: record.targetKey,
    );
    final failure = expectLater(deleting, throwsA(isA<StateError>()));
    await h.drain();
    (h.container.read(activeServerProvider.notifier) as _Active).select(
      _second,
    );
    h.container.read(terminalProvider);
    h.client.checkGate!.complete();
    await failure;
    expect(h.client.commands.where((c) => c.contains('kill-session')), isEmpty);
    expect(
      h.storage
          .getTerminalHistory(_server.id, record.targetKey)
          .records
          .single
          .id,
      record.id,
    );
  });

  test(
    'failed local save does not hide history or suppress future refresh',
    () async {
      final h = await _Harness.create();
      await h.notifier.addNewTab();
      await h.drain();
      final record = h.state.history.single;
      h.storage.failSave = true;
      await expectLater(
        h.notifier.deleteHistory(
          record.id,
          expectedTargetKey: record.targetKey,
        ),
        throwsA(anything),
      );
      expect(h.state.history.single.id, record.id);
      expect(
        h.storage
            .getTerminalHistory(_server.id, record.targetKey)
            .forgottenSessionNames,
        isEmpty,
      );
    },
  );

  test(
    'a replacement arriving during live rebind is applied after the stale attempt',
    () async {
      final h = await _Harness.create();
      await h.notifier.addNewTab();
      await h.drain();
      final record = h.state.history.single;
      final connection =
          h.container.read(serverConnectionProvider.notifier) as _Connection;
      connection.set(false, _server.id);
      final delayed = _replacementClient(h.client, [record.remoteSessionName])
        ..checkGate = Completer<void>();
      h.manager.clients[_server.id] = delayed;
      connection.set(true, _server.id);
      await h.drain();
      connection.set(false, _server.id);
      final latest = _replacementClient(h.client, [record.remoteSessionName]);
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
      await h.notifier.addNewTab();
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
      await h.notifier.addNewTab();
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
      await h.notifier.addNewTab();
      await h.drain();
      final first = h.state.history.single;
      await h.notifier.setDefaultHistory(first.id);
      await h.notifier.addNewTab();
      await h.drain();
      final secondId = h.state.activeTab!.id;
      expect(secondId, isNot(first.id));
      h.storage.saveGate = Completer<void>();
      final saveA = h.notifier.renameHistory(secondId, 'Target A');
      final defaultA = h.notifier.setDefaultHistory(secondId);
      // 验证尚未完成就切换服务器：新默认被明确取消，旧默认保持不变。
      final cancelled = expectLater(
        defaultA,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'TERMINAL_HISTORY_TARGET_CHANGED',
          ),
        ),
      );
      final connection =
          h.container.read(serverConnectionProvider.notifier) as _Connection;
      final active = h.container.read(activeServerProvider.notifier) as _Active;
      connection.set(false, _server.id);
      active.select(_second);
      connection.set(true, _second.id);
      await h.notifier.addNewTab();
      final bId = h.state.activeTab!.id;
      h.storage.saveGate!.complete();
      await Future.wait([saveA, cancelled]);
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
      expect(
        storedA.records.firstWhere((record) => record.id == secondId).title,
        'Target A',
      );
      expect(storedA.defaultRecordId, first.id);
      expect(storedB.records.single.title, 'Target B');
      expect(storedB.defaultRecordId, bId);
      expect(storedB.defaultRecordId, isNot(first.id));
      expect(storedB.defaultRecordId, isNot(secondId));
      expect(h.state.history.single.title, 'Target B');
      expect(h.state.errorCode, isNull);
    },
  );

  test(
    'retrying an already-open failed history reuses its terminal and exact session',
    () async {
      final first = await _Harness.create();
      await first.notifier.addNewTab();
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
      await first.notifier.addNewTab();
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
      final replacement = _replacementClient(h.client, [
        record.remoteSessionName,
      ]);
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
      expect(h.client.remoteNames, hasLength(2));
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
      expect(h.state.history, hasLength(2));
    },
  );

  test('explicit plus does not attach the selected default', () async {
    final h = await _Harness.create();
    await h.notifier.addNewTab();
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
      await first.notifier.addNewTab();
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

  test(
    'history without a default still opens plain after app restart',
    () async {
      final first = await _Harness.create();
      await first.notifier.addNewTab();
      await first.drain();
      final record = first.state.history.single;
      first.container.dispose();
      first.client.commands.clear();
      final h = await _Harness.create(
        storage: first.storage,
        client: first.client,
      );
      await h.notifier.ensureInitialized();
      await h.drain();
      expect(h.state.activeTab!.id, isNot(record.id));
      expect(h.state.activeTab!.bridge.mode, TerminalSessionMode.plain);
      expect(h.client.remoteNames, {record.remoteSessionName});
      expect(h.state.history.single.id, record.id);
      expect(h.state.defaultHistoryId, isNull);
      expect(h.client.commands, ['SHELL']);
    },
  );

  test(
    'confirmed missing default is cleared and replaced by a fresh terminal',
    () async {
      final first = await _Harness.create();
      await first.notifier.addNewTab();
      await first.drain();
      final record = first.state.history.single;
      await first.notifier.setDefaultHistory(record.id);
      first.container.dispose();
      first.client.remoteNames.clear();
      first.client.commands.clear();
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
      expect(h.state.activeTab!.bridge.mode, TerminalSessionMode.plain);
      expect(h.client.remoteNames, isEmpty);
      expect(
        h.client.commands.any((cmd) => cmd.contains('new-session')),
        isFalse,
      );
    },
  );

  test(
    'failed query preserves default and never silently creates replacement',
    () async {
      final first = await _Harness.create();
      await first.notifier.addNewTab();
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
      await h.notifier.addNewTab();
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
      await h.notifier.addNewTab();
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
      await first.notifier.addNewTab();
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
      await h.notifier.addNewTab();
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
      await h.notifier.addNewTab();
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
      await h.notifier.addNewTab();
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
      final target = TerminalHistoryRecord.targetFor(_server);
      final v1Key = 'valhalla_terminal_history_v1::${_server.id}::$target';
      final v2Key = 'valhalla_terminal_history_v2::${_server.id}::$target';
      const legacy = '{"records":[]}';
      await prefs.setString(v1Key, legacy);
      await prefs.setString(v2Key, '{broken');
      final restarted = await _Harness.create(
        storage: h.storage,
        client: h.client,
      );
      expect(restarted.state.errorCode, 'TERMINAL_HISTORY_LOAD_FAILED');
      await restarted.notifier.ensureInitialized();
      await restarted.drain();
      expect(prefs.getString(v2Key), '{broken');
      expect(prefs.getString(v1Key), legacy);
      expect(restarted.state.errorCode, 'TERMINAL_HISTORY_LOAD_FAILED');
      await restarted.notifier.addNewTab();
      await restarted.drain();
      expect(prefs.getString(v2Key), '{broken');
      expect(prefs.getString(v1Key), legacy);
      expect(restarted.state.errorCode, 'TERMINAL_HISTORY_SAVE_FAILED');
    },
  );

  test('failed rename and default writes leave old values intact', () async {
    final h = await _Harness.create();
    await h.notifier.addNewTab();
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
      await h.notifier.addNewTab();
      await h.drain();
      final original = h.state.activeTab!;
      original.terminal.write('keep output');
      final connection =
          h.container.read(serverConnectionProvider.notifier) as _Connection;
      final active = h.container.read(activeServerProvider.notifier) as _Active;
      connection.set(false, _server.id);
      active.select(_second);
      connection.set(true, _second.id);
      await h.notifier.addNewTab();
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
      expect(h.state.history, isNotEmpty);
      expect(
        h.state.history.every((record) => record.serverId == _server.id),
        isTrue,
      );
    },
  );

  test(
    'discovery lists every current session and marks foreign ones external',
    () async {
      final h = await _Harness.create();
      final target = TerminalHistoryRecord.targetFor(_server);
      const id = 'ab64f471-7df7-49da-bfb4-b6c4499b80d4';
      final ownName = TmuxSessionPlanner.sessionName(
        _server.id,
        '${target}_$id',
      );
      h.client.remoteNames.addAll([
        ownName,
        TmuxSessionPlanner.sessionName(_server.id, 'other_$id'),
        TmuxSessionPlanner.sessionName(_server.id, '0'),
        'personal-terminal',
      ]);
      h.client.defaultNames.addAll(['user-work', 'user-play']);
      await h.notifier.refreshHistory();
      expect(h.state.tabs, isEmpty);
      expect(
        h.client.commands.any((command) => command.contains('new-session')),
        isFalse,
      );
      expect(h.state.history, hasLength(6));
      expect(h.state.history.every((record) => record.isLegacy), isTrue);
      expect(h.storage.getTerminalHistory(_server.id, target).records, isEmpty);

      final own = h.state.history.where((record) => record.id == id).single;
      expect(own.remoteSessionName, ownName);
      expect(own.isExternal, isFalse);
      expect(own.socket.id, TmuxSocketSource.app.id);

      final foreign = h.state.history.where((record) => record.isExternal);
      expect(foreign, hasLength(5));
      expect(
        foreign.map((record) => record.remoteSessionName),
        containsAll([
          TmuxSessionPlanner.sessionName(_server.id, 'other_$id'),
          TmuxSessionPlanner.sessionName(_server.id, '0'),
          'personal-terminal',
          'user-work',
          'user-play',
        ]),
      );
      expect(
        foreign
            .where((record) => record.remoteSessionName == 'user-work')
            .single
            .socket
            .id,
        TmuxSocketSource.standard.id,
      );
      expect(
        foreign
            .where((record) => record.remoteSessionName == 'personal-terminal')
            .single
            .socket
            .id,
        TmuxSocketSource.app.id,
      );

      await h.notifier.restoreHistory(id);
      await h.drain();
      expect(
        h.storage.getTerminalHistory(_server.id, target).records.single.id,
        id,
      );
    },
  );

  test(
    'a failing default socket keeps the app session and the saved default',
    () async {
      final h = await _Harness.create();
      h.client.defaultNames.add('user-work');
      await h.notifier.addNewTab();
      await h.drain();
      await h.notifier.refreshHistory();
      await h.drain();
      final appRecord = h.state.history.firstWhere(
        (record) => record.socket.id == TmuxSocketSource.app.id,
      );
      final external = h.state.history.firstWhere(
        (record) => record.socket.id == TmuxSocketSource.standard.id,
      );
      await h.notifier.setDefaultHistory(external.id);
      await h.drain();
      expect(h.state.defaultHistoryId, external.id);
      expect(
        h.state.historyStatuses[external.id],
        TerminalHistoryStatus.available,
      );

      // 只有默认 socket 的会话列表查询失败，App 专用 socket 照常返回。
      h.client.failingSocketIds.add(TmuxSocketSource.standard.id);
      final commandsBefore = h.client.commands.length;
      await h.notifier.refreshHistory();
      await h.drain();

      expect(h.state.socketErrors.keys, {TmuxSocketSource.standard.id});
      expect(
        h.state.socketErrors[TmuxSocketSource.standard.id],
        'TMUX_HISTORY_QUERY_FAILED',
      );
      expect(h.state.history.any((record) => record.id == external.id), isTrue);
      expect(
        h.state.historyStatuses[external.id],
        TerminalHistoryStatus.unknown,
      );
      expect(h.state.defaultHistoryId, external.id);
      expect(h.state.historyStatuses[appRecord.id], TerminalHistoryStatus.open);
      final added = h.client.commands.skip(commandsBefore);
      expect(added.any((command) => command.contains('new-session')), isFalse);
      expect(added.any((command) => command.contains('kill-session')), isFalse);
      expect(
        h.storage
            .getTerminalHistory(
              _server.id,
              TerminalHistoryRecord.targetFor(_server),
            )
            .defaultRecordId,
        external.id,
      );
    },
  );

  test(
    'metadata does not persist screen, commands or enter configuration export',
    () async {
      final h = await _Harness.create();
      await h.notifier.addNewTab();
      h.state.activeTab!.terminal.write('secret output');
      h.notifier.sendCommand('private-command');
      await h.drain();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs
          .getKeys()
          .where((key) => key.startsWith('valhalla_terminal_history'))
          .map(prefs.getString)
          .join();
      expect(h.state.history, isNotEmpty);
      expect(saved, isNotEmpty);
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
    'a default socket session stays distinct from an app session of the same name',
    () async {
      final h = await _Harness.create();
      final target = TerminalHistoryRecord.targetFor(_server);
      const id = 'ab64f471-7df7-49da-bfb4-b6c4499b80d4';
      final sharedName = TmuxSessionPlanner.sessionName(
        _server.id,
        '${target}_$id',
      );
      h.client.remoteNames.add(sharedName);
      h.client.defaultNames.add(sharedName);
      await h.notifier.refreshHistory();
      expect(h.state.history, hasLength(2));
      final own = h.state.history
          .where((record) => record.socket.id == TmuxSocketSource.app.id)
          .single;
      final external = h.state.history
          .where((record) => record.socket.id == TmuxSocketSource.standard.id)
          .single;
      expect(own.remoteSessionName, sharedName);
      expect(external.remoteSessionName, sharedName);
      expect(own.id, isNot(external.id));
      expect(own.isExternal, isFalse);
      expect(external.isExternal, isTrue);
      expect(own.identity, isNotNull);
      expect(external.identity, isNotNull);
      expect(own.identity!.key, isNot(external.identity!.key));
      expect(own.identity!.socketPath, '/tmp/tmux-fixture/valhalla');
      expect(external.identity!.socketPath, '/tmp/tmux-fixture/default');
    },
  );

  test(
    'an external default keeps its identity and source across a restart',
    () async {
      final h = await _Harness.create();
      final target = TerminalHistoryRecord.targetFor(_server);
      h.client.defaultNames.add('user-work');
      await h.notifier.refreshHistory();
      final record = h.state.history.single;
      expect(record.socket.id, TmuxSocketSource.standard.id);
      expect(record.isExternal, isTrue);
      expect(record.identity, isNotNull);
      await h.notifier.setDefaultHistory(record.id);
      final stored = h.storage.getTerminalHistory(_server.id, target);
      expect(stored.defaultRecordId, record.id);
      final persisted = stored.records.single;
      expect(persisted.socket.id, TmuxSocketSource.standard.id);
      expect(persisted.identity!.key, record.identity!.key);
      expect(persisted.remoteSessionName, 'user-work');
      h.container.dispose();
      h.client.commands.clear();
      final restarted = await _Harness.create(
        storage: h.storage,
        client: h.client,
      );
      await restarted.notifier.ensureInitialized();
      await restarted.drain();
      expect(restarted.state.activeTab!.id, record.id);
      final attach = restarted.client.commands.singleWhere(
        (command) => command.contains('attach-session'),
      );
      expect(attach, contains('-L default'));
      expect(
        restarted.client.commands.any(
          (command) => command.contains('new-session'),
        ),
        isFalse,
      );
    },
  );

  test(
    'hiding and unhiding a record survives a restart without touching the remote session',
    () async {
      final h = await _Harness.create();
      final target = TerminalHistoryRecord.targetFor(_server);
      await h.notifier.addNewTab();
      await h.drain();
      final record = h.state.history.single;
      await h.notifier.deleteHistory(record.id, expectedTargetKey: target);
      expect(h.state.hiddenRecordIds, contains(record.id));
      expect(h.state.defaultHistoryId, isNull);
      expect(h.client.remoteNames, contains(record.remoteSessionName));
      expect(
        h.client.commands.where((command) => command.contains('kill-session')),
        isEmpty,
      );
      await h.notifier.unhideHistory(record.id, expectedTargetKey: target);
      expect(h.state.hiddenRecordIds, isEmpty);
      final stored = h.storage.getTerminalHistory(_server.id, target);
      expect(stored.hiddenRecordIds, isEmpty);
      expect(stored.records.map((record) => record.id), contains(record.id));
      h.container.dispose();
      final restarted = await _Harness.create(
        storage: h.storage,
        client: h.client,
      );
      expect(restarted.state.hiddenRecordIds, isEmpty);
      expect(restarted.state.history.single.id, record.id);
      expect(
        restarted.client.commands.where(
          (command) => command.contains('kill-session'),
        ),
        isEmpty,
      );
      expect(restarted.client.remoteNames, contains(record.remoteSessionName));
    },
  );

  test(
    'removing a selected source clears only the local default and marks its records unavailable',
    () async {
      final h = await _Harness.create();
      final target = TerminalHistoryRecord.targetFor(_server);
      final source = TmuxSocketSource.named('team');
      await h.notifier.addNewTab();
      await h.drain();
      final own = h.state.history.single;
      await h.notifier.addSocketSource(source);
      expect(h.state.socketSources.map((item) => item.id), contains(source.id));
      expect(
        h.storage
            .getTerminalHistory(_server.id, target)
            .socketSources
            .map((item) => item.id),
        contains(source.id),
      );
      h.client.extraNames
          .putIfAbsent(source.id, () => <String>{})
          .add('team-session');
      await h.notifier.refreshHistory();
      expect(h.state.history, hasLength(2));
      final external = h.state.history
          .where((record) => record.socket.id == source.id)
          .single;
      expect(external.isExternal, isTrue);
      await h.notifier.setDefaultHistory(external.id);
      expect(h.state.defaultHistoryId, external.id);
      await h.notifier.removeSocketSource(source.id);
      expect(h.state.socketSources, isEmpty);
      expect(h.state.defaultHistoryId, isNull);
      final stored = h.storage.getTerminalHistory(_server.id, target);
      expect(stored.defaultRecordId, isNull);
      expect(stored.records.map((record) => record.id), contains(own.id));
      expect(stored.records.map((record) => record.id), contains(external.id));
      expect(
        h.state.historyStatuses[external.id],
        TerminalHistoryStatus.unavailable,
      );
      expect(h.state.historyStatuses[own.id], TerminalHistoryStatus.open);
      expect(
        h.client.commands.where((command) => command.contains('kill-session')),
        isEmpty,
      );
      expect(h.client.extraNames[source.id], contains('team-session'));
    },
  );

  test('socket source actions reject a stale expected target', () async {
    final h = await _Harness.create();
    final target = TerminalHistoryRecord.targetFor(_server);
    final source = TmuxSocketSource.named('team');
    final stale = expectLater(
      h.notifier.addSocketSource(source, expectedTargetKey: 'stale-target'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'TERMINAL_HISTORY_TARGET_CHANGED',
        ),
      ),
    );
    final staleRemove = expectLater(
      h.notifier.removeSocketSource(
        source.id,
        expectedTargetKey: 'stale-target',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'TERMINAL_HISTORY_TARGET_CHANGED',
        ),
      ),
    );
    final staleUnhide = expectLater(
      h.notifier.unhideHistory('any-record', expectedTargetKey: 'stale-target'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'TERMINAL_HISTORY_TARGET_CHANGED',
        ),
      ),
    );
    await Future.wait([stale, staleRemove, staleUnhide]);
    expect(h.state.socketSources, isEmpty);
    expect(
      h.storage.getTerminalHistory(_server.id, target).socketSources,
      isEmpty,
    );
  });

  test(
    'an alias of the same socket keeps one record and reroutes restore to the working source',
    () async {
      final h = await _Harness.create();
      final target = TerminalHistoryRecord.targetFor(_server);
      await h.notifier.addNewTab();
      await h.drain();
      final own = h.state.history.single;
      expect(own.identity, isNotNull);
      final alias = TmuxSocketSource.path(own.identity!.socketPath);
      await h.notifier.addSocketSource(alias);
      h.client.extraNames
          .putIfAbsent(alias.id, () => <String>{})
          .add(own.remoteSessionName);
      await h.notifier.refreshHistory();
      expect(h.state.history, hasLength(1));
      expect(h.state.history.single.id, own.id);
      expect(h.state.history.single.identity!.key, own.identity!.key);

      await h.notifier.setDefaultHistory(own.id);
      expect(h.state.defaultHistoryId, own.id);

      // The app socket becomes unreachable while the alias still answers.
      h.client.failingSocketIds.add(TmuxSocketSource.app.id);
      final commandsBefore = h.client.commands.length;
      await h.notifier.refreshHistory();
      expect(h.state.history, hasLength(1));
      final record = h.state.history.single;
      expect(record.id, own.id);
      expect(record.identity!.key, own.identity!.key);
      expect(record.socket.id, alias.id);
      expect(h.state.defaultHistoryId, own.id);
      expect(
        h.storage.getTerminalHistory(_server.id, target).defaultRecordId,
        own.id,
      );
      final added = h.client.commands.skip(commandsBefore);
      expect(
        added.where((command) => command.contains('new-session')),
        isEmpty,
      );
      expect(
        added.where((command) => command.contains('kill-session')),
        isEmpty,
      );
    },
  );

  test(
    'two simultaneous hide operations retain both hidden record ids',
    () async {
      final h = await _Harness.create();
      await h.notifier.addNewTab();
      await h.drain();
      await h.notifier.addNewTab();
      await h.drain();
      final records = h.state.history;
      expect(records, hasLength(2));
      final target = records.first.targetKey;
      h.storage.saveGate = Completer<void>();
      final hidingA = h.notifier.deleteHistory(
        records[0].id,
        expectedTargetKey: target,
      );
      final hidingB = h.notifier.deleteHistory(
        records[1].id,
        expectedTargetKey: target,
      );
      await h.drain();
      h.storage.saveGate!.complete();
      await Future.wait([hidingA, hidingB]);
      await h.drain();
      expect(
        h.state.hiddenRecordIds,
        containsAll([records[0].id, records[1].id]),
      );
      expect(
        h.storage.getTerminalHistory(_server.id, target).hiddenRecordIds,
        containsAll([records[0].id, records[1].id]),
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

  test(
    'stable tab ids, target checks and last-tab retention govern close and reconnect',
    () async {
      final h = await _Harness.create();
      await h.notifier.ensureInitialized();
      await h.drain();
      await h.notifier.addNewTab();
      await h.notifier.addNewTab();
      await h.drain();
      final tabs = h.state.tabs;
      expect(tabs, hasLength(3));
      final firstId = tabs[0].id;
      final middleId = tabs[1].id;
      final lastId = tabs[2].id;
      final target = TerminalHistoryRecord.targetFor(_server);

      await expectLater(
        h.notifier.closeTabById(middleId, expectedTargetKey: 'stale-target'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'TERMINAL_TARGET_CHANGED',
          ),
        ),
      );
      expect(h.state.tabs.map((tab) => tab.id), [firstId, middleId, lastId]);

      await h.notifier.closeTabById('missing-id', expectedTargetKey: target);
      expect(h.state.tabs.map((tab) => tab.id), [firstId, middleId, lastId]);

      h.notifier.selectTab(0);
      await h.notifier.closeTabById(middleId, expectedTargetKey: target);
      expect(h.state.tabs.map((tab) => tab.id), [firstId, lastId]);
      expect(h.state.activeTab!.id, firstId);

      final kept = h.state.tabs.last;
      kept.terminal.write('kept across stale reconnect');
      await expectLater(
        h.notifier.reconnectTab(kept.id, expectedTargetKey: 'stale-target'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'TERMINAL_TARGET_CHANGED',
          ),
        ),
      );
      expect(
        kept.terminal.buffer.getText(),
        contains('kept across stale reconnect'),
      );
      expect(h.state.tabs.map((tab) => tab.id), [firstId, lastId]);

      await h.notifier.closeTabById(firstId, expectedTargetKey: target);
      expect(h.state.tabs.single.id, lastId);
      expect(h.state.tabs.single.terminal, same(kept.terminal));

      // 现在支持关闭最后一个标签页：关闭后列表为空，而非保留占位标签。
      await h.notifier.closeTabById(lastId, expectedTargetKey: target);
      expect(h.state.tabs, isEmpty);
    },
  );

  test('SshTerminalState.copyWith drops stale detail for a new error code', () {
    final state = SshTerminalState(
      tabs: const [],
      errorCode: 'OLD_CODE',
      errorDetail: 'old detail',
    );
    final next = state.copyWith(errorCode: 'NEW_CODE');
    expect(next.errorCode, 'NEW_CODE');
    expect(next.errorDetail, isNull);
  });

  test('clearNotice clears cached terminal error detail', () async {
    final first = await _Harness.create();
    await first.notifier.addNewTab();
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
    expect(h.state.errorCode, 'TERMINAL_RESTORE_FAILED');
    expect(h.state.errorDetail, isNotNull);

    h.notifier.clearNotice();
    expect(h.state.errorCode, isNull);
    expect(h.state.errorDetail, isNull);

    await h.notifier.refreshHistory();
    await h.drain();
    expect(h.state.errorCode, isNull);
    expect(h.state.errorDetail, isNull);
  });

  test(
    'refresh records socketCheckedAt for app and default including a failed probe',
    () async {
      final h = await _Harness.create();
      // 仅默认 socket 的探测失败；App 专用 socket 照常返回。
      h.client.failingSocketIds.add(TmuxSocketSource.standard.id);
      final before = DateTime.now();
      await h.notifier.refreshHistory();
      await h.drain();
      final after = DateTime.now();

      // 失败探测仍要登记错误码。
      expect(h.state.socketErrors.keys, {TmuxSocketSource.standard.id});
      expect(
        h.state.socketErrors[TmuxSocketSource.standard.id],
        'TMUX_HISTORY_QUERY_FAILED',
      );
      // 成功与失败的来源都记录探测时间，键为 socket.id。
      expect(h.state.socketCheckedAt.keys, {
        TmuxSocketSource.app.id,
        TmuxSocketSource.standard.id,
      });
      for (final stamp in h.state.socketCheckedAt.values) {
        expect(stamp.isAfter(before) || stamp.isAtSameMomentAs(before), isTrue);
        expect(stamp.isBefore(after) || stamp.isAtSameMomentAs(after), isTrue);
      }
    },
  );

  test('SshTerminalState.copyWith retains the socketCheckedAt map', () {
    final stamp = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    final state = SshTerminalState(
      tabs: const [],
      socketCheckedAt: {TmuxSocketSource.app.id: stamp},
    );
    // 不传 socketCheckedAt 时复用原 map（同一引用，值无损）。
    final next = state.copyWith();
    expect(next.socketCheckedAt, same(state.socketCheckedAt));
    expect(next.socketCheckedAt[TmuxSocketSource.app.id], stamp);
    expect(next.socketErrors, isEmpty);

    // 显式传入时覆盖，且不再回退到原 map。
    final replaced = state.copyWith(socketCheckedAt: const {});
    expect(replaced.socketCheckedAt, isEmpty);
    expect(replaced.socketCheckedAt, isNot(same(state.socketCheckedAt)));
  });

  test(
    'switching server does not reuse another server socketCheckedAt',
    () async {
      final h = await _Harness.create();
      await h.notifier.refreshHistory();
      await h.drain();
      expect(h.state.socketCheckedAt.keys, contains(TmuxSocketSource.app.id));
      final fixtureStamp = h.state.socketCheckedAt[TmuxSocketSource.app.id];

      // 切到另一个服务器：新工作区的探测时间必须是空的，不能继承 fixture 的。
      final connection =
          h.container.read(serverConnectionProvider.notifier) as _Connection;
      final active = h.container.read(activeServerProvider.notifier) as _Active;
      connection.set(false, _server.id);
      active.select(_second);
      connection.set(true, _second.id);
      expect(h.state.socketCheckedAt, isEmpty);

      // 新服务器自己的探测会写入它自己的时间，而非 fixture 旧值。
      await h.notifier.refreshHistory();
      await h.drain();
      expect(h.state.socketCheckedAt.keys, contains(TmuxSocketSource.app.id));
      expect(
        h.state.socketCheckedAt[TmuxSocketSource.app.id],
        isNot(fixtureStamp),
      );
    },
  );

/// 后端 tmux 历史修复的集中回归：实时会话、已销毁排除、未校验、陈旧身份、
/// 发现失败、关闭销毁/保留与关闭最后一个标签页。全部使用 mock SSH，绝不触碰
/// 任何真实 tmux 服务器或已存在的会话。
group('tmux 历史修复（实时会话与销毁类操作）', () {
  final target = TerminalHistoryRecord.targetFor(_server);

  test('默认/命名 socket 上的活动外部会话始终展示，不受 forgotten 影响', () async {
    final storage = _ForgetfulStorage(await SharedPreferences.getInstance());
    final h = await _Harness.create(storage: storage);
    await h.notifier.ensureInitialized();
    await h.drain();
    // 预置一个会被判为 forgotten 的命名来源外部会话，刷新后仍应展示（live 优先）。
    h.client.extraNames[TmuxSocketSource.named('team').id] = {'team-ext'};
    await h.notifier.addSocketSource(
      TmuxSocketSource.named('team'),
      expectedTargetKey: target,
    );
    await h.drain();

    final external = h.state.history
        .where((r) => r.isExternal && r.socket.id == TmuxSocketSource.named('team').id)
        .toList();
    expect(external, hasLength(1));
    expect(external.single.remoteSessionName, 'team-ext');
    expect(
      h.state.historyStatuses[external.single.id],
      TerminalHistoryStatus.available,
    );
    expect(h.state.isHistoryVerified, isTrue);
  });

  test('已确认销毁（ended）的会话不再出现在历史中', () async {
    final h = await _Harness.create();
    await h.notifier.addNewTab();
    await h.drain();
    final record = h.state.history.single;
    final name = record.remoteSessionName;

    // 关闭唯一标签页（closeTabById 允许关闭最后一个），记录仍保留为元数据。
    await h.notifier.closeTabById(record.id, expectedTargetKey: target);
    await h.drain();
    expect(h.state.tabs, isEmpty);

    // 远端会话实际被销毁。
    h.client.remoteNames.remove(name);
    await h.notifier.refreshHistory();
    await h.drain();

    expect(
      h.state.history.any((r) => r.id == record.id),
      isFalse,
      reason: '已确认销毁的会话不应再展示',
    );
    // 内部状态仍保留 ended，便于默认/清理逻辑判断。
    expect(
      h.state.historyStatuses[record.id],
      TerminalHistoryStatus.ended,
    );
    expect(h.state.isHistoryVerified, isTrue);
  });

  test('发现全部失败时保留既有快照为未校验并禁用危险操作', () async {
    final h = await _Harness.create();
    await h.notifier.addNewTab();
    await h.drain();
    final id = h.state.history.single.id;

    h.client.failingSocketIds.add(TmuxSocketSource.app.id);
    h.client.failingSocketIds.add(TmuxSocketSource.standard.id);
    await h.notifier.refreshHistory();
    await h.drain();

    expect(h.state.isHistoryVerified, isFalse);
    expect(h.state.dangerousOperationsDisabled, isTrue);
    expect(h.state.historyStatuses[id], TerminalHistoryStatus.unknown);
    expect(
      h.state.history.any((r) => r.id == id),
      isTrue,
      reason: '发现失败应保留既有快照',
    );
  });

  test('陈旧身份的恢复不会创建替代会话，而是判为销毁', () async {
    final h = await _Harness.create();
    await h.notifier.addNewTab();
    await h.drain();
    final record = h.state.history.single;
    final name = record.remoteSessionName;

    // 先关闭标签页（远程会话保留），让 restore 走「未打开→按身份校验」路径。
    await h.notifier.closeTabById(record.id, expectedTargetKey: target);
    await h.drain();
    // 清空累计命令，仅校验恢复阶段是否产生替代会话（new-session）。
    h.client.commands.clear();

    // 远端会话被重建：同一名字映射到不同的数字 session id，旧身份失效。
    h.client.seedSession(name, 9999);

    await h.notifier.restoreHistory(record.id);
    await h.drain();

    expect(
      h.state.historyStatuses[record.id],
      TerminalHistoryStatus.ended,
    );
    expect(
      h.client.commands.where((c) => c.contains('new-session')),
      isEmpty,
      reason: '恢复绝不能为失效身份创建替代会话',
    );
    expect(h.state.tabs, isEmpty);
  });

  test('closeTabById(destroyRemote) 按身份销毁，失败则保留会话与标签页', () async {
    final h = await _Harness.create();
    await h.notifier.addNewTab();
    await h.drain();
    final record = h.state.history.single;
    final name = record.remoteSessionName;
    expect(h.client.remoteNames, contains(name));

    h.client.failKill = true;
    await h.notifier.closeTabById(
      record.id,
      expectedTargetKey: target,
      destroyRemote: true,
    );
    await h.drain();

    expect(h.state.tabs, isEmpty, reason: '标签页仍应关闭');
    expect(
      h.client.remoteNames,
      contains(name),
      reason: '销毁失败时远程会话必须保留',
    );
    expect(h.state.errorCode, isNull, reason: '保留失败时不应上抛错误');
  });

  test('closeTabById 可以关闭最后一个标签页', () async {
    final h = await _Harness.create();
    await h.notifier.ensureInitialized();
    await h.drain();
    final id = h.state.tabs.single.id;
    await h.notifier.closeTabById(id, expectedTargetKey: target);
    await h.drain();
    expect(h.state.tabs, isEmpty);
  });

  test('未校验时拒绝销毁类操作但照常关闭标签页', () async {
    final h = await _Harness.create();
    await h.notifier.addNewTab();
    await h.drain();
    final record = h.state.history.single;
    final name = record.remoteSessionName;
    expect(h.client.remoteNames, contains(name));

    // 后续发现失败：保留既有快照，但标记为未校验并禁用危险操作。
    h.client.failQuery = true;
    await h.notifier.refreshHistory();
    await h.drain();
    expect(h.state.isHistoryVerified, isFalse);

    await h.notifier.closeTabById(
      record.id,
      expectedTargetKey: target,
      destroyRemote: true,
    );
    await h.drain();

    expect(h.state.tabs, isEmpty, reason: '未校验仍可关闭标签页');
    expect(
      h.client.remoteNames,
      contains(name),
      reason: '未校验时不得执行远程销毁',
    );

    // terminateRemote 在未校验（发现失败）时直接拒绝，绝不动手。
    await expectLater(
      h.notifier.deleteHistory(
        record.id,
        terminateRemote: true,
        expectedTargetKey: target,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'TERMINAL_HISTORY_UNVERIFIED',
        ),
      ),
    );
  });
});

group('部分可解析响应：不误判已校验、不误删未知活动会话', () {
  final target = TerminalHistoryRecord.targetFor(_server);

  // 6 字段但 session_id 非法，交给逐行解析判为畸形（不会被续行合并吞掉）。
  const malformed =
      'NOT_AN_ID\u001f1730000000\u001f0\u001f12345\u001f/tmp/x\u001fevil';

  test('同一响应部分可解析：正常会话照常展示，未出现的记录保持 unknown 而非 ended', () async {
    final h = await _Harness.create();
    await h.notifier.addNewTab(); // tab1 -> name1
    await h.drain();
    await h.notifier.addNewTab(); // tab2 -> name2
    await h.drain();
    final first = h.state.history.firstWhere(
      (r) => r.socket.id == TmuxSocketSource.app.id,
    );
    final second = h.state.history.firstWhere(
      (r) => r.id != first.id && r.socket.id == TmuxSocketSource.app.id,
    );
    // 关闭 tab2（不销毁远端），随后让远端会话消失，制造一条「未在本次结果中
    // 出现」的记录；再让 standard 来源保持完整，从而只有 app 是「部分可解析」。
    await h.notifier.closeTabById(second.id, expectedTargetKey: target);
    await h.drain();
    h.client.remoteNames.remove(second.remoteSessionName);
    h.client.defaultNames.add('other-user');
    h.client.malformedLines[TmuxSocketSource.app.id] = malformed;

    await h.notifier.refreshHistory();
    await h.drain();

    // 部分可解析的来源绝不能算「已完全校验」。
    expect(h.state.isHistoryVerified, isFalse);
    expect(h.state.dangerousOperationsDisabled, isTrue);
    // 仍在运行的正常会话照常展示（不因同响应里的畸形行而消失）。
    expect(
      h.state.historyStatuses[first.id],
      isNot(TerminalHistoryStatus.ended),
    );
    // 未出现在结果中的记录只能是 unknown，绝不能被误判为 ended，也不能被删除。
    expect(
      h.state.historyStatuses[second.id],
      TerminalHistoryStatus.unknown,
    );
    expect(h.state.history.any((r) => r.id == second.id), isTrue);
  });

  test('整段响应全畸形：该来源记入错误且其未出现记录保持 unknown，绝不 ended', () async {
    final h = await _Harness.create();
    await h.notifier.addNewTab();
    await h.drain();
    await h.notifier.addNewTab();
    await h.drain();
    final appRecords = h.state.history
        .where((r) => r.socket.id == TmuxSocketSource.app.id)
        .toList();
    expect(appRecords, hasLength(2));
    // 让 app socket 的响应只剩一条畸形行（会话名清空），standard 保持完整。
    h.client.remoteNames.clear();
    h.client.defaultNames.add('other-user');
    h.client.malformedLines[TmuxSocketSource.app.id] = malformed;

    await h.notifier.refreshHistory();
    await h.drain();

    expect(h.state.isHistoryVerified, isFalse);
    expect(
      h.state.socketErrors[TmuxSocketSource.app.id],
      'TMUX_HISTORY_QUERY_FAILED',
    );
    for (final record in appRecords) {
      expect(
        h.state.historyStatuses[record.id],
        isNot(TerminalHistoryStatus.ended),
        reason: '整段响应畸形时绝不能把未知会话判为 ended',
      );
      expect(h.state.history.any((r) => r.id == record.id), isTrue);
    }
  });
});

}

/// 返回带 forgotten 集合的快照，用于验证 live 外部会话不被 forgotten 过滤掉。
class _ForgetfulStorage extends _Storage {
  _ForgetfulStorage(super.prefs);
  @override
  TerminalHistorySnapshot getTerminalHistory(
    String serverId,
    String targetKey,
  ) => const TerminalHistorySnapshot(
    forgottenSessionNames: ['team-ext'],
  );
}
