import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:xterm/xterm.dart';

import '../../data/models/server_profile.dart';
import '../../data/models/terminal_history.dart';
import '../security/agent_command_validator.dart';
import '../services/app_diagnostics.dart';
import '../utils/tmux_session_planner.dart';
import '../../infrastructure/mosh/mosh_bridge_adapter.dart';
import '../../infrastructure/mosh/mosh_providers.dart';
import '../../infrastructure/mosh/mosh_session_service.dart';
import '../../infrastructure/mosh/mosh_terminal_bridge.dart';
import '../../infrastructure/terminal/terminal_session_bridge.dart';
import 'server_provider.dart';
import 'storage_providers.dart';
import 'terminal_settings_provider.dart';

export '../../data/models/terminal_history.dart';

/// 远端缺 tmux 时给 UI 的安装询问契约。不含任何展示文案。
class TmuxInstallOffer {
  /// 将要执行的安装命令；无法识别包管理器时为 null。
  final String? installCommand;
  final bool isInstalling;

  /// 稳定错误码，由 UI 映射 ARB。例如 `TMUX_INSTALL_UNSUPPORTED`、
  /// `TMUX_INSTALL_FAILED`、`SSH_DISCONNECTED`。
  final String? errorCode;

  const TmuxInstallOffer({
    this.installCommand,
    this.isInstalling = false,
    this.errorCode,
  });

  TmuxInstallOffer copyWith({
    String? installCommand,
    bool? isInstalling,
    String? errorCode,
    bool clearError = false,
  }) {
    return TmuxInstallOffer(
      installCommand: installCommand ?? this.installCommand,
      isInstalling: isInstalling ?? this.isInstalling,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}

class TerminalTab {
  final String id;
  final String title;
  final Terminal terminal;
  final TerminalSessionBridge bridge;

  TerminalTab({
    required this.id,
    required this.title,
    required this.terminal,
    required this.bridge,
  });

  TerminalTab withTitle(String value) =>
      TerminalTab(id: id, title: value, terminal: terminal, bridge: bridge);
}

class SshTerminalState {
  int get activeConnectionCount => tabs
      .where((tab) => tab.bridge.state == TerminalConnectionState.connected)
      .length;
  final List<TerminalTab> tabs;
  final int activeTabIndex;
  final bool isCtrlActive;
  final bool isAltActive;
  final TmuxInstallOffer? tmuxInstallOffer;

  /// 当前激活的服务器是否开启了 Mosh (true 时新建会话入口出现 Mosh 选项)。
  final bool moshAvailable;
  final List<TerminalHistoryRecord> history;
  final Map<String, TerminalHistoryStatus> historyStatuses;
  final String? defaultHistoryId;
  final List<TmuxSocketSource> socketSources;
  final List<String> hiddenRecordIds;
  final Map<String, String> socketErrors;
  final bool isInitialized;
  final bool isInitializing;
  final bool isHistoryLoading;
  final String? errorCode;
  final String? noticeCode;

  SshTerminalState({
    required this.tabs,
    this.activeTabIndex = 0,
    this.isCtrlActive = false,
    this.isAltActive = false,
    this.tmuxInstallOffer,
    this.moshAvailable = false,
    this.history = const [],
    this.historyStatuses = const {},
    this.defaultHistoryId,
    this.socketSources = const [],
    this.hiddenRecordIds = const [],
    this.socketErrors = const {},
    this.isInitialized = false,
    this.isInitializing = false,
    this.isHistoryLoading = false,
    this.errorCode,
    this.noticeCode,
  });

  TerminalTab? get activeTab =>
      tabs.isNotEmpty && activeTabIndex >= 0 && activeTabIndex < tabs.length
      ? tabs[activeTabIndex]
      : null;

  SshTerminalState copyWith({
    List<TerminalTab>? tabs,
    int? activeTabIndex,
    bool? isCtrlActive,
    bool? isAltActive,
    TmuxInstallOffer? tmuxInstallOffer,
    bool clearTmuxInstallOffer = false,
    bool? moshAvailable,
    List<TerminalHistoryRecord>? history,
    Map<String, TerminalHistoryStatus>? historyStatuses,
    String? defaultHistoryId,
    List<TmuxSocketSource>? socketSources,
    List<String>? hiddenRecordIds,
    Map<String, String>? socketErrors,
    bool clearDefaultHistory = false,
    bool? isInitialized,
    bool? isInitializing,
    bool? isHistoryLoading,
    String? errorCode,
    bool clearError = false,
    String? noticeCode,
    bool clearNotice = false,
  }) {
    return SshTerminalState(
      tabs: tabs ?? this.tabs,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      isCtrlActive: isCtrlActive ?? this.isCtrlActive,
      isAltActive: isAltActive ?? this.isAltActive,
      tmuxInstallOffer: clearTmuxInstallOffer
          ? null
          : (tmuxInstallOffer ?? this.tmuxInstallOffer),
      moshAvailable: moshAvailable ?? this.moshAvailable,
      history: history ?? this.history,
      historyStatuses: historyStatuses ?? this.historyStatuses,
      defaultHistoryId: clearDefaultHistory
          ? null
          : (defaultHistoryId ?? this.defaultHistoryId),
      socketSources: socketSources ?? this.socketSources,
      hiddenRecordIds: hiddenRecordIds ?? this.hiddenRecordIds,
      socketErrors: socketErrors ?? this.socketErrors,
      isInitialized: isInitialized ?? this.isInitialized,
      isInitializing: isInitializing ?? this.isInitializing,
      isHistoryLoading: isHistoryLoading ?? this.isHistoryLoading,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      noticeCode: clearNotice ? null : (noticeCode ?? this.noticeCode),
    );
  }
}

class _TerminalWorkspace {
  ServerProfile server;
  final String targetKey;
  SshTerminalState value;
  bool requested = false;
  bool startupApplied = false;
  bool historyReadable = true;
  Future<void>? initializing;
  Future<void>? refreshing;
  Future<void>? rebinding;
  Future<void> saveTail = Future<void>.value();
  final Map<String, Future<void>> starting = {};
  final Map<String, VoidCallback> listeners = {};
  final Map<String, Future<void>> deleting = {};
  Set<String> forgottenSessionNames = {};
  int connectionEpoch = 0;
  int interactionEpoch = 0;

  _TerminalWorkspace(this.server, this.targetKey, this.value);
}

class TerminalNotifier extends Notifier<SshTerminalState> {
  Timer? _historyTimer;
  bool _historyVisible = false;

  void setHistoryVisible(bool visible) {
    _historyVisible = visible;
    _historyTimer?.cancel();
    _historyTimer = null;
    if (!visible) return;
    unawaited(refreshHistory());
    _historyTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(refreshHistory()),
    );
  }

  Future<void> addSocketSource(
    TmuxSocketSource source, {
    String? expectedTargetKey,
  }) async {
    final workspace = _current;
    if (expectedTargetKey != null &&
        workspace?.targetKey != expectedTargetKey) {
      throw StateError('TERMINAL_HISTORY_TARGET_CHANGED');
    }
    if (workspace == null ||
        source.isBuiltin ||
        workspace.value.socketSources.any((s) => s.id == source.id)) {
      return;
    }
    await _saveHistory(
      workspace,
      (current) => current,
      updateSocketSources: (sources) => sources.any((s) => s.id == source.id)
          ? sources
          : [...sources, source],
    );
    await workspace.refreshing;
    if (_isCurrent(workspace)) await refreshHistory();
  }

  Future<void> removeSocketSource(
    String sourceId, {
    String? expectedTargetKey,
  }) async {
    final workspace = _current;
    if (expectedTargetKey != null &&
        workspace?.targetKey != expectedTargetKey) {
      throw StateError('TERMINAL_HISTORY_TARGET_CHANGED');
    }
    if (workspace == null) return;
    await _saveHistory(
      workspace,
      (current) =>
          current.records.any(
            (r) => r.id == current.defaultRecordId && r.socket.id == sourceId,
          )
          ? TerminalHistorySnapshot(records: current.records)
          : current,
      updateSocketSources: (sources) =>
          sources.where((s) => s.id != sourceId).toList(),
    );
    await workspace.refreshing;
    if (_isCurrent(workspace)) await refreshHistory();
  }

  Future<void> unhideHistory(String id, {String? expectedTargetKey}) async {
    final workspace = _current;
    if (expectedTargetKey != null &&
        workspace?.targetKey != expectedTargetKey) {
      throw StateError('TERMINAL_HISTORY_TARGET_CHANGED');
    }
    if (workspace == null) return;
    await _saveHistory(
      workspace,
      (current) => current,
      updateHiddenRecordIds: (ids) => ids.where((item) => item != id).toList(),
    );
  }

  final Map<String, _TerminalWorkspace> _workspaces = {};
  _TerminalWorkspace? _current;
  static const _uuid = Uuid();

  @override
  bool updateShouldNotify(SshTerminalState previous, SshTerminalState next) {
    _current?.value = next;
    return !identical(previous, next);
  }

  @override
  SshTerminalState build() {
    ref.listen(activeServerProvider, (_, next) => _activate(next));
    ref.listen(serverListProvider, (_, next) {
      final ids = next.map((server) => server.id).toSet();
      for (final workspace in _workspaces.values.toList()) {
        if (!ids.contains(workspace.server.id)) {
          _workspaces.remove(workspace.targetKey);
          _disposeWorkspace(workspace);
        }
      }
    });
    ref.listen(serverConnectionProvider, (prev, next) {
      if (next.isConnected &&
          (prev?.isConnected != true ||
              prev?.activeServerId != next.activeServerId)) {
        unawaited(rebindAfterReconnect());
        if (_historyVisible) unawaited(refreshHistory());
      } else if (!next.isConnected) {
        final workspace = _current;
        if (workspace != null) {
          workspace.connectionEpoch++;
          state = state.copyWith(
            historyStatuses: {
              for (final record in state.history)
                record.id:
                    state.historyStatuses[record.id] ==
                        TerminalHistoryStatus.ended
                    ? TerminalHistoryStatus.ended
                    : TerminalHistoryStatus.unknown,
            },
          );
        }
      }
    });
    ref.onDispose(() {
      _historyTimer?.cancel();
      for (final workspace in _workspaces.values) {
        _disposeWorkspace(workspace);
      }
      _workspaces.clear();
    });
    final server = ref.read(activeServerProvider);
    _current = server == null ? null : _workspaceFor(server);
    return _current?.value ?? SshTerminalState(tabs: const []);
  }

  _TerminalWorkspace _workspaceFor(ServerProfile server) {
    final key = TerminalHistoryRecord.targetFor(server);
    final existing = _workspaces[key];
    if (existing != null) {
      existing.server = server;
      existing.value = existing.value.copyWith(
        moshAvailable: server.moshEnabled,
      );
      return existing;
    }
    var snapshot = const TerminalHistorySnapshot();
    String? errorCode;
    try {
      snapshot = ref
          .read(localStorageServiceProvider)
          .getTerminalHistory(server.id, key);
    } catch (error, stack) {
      errorCode = 'TERMINAL_HISTORY_LOAD_FAILED';
      unawaited(
        AppDiagnostics.instance.record('terminal.history.load', error, stack),
      );
    }
    final workspace =
        _TerminalWorkspace(
            server,
            key,
            SshTerminalState(
              tabs: const [],
              moshAvailable: server.moshEnabled,
              history: snapshot.records,
              defaultHistoryId: snapshot.defaultRecordId,
              socketSources: snapshot.socketSources,
              hiddenRecordIds: snapshot.hiddenRecordIds,
              errorCode: errorCode,
            ),
          )
          ..historyReadable = errorCode == null
          ..forgottenSessionNames = snapshot.forgottenSessionNames.toSet();
    _workspaces[key] = workspace;
    return workspace;
  }

  void _activate(ServerProfile? server) {
    final previous = _current;
    final sameConnection =
        previous != null &&
        server != null &&
        previous.server.hasSameConnectionSettings(server);
    if (previous != null && !sameConnection) previous.connectionEpoch++;
    _current = server == null ? null : _workspaceFor(server);
    state = _current?.value ?? SshTerminalState(tabs: const []);
    final workspace = _current;
    if (!sameConnection &&
        workspace != null &&
        workspace.requested &&
        _clientFor(workspace) != null) {
      // Let the connection controller invalidate a replaced endpoint first.
      unawaited(
        Future<void>.microtask(() async {
          if (_isCurrent(workspace)) await rebindAfterReconnect();
        }),
      );
    }
  }

  bool _valid(_TerminalWorkspace workspace) =>
      ref.mounted && identical(_workspaces[workspace.targetKey], workspace);

  bool _isCurrent(_TerminalWorkspace workspace) =>
      _valid(workspace) && identical(_current, workspace);

  void _publish(_TerminalWorkspace workspace, SshTerminalState next) {
    if (!_valid(workspace)) return;
    workspace.value = next;
    if (identical(_current, workspace)) state = next;
  }

  SSHClient? _clientFor(_TerminalWorkspace workspace) {
    if (!_isCurrent(workspace)) return null;
    if (!(ref
            .read(activeServerProvider)
            ?.hasSameConnectionSettings(workspace.server) ??
        false)) {
      return null;
    }
    final connection = ref.read(serverConnectionProvider);
    if (!connection.isConnected ||
        (connection.activeServerId != null &&
            connection.activeServerId != workspace.server.id)) {
      return null;
    }
    final client = ref
        .read(sshClientManagerProvider)
        .getClient(workspace.server.id);
    return client?.isClosed == false ? client : null;
  }

  void _disposeWorkspace(_TerminalWorkspace workspace) {
    workspace.connectionEpoch++;
    for (final tab in workspace.value.tabs) {
      final listener = workspace.listeners.remove(tab.id);
      if (listener != null) tab.bridge.stateListenable.removeListener(listener);
      tab.bridge.dispose();
    }
  }

  /// Explicit entry point: merely observing this provider never opens a PTY.
  Future<void> ensureInitialized() {
    final workspace = _current;
    if (workspace == null) return Future<void>.value();
    workspace.requested = true;
    if (workspace.value.tabs.isNotEmpty) return Future<void>.value();
    if (workspace.initializing case final Future<void> pending) return pending;
    final epoch = workspace.connectionEpoch;
    final pending = _initialize(workspace).whenComplete(() {
      workspace.initializing = null;
    });
    workspace.initializing = pending;
    return pending.then((_) async {
      if (_isCurrent(workspace) &&
          epoch != workspace.connectionEpoch &&
          workspace.value.tabs.isEmpty &&
          _clientFor(workspace) != null) {
        await ensureInitialized();
      }
    });
  }

  Future<void> _initialize(_TerminalWorkspace workspace) async {
    if (_clientFor(workspace) == null) return;
    _publish(workspace, workspace.value.copyWith(isInitializing: true));
    try {
      final defaultId = workspace.startupApplied
          ? null
          : workspace.value.defaultHistoryId;
      if (defaultId != null) {
        final record = workspace.value.history
            .where((item) => item.id == defaultId)
            .firstOrNull;
        if (record != null) {
          await _restore(workspace, record, isStartup: true);
          return;
        }
        await _saveHistory(
          workspace,
          (current) => TerminalHistorySnapshot(records: current.records),
        );
        if (!_isCurrent(workspace)) return;
        _publish(
          workspace,
          workspace.value.copyWith(noticeCode: 'TERMINAL_DEFAULT_MISSING'),
        );
      }
      if (_isCurrent(workspace) && workspace.value.tabs.isEmpty) {
        await _addFresh(workspace);
      }
    } catch (error, stack) {
      _report(workspace, 'TERMINAL_START_FAILED', error, stack);
    } finally {
      if (_valid(workspace)) {
        _publish(workspace, workspace.value.copyWith(isInitializing: false));
      }
    }
  }

  void _report(
    _TerminalWorkspace workspace,
    String code,
    Object error,
    StackTrace stack,
  ) {
    unawaited(
      AppDiagnostics.instance.record('terminal.operation', error, stack),
    );
    if (_valid(workspace)) {
      _publish(workspace, workspace.value.copyWith(errorCode: code));
    }
  }

  void clearNotice() =>
      state = state.copyWith(clearNotice: true, clearError: true);

  Future<void> _saveHistory(
    _TerminalWorkspace workspace,
    TerminalHistorySnapshot Function(TerminalHistorySnapshot) update, {
    List<TmuxSocketSource> Function(List<TmuxSocketSource>)?
    updateSocketSources,
    List<String> Function(List<String>)? updateHiddenRecordIds,
  }) {
    final pending = workspace.saveTail.then((_) async {
      if (!_valid(workspace)) return;
      if (!workspace.historyReadable) {
        throw StateError('TERMINAL_HISTORY_LOAD_FAILED');
      }
      final updated = update(
        TerminalHistorySnapshot(
          records: workspace.value.history,
          defaultRecordId: workspace.value.defaultHistoryId,
          forgottenSessionNames: workspace.forgottenSessionNames.toList(),
        ),
      );
      final forgotten = {
        ...workspace.forgottenSessionNames,
        ...updated.forgottenSessionNames,
      };
      final snapshot = TerminalHistorySnapshot(
        records: updated.records
            .where(
              (record) =>
                  record.socket.id != TmuxSocketSource.app.id ||
                  !forgotten.contains(record.remoteSessionName),
            )
            .toList(),
        defaultRecordId: updated.defaultRecordId,
        forgottenSessionNames: forgotten.toList(),
        socketSources:
            updateSocketSources?.call(workspace.value.socketSources) ??
            workspace.value.socketSources,
        hiddenRecordIds:
            updateHiddenRecordIds?.call(workspace.value.hiddenRecordIds) ??
            workspace.value.hiddenRecordIds,
      );
      await ref
          .read(localStorageServiceProvider)
          .saveTerminalHistory(
            workspace.server.id,
            workspace.targetKey,
            snapshot,
          );
      if (!_valid(workspace)) return;
      workspace.forgottenSessionNames = forgotten;
      final records = [...snapshot.records]
        ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      final titles = {for (final record in records) record.id: record.title};
      _publish(
        workspace,
        workspace.value.copyWith(
          history: List.unmodifiable(records),
          tabs: [
            for (final tab in workspace.value.tabs)
              titles.containsKey(tab.id) ? tab.withTitle(titles[tab.id]!) : tab,
          ],
          defaultHistoryId: snapshot.defaultRecordId,
          clearDefaultHistory: snapshot.defaultRecordId == null,
          socketSources: snapshot.socketSources,
          hiddenRecordIds: snapshot.hiddenRecordIds,
        ),
      );
    });
    workspace.saveTail = pending.catchError((Object error, StackTrace stack) {
      _report(workspace, 'TERMINAL_HISTORY_SAVE_FAILED', error, stack);
    });
    return pending;
  }

  void _syncTmuxOffer() {
    final bridge = state.activeTab?.bridge;
    if (bridge != null && bridge.awaitingTmuxDecision) {
      state = state.copyWith(
        tmuxInstallOffer: TmuxInstallOffer(
          installCommand: bridge.proposedInstallCommand,
        ),
      );
    } else {
      state = state.copyWith(clearTmuxInstallOffer: true);
    }
  }

  /// 用户拒绝安装：当前标签页走普通 SSH PTY。
  Future<void> skipTmuxInstall() async {
    final workspace = _current;
    final tab = state.activeTab;
    if (workspace == null || tab == null) return;
    await tab.bridge.proceedWithoutTmux();
    if (_isCurrent(workspace)) _syncTmuxOffer();
  }

  /// 用户确认安装。命令来自 [TmuxInstallOffer.installCommand]。
  ///
  /// 不在这里弹出 UI。失败只写稳定 [TmuxInstallOffer.errorCode]。
  Future<void> confirmTmuxInstall() async {
    final workspace = _current;
    final offer = state.tmuxInstallOffer;
    final tab = state.activeTab;
    final server = ref.read(activeServerProvider);
    if (workspace == null || offer == null || tab == null) return;

    final command = offer.installCommand;
    if (command == null || command.trim().isEmpty) {
      state = state.copyWith(
        tmuxInstallOffer: offer.copyWith(errorCode: 'TMUX_INSTALL_UNSUPPORTED'),
      );
      return;
    }

    if (server == null || !ref.read(serverConnectionProvider).isConnected) {
      state = state.copyWith(
        tmuxInstallOffer: offer.copyWith(errorCode: 'SSH_DISCONNECTED'),
      );
      return;
    }

    try {
      AgentCommandValidator.validate(command);
    } catch (_) {
      state = state.copyWith(
        tmuxInstallOffer: offer.copyWith(errorCode: 'TMUX_INSTALL_UNSUPPORTED'),
      );
      return;
    }

    state = state.copyWith(
      tmuxInstallOffer: offer.copyWith(isInstalling: true, clearError: true),
    );

    final result = await ref
        .read(sshClientManagerProvider)
        .executeWithLoginShell(
          server.id,
          command,
          timeout: const Duration(minutes: 5),
        );

    if (!_isCurrent(workspace) ||
        !workspace.value.tabs.any(
          (item) => identical(item.bridge, tab.bridge),
        )) {
      return;
    }

    if (!result.isSuccess) {
      if (state.activeTab?.id == tab.id) {
        state = state.copyWith(
          tmuxInstallOffer: offer.copyWith(
            isInstalling: false,
            errorCode: 'TMUX_INSTALL_FAILED',
          ),
        );
      }
      return;
    }

    await tab.bridge.retryAfterTmuxInstall();
    if (_isCurrent(workspace)) _syncTmuxOffer();
  }

  TerminalTab _createTab(
    String title, {
    required String serverName,
    required String serverId,
    required String terminalId,
    SSHClient? sshClient,
    required bool preferTmux,
    String? targetKey,
    TerminalSessionIntent sessionIntent = TerminalSessionIntent.createFresh,
    String? tmuxSessionName,
    TmuxSocketSource tmuxSocket = TmuxSocketSource.app,
    TmuxSessionIdentity? tmuxIdentity,
  }) {
    final terminal = Terminal(maxLines: 1500);
    final bridge = TerminalSessionBridge(
      terminal: terminal,
      sshClient: sshClient,
      serverName: serverName,
      serverId: serverId,
      terminalId: targetKey == null ? terminalId : '${targetKey}_$terminalId',
      preferTmux: preferTmux,
      sessionIntent: sessionIntent,
      tmuxSessionName: tmuxSessionName,
      tmuxSocket: tmuxSocket,
      tmuxIdentity: tmuxIdentity,
    );

    return TerminalTab(
      id: terminalId,
      title: title,
      terminal: terminal,
      bridge: bridge,
    );
  }

  void selectTab(int index) {
    if (index >= 0 && index < state.tabs.length) {
      _current?.interactionEpoch++;
      state = state.copyWith(activeTabIndex: index);
      _syncTmuxOffer();
      final workspace = _current;
      if (workspace != null) {
        unawaited(_rememberTab(workspace, state.tabs[index]));
      }
    }
  }

  Future<void> addNewTab([String? customTitle]) async {
    final workspace = _current;
    if (workspace == null) return;
    workspace.interactionEpoch++;
    workspace.requested = true;
    workspace.startupApplied = true;
    try {
      await _addFresh(
        workspace,
        customTitle: customTitle,
        preferTmux: ref.read(terminalSettingsProvider).useTmux,
      );
    } catch (error, stack) {
      _report(workspace, 'TERMINAL_START_FAILED', error, stack);
    }
  }

  Future<void> _addFresh(
    _TerminalWorkspace workspace, {
    String? customTitle,
    bool preferTmux = false,
  }) async {
    if (!_isCurrent(workspace)) return;
    final title = TerminalHistoryRecord.validateTitle(
      customTitle ?? 'bash #${workspace.value.tabs.length + 1}',
    );
    final tab = _createTab(
      title,
      serverName: workspace.server.name,
      serverId: workspace.server.id,
      terminalId: _uuid.v4(),
      targetKey: workspace.targetKey,
      sshClient: _clientFor(workspace),
      // Automatic initialization must not leave a persistent remote session.
      preferTmux: preferTmux,
    );
    workspace.startupApplied = true;
    _appendTab(workspace, tab);
    await _startTab(workspace, tab);
  }

  void _appendTab(_TerminalWorkspace workspace, TerminalTab tab) {
    _publish(
      workspace,
      workspace.value.copyWith(
        tabs: [...workspace.value.tabs, tab],
        activeTabIndex: workspace.value.tabs.length,
        isInitialized: true,
      ),
    );
    void listener() {
      if (!_valid(workspace)) return;
      if (tab.bridge.state == TerminalConnectionState.connected) {
        unawaited(_rememberTab(workspace, tab));
      } else if (workspace.value.history.any((record) => record.id == tab.id)) {
        _publish(
          workspace,
          workspace.value.copyWith(
            noticeCode: tab.bridge.remoteSessionMissing
                ? 'TERMINAL_SESSION_MISSING'
                : null,
            historyStatuses: {
              ...workspace.value.historyStatuses,
              tab.id: tab.bridge.remoteSessionMissing
                  ? TerminalHistoryStatus.ended
                  : TerminalHistoryStatus.unknown,
            },
          ),
        );
        if (tab.bridge.remoteSessionMissing &&
            workspace.value.defaultHistoryId == tab.id) {
          unawaited(
            _saveHistory(
              workspace,
              (current) => current.defaultRecordId == tab.id
                  ? TerminalHistorySnapshot(records: current.records)
                  : current,
            ).catchError((Object error, StackTrace stack) {
              _report(workspace, 'TERMINAL_DEFAULT_SAVE_FAILED', error, stack);
            }),
          );
        }
      }
    }

    workspace.listeners[tab.id] = listener;
    tab.bridge.stateListenable.addListener(listener);
  }

  Future<void> _startTab(_TerminalWorkspace workspace, TerminalTab tab) {
    final pending = tab.bridge.start(
      initialWidth: tab.terminal.viewWidth,
      initialHeight: tab.terminal.viewHeight,
    );
    workspace.starting[tab.id] = pending;
    return pending.whenComplete(() {
      workspace.starting.remove(tab.id);
      if (_isCurrent(workspace)) _syncTmuxOffer();
    });
  }

  Future<void> _rememberTab(
    _TerminalWorkspace workspace,
    TerminalTab tab,
  ) async {
    final name = tab.bridge.activeTmuxSessionName;
    if (!_valid(workspace) ||
        name == null ||
        (tab.bridge.tmuxSocket.id == TmuxSocketSource.app.id &&
            workspace.forgottenSessionNames.contains(name)) ||
        tab.bridge.state != TerminalConnectionState.connected ||
        !workspace.value.tabs.any((item) => item.id == tab.id)) {
      return;
    }
    try {
      final client = _clientFor(workspace);
      final epoch = workspace.connectionEpoch;
      await _saveHistory(workspace, (current) {
        final liveTab = workspace.value.tabs
            .where((item) => item.id == tab.id)
            .firstOrNull;
        final existing = current.records
            .where((item) => item.id == tab.id)
            .firstOrNull;
        final now = DateTime.now().toUtc();
        final record =
            existing?.copyWith(
              lastUsedAt: now,
              isLegacy: false,
              identity: tab.bridge.tmuxIdentity,
            ) ??
            TerminalHistoryRecord(
              id: tab.id,
              serverId: workspace.server.id,
              targetKey: workspace.targetKey,
              remoteSessionName: name,
              title: liveTab?.title ?? tab.title,
              createdAt: now,
              lastUsedAt: now,
              socket: tab.bridge.tmuxSocket,
              identity: tab.bridge.tmuxIdentity,
            );
        return TerminalHistorySnapshot(
          records: [
            record,
            ...current.records.where((item) => item.id != tab.id),
          ],
          defaultRecordId: current.defaultRecordId,
        );
      });
      if (_valid(workspace) &&
          workspace.value.tabs.any(
            (item) =>
                item.id == tab.id &&
                item.bridge.state == TerminalConnectionState.connected,
          )) {
        _publish(
          workspace,
          workspace.value.copyWith(
            historyStatuses: {
              ...workspace.value.historyStatuses,
              tab.id: TerminalHistoryStatus.open,
            },
          ),
        );
      }
      // Queue the first save before any metadata I/O, preserving immediate rename/close ordering.
      if (tab.bridge.tmuxIdentity == null && client != null) {
        try {
          final sessions = await TerminalSessionBridge.discoverTmuxSessions(
            client,
            serverId: workspace.server.id,
            socket: tab.bridge.tmuxSocket,
            includeExternal: true,
          );
          if (!_isCurrent(workspace) || epoch != workspace.connectionEpoch) {
            return;
          }
          final identity = sessions
              .where((s) => s.name == name)
              .firstOrNull
              ?.identity;
          if (identity == null) return;
          tab.bridge.tmuxIdentity = identity;
          await _saveHistory(
            workspace,
            (current) => TerminalHistorySnapshot(
              records: [
                for (final record in current.records)
                  record.id == tab.id
                      ? record.copyWith(identity: identity)
                      : record,
              ],
              defaultRecordId: current.defaultRecordId,
            ),
          );
        } catch (_) {
          // Metadata failure does not tear down the PTY; later discovery can retry binding.
        }
      }
    } catch (error, stack) {
      _report(workspace, 'TERMINAL_HISTORY_SAVE_FAILED', error, stack);
    }
  }

  Future<void> refreshHistory() {
    final workspace = _current;
    if (workspace == null) return Future<void>.value();
    if (workspace.refreshing case final Future<void> pending) return pending;
    final pending = _refreshHistory(workspace);
    workspace.refreshing = pending;
    return pending.whenComplete(() => workspace.refreshing = null);
  }

  Future<void> _refreshHistory(_TerminalWorkspace workspace) async {
    final client = _clientFor(workspace);
    if (client == null) return;
    final epoch = workspace.connectionEpoch;
    final sources = [
      TmuxSocketSource.app,
      TmuxSocketSource.standard,
      ...workspace.value.socketSources,
    ];
    _publish(workspace, workspace.value.copyWith(isHistoryLoading: true));
    final found = <TmuxSessionInfo>[];
    final errors = <String, String>{};
    final complete = <String>{};
    try {
      // Bounded workers: a slow or inaccessible custom socket cannot flood SSH.
      var cursor = 0;
      Future<void> worker() async {
        while (cursor < sources.length) {
          final source = sources[cursor++];
          try {
            final sessions = await TerminalSessionBridge.discoverTmuxSessions(
              client,
              serverId: workspace.server.id,
              socket: source,
              includeExternal: true,
            );
            found.addAll(sessions);
            complete.add(source.id);
          } catch (_) {
            errors[source.id] = 'TMUX_HISTORY_QUERY_FAILED';
          }
          if (!_isCurrent(workspace) || epoch != workspace.connectionEpoch) {
            return;
          }
        }
      }

      await Future.wait([worker(), worker()]);
      if (!_isCurrent(workspace) ||
          epoch != workspace.connectionEpoch ||
          !identical(client, _clientFor(workspace))) {
        return;
      }
      if (sources.map((s) => s.id).join('\n') !=
          [
            TmuxSocketSource.app,
            TmuxSocketSource.standard,
            ...workspace.value.socketSources,
          ].map((s) => s.id).join('\n')) {
        return;
      }
      found.sort(
        (a, b) => sources
            .indexWhere((s) => s.id == a.socket.id)
            .compareTo(sources.indexWhere((s) => s.id == b.socket.id)),
      );
      final sourceIds = sources.map((s) => s.id).toSet();
      final byIdentity = {
        for (final session in found) session.identity!.key: session,
      };
      final bySourceIdentity = {
        for (final session in found)
          '${session.socket.id}\x00${session.identity!.key}': session,
      };
      final byName = {
        for (final session in found)
          '${session.socket.id}\x00${session.name}': session,
      };
      final records = <TerminalHistoryRecord>[];
      final statuses = <String, TerminalHistoryStatus>{};
      final known = <String>{};
      for (final record in workspace.value.history) {
        final session = record.identity != null
            ? (bySourceIdentity['${record.socket.id}\x00${record.identity!.key}'] ??
                  byIdentity[record.identity!.key])
            : byName['${record.socket.id}\x00${record.remoteSessionName}'];
        var updated = record;
        if (!sourceIds.contains(record.socket.id) && session == null) {
          statuses[record.id] = TerminalHistoryStatus.unavailable;
        } else if (session != null) {
          updated = record.copyWith(
            identity: session.identity,
            attachedClients: session.attachedClients,
            remoteSessionName: session.name,
            socket: session.socket,
          );
          known.add(session.identity!.key);
          statuses[record.id] =
              workspace.value.tabs.any(
                (t) =>
                    t.id == record.id &&
                    t.bridge.state == TerminalConnectionState.connected,
              )
              ? TerminalHistoryStatus.open
              : TerminalHistoryStatus.available;
          for (final tab in workspace.value.tabs.where(
            (t) => t.id == record.id,
          )) {
            tab.bridge.tmuxIdentity = session.identity;
            tab.bridge.tmuxSocket = updated.socket;
          }
        } else if (complete.contains(record.socket.id)) {
          statuses[record.id] = TerminalHistoryStatus.ended;
        } else {
          statuses[record.id] =
              workspace.value.historyStatuses[record.id] ==
                  TerminalHistoryStatus.ended
              ? TerminalHistoryStatus.ended
              : TerminalHistoryStatus.unknown;
        }
        records.add(updated);
      }
      final prefix =
          '${TmuxSessionPlanner.sessionName(workspace.server.id, '')}${workspace.targetKey}_';
      final recordIds = records.map((r) => r.id).toSet();
      for (final session in found) {
        final identity = session.identity!;
        if (!known.add(identity.key)) continue;
        if (session.socket.id == TmuxSocketSource.app.id &&
            workspace.forgottenSessionNames.contains(session.name)) {
          continue;
        }
        final own =
            session.socket.id == TmuxSocketSource.app.id &&
            session.name.startsWith(prefix);
        final scopedId = own ? session.name.substring(prefix.length) : null;
        final id =
            scopedId != null &&
                RegExp(r'^[a-f0-9-]{36}$').hasMatch(scopedId) &&
                !recordIds.contains(scopedId)
            ? scopedId
            : 'remote-${identity.key}';
        if (!recordIds.add(id)) continue;
        final record = TerminalHistoryRecord(
          id: id,
          serverId: workspace.server.id,
          targetKey: workspace.targetKey,
          remoteSessionName: session.name,
          title: own ? 'bash' : session.name.characters.take(64).toString(),
          createdAt: session.createdAt,
          lastUsedAt: session.createdAt,
          isLegacy: true,
          socket: session.socket,
          identity: identity,
          isExternal: !own,
          attachedClients: session.attachedClients,
        );
        records.add(record);
        statuses[id] = TerminalHistoryStatus.available;
      }
      records.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      _publish(
        workspace,
        workspace.value.copyWith(
          history: List.unmodifiable(records),
          historyStatuses: statuses,
          socketErrors: errors,
        ),
      );
      // Display remote truth immediately; never wait on a pending rename/default disk write.
      unawaited(
        _saveHistory(workspace, (current) {
          final id = current.defaultRecordId;
          return id != null &&
                  workspace.value.historyStatuses[id] ==
                      TerminalHistoryStatus.ended
              ? TerminalHistorySnapshot(records: current.records)
              : current;
        }).catchError((Object error, StackTrace stack) {
          _report(workspace, 'TERMINAL_HISTORY_SAVE_FAILED', error, stack);
        }),
      );
    } catch (error, stack) {
      if (_isCurrent(workspace) && epoch == workspace.connectionEpoch) {
        _report(workspace, 'TERMINAL_HISTORY_REFRESH_FAILED', error, stack);
      }
    } finally {
      if (_valid(workspace)) {
        _publish(workspace, workspace.value.copyWith(isHistoryLoading: false));
      }
    }
  }

  Future<void> restoreHistory(String id) async {
    final workspace = _current;
    if (workspace == null) return;
    final record = workspace.value.history
        .where((item) => item.id == id)
        .firstOrNull;
    if (record == null) return;
    workspace.interactionEpoch++;
    workspace.requested = true;
    try {
      await _restore(workspace, record);
    } catch (error, stack) {
      _report(workspace, 'TERMINAL_RESTORE_FAILED', error, stack);
    }
  }

  Future<void> _restore(
    _TerminalWorkspace workspace,
    TerminalHistoryRecord record, {
    bool isStartup = false,
  }) async {
    if (!_isCurrent(workspace) ||
        record.targetKey != workspace.targetKey ||
        record.serverId != workspace.server.id) {
      return;
    }
    if (record.identity == null) {
      await refreshHistory();
      if (!_isCurrent(workspace)) return;
      record =
          workspace.value.history.where((r) => r.id == record.id).firstOrNull ??
          record;
    }
    final status = workspace.value.historyStatuses[record.id];
    if (status == TerminalHistoryStatus.ended) {
      await _handleMissing(workspace, record, isStartup: isStartup);
      return;
    }
    if (status == TerminalHistoryStatus.unavailable ||
        record.identity == null ||
        ![
          TmuxSocketSource.app.id,
          TmuxSocketSource.standard.id,
          ...workspace.value.socketSources.map((s) => s.id),
        ].contains(record.socket.id)) {
      throw StateError('TERMINAL_HISTORY_UNVERIFIED');
    }
    final openIndex = workspace.value.tabs.indexWhere(
      (tab) => tab.id == record.id,
    );
    if (openIndex >= 0) {
      selectTab(openIndex);
      final tab = workspace.value.tabs[openIndex];
      if (tab.bridge.state != TerminalConnectionState.connected) {
        await _retryHistoryTab(workspace, tab, record);
      }
      return;
    }
    final client = _clientFor(workspace);
    if (client == null) throw StateError('SSH_DISCONNECTED');
    final epoch = workspace.connectionEpoch;
    final exists = await TerminalSessionBridge.tmuxSessionExists(
      client,
      record.remoteSessionName,
      socket: record.socket,
      identity: record.identity,
    );
    if (!_isCurrent(workspace) ||
        epoch != workspace.connectionEpoch ||
        !identical(client, _clientFor(workspace))) {
      return;
    }
    if (!exists) {
      await _handleMissing(workspace, record, isStartup: isStartup);
      return;
    }
    // A concurrent click may already have opened this record during discovery.
    final alreadyOpen = workspace.value.tabs.indexWhere(
      (tab) => tab.id == record.id,
    );
    if (alreadyOpen >= 0) {
      selectTab(alreadyOpen);
      return;
    }
    if (isStartup && workspace.value.tabs.isNotEmpty) return;
    final tab = _createTab(
      record.title,
      serverName: workspace.server.name,
      serverId: workspace.server.id,
      terminalId: record.id,
      sshClient: client,
      preferTmux: true,
      sessionIntent: TerminalSessionIntent.restoreExisting,
      tmuxSessionName: record.remoteSessionName,
      tmuxSocket: record.socket,
      tmuxIdentity: record.identity,
    );
    workspace.startupApplied = true;
    _appendTab(workspace, tab);
    await _startTab(workspace, tab);
    if (!_isCurrent(workspace)) return;
    if (tab.bridge.remoteSessionMissing) {
      // The process can exit between the read-only existence check and attach.
      _removeTab(workspace, tab.id);
      await _handleMissing(workspace, record, isStartup: isStartup);
    } else if (tab.bridge.state != TerminalConnectionState.connected) {
      _publish(
        workspace,
        workspace.value.copyWith(errorCode: 'TERMINAL_RESTORE_FAILED'),
      );
    }
  }

  Future<void> _handleMissing(
    _TerminalWorkspace workspace,
    TerminalHistoryRecord record, {
    required bool isStartup,
  }) async {
    if (!_valid(workspace)) return;
    _publish(
      workspace,
      workspace.value.copyWith(
        historyStatuses: {
          ...workspace.value.historyStatuses,
          record.id: TerminalHistoryStatus.ended,
        },
        noticeCode: isStartup
            ? 'TERMINAL_DEFAULT_MISSING'
            : 'TERMINAL_SESSION_MISSING',
      ),
    );
    if (workspace.value.defaultHistoryId == record.id) {
      await _saveHistory(
        workspace,
        (current) => current.defaultRecordId == record.id
            ? TerminalHistorySnapshot(records: current.records)
            : current,
      );
    }
    if (isStartup && _isCurrent(workspace) && workspace.value.tabs.isEmpty) {
      await _addFresh(workspace);
    }
  }

  Future<void> _retryHistoryTab(
    _TerminalWorkspace workspace,
    TerminalTab tab,
    TerminalHistoryRecord record,
  ) async {
    if (workspace.starting[tab.id] case final Future<void> pending) {
      await pending;
      return;
    }
    final client = _clientFor(workspace);
    if (client == null) throw StateError('SSH_DISCONNECTED');
    final pending = tab.bridge.rebind(client);
    workspace.starting[tab.id] = pending;
    await pending.whenComplete(() => workspace.starting.remove(tab.id));
    if (!_isCurrent(workspace)) return;
    if (tab.bridge.remoteSessionMissing) {
      await _handleMissing(workspace, record, isStartup: false);
    } else if (tab.bridge.state != TerminalConnectionState.connected) {
      _publish(
        workspace,
        workspace.value.copyWith(errorCode: 'TERMINAL_RESTORE_FAILED'),
      );
    } else {
      _publish(workspace, workspace.value.copyWith(clearError: true));
    }
  }

  Future<void> setDefaultHistory(String? id) async {
    final workspace = _current;
    if (workspace == null) return;
    try {
      if (id != null) await refreshHistory();
      if (!_isCurrent(workspace)) {
        throw StateError('TERMINAL_HISTORY_TARGET_CHANGED');
      }
      await _saveHistory(workspace, (current) {
        if (id != null) {
          final record = current.records
              .where((item) => item.id == id)
              .firstOrNull;
          if (record == null ||
              (workspace.value.historyStatuses[id] !=
                      TerminalHistoryStatus.available &&
                  workspace.value.historyStatuses[id] !=
                      TerminalHistoryStatus.open) ||
              workspace.value.hiddenRecordIds.contains(id)) {
            throw StateError('TERMINAL_SESSION_MISSING');
          }
          if (record.isLegacy &&
              workspace.value.historyStatuses[id] !=
                  TerminalHistoryStatus.available &&
              workspace.value.historyStatuses[id] !=
                  TerminalHistoryStatus.open) {
            throw StateError('TERMINAL_HISTORY_UNVERIFIED');
          }
        }
        return TerminalHistorySnapshot(
          records: [
            for (final record in current.records)
              record.id == id ? record.copyWith(isLegacy: false) : record,
          ],
          defaultRecordId: id,
        );
      });
      if (_valid(workspace) &&
          id != null &&
          workspace.value.defaultHistoryId == id &&
          workspace.value.historyStatuses[id] == TerminalHistoryStatus.ended) {
        final record = workspace.value.history
            .where((item) => item.id == id)
            .first;
        await _handleMissing(workspace, record, isStartup: false);
        throw StateError('TERMINAL_SESSION_MISSING');
      }
    } catch (error, stack) {
      if (error is StateError &&
          error.message == 'TERMINAL_HISTORY_TARGET_CHANGED') {
        rethrow;
      }
      _report(workspace, 'TERMINAL_DEFAULT_SAVE_FAILED', error, stack);
      rethrow;
    }
  }

  Future<void> renameTab(String id, String title) async {
    final workspace = _current;
    if (workspace == null) return;
    final validTitle = TerminalHistoryRecord.validateTitle(title);
    if (!workspace.value.tabs.any((tab) => tab.id == id)) return;
    await workspace.saveTail;
    if (!_isCurrent(workspace)) return;
    if (workspace.value.history.any((record) => record.id == id)) {
      await renameHistory(id, validTitle);
      return;
    }
    if (workspace.value.tabs.any(
      (tab) => tab.id == id && tab.bridge.activeTmuxSessionName != null,
    )) {
      throw StateError('TERMINAL_HISTORY_SAVE_FAILED');
    }
    _publish(
      workspace,
      workspace.value.copyWith(
        tabs: [
          for (final tab in workspace.value.tabs)
            tab.id == id ? tab.withTitle(validTitle) : tab,
        ],
      ),
    );
  }

  Future<void> renameHistory(String id, String title) async {
    final workspace = _current;
    if (workspace == null) return;
    final validTitle = TerminalHistoryRecord.validateTitle(title);
    if (!workspace.value.history.any((record) => record.id == id)) return;
    try {
      await _saveHistory(
        workspace,
        (current) => TerminalHistorySnapshot(
          records: [
            for (final record in current.records)
              record.id == id
                  ? record.copyWith(title: validTitle, isLegacy: false)
                  : record,
          ],
          defaultRecordId: current.defaultRecordId,
        ),
      );
    } catch (error, stack) {
      _report(workspace, 'TERMINAL_HISTORY_SAVE_FAILED', error, stack);
      rethrow;
    }
  }

  Future<void> deleteHistory(
    String id, {
    bool terminateRemote = false,
    String? expectedTargetKey,
  }) {
    final workspace = _current;
    if (workspace == null) return Future<void>.value();
    if (expectedTargetKey != null && workspace.targetKey != expectedTargetKey) {
      return Future<void>.error(StateError('TERMINAL_HISTORY_TARGET_CHANGED'));
    }
    if (workspace.deleting[id] case final pending?) return pending;
    final pending = _deleteHistory(
      workspace,
      id,
      terminateRemote: terminateRemote,
    );
    workspace.deleting[id] = pending;
    return pending.whenComplete(() => workspace.deleting.remove(id));
  }

  Future<void> _deleteHistory(
    _TerminalWorkspace workspace,
    String id, {
    required bool terminateRemote,
  }) async {
    var terminating = terminateRemote;
    try {
      await workspace.saveTail;
      if (!_isCurrent(workspace)) return;
      final record = workspace.value.history
          .where((item) => item.id == id)
          .firstOrNull;
      if (record == null) return;
      if (record.targetKey != workspace.targetKey ||
          record.serverId != workspace.server.id) {
        throw StateError('TERMINAL_HISTORY_INVALID');
      }
      if (terminateRemote) {
        if (![
          TmuxSocketSource.app.id,
          TmuxSocketSource.standard.id,
          ...workspace.value.socketSources.map((s) => s.id),
        ].contains(record.socket.id)) {
          throw StateError('TERMINAL_HISTORY_UNVERIFIED');
        }
        if (record.identity == null) {
          throw StateError('TERMINAL_HISTORY_UNVERIFIED');
        }
        final client = _clientFor(workspace);
        if (client == null) throw StateError('SSH_DISCONNECTED');
        final epoch = workspace.connectionEpoch;
        bool currentTarget() =>
            _isCurrent(workspace) &&
            epoch == workspace.connectionEpoch &&
            identical(client, _clientFor(workspace));
        final tmuxPath = await TerminalSessionBridge.tmuxExecutable(client);
        if (!currentTarget()) throw StateError('SSH_DISCONNECTED');
        final exists = await TerminalSessionBridge.tmuxSessionExists(
          client,
          record.remoteSessionName,
          tmuxPath: tmuxPath,
          socket: record.socket,
          identity: record.identity,
        );
        if (!currentTarget()) throw StateError('SSH_DISCONNECTED');
        if (exists) {
          await TerminalSessionBridge.terminateTmuxSession(
            client,
            record.remoteSessionName,
            tmuxPath: tmuxPath,
            socket: record.socket,
            identity: record.identity,
          );
        }
        terminating = false;
      }
      await _saveHistory(
        workspace,
        (current) => TerminalHistorySnapshot(
          records: current.records
              .map(
                (item) => item.id == id ? item.copyWith(isLegacy: false) : item,
              )
              .toList(),
          defaultRecordId: current.defaultRecordId == id
              ? null
              : current.defaultRecordId,
        ),
        updateHiddenRecordIds: (ids) =>
            terminateRemote ? ids : {...ids, id}.toList(),
      );
      if (!_valid(workspace)) return;
      _publish(
        workspace,
        workspace.value.copyWith(
          historyStatuses: {
            ...workspace.value.historyStatuses,
            if (terminateRemote) id: TerminalHistoryStatus.ended,
          },
        ),
      );
    } catch (error, stack) {
      _report(
        workspace,
        terminating
            ? 'TERMINAL_HISTORY_TERMINATE_FAILED'
            : 'TERMINAL_HISTORY_DELETE_FAILED',
        error,
        stack,
      );
      rethrow;
    }
  }

  /// 新建一个 Mosh 会话标签页。
  ///
  /// [sessionTag] 来自 l10n (`moshSessionTag`)，用作标签标题后缀以区分
  /// SSH 标签页。bootstrap 参数取当前激活服务器的 Mosh 配置；缺省字段
  /// 落到 MoshBootstrapRequest 的内置默认 (`mosh-server` / `60000:61000`)。
  void addMoshTab([String? sessionTag]) {
    final workspace = _current;
    if (workspace == null) return;
    workspace.interactionEpoch++;
    workspace.requested = true;
    workspace.startupApplied = true;
    final activeServer = ref.read(activeServerProvider);
    final index = state.tabs.length + 1;
    final tag = sessionTag ?? 'mosh';
    final serverName = activeServer?.name ?? 'localhost';
    final terminal = Terminal(maxLines: 1500);
    final moshBridge = MoshTerminalBridge(
      terminal: terminal,
      sessionService: ref.read(moshSessionServiceProvider),
      request: MoshBootstrapRequest(
        serverId: activeServer?.id ?? '',
        host: activeServer?.host ?? '',
        serverPath: activeServer?.moshServerPath ?? 'mosh-server',
        portRange: activeServer?.moshPortRange ?? '60000:61000',
      ),
      serverName: serverName,
    );
    final bridge = MoshBridgeAdapter(
      moshBridge: moshBridge,
      terminal: terminal,
      serverName: serverName,
      serverId: activeServer?.id ?? '',
    );
    final tab = TerminalTab(
      id: _uuid.v4(),
      title: 'bash #$index ($tag)',
      terminal: terminal,
      bridge: bridge,
    );

    _appendTab(workspace, tab);
    unawaited(
      _startTab(workspace, tab).catchError((Object error, StackTrace stack) {
        _report(workspace, 'TERMINAL_START_FAILED', error, stack);
      }),
    );
  }

  void closeTab(int index) {
    if (state.tabs.length <= 1 || index < 0 || index >= state.tabs.length) {
      return; // 保留至少一个 Tab
    }
    final workspace = _current;
    workspace?.interactionEpoch++;
    if (workspace != null) _removeTab(workspace, state.tabs[index].id);
  }

  Future<void> closeTabById(
    String id, {
    required String expectedTargetKey,
  }) async {
    final workspace = _current;
    if (workspace == null || workspace.targetKey != expectedTargetKey) {
      throw StateError('TERMINAL_TARGET_CHANGED');
    }
    if (workspace.value.tabs.length <= 1) return;
    if (!workspace.value.tabs.any((tab) => tab.id == id)) return;
    workspace.interactionEpoch++;
    _removeTab(workspace, id);
  }

  Future<void> reconnectTab(
    String id, {
    required String expectedTargetKey,
  }) async {
    final workspace = _current;
    if (workspace == null || workspace.targetKey != expectedTargetKey) {
      throw StateError('TERMINAL_TARGET_CHANGED');
    }
    final tab = workspace.value.tabs.where((tab) => tab.id == id).firstOrNull;
    if (tab == null) return;
    final client = _clientFor(workspace);
    if (client == null) throw StateError('SSH_DISCONNECTED');
    await workspace.starting[id];
    if (!_isCurrent(workspace) ||
        !workspace.value.tabs.contains(tab) ||
        !identical(client, _clientFor(workspace))) {
      throw StateError('TERMINAL_TARGET_CHANGED');
    }
    await tab.bridge.rebind(client);
    if (_isCurrent(workspace)) _syncTmuxOffer();
  }

  void _removeTab(_TerminalWorkspace workspace, String id) {
    final index = workspace.value.tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    final tabToClose = workspace.value.tabs[index];
    final listener = workspace.listeners.remove(id);
    if (listener != null) {
      tabToClose.bridge.stateListenable.removeListener(listener);
    }
    tabToClose.bridge.dispose();

    final newTabs = [...workspace.value.tabs]..removeAt(index);
    final activeClosed = index == workspace.value.activeTabIndex;
    final int newActive;
    if (index < workspace.value.activeTabIndex) {
      newActive = workspace.value.activeTabIndex - 1;
    } else if (workspace.value.activeTabIndex >= newTabs.length) {
      newActive = newTabs.isEmpty ? 0 : newTabs.length - 1;
    } else {
      newActive = workspace.value.activeTabIndex;
    }

    _publish(
      workspace,
      workspace.value.copyWith(
        tabs: newTabs,
        activeTabIndex: newActive,
        clearTmuxInstallOffer: activeClosed,
        historyStatuses: {
          ...workspace.value.historyStatuses,
          if (workspace.value.history.any((record) => record.id == id))
            id: tabToClose.bridge.remoteSessionMissing
                ? TerminalHistoryStatus.ended
                : TerminalHistoryStatus.unknown,
        },
      ),
    );
    if (activeClosed && _isCurrent(workspace)) _syncTmuxOffer();
  }

  void toggleCtrl() {
    HapticFeedback.mediumImpact();
    state = state.copyWith(isCtrlActive: !state.isCtrlActive);
  }

  void toggleAlt() {
    HapticFeedback.mediumImpact();
    state = state.copyWith(isAltActive: !state.isAltActive);
  }

  void sendKey(
    String key, {
    bool isCtrl = false,
    bool isAlt = false,
    bool isShift = false,
  }) {
    final activeTab = state.activeTab;
    if (activeTab != null) {
      activeTab.bridge.sendKey(
        key,
        isCtrl: isCtrl || state.isCtrlActive,
        isAlt: isAlt || state.isAltActive,
        isShift: isShift,
      );
      if (state.isCtrlActive || state.isAltActive) {
        state = state.copyWith(isCtrlActive: false, isAltActive: false);
      }
    }
  }

  void sendCommand(String cmd) {
    final workspace = _current;
    if (workspace == null) return;
    unawaited(_sendCommand(workspace, cmd));
  }

  Future<void> _sendCommand(
    _TerminalWorkspace workspace,
    String command,
  ) async {
    final client = _clientFor(workspace);
    final epoch = workspace.connectionEpoch;
    final interactionEpoch = workspace.interactionEpoch;
    try {
      if (client == null) throw StateError('SSH_DISCONNECTED');
      await ensureInitialized();
      if (!_isCurrent(workspace) ||
          epoch != workspace.connectionEpoch ||
          interactionEpoch != workspace.interactionEpoch ||
          !identical(client, _clientFor(workspace))) {
        return;
      }
      final tab = workspace.value.activeTab;
      if (tab == null) throw StateError('TERMINAL_NOT_READY');
      await workspace.starting[tab.id];
      if (!_isCurrent(workspace) ||
          epoch != workspace.connectionEpoch ||
          interactionEpoch != workspace.interactionEpoch ||
          !identical(client, _clientFor(workspace)) ||
          workspace.value.activeTab?.id != tab.id) {
        return;
      }
      if (tab.bridge.state != TerminalConnectionState.connected) {
        throw StateError('TERMINAL_NOT_READY');
      }
      tab.bridge.sendCommand(command);
    } catch (error, stack) {
      _report(workspace, 'TERMINAL_COMMAND_FAILED', error, stack);
    }
  }

  Future<void> pasteClipboard() async {
    final activeTab = state.activeTab;
    if (activeTab != null) {
      await activeTab.bridge.pasteClipboard();
    }
  }

  void pasteText(String text) => state.activeTab?.bridge.pasteText(text);

  /// 重连成功后把每个标签页重新挂到新的 SSH 客户端上。
  ///
  /// 不重新挂的话，标签页会一直握着那个已经死掉的 `SSHClient`：
  /// 界面看起来是活的，实际敲什么都不会有反应。这是断线重连最典型的
  /// 「幽灵终端」现象。
  ///
  /// 用 tmux 承载的会话会自动 attach 回原来的 tmux session，
  /// 所以这里不需要（也不应该）重建 [Terminal] 实例 —— 重建会把
  /// 回滚缓冲全部丢掉，用户就看不到断线前的输出了。
  Future<void> rebindAfterReconnect() async {
    final workspace = _current;
    if (workspace == null || !workspace.requested) return;
    if (workspace.rebinding case final Future<void> pending) {
      final requestedClient = _clientFor(workspace);
      await pending;
      if (_isCurrent(workspace) &&
          requestedClient != null &&
          identical(requestedClient, _clientFor(workspace)) &&
          workspace.value.tabs.any(
            (tab) =>
                tab.bridge is! MoshBridgeAdapter &&
                !identical(tab.bridge.sshClient, requestedClient),
          )) {
        await rebindAfterReconnect();
      }
      return;
    }
    final pending = _rebindWorkspace(workspace).catchError((
      Object error,
      StackTrace stack,
    ) {
      _report(workspace, 'TERMINAL_RESTORE_FAILED', error, stack);
    });
    workspace.rebinding = pending;
    await pending.whenComplete(() => workspace.rebinding = null);
  }

  Future<void> _rebindWorkspace(_TerminalWorkspace workspace) async {
    final client = _clientFor(workspace);
    if (client == null) return;
    if (workspace.value.tabs.isEmpty) {
      await ensureInitialized();
      return;
    }
    final epoch = workspace.connectionEpoch;
    for (final tab in List.of(workspace.value.tabs)) {
      if (!_isCurrent(workspace) ||
          epoch != workspace.connectionEpoch ||
          !identical(client, _clientFor(workspace))) {
        return;
      }
      if (!workspace.value.tabs.any((item) => item.id == tab.id)) continue;
      if (tab.bridge.mode == TerminalSessionMode.tmux &&
          ![
            TmuxSocketSource.app.id,
            TmuxSocketSource.standard.id,
            ...workspace.value.socketSources.map((s) => s.id),
          ].contains(tab.bridge.tmuxSocket.id)) {
        continue;
      }
      try {
        await workspace.starting[tab.id];
      } catch (error, stack) {
        _report(workspace, 'TERMINAL_RESTORE_FAILED', error, stack);
        continue;
      }
      if (!_isCurrent(workspace) || epoch != workspace.connectionEpoch) return;
      await rebindTabsAfterReconnect([tab], client);
      if (!_isCurrent(workspace) || epoch != workspace.connectionEpoch) return;
      if (tab.bridge.plainSessionInterrupted) {
        _publish(
          workspace,
          workspace.value.copyWith(noticeCode: 'TERMINAL_PLAIN_INTERRUPTED'),
        );
      } else if (tab.bridge.remoteSessionMissing) {
        final record = workspace.value.history
            .where((item) => item.id == tab.id)
            .firstOrNull;
        if (record != null) {
          await _handleMissing(workspace, record, isStartup: false);
        }
      }
    }
    if (_isCurrent(workspace)) _syncTmuxOffer();
  }
}

/// 把 [tabs] 逐个重新挂到 [sshClient] 上。
///
/// 单个标签页 rebind 抛异常绝不能拖垮其余标签页（否则第一个坏标签页会让
/// 后面所有标签页都握着死连接）：记录诊断、往该标签页终端写一行诊断信息，
/// 然后继续处理剩下的。遍历用快照，重连期间用户新建/关闭标签页也不会
/// 触发 ConcurrentModificationError。
Future<void> rebindTabsAfterReconnect(
  Iterable<TerminalTab> tabs,
  SSHClient sshClient,
) async {
  for (final tab in List.of(tabs)) {
    try {
      await tab.bridge.rebind(sshClient);
    } catch (error, stack) {
      unawaited(
        AppDiagnostics.instance.record('terminal.rebind', error, stack),
      );
      tab.terminal.write(
        '\r\n\x1b[31m[Reconnect failed for this tab: $error]\x1b[0m\r\n',
      );
    }
  }
}

final terminalProvider = NotifierProvider<TerminalNotifier, SshTerminalState>(
  () {
    return TerminalNotifier();
  },
);
