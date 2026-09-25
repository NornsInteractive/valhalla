import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/quick_command.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';
import '../logging/sanitizer.dart';
import 'server_provider.dart';
import 'storage_providers.dart';
import 'terminal_provider.dart';

class CommandsState {
  final List<QuickCommand> allCommands;
  final String selectedCategory;
  final String searchQuery;

  const CommandsState({
    this.allCommands = const [],
    this.selectedCategory = 'All',
    this.searchQuery = '',
  });

  List<String> get categories {
    final cats = allCommands.map((c) => c.category).toSet().toList();
    return ['All', ...cats];
  }

  List<QuickCommand> get filteredCommands {
    var result = allCommands;
    if (selectedCategory != 'All') {
      result = result.where((c) => c.category == selectedCategory).toList();
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result
          .where(
            (c) =>
                c.title.toLowerCase().contains(q) ||
                c.command.toLowerCase().contains(q),
          )
          .toList();
    }
    return result;
  }

  CommandsState copyWith({
    List<QuickCommand>? allCommands,
    String? selectedCategory,
    String? searchQuery,
  }) {
    return CommandsState(
      allCommands: allCommands ?? this.allCommands,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class CommandsNotifier extends Notifier<CommandsState> {
  @override
  CommandsState build() {
    final repo = ref.watch(commandRepositoryProvider);
    return CommandsState(allCommands: repo.getAllCommands());
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> addCommand(QuickCommand cmd) async {
    final repo = ref.read(commandRepositoryProvider);
    await repo.addOrUpdateCommand(cmd);
    state = state.copyWith(allCommands: repo.getAllCommands());
  }

  Future<void> deleteCommand(String id) async {
    final repo = ref.read(commandRepositoryProvider);
    await repo.deleteCommand(id);
    state = state.copyWith(allCommands: repo.getAllCommands());
  }

  /// 方式 A：直通终端执行
  void executeInTerminal(QuickCommand cmd, Map<String, String> params) {
    final finalCmd = cmd.applyParams(params);
    ref.read(terminalProvider.notifier).sendCommand(finalCmd);
  }

  /// 方式 B：后台通过 SSH 独立通道执行
  Future<SSHExecutionResult> executeBackground(
    QuickCommand cmd,
    Map<String, String> params,
  ) async {
    try {
      final finalCmd = cmd.applyParams(params);
      final activeServer = ref.read(activeServerProvider);
      if (activeServer == null) {
        return const SSHExecutionResult(
          exitCode: -1,
          stdout: '',
          stderr: 'No active server selected',
        );
      }
      final sshManager = ref.read(sshClientManagerProvider);
      final client = sshManager.getClient(activeServer.id);
      if (client == null || !sshManager.isConnected(activeServer.id)) {
        throw StateError(
          '服务器 ${activeServer.name} (${activeServer.host}) 尚未建立 SSH 连接，无法在远端执行命令。请先点击顶部连接。',
        );
      }
      final sudoPassword = cmd.requiresSudo
          ? await ref
                .read(serverRepositoryProvider)
                .getSudoPassword(activeServer.id)
          : null;
      // Credentials may finish after a source edit, disconnect, or reconnect.
      // Never dispatch an old action through a replacement client with the same ID.
      if (!ref.mounted ||
          !(ref
                  .read(activeServerProvider)
                  ?.hasSameConnectionSettings(activeServer) ??
              false) ||
          !identical(client, sshManager.getClient(activeServer.id)) ||
          !sshManager.isConnected(activeServer.id)) {
        throw StateError(
          'Command target or connection changed before execution; retry on the selected server.',
        );
      }
      return await sshManager.executeWithLoginShell(
        activeServer.id,
        finalCmd,
        sudoPassword: sudoPassword,
      );
    } catch (error) {
      return SSHExecutionResult(
        exitCode: -1,
        stdout: '',
        stderr: LogSanitizer.sanitize(error.toString()),
      );
    }
  }
}

final commandsProvider = NotifierProvider<CommandsNotifier, CommandsState>(() {
  return CommandsNotifier();
});
