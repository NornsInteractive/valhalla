import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/layout_breakpoints.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/logging/sanitizer.dart';
import '../../core/providers/commands_provider.dart';
import '../../data/models/quick_command.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';
import '../../widgets/danger_confirm_dialog.dart';
import '../../widgets/state_views.dart';
import '../../widgets/valhalla_card.dart';

class QuickCommandsView extends ConsumerStatefulWidget {
  const QuickCommandsView({super.key});

  @override
  ConsumerState<QuickCommandsView> createState() => _QuickCommandsViewState();
}

class _QuickCommandsViewState extends ConsumerState<QuickCommandsView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isRunningBackground = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCommandDialog() {
    final titleCtrl = TextEditingController();
    final cmdCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Custom');
    final descCtrl = TextEditingController();
    bool isDangerous = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(context.l10n.addCommand),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.commandTitle,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cmdCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.commandContent,
                    hintText: 'e.g. docker stop {{container_id}}',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: catCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.commandCategory,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.commandDescription,
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: Text(context.l10n.cmdDangerous),
                  value: isDangerous,
                  onChanged: (val) =>
                      setDialogState(() => isDangerous = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.isNotEmpty && cmdCtrl.text.isNotEmpty) {
                  final newCmd = QuickCommand(
                    id: const Uuid().v4(),
                    title: titleCtrl.text.trim(),
                    command: cmdCtrl.text.trim(),
                    category: catCtrl.text.trim().isEmpty
                        ? 'Custom'
                        : catCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    isDangerous: isDangerous,
                  );
                  ref.read(commandsProvider.notifier).addCommand(newCmd);
                  Navigator.pop(ctx);
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerCommandExecution(QuickCommand cmd) async {
    final params = cmd.extractParams();
    final paramValues = <String, String>{};

    // 1. 如果需要参数输入，弹出参数填写框
    if (params.isNotEmpty) {
      final controllers = {for (var p in params) p: TextEditingController()};
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.cmdParamRequired),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: params.map((p) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: controllers[p],
                  decoration: InputDecoration(
                    labelText: p,
                    hintText: context.l10n.cmdParamPlaceholder(p),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cmdCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      );

      if (ok != true) return;
      for (final p in params) {
        paramValues[p] = controllers[p]!.text.trim();
      }
    }

    final finalCmd = cmd.applyParams(paramValues);

    // 2. 命令安全校验与高危确认 (DangerConfirmDialog)
    if (!mounted) return;
    final confirmed = await DangerConfirmDialog.show(
      context,
      command: finalCmd,
      forceShow: cmd.isDangerous,
    );
    if (!confirmed) return;

    // 3. 选择执行通道：终端直通 或 后台运行
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.cmdExecutionChannel,
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.terminal),
                title: Text(context.l10n.cmdChannelTerminal),
                subtitle: Text(context.l10n.cmdChannelTerminalDesc),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(commandsProvider.notifier)
                      .executeInTerminal(cmd, paramValues);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.cmdInjectedToTerminal)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(context.l10n.cmdChannelBackground),
                subtitle: Text(context.l10n.cmdChannelBackgroundDesc),
                onTap: _isRunningBackground
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        _runBackgroundAndShowResult(cmd, paramValues);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runBackgroundAndShowResult(
    QuickCommand cmd,
    Map<String, String> params,
  ) async {
    if (_isRunningBackground) return;
    _isRunningBackground = true;

    final navigator = Navigator.of(context, rootNavigator: true);
    final loadingRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        key: const Key('cmd_loading_dialog'),
        child: Card(
          child: LoadingStateView(
            message: context.l10n.cmdExecutingRemote,
          ),
        ),
      ),
    );

    navigator.push(loadingRoute);

    void dismissLoading() {
      if (loadingRoute.isActive) {
        navigator.removeRoute(loadingRoute);
      }
    }

    try {
      final result = await ref
          .read(commandsProvider.notifier)
          .executeBackground(cmd, params);

      dismissLoading();
      if (!mounted) return;
      _showResultDialog(result);
    } catch (e) {
      dismissLoading();
      if (!mounted) return;
      _showResultDialog(
        SSHExecutionResult(
          exitCode: -1,
          stdout: '',
          stderr: LogSanitizer.sanitize(e.toString()),
        ),
      );
    } finally {
      _isRunningBackground = false;
    }
  }

  void _showResultDialog(SSHExecutionResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('cmd_result_dialog'),
        title: Row(
          children: [
            Icon(
              result.isSuccess ? Icons.check_circle : Icons.error,
              color: result.isSuccess
                  ? context.vSuccess
                  : context.vDanger,
            ),
            const SizedBox(width: 8),
            Text(
              result.isSuccess
                  ? context.l10n.cmdExecutionCompleted
                  : context.l10n.cmdExecutionFailed,
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.stateExitCode(result.exitCode),
                  style: monoTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (result.stdout.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    key: const Key('cmd_result_stdout'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F141C),
                      borderRadius: BorderRadius.circular(VRadius.input),
                    ),
                    child: Text(
                      result.stdout,
                      style: monoTextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
                if (result.stderr.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    key: const Key('cmd_result_stderr'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1014),
                      borderRadius: BorderRadius.circular(VRadius.input),
                      border: Border.all(
                        color: context.vDanger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      result.stderr,
                      style: monoTextStyle(
                        fontSize: 12,
                        color: const Color(0xFFFCA5A5),
                      ),
                    ),
                  ),
                ],
                if (result.stdout.isEmpty && result.stderr.isEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F141C),
                      borderRadius: BorderRadius.circular(VRadius.input),
                    ),
                    child: Text(
                      '(No Output)',
                      style: monoTextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cmdClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cmdState = ref.watch(commandsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(context.l10n.addCommand),
        onPressed: _showAddCommandDialog,
      ),
      body: Column(
        children: [
          // 搜索与过滤
          Entrance(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                onChanged: (val) =>
                    ref.read(commandsProvider.notifier).setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'Search commands or tags...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VRadius.input),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),

          // 分类 Chip 列表
          Entrance(
            index: 1,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: cmdState.categories.map((cat) {
                  final isSelected = cmdState.selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(cat),
                      onSelected: (_) =>
                          ref.read(commandsProvider.notifier).setCategory(cat),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // 指令列表
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < LayoutBreakpoints.compactMax) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cmdState.filteredCommands.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final cmd = cmdState.filteredCommands[index];
                      return _buildCommandCard(context, cmd);
                    },
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent:
                        LayoutBreakpoints.gridCommandCardMaxExtent,
                    mainAxisExtent: 88,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: cmdState.filteredCommands.length,
                  itemBuilder: (context, index) {
                    final cmd = cmdState.filteredCommands[index];
                    return _buildCommandCard(context, cmd, isGrid: true);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandCard(
    BuildContext context,
    QuickCommand cmd, {
    bool isGrid = false,
  }) {
    final danger = context.vDanger;
    return ValhallaCard(
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.all(4),
      borderColor: cmd.isDangerous ? danger.withValues(alpha: 0.55) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cmd.isDangerous
              ? danger.withValues(alpha: 0.15)
              : context.colorScheme.primaryContainer,
          child: Icon(
            cmd.isDangerous ? Icons.warning : Icons.terminal,
            color: cmd.isDangerous ? danger : context.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                cmd.title,
                style: context.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (cmd.isDangerous) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: danger,
                  borderRadius: BorderRadius.circular(VRadius.pill),
                ),
                child: const Text(
                  'HIGH RISK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              cmd.description,
              style: context.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              cmd.command,
              style: monoTextStyle(
                fontSize: 11,
                color: context.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: IconButton.filledTonal(
          icon: const Icon(Icons.play_arrow, size: 18),
          tooltip: context.l10n.cmdExecute,
          onPressed: () => _triggerCommandExecution(cmd),
        ),
        onTap: () => _triggerCommandExecution(cmd),
      ),
    );
  }
}
