import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../infrastructure/acp/acp_client_adapter.dart';

class ChatCommandsSkillsDialog extends StatefulWidget {
  final List<AcpSlashCommand> commands;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onPickWorkingDirectory;
  final Future<List<AcpSlashCommand>?> Function()? onRetry;
  final bool isLoading;
  final String? errorMessage;

  const ChatCommandsSkillsDialog({
    super.key,
    required this.commands,
    this.onOpenSettings,
    this.onPickWorkingDirectory,
    this.onRetry,
    this.isLoading = false,
    this.errorMessage,
  });

  static Future<AcpSlashCommand?> show(
    BuildContext context, {
    required List<AcpSlashCommand> commands,
    VoidCallback? onOpenSettings,
    VoidCallback? onPickWorkingDirectory,
    Future<List<AcpSlashCommand>?> Function()? onRetry,
    bool isLoading = false,
    String? errorMessage,
  }) {
    return showDialog<AcpSlashCommand?>(
      context: context,
      builder: (ctx) => ChatCommandsSkillsDialog(
        commands: commands,
        onOpenSettings: onOpenSettings,
        onPickWorkingDirectory: onPickWorkingDirectory,
        onRetry: onRetry,
        isLoading: isLoading,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  State<ChatCommandsSkillsDialog> createState() =>
      _ChatCommandsSkillsDialogState();
}

class _ChatCommandsSkillsDialogState extends State<ChatCommandsSkillsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRetrying = false;
  late List<AcpSlashCommand> _commands;
  String? _retryError;
  bool _hasRetriedSuccessfully = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _commands = widget.commands;
  }

  @override
  void didUpdateWidget(ChatCommandsSkillsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.commands != oldWidget.commands) {
      _commands = widget.commands;
    }
    if (widget.errorMessage != oldWidget.errorMessage) {
      _hasRetriedSuccessfully = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? get _effectiveError {
    final err = _hasRetriedSuccessfully
        ? _retryError
        : (_retryError ?? widget.errorMessage);
    if (err == null || !err.startsWith('AGENT_COMPOSER_QUERY_FAILED')) {
      return null;
    }
    return err;
  }

  Future<void> _handleRetry() async {
    if (widget.onRetry == null || _isRetrying) return;
    setState(() {
      _isRetrying = true;
      _retryError = null;
    });
    try {
      final updated = await widget.onRetry!();
      if (mounted) {
        if (updated != null) {
          setState(() {
            _commands = updated;
            _retryError = null;
            _hasRetriedSuccessfully = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _retryError = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = _commands;
    final query = _searchQuery.toLowerCase();

    final filtered = query.isEmpty
        ? all
        : all
              .where(
                (c) =>
                    c.name.toLowerCase().contains(query) ||
                    c.description.toLowerCase().contains(query) ||
                    (c.hint != null && c.hint!.toLowerCase().contains(query)),
              )
              .toList();

    final commands = filtered.where((c) => !c.isSkill).toList();
    final skills = filtered.where((c) => c.isSkill).toList();

    return Dialog(
      key: const Key('chat_commands_skills_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Column(
          children: [
            // Search header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('chat_commands_search_input'),
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: context.l10n.chatSearchCommandsHint,
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(VRadius.input),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab bar: Commands vs Skills
            TabBar(
              controller: _tabController,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.terminal, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${context.l10n.chatCommandsTab} (${commands.length})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${context.l10n.chatSkillsTab} (${skills.length})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 1),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCommandList(commands, theme, isSkillTab: false),
                  _buildCommandList(skills, theme, isSkillTab: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandList(
    List<AcpSlashCommand> list,
    ThemeData theme, {
    required bool isSkillTab,
  }) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final query = _searchQuery.toLowerCase();
    final clientActions = <_ClientActionItem>[];
    if (!isSkillTab) {
      if (widget.onOpenSettings != null) {
        clientActions.add(
          _ClientActionItem(
            icon: Icons.tune,
            title: context.l10n.chatCommandsClientActionRunSettings,
            onTap: () {
              Navigator.pop(context);
              widget.onOpenSettings!();
            },
          ),
        );
      }
      if (widget.onPickWorkingDirectory != null) {
        clientActions.add(
          _ClientActionItem(
            icon: Icons.folder_outlined,
            title: context.l10n.chatCommandsClientActionWorkingDirectory,
            onTap: () {
              Navigator.pop(context);
              widget.onPickWorkingDirectory!();
            },
          ),
        );
      }
    }

    final matchingClientActions = clientActions.where((a) {
      if (query.isEmpty) return true;
      return a.title.toLowerCase().contains(query);
    }).toList();

    final effectiveError = _effectiveError;
    final hasErrorBanner = effectiveError != null && effectiveError.isNotEmpty;

    if (list.isEmpty && matchingClientActions.isEmpty) {
      final emptyText = _searchQuery.isNotEmpty
          ? context.l10n.stateEmpty
          : (isSkillTab
                ? context.l10n.chatSkillsEmpty
                : context.l10n.chatCommandsFirstTurnNote);
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasErrorBanner) ...[
                Icon(
                  Icons.error_outline,
                  size: 24,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.chatCommandsDiscoveryFailed,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  effectiveError,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                emptyText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('chat_commands_retry_button'),
                  icon: _isRetrying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(context.l10n.refresh),
                  onPressed: _isRetrying ? null : _handleRetry,
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return ListView(
        children: [
          if (hasErrorBanner) _buildErrorBanner(theme, effectiveError),
          ...matchingClientActions.map(
            (action) => ListTile(
              dense: true,
              leading: Icon(
                action.icon,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                action.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: theme.colorScheme.outline,
              ),
              onTap: action.onTap,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(VRadius.input),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.chatCommandsFirstTurnNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.onRetry != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    key: const Key('chat_commands_retry_button'),
                    icon: _isRetrying
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: Text(context.l10n.refresh),
                    onPressed: _isRetrying ? null : _handleRetry,
                  ),
                ),
              ),
          ],
        ],
      );
    }

    final hasDraftPreview = !isSkillTab && list.any((c) => c.isDraftPreview);
    final totalCount = matchingClientActions.length + list.length;
    final listView = ListView.separated(
      itemCount: totalCount,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, index) {
        if (index < matchingClientActions.length) {
          final action = matchingClientActions[index];
          return ListTile(
            dense: true,
            leading: Icon(
              action.icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              action.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: theme.colorScheme.outline,
            ),
            onTap: action.onTap,
          );
        }
        final cmd = list[index - matchingClientActions.length];
        return ListTile(
          dense: true,
          leading: Icon(
            cmd.isSkill ? Icons.auto_awesome : Icons.terminal,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  cmd.name,
                  style: monoTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (cmd.hint != null && cmd.hint!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      cmd.hint!,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: cmd.description.isNotEmpty
              ? Text(
                  cmd.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                )
              : null,
          onTap: () => Navigator.pop(context, cmd),
        );
      },
    );

    if (!hasDraftPreview && !hasErrorBanner) {
      return listView;
    }

    return Column(
      children: [
        if (hasErrorBanner)
          _buildErrorBanner(
            theme,
            effectiveError,
            showRetry: widget.onRetry != null,
          ),
        if (hasDraftPreview) _buildDraftPreviewNotice(theme),
        Expanded(child: listView),
      ],
    );
  }

  Widget _buildDraftPreviewNotice(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        key: const Key('chat_commands_draft_preview_notice'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(VRadius.input),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.chatCommandsDraftPreviewNotice,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(
    ThemeData theme,
    String error, {
    bool showRetry = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        key: const Key('chat_commands_error_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(VRadius.input),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.chatCommandsDiscoveryFailed,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    error,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onErrorContainer.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showRetry) ...[
              const SizedBox(width: 8),
              InkWell(
                key: const Key('chat_commands_retry_button'),
                borderRadius: BorderRadius.circular(4),
                onTap: _isRetrying ? null : _handleRetry,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _isRetrying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.refresh,
                          size: 16,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClientActionItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ClientActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}
