import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/ai_chat_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/chat_session.dart';
import '../../../data/repositories/chat_repository.dart';

/// 对话历史检索与上下文定位预览对话框。
///
/// 具备两级视图：
/// 1. 检索列表：默认当前会话，可切换当前服务器；300ms防抖、30条游标分页、保留结果与滚动；
/// 2. 上下文定位预览：双向Sliver列表（center锚定目标，目标直接可见且hitTestable，之前消息向上读）；
///    不改变活动会话、草稿与远端上下文；支持工具输出分段加载与关键字高亮，外部网页/邮件链接安全打开，
///    禁止借用当前环境打开 remote-file。
class ChatHistorySearchDialog extends ConsumerStatefulWidget {
  const ChatHistorySearchDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const ChatHistorySearchDialog(),
    );
  }

  @override
  ConsumerState<ChatHistorySearchDialog> createState() =>
      _ChatHistorySearchDialogState();
}

class _ChatHistorySearchDialogState
    extends ConsumerState<ChatHistorySearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _windowScrollController = ScrollController();

  Timer? _debounceTimer;
  bool _allSessions = false;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  String? _searchError;
  List<ChatSearchHit> _hits = [];
  String? _nextCursor;
  int _searchEpoch = 0;
  String _activeQuery = '';

  ChatSearchHit? _selectedHit;
  ChatSession? _windowSession;
  bool _isLoadingWindow = false;
  String? _windowError;

  ChatToolOutputPage? _toolOutputPage;
  int _toolOutputOffset = 0;
  bool _isLoadingToolOutput = false;
  String? _toolOutputError;

  final Set<String> _expandedMessageIds = {};

  @override
  void initState() {
    super.initState();
    _listScrollController.addListener(_onListScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _listScrollController.removeListener(_onListScroll);
    _listScrollController.dispose();
    _windowScrollController.dispose();
    super.dispose();
  }

  void _onListScroll() {
    if (!_listScrollController.hasClients) return;
    final maxScroll = _listScrollController.position.maxScrollExtent;
    final currentScroll = _listScrollController.offset;
    if (maxScroll - currentScroll <= 200) {
      _loadMore();
    }
  }

  void _onQueryChanged(String query) {
    _searchEpoch++;
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _activeQuery = '';
        _hits = [];
        _nextCursor = null;
        _isSearching = false;
        _isLoadingMore = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query, reset: true);
    });
  }

  void _onScopeChanged(bool allSessions) {
    if (_allSessions == allSessions) return;
    setState(() {
      _allSessions = allSessions;
    });
    _searchEpoch++;
    _debounceTimer?.cancel();
    _performSearch(_searchController.text, reset: true);
  }

  void _handleScopeInvalidated() {
    _searchEpoch++;
    _debounceTimer?.cancel();
    if (mounted) {
      setState(() {
        _selectedHit = null;
        _windowSession = null;
        _hits.clear();
        _nextCursor = null;
        _isSearching = false;
        _isLoadingMore = false;
        _isLoadingWindow = false;
        _searchError = context.l10n.chatSearchTargetChanged;
      });
    }
  }

  Future<void> _performSearch(String query, {bool reset = true}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _activeQuery = '';
        _hits = [];
        _nextCursor = null;
        _isSearching = false;
        _isLoadingMore = false;
        _searchError = null;
      });
      return;
    }

    final epoch = ++_searchEpoch;
    final notifier = ref.read(aiChatProvider.notifier);
    final target = notifier.workspaceSelectionKey;

    if (reset) {
      setState(() {
        _isSearching = true;
        _activeQuery = trimmed;
        _searchError = null;
        _nextCursor = null;
      });
    }

    try {
      final page = await notifier.searchMessages(
        trimmed,
        allSessions: _allSessions,
        cursor: reset ? null : _nextCursor,
        expectedTarget: target,
      );

      if (!mounted || epoch != _searchEpoch) return;

      setState(() {
        if (reset) {
          _hits = List.of(page.hits);
        } else {
          _hits.addAll(page.hits);
        }
        _nextCursor = page.nextCursor;
        _isSearching = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || epoch != _searchEpoch) return;
      setState(() {
        _isSearching = false;
        _isLoadingMore = false;
        _hits = [];
        if (e is StateError && e.message == 'ACP_TARGET_CHANGED') {
          _searchError = context.l10n.chatSearchTargetChanged;
        } else {
          _searchError = e.toString();
        }
      });
    }
  }

  Future<void> _loadMore() async {
    if (_nextCursor == null ||
        _isLoadingMore ||
        _isSearching ||
        _activeQuery.isEmpty) {
      return;
    }
    setState(() => _isLoadingMore = true);
    await _performSearch(_activeQuery, reset: false);
  }

  Future<void> _loadWindow(ChatSearchHit hit) async {
    final notifier = ref.read(aiChatProvider.notifier);
    final target = notifier.workspaceSelectionKey;

    setState(() {
      _isLoadingWindow = true;
      _windowError = null;
      _windowSession = null;
      _toolOutputPage = null;
      _toolOutputOffset = 0;
      _toolOutputError = null;
    });

    try {
      final session = await notifier.loadSearchWindow(
        hit,
        expectedTarget: target,
      );

      if (!mounted || _selectedHit != hit) return;

      if (session == null) {
        setState(() {
          _isLoadingWindow = false;
          _windowError = context.l10n.chatSearchNoResults;
        });
        return;
      }

      setState(() {
        _windowSession = session;
        _isLoadingWindow = false;
      });

      if (hit.source == 'tool' && hit.toolId != null) {
        _loadToolOutput(hit, offset: null);
      }
    } catch (e) {
      if (!mounted || _selectedHit != hit) return;
      setState(() {
        _isLoadingWindow = false;
        _windowSession = null;
        if (e is StateError && e.message == 'ACP_TARGET_CHANGED') {
          _windowError = context.l10n.chatSearchTargetChanged;
        } else {
          _windowError = e.toString();
        }
      });
    }
  }

  Future<void> _loadToolOutput(ChatSearchHit hit, {int? offset}) async {
    final notifier = ref.read(aiChatProvider.notifier);
    final target = notifier.workspaceSelectionKey;

    setState(() {
      _isLoadingToolOutput = true;
      _toolOutputError = null;
    });

    try {
      final page = await notifier.loadSearchToolOutput(
        hit,
        expectedTarget: target,
        offset: offset,
      );

      if (!mounted || _selectedHit != hit) return;

      setState(() {
        _toolOutputPage = page;
        _toolOutputOffset =
            offset ?? (hit.matchOffset > 60 ? hit.matchOffset - 60 : 0);
        _isLoadingToolOutput = false;
      });
    } catch (e) {
      if (!mounted || _selectedHit != hit) return;
      setState(() {
        _isLoadingToolOutput = false;
        _toolOutputError = e.toString();
      });
    }
  }

  Future<void> _handleLinkTap(String? href) async {
    if (href == null || href.isEmpty) return;
    if (href.startsWith('remote-file:')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.chatSearchRemoteFileDisabled),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final uri = Uri.tryParse(href);
    if (uri != null &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'mailto')) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.chatFailedToOpenLink),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.chatFailedToOpenLink),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  String _roleLabel(BuildContext context, MessageRole role) {
    switch (role) {
      case MessageRole.user:
        return context.l10n.chatRoleUser;
      case MessageRole.assistant:
        return context.l10n.chatRoleAssistant;
      case MessageRole.system:
        return context.l10n.chatRoleSystem;
    }
  }

  Widget _buildHighlightedExcerpt(
    String excerpt,
    String query,
    BuildContext context, {
    int maxLines = 3,
  }) {
    if (query.isEmpty) {
      return Text(
        excerpt,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final spans = <TextSpan>[];
    final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
    var start = 0;

    for (final match in pattern.allMatches(excerpt)) {
      if (match.start > start) {
        spans.add(TextSpan(text: excerpt.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: excerpt.substring(match.start, match.end),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
      start = match.end;
    }
    if (start < excerpt.length) {
      spans.add(TextSpan(text: excerpt.substring(start)));
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeServerProvider.select((s) => s?.connectionKey), (
      prev,
      next,
    ) {
      if (prev != null && prev != next) {
        _handleScopeInvalidated();
      }
    });
    ref.listen(
      aiChatProvider.select(
        (s) => ref.read(aiChatProvider.notifier).workspaceSelectionKey,
      ),
      (prev, next) {
        if (prev != null && prev != next) {
          _handleScopeInvalidated();
        }
      },
    );
    ref.listen(aiChatProvider.select((s) => s.shareAgentSessions), (
      prev,
      next,
    ) {
      if (prev != null && prev != next) {
        _handleScopeInvalidated();
      }
    });

    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final isDesktop = screenWidth >= 600;
    final horizontalInset = isDesktop ? 24.0 : (screenWidth < 360 ? 4.0 : 12.0);
    final availableWidth = screenWidth - horizontalInset * 2;

    return Dialog(
      key: const Key('chat_history_search_dialog'),
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: isDesktop ? 24 : 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 760 : double.infinity,
          maxHeight: isDesktop ? 700 : double.infinity,
          minWidth: math.min(availableWidth, 320.0),
        ),
        child: _selectedHit == null
            ? _buildSearchListView(context)
            : _buildReaderView(context),
      ),
    );
  }

  Widget _buildSearchListView(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Top search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('chat_search_input'),
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    hintText: context.l10n.chatSearchHint,
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchEpoch++;
                              _debounceTimer?.cancel();
                              _searchController.clear();
                              _onQueryChanged('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VRadius.input),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Scope toggle bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(
                      context.l10n.chatSearchScopeCurrent,
                      style: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 14),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(
                      context.l10n.chatSearchScopeAll,
                      style: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.dns_outlined, size: 14),
                  ),
                ],
                selected: {_allSessions},
                onSelectionChanged: (set) {
                  _onScopeChanged(set.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              if (_hits.isNotEmpty && !_isSearching)
                Text(
                  context.l10n.chatSearchResultsCount(_hits.length.toString()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),

        if (_isSearching)
          const LinearProgressIndicator(minHeight: 2)
        else
          const Divider(height: 1),

        // Results or empty state
        Expanded(
          child: _searchError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _searchError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                )
              : _activeQuery.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.manage_search,
                        size: 48,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.chatSearchNoQuery,
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : _hits.isEmpty && !_isSearching
              ? Center(
                  child: Text(
                    context.l10n.chatSearchNoResults,
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                )
              : IgnorePointer(
                  ignoring: _isSearching,
                  child: ListView.separated(
                    controller: _listScrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _hits.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      if (index == _hits.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final hit = _hits[index];
                      final isTool = hit.source == 'tool';

                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _isSearching
                            ? null
                            : () {
                                setState(() {
                                  _selectedHit = hit;
                                });
                                _loadWindow(hit);
                              },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isTool
                                              ? theme
                                                    .colorScheme
                                                    .tertiaryContainer
                                              : theme
                                                    .colorScheme
                                                    .secondaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          isTool
                                              ? context
                                                    .l10n
                                                    .chatSearchSourceTool
                                              : context
                                                    .l10n
                                                    .chatSearchSourceMessage,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isTool
                                                ? theme
                                                      .colorScheme
                                                      .onTertiaryContainer
                                                : theme
                                                      .colorScheme
                                                      .onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _roleLabel(context, hit.role),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_allSessions &&
                                          hit.title.isNotEmpty) ...[
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 120,
                                          ),
                                          child: Text(
                                            hit.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        _formatDate(hit.createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _buildHighlightedExcerpt(
                                hit.excerpt,
                                _activeQuery,
                                context,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildReaderView(BuildContext context) {
    final theme = Theme.of(context);
    final hit = _selectedHit!;

    return Column(
      children: [
        // Reader navigation header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                tooltip: context.l10n.chatSearchBackToResults,
                onPressed: () {
                  setState(() {
                    _selectedHit = null;
                    _windowSession = null;
                  });
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.chatSearchReaderTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (hit.title.isNotEmpty)
                      Text(
                        hit.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const Key('chat_search_open_session_button'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(
                  context.l10n.chatSearchGoToSession,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  final sessionId = hit.sessionId;
                  Navigator.of(context).pop();
                  ref.read(aiChatProvider.notifier).selectSession(sessionId);
                },
              ),
            ],
          ),
        ),

        // Reader messages view
        Expanded(
          child: _isLoadingWindow
              ? const Center(child: CircularProgressIndicator())
              : _windowError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _windowError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(context.l10n.stateRetry),
                          onPressed: () => _loadWindow(hit),
                        ),
                      ],
                    ),
                  ),
                )
              : _windowSession == null || _windowSession!.messages.isEmpty
              ? Center(
                  child: Text(
                    context.l10n.chatSearchNoResults,
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                )
              : _buildBidirectionalMessagesView(context, hit),
        ),
      ],
    );
  }

  Widget _buildBidirectionalMessagesView(
    BuildContext context,
    ChatSearchHit hit,
  ) {
    final messages = _windowSession!.messages;
    final targetIndex = messages.indexWhere((m) => m.id == hit.messageId);

    if (targetIndex < 0) {
      return ListView.builder(
        controller: _windowScrollController,
        padding: const EdgeInsets.all(12),
        itemCount: messages.length,
        itemBuilder: (ctx, i) => _buildReaderMessageItem(
          ctx,
          messages[i],
          isTarget: false,
          hit: hit,
        ),
      );
    }

    final beforeMessages = messages.sublist(0, targetIndex);
    final targetMessage = messages[targetIndex];
    final afterMessages = messages.sublist(targetIndex + 1);

    return CustomScrollView(
      controller: _windowScrollController,
      center: const ValueKey('search_reader_target_sliver'),
      slivers: [
        if (beforeMessages.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((ctx, i) {
                final msg = beforeMessages[beforeMessages.length - 1 - i];
                return _buildReaderMessageItem(
                  ctx,
                  msg,
                  isTarget: false,
                  hit: hit,
                );
              }, childCount: beforeMessages.length),
            ),
          ),
        SliverPadding(
          key: const ValueKey('search_reader_target_sliver'),
          padding: EdgeInsets.fromLTRB(
            12,
            beforeMessages.isEmpty ? 12 : 0,
            12,
            afterMessages.isEmpty ? 12 : 0,
          ),
          sliver: SliverToBoxAdapter(
            child: _buildReaderMessageItem(
              context,
              targetMessage,
              isTarget: true,
              hit: hit,
            ),
          ),
        ),
        if (afterMessages.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((ctx, i) {
                final msg = afterMessages[i];
                return _buildReaderMessageItem(
                  ctx,
                  msg,
                  isTarget: false,
                  hit: hit,
                );
              }, childCount: afterMessages.length),
            ),
          ),
      ],
    );
  }

  Widget _buildReaderMessageItem(
    BuildContext context,
    ChatMessage msg, {
    required bool isTarget,
    required ChatSearchHit hit,
  }) {
    final theme = Theme.of(context);
    final isExpanded = _expandedMessageIds.contains(msg.id);
    final isLongContent = msg.content.length > 2500;
    final displayContent = isLongContent && !isExpanded
        ? '${msg.content.substring(0, 2400)}\n\n...'
        : msg.content;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTarget
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerLowest,
        border: Border.all(
          color: isTarget
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isTarget ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                msg.role == MessageRole.user
                    ? Icons.person
                    : msg.role == MessageRole.assistant
                    ? Icons.smart_toy
                    : Icons.build_circle,
                size: 16,
                color: isTarget
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                _roleLabel(context, msg.role),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isTarget
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              if (msg.content.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy, size: 14),
                  tooltip: context.l10n.chatCodeCopied,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: msg.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.chatCodeCopied),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 8),
              Text(
                _formatDate(msg.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (msg.content.isNotEmpty) ...[
            MarkdownBody(
              data: displayContent,
              selectable: true,
              onTapLink: (text, href, title) => _handleLinkTap(href),
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (isTarget &&
                isLongContent &&
                !isExpanded &&
                hit.excerpt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.search,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.chatSearchSourceMessage,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildHighlightedExcerpt(
                      hit.excerpt,
                      _activeQuery,
                      context,
                      maxLines: 10,
                    ),
                  ],
                ),
              ),
            ],
            if (isLongContent)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                  ),
                  label: Text(
                    isExpanded
                        ? context.l10n.chatCollapseCode
                        : context.l10n.agentExpandDetails,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedMessageIds.remove(msg.id);
                      } else {
                        _expandedMessageIds.add(msg.id);
                      }
                    });
                  },
                ),
              ),
          ],

          if (isTarget && hit.source == 'tool' && hit.toolId != null) ...[
            const SizedBox(height: 12),
            _buildToolOutputViewer(context, hit),
          ],
        ],
      ),
    );
  }

  Widget _buildToolOutputViewer(BuildContext context, ChatSearchHit hit) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.terminal,
                  size: 14,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.chatSearchSourceTool,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
                const Spacer(),
                if (_toolOutputOffset > 0)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: const Icon(Icons.arrow_upward, size: 12),
                    label: const Text('Prev', style: TextStyle(fontSize: 11)),
                    onPressed: _isLoadingToolOutput
                        ? null
                        : () {
                            final prev = _toolOutputOffset > 4096
                                ? _toolOutputOffset - 4096
                                : 0;
                            _loadToolOutput(hit, offset: prev);
                          },
                  ),
                if (_toolOutputPage?.nextOffset != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: const Icon(Icons.arrow_downward, size: 12),
                    label: const Text('Next', style: TextStyle(fontSize: 11)),
                    onPressed: _isLoadingToolOutput
                        ? null
                        : () {
                            _loadToolOutput(
                              hit,
                              offset: _toolOutputPage!.nextOffset,
                            );
                          },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_isLoadingToolOutput)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_toolOutputError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _toolOutputError!,
                style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
              ),
            )
          else if (_toolOutputPage != null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText.rich(
                  TextSpan(
                    style: monoTextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface,
                    ),
                    children: _buildToolOutputSpans(
                      _toolOutputPage!.text,
                      _activeQuery,
                      theme,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<TextSpan> _buildToolOutputSpans(
    String text,
    String query,
    ThemeData theme,
  ) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }
    final spans = <TextSpan>[];
    final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
    var start = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            backgroundColor: theme.colorScheme.primaryContainer,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return spans;
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$mo-$d $h:$m';
  }
}
