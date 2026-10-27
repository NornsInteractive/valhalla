import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../infrastructure/acp/acp_client_adapter.dart';

enum _CommandFilter { all, favorites, recent }

class _CommandListItem {
  final String id;
  final String name;
  final String? hint;
  final String description;
  final bool isSkill;
  final bool isAvailable;
  final AcpSlashCommand? command;

  const _CommandListItem({
    required this.id,
    required this.name,
    this.hint,
    required this.description,
    required this.isSkill,
    required this.isAvailable,
    this.command,
  });
}

class ChatCommandsSkillsDialog extends StatefulWidget {
  final List<AcpSlashCommand> commands;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onPickWorkingDirectory;
  final Future<List<AcpSlashCommand>?> Function()? onRetry;
  final bool isLoading;
  final String? errorMessage;
  final Set<String> favorites;
  final List<String> recent;
  final Future<void> Function(String id, bool favorite)? onToggleFavorite;

  const ChatCommandsSkillsDialog({
    super.key,
    required this.commands,
    this.onOpenSettings,
    this.onPickWorkingDirectory,
    this.onRetry,
    this.isLoading = false,
    this.errorMessage,
    this.favorites = const <String>{},
    this.recent = const <String>[],
    this.onToggleFavorite,
  });

  static Future<AcpSlashCommand?> show(
    BuildContext context, {
    required List<AcpSlashCommand> commands,
    VoidCallback? onOpenSettings,
    VoidCallback? onPickWorkingDirectory,
    Future<List<AcpSlashCommand>?> Function()? onRetry,
    bool isLoading = false,
    String? errorMessage,
    Set<String> favorites = const <String>{},
    List<String> recent = const <String>[],
    Future<void> Function(String id, bool favorite)? onToggleFavorite,
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
        favorites: favorites,
        recent: recent,
        onToggleFavorite: onToggleFavorite,
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

  late Set<String> _favorites;
  final Set<String> _pendingFavorites = <String>{};
  late List<String> _recent;
  _CommandFilter _filter = _CommandFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _commands = widget.commands;
    _favorites = widget.favorites.toSet();
    _recent = widget.recent.toList();
  }

  @override
  void didUpdateWidget(ChatCommandsSkillsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.commands != oldWidget.commands) {
      _commands = widget.commands;
    }
    if (widget.favorites != oldWidget.favorites) {
      final newFavs = widget.favorites.toSet();
      for (final id in _pendingFavorites) {
        if (_favorites.contains(id)) {
          newFavs.add(id);
        } else {
          newFavs.remove(id);
        }
      }
      _favorites = newFavs;
    }
    if (widget.recent != oldWidget.recent) {
      _recent = widget.recent.toList();
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

  Future<void> _handleToggleFavorite(String id) async {
    if (_pendingFavorites.contains(id)) return;
    final isFav = _favorites.contains(id);
    final nextFav = !isFav;
    setState(() {
      _pendingFavorites.add(id);
      if (nextFav) {
        _favorites.add(id);
      } else {
        _favorites.remove(id);
      }
    });

    if (widget.onToggleFavorite != null) {
      try {
        await widget.onToggleFavorite!(id, nextFav);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          if (isFav) {
            _favorites.add(id);
          } else {
            _favorites.remove(id);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatCommandPreferencesSaveFailed),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _pendingFavorites.remove(id);
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _pendingFavorites.remove(id);
        });
      }
    }
  }

  List<_CommandListItem> _getItemsForTab({required bool isSkillTab}) {
    final prefix = isSkillTab ? 'skill:' : 'command:';
    final availableForTab = _commands
        .where((c) => c.isSkill == isSkillTab)
        .toList();
    final Map<String, AcpSlashCommand> availableById = {
      for (final c in availableForTab)
        (c.isSkill ? 'skill:${c.name}' : 'command:${c.name}'): c,
    };

    List<_CommandListItem> result;
    switch (_filter) {
      case _CommandFilter.all:
        result = availableForTab.map((c) {
          final id = c.isSkill ? 'skill:${c.name}' : 'command:${c.name}';
          return _CommandListItem(
            id: id,
            name: c.name,
            hint: c.hint,
            description: c.description,
            isSkill: c.isSkill,
            isAvailable: true,
            command: c,
          );
        }).toList();
        break;

      case _CommandFilter.favorites:
        final matchingFavs = _favorites
            .where((id) => id.startsWith(prefix))
            .toList();
        result = matchingFavs.map((id) {
          final rawName = id.substring(prefix.length);
          final available = availableById[id];
          if (available != null) {
            return _CommandListItem(
              id: id,
              name: available.name,
              hint: available.hint,
              description: available.description,
              isSkill: available.isSkill,
              isAvailable: true,
              command: available,
            );
          } else {
            return _CommandListItem(
              id: id,
              name: rawName,
              description: '',
              isSkill: isSkillTab,
              isAvailable: false,
              command: null,
            );
          }
        }).toList();
        break;

      case _CommandFilter.recent:
        final matchingRecent = _recent
            .where((id) => id.startsWith(prefix))
            .take(10)
            .toList();
        result = matchingRecent.map((id) {
          final rawName = id.substring(prefix.length);
          final available = availableById[id];
          if (available != null) {
            return _CommandListItem(
              id: id,
              name: available.name,
              hint: available.hint,
              description: available.description,
              isSkill: available.isSkill,
              isAvailable: true,
              command: available,
            );
          } else {
            return _CommandListItem(
              id: id,
              name: rawName,
              description: '',
              isSkill: isSkillTab,
              isAvailable: false,
              command: null,
            );
          }
        }).toList();
        break;
    }

    final query = _searchQuery.toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((it) {
        return it.name.toLowerCase().contains(query) ||
            it.description.toLowerCase().contains(query) ||
            (it.hint != null && it.hint!.toLowerCase().contains(query));
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commandItems = _getItemsForTab(isSkillTab: false);
    final skillItems = _getItemsForTab(isSkillTab: true);

    final favCount = _favorites.length;
    final recentCount = _recent.take(10).length;

    return Dialog(
      key: const Key('chat_commands_skills_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 540),
        child: Column(
          children: [
            // Search header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
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

            // Filter bar: All / Favorites / Recent
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_CommandFilter>(
                  segments: [
                    ButtonSegment(
                      value: _CommandFilter.all,
                      label: Text(
                        context.l10n.chatCommandFilterAll,
                        style: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.list, size: 14),
                    ),
                    ButtonSegment(
                      value: _CommandFilter.favorites,
                      label: Text(
                        favCount > 0
                            ? '${context.l10n.chatCommandFilterFavorites} ($favCount)'
                            : context.l10n.chatCommandFilterFavorites,
                        style: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.star, size: 14),
                    ),
                    ButtonSegment(
                      value: _CommandFilter.recent,
                      label: Text(
                        recentCount > 0
                            ? '${context.l10n.chatCommandFilterRecent} ($recentCount)'
                            : context.l10n.chatCommandFilterRecent,
                        style: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.history, size: 14),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (set) {
                    setState(() => _filter = set.first);
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 2),

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
                          '${context.l10n.chatCommandsTab} (${commandItems.length})',
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
                          '${context.l10n.chatSkillsTab} (${skillItems.length})',
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
                  _buildCommandList(commandItems, theme, isSkillTab: false),
                  _buildCommandList(skillItems, theme, isSkillTab: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandList(
    List<_CommandListItem> list,
    ThemeData theme, {
    required bool isSkillTab,
  }) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final query = _searchQuery.toLowerCase();
    final clientActions = <_ClientActionItem>[];
    if (!isSkillTab && _filter == _CommandFilter.all) {
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
      String emptyText;
      if (_searchQuery.isNotEmpty) {
        emptyText = context.l10n.stateEmpty;
      } else if (_filter == _CommandFilter.favorites) {
        emptyText = context.l10n.stateEmpty;
      } else if (_filter == _CommandFilter.recent) {
        emptyText = context.l10n.stateEmpty;
      } else {
        emptyText = isSkillTab
            ? context.l10n.chatSkillsEmpty
            : context.l10n.chatCommandsFirstTurnNote;
      }

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

    final hasDraftPreview =
        !isSkillTab &&
        list.any((c) => c.command != null && c.command!.isDraftPreview);
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
        final item = list[index - matchingClientActions.length];
        final isFav = _favorites.contains(item.id);
        final isPending = _pendingFavorites.contains(item.id);

        return ListTile(
          dense: true,
          enabled: item.isAvailable,
          leading: Icon(
            item.isSkill ? Icons.auto_awesome : Icons.terminal,
            size: 18,
            color: item.isAvailable
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  item.name,
                  style: monoTextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: item.isAvailable
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.hint != null && item.hint!.isNotEmpty) ...[
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
                      item.hint!,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              if (!item.isAvailable) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.l10n.chatCommandUnavailable,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: item.isAvailable
              ? (item.description.isNotEmpty
                    ? Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      )
                    : null)
              : Text(
                  context.l10n.chatCommandUnavailable,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.outline.withValues(alpha: 0.7),
                  ),
                ),
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: isPending ? () {} : null,
            child: IconButton(
              icon: Icon(
                isFav ? Icons.star : Icons.star_border,
                size: 18,
                color: isFav ? Colors.amber : theme.colorScheme.outline,
              ),
              tooltip: isFav
                  ? context.l10n.chatCommandFavoriteRemove
                  : context.l10n.chatCommandFavoriteAdd,
              onPressed: isPending
                  ? null
                  : () => _handleToggleFavorite(item.id),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
          ),
          onTap: item.isAvailable
              ? () => Navigator.pop(context, item.command)
              : null,
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
