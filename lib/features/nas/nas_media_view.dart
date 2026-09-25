import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/providers/nas_metadata_provider.dart';
import '../../core/providers/nas_provider.dart';
import '../../core/providers/nas_sources_provider.dart';
import '../../core/providers/storage_providers.dart';
import '../../core/services/nas_download_service.dart';
import '../../core/services/nas_metadata_service.dart';
import '../../data/models/nas_media.dart';
import '../../data/models/nas_source.dart';
import '../../data/repositories/nas_index_repository.dart';
import '../../infrastructure/sftp/sftp_client_service.dart';
import '../shell/main_shell.dart';
import 'widgets/nas_cast_sheet.dart';
import 'widgets/nas_downloads_sheet.dart';
import 'widgets/nas_full_player_dialog.dart';
import 'widgets/nas_image_viewer_dialog.dart';
import 'widgets/nas_install_dialog.dart';
import 'widgets/nas_library_settings_dialog.dart';
import 'widgets/nas_localizations.dart';
import 'widgets/nas_mini_player.dart';
import 'widgets/nas_scan_config_dialog.dart';
import 'widgets/nas_source_dialog.dart';

enum NasMediaTab {
  home,
  photos,
  videos,
  music,
  folders,
  favorites,
  playlists,
  downloads,
}

class NasMediaView extends ConsumerStatefulWidget {
  const NasMediaView({super.key});

  @override
  ConsumerState<NasMediaView> createState() => _NasMediaViewState();
}

class _NasMediaViewState extends ConsumerState<NasMediaView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  NasMediaTab _currentTab = NasMediaTab.home;
  NasOpenPolicy _openPolicy = NasOpenPolicy.external;

  // Music surface sub-view: tracks, artists, albums
  NasIndexGroup? _musicGroup;
  List<NasIndexGroupCount> _musicGroups = [];
  bool _loadingGroups = false;
  bool _hasMoreMusicGroups = false;
  int _musicPageIndex = 0;
  final List<String?> _musicCursorHistory = [null];

  // Folders surface groups
  List<NasIndexGroupCount> _folderGroups = [];
  bool _loadingFolders = false;
  bool _hasMoreFolderGroups = false;
  int _folderPageIndex = 0;
  final List<String?> _folderCursorHistory = [null];

  int _groupLoadGeneration = 0;
  bool _miniPlayerCommandInProgress = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  NasOpenPolicy _getOpenPolicy(NasMediaKind kind) {
    try {
      return ref.read(localStorageServiceProvider).getNasOpenPolicy(kind);
    } catch (_) {
      return _openPolicy;
    }
  }

  Future<void> _setOpenPolicy(NasMediaKind kind, NasOpenPolicy policy) async {
    setState(() => _openPolicy = policy);
    try {
      await ref.read(nasProvider.notifier).setOpenPolicy(kind, policy);
    } catch (_) {}
  }

  Future<void> _openExternal(NasMediaItem item) async {
    try {
      ref.read(nasProvider.notifier).openExternal(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.nasMediaOpening(item.name)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.nasSanitizedError(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _handleItemTap(NasMediaItem item) {
    final policy = _getOpenPolicy(item.kind);
    switch (policy) {
      case NasOpenPolicy.external:
        _openExternal(item);
        break;
      case NasOpenPolicy.inApp:
        _openInApp(item);
        break;
      case NasOpenPolicy.askEveryTime:
        _showAskOpenMethodSheet(item);
        break;
    }
  }

  Future<void> _openInApp(NasMediaItem item) async {
    if (item.kind == NasMediaKind.image) {
      final images = ref
          .read(nasProvider)
          .items
          .where((i) => i.kind == NasMediaKind.image)
          .toList();
      final idx = images.indexWhere((i) => i.path == item.path);
      NasImageViewerDialog.show(
        context,
        item: item,
        items: images,
        initialIndex: idx >= 0 ? idx : 0,
        thumbnailFuture: ref.read(nasProvider.notifier).thumbnailPath(item),
        isFavorite: item.isFavorite,
        onToggleFavorite: () => _toggleFavorite(item),
        onOpenExternal: () => _openExternal(item),
      );
      return;
    }

    // Audio or Video
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.nasMediaOpening(item.name)),
        duration: const Duration(seconds: 3),
      ),
    );

    try {
      await ref.read(nasProvider.notifier).openInApp(item);
      if (!mounted) return;

      final playerService = ref.read(nasMediaPlayerProvider).asData?.value;
      final player = playerService?.player;

      if (item.kind == NasMediaKind.video) {
        _showFullPlayer(item, player);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.nasSanitizedError(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showFullPlayer(NasMediaItem item, [dynamic player]) {
    final playerService = ref.read(nasMediaPlayerProvider).asData?.value;
    final playbackSnapshot = ref.read(nasPlaybackProvider).asData?.value;
    final isPlaying =
        playbackSnapshot?.playing ?? (player?.state.playing ?? false);
    final position = playbackSnapshot?.position ?? Duration.zero;
    final duration =
        playbackSnapshot?.duration ?? (item.duration ?? Duration.zero);
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    NasFullPlayerDialog.show(
      context,
      item: item,
      player: player,
      isPlaying: isPlaying,
      progress: progress,
      onPlayPause: (val) async {
        try {
          if (playerService != null) {
            await playerService.playOrPause();
          } else if (player != null) {
            if (val) {
              await player.play();
            } else {
              await player.pause();
            }
          }
        } catch (_) {}
      },
      onSeek: (val) async {
        try {
          if (playerService != null) {
            final d = playbackSnapshot?.duration ?? Duration.zero;
            if (d > Duration.zero) {
              await playerService.seek(d * val);
            }
          } else if (player != null && player.state.duration > Duration.zero) {
            await player.seek(player.state.duration * val);
          }
        } catch (_) {}
      },
      onOpenExternal: () => _openExternal(item),
      isFavorite: item.isFavorite,
      onToggleFavorite: () => _toggleFavorite(item),
    );
  }

  void _showAskOpenMethodSheet(NasMediaItem item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  context.l10n.nasOpenMethodPrompt,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                key: const Key('nas_ask_sheet_in_app'),
                leading: const Icon(Icons.visibility),
                title: Text(context.l10n.nasOpenPolicyInApp),
                onTap: () {
                  Navigator.pop(ctx);
                  _openInApp(item);
                },
              ),
              ListTile(
                key: const Key('nas_ask_sheet_external'),
                leading: const Icon(Icons.open_in_new),
                title: Text(context.l10n.nasOpenPolicyExternal),
                onTap: () {
                  Navigator.pop(ctx);
                  _openExternal(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(NasMediaItem item) async {
    try {
      await ref.read(nasProvider.notifier).setFavorite(item, !item.isFavorite);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.nasSanitizedError(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showCreatePlaylistDialog() {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.nasCreatePlaylist),
        content: TextField(
          key: const Key('nas_playlist_name_field'),
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(hintText: context.l10n.nasPlaylistName),
          onSubmitted: (val) {
            final name = val.trim();
            if (name.isNotEmpty) {
              ref.read(nasProvider.notifier).createPlaylist(name);
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('nas_create_playlist_confirm_button'),
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                ref.read(nasProvider.notifier).createPlaylist(name);
              }
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showRenamePlaylistDialog(NasPlaylist playlist) {
    final textController = TextEditingController(text: playlist.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.nasRenamePlaylist),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(hintText: context.l10n.nasPlaylistName),
          onSubmitted: (val) {
            final name = val.trim();
            if (name.isNotEmpty) {
              ref.read(nasProvider.notifier).renamePlaylist(playlist.id, name);
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(nasProvider.notifier)
                    .renamePlaylist(playlist.id, name);
              }
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(NasMediaItem item) {
    final playlists = ref.read(nasProvider).playlists;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.nasNoPlaylists)));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.nasTabPlaylists,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(height: 1),
            for (final playlist in playlists)
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(playlist.name),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(nasProvider.notifier)
                      .addToPlaylist(
                        playlistId: playlist.id,
                        item: item,
                        position: 0,
                      );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _formatEpoch(int epoch) {
    if (epoch <= 0) return '-';
    return _formatDateTime(DateTime.fromMillisecondsSinceEpoch(epoch * 1000));
  }

  void _selectTab(NasMediaTab tab) {
    _groupLoadGeneration++;
    setState(() {
      _currentTab = tab;
      _musicGroup = null;
      _folderGroups = [];
      _folderPageIndex = 0;
      _folderCursorHistory
        ..clear()
        ..add(null);
      _hasMoreFolderGroups = false;
      _musicGroups = [];
      _musicPageIndex = 0;
      _musicCursorHistory
        ..clear()
        ..add(null);
      _hasMoreMusicGroups = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    final notifier = ref.read(nasProvider.notifier);
    switch (tab) {
      case NasMediaTab.home:
      case NasMediaTab.folders:
      case NasMediaTab.playlists:
      case NasMediaTab.downloads:
        notifier.setFilter(null);
        break;
      case NasMediaTab.photos:
        notifier.setFilter(NasMediaKind.image);
        break;
      case NasMediaTab.videos:
        notifier.setFilter(NasMediaKind.video);
        break;
      case NasMediaTab.music:
        notifier.setFilter(NasMediaKind.audio);
        break;
      case NasMediaTab.favorites:
        notifier.setFavoritesOnly(true);
        break;
    }

    if (tab == NasMediaTab.folders) {
      _loadFolderGroupsPage();
    }
  }

  Future<void> _loadFolderGroupsPage() async {
    final gen = ++_groupLoadGeneration;
    final expectedTab = _currentTab;
    final expectedSource = ref.read(nasSourcesProvider).selected?.id;
    setState(() {
      _loadingFolders = true;
      _hasMoreFolderGroups = false;
    });

    try {
      final after = _folderCursorHistory[_folderPageIndex];
      final groups = await ref
          .read(nasProvider.notifier)
          .groups(NasIndexGroup.byFolder, after: after);
      if (!mounted ||
          gen != _groupLoadGeneration ||
          _currentTab != expectedTab ||
          ref.read(nasSourcesProvider).selected?.id != expectedSource) {
        return;
      }
      setState(() {
        _folderGroups = groups;
        _hasMoreFolderGroups = groups.length >= 200;
        _loadingFolders = false;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } catch (_) {
      if (mounted && gen == _groupLoadGeneration) {
        setState(() => _loadingFolders = false);
      }
    }
  }

  void _nextFolderGroupsPage() {
    if (!_hasMoreFolderGroups || _folderGroups.isEmpty || _loadingFolders) {
      return;
    }
    final lastCursor = _folderGroups.last.name;
    _folderPageIndex++;
    if (_folderCursorHistory.length <= _folderPageIndex) {
      _folderCursorHistory.add(lastCursor);
    } else {
      _folderCursorHistory[_folderPageIndex] = lastCursor;
    }
    _loadFolderGroupsPage();
  }

  void _previousFolderGroupsPage() {
    if (_folderPageIndex <= 0 || _loadingFolders) {
      return;
    }
    _folderPageIndex--;
    _loadFolderGroupsPage();
  }

  void _selectMusicGroup(NasIndexGroup group) {
    setState(() {
      _musicPageIndex = 0;
      _musicCursorHistory
        ..clear()
        ..add(null);
    });
    _loadMusicGroupsPage(group);
  }

  Future<void> _loadMusicGroupsPage(NasIndexGroup group) async {
    final gen = ++_groupLoadGeneration;
    final expectedTab = _currentTab;
    final expectedSource = ref.read(nasSourcesProvider).selected?.id;
    setState(() {
      _musicGroup = group;
      _loadingGroups = true;
      _hasMoreMusicGroups = false;
    });

    try {
      final after = _musicCursorHistory[_musicPageIndex];
      final groups = await ref
          .read(nasProvider.notifier)
          .groups(group, after: after);
      if (!mounted ||
          gen != _groupLoadGeneration ||
          _currentTab != expectedTab ||
          ref.read(nasSourcesProvider).selected?.id != expectedSource) {
        return;
      }
      setState(() {
        _musicGroups = groups;
        _hasMoreMusicGroups = groups.length >= 200;
        _loadingGroups = false;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } catch (_) {
      if (mounted && gen == _groupLoadGeneration) {
        setState(() => _loadingGroups = false);
      }
    }
  }

  void _nextMusicGroupsPage() {
    if (!_hasMoreMusicGroups ||
        _musicGroups.isEmpty ||
        _loadingGroups ||
        _musicGroup == null) {
      return;
    }
    final lastCursor = _musicGroups.last.name;
    _musicPageIndex++;
    if (_musicCursorHistory.length <= _musicPageIndex) {
      _musicCursorHistory.add(lastCursor);
    } else {
      _musicCursorHistory[_musicPageIndex] = lastCursor;
    }
    _loadMusicGroupsPage(_musicGroup!);
  }

  void _previousMusicGroupsPage() {
    if (_musicPageIndex <= 0 || _loadingGroups || _musicGroup == null) {
      return;
    }
    _musicPageIndex--;
    _loadMusicGroupsPage(_musicGroup!);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<NasMetadataProgress>>(nasMetadataProgressProvider, (
      prev,
      next,
    ) {
      final wasRunning = prev?.asData?.value.running ?? false;
      final isRunning = next.asData?.value.running ?? false;
      if (wasRunning && !isRunning) {
        if (mounted && _musicGroup != null) {
          _loadMusicGroupsPage(_musicGroup!);
        }
      }
    });

    ref.listen(nasSourcesProvider.select((s) => s.selected?.id), (prev, next) {
      if (prev != next) {
        _groupLoadGeneration++;
        if (mounted) {
          setState(() {
            _folderGroups = [];
            _folderPageIndex = 0;
            _folderCursorHistory
              ..clear()
              ..add(null);
            _hasMoreFolderGroups = false;
            _musicGroups = [];
            _musicPageIndex = 0;
            _musicCursorHistory
              ..clear()
              ..add(null);
            _hasMoreMusicGroups = false;
          });
          if (_currentTab == NasMediaTab.folders) {
            _loadFolderGroupsPage();
          } else if (_currentTab == NasMediaTab.music && _musicGroup != null) {
            _loadMusicGroupsPage(_musicGroup!);
          }
        }
      }
    });

    final state = ref.watch(nasProvider);
    final sourcesState = ref.watch(nasSourcesProvider);
    final activeSource = sourcesState.selected;

    final playerService = ref.watch(nasMediaPlayerProvider).asData?.value;
    final playbackAsync = ref.watch(nasPlaybackProvider);
    final snapshot = playbackAsync.asData?.value ?? playerService?.state;
    final activeItem = snapshot?.current;
    final isPlaying = snapshot?.playing ?? false;

    final inShell = context.findAncestorWidgetOfExactType<MainShell>() != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Action Toolbar
            _buildTopBar(context, state, sourcesState, activeSource),
            if (state.isScanning)
              const LinearProgressIndicator(
                key: Key('nas_scanning_indicator'),
                minHeight: 2,
              ),
            const Divider(height: 1),

            // Search Bar Row (with debounce)
            _buildSearchBar(context, state),
            const Divider(height: 1),

            // Active Scope Breadcrumbs (if folder, artist, album, or playlist is set)
            if (state.folder != null ||
                state.artist != null ||
                state.album != null ||
                state.playlistId != null)
              _buildScopeBreadcrumbs(context, state),

            // Media Center Tabs
            _buildTabBar(context, state),
            const Divider(height: 1),

            // Error Banner (if any)
            if (state.errorCode != null)
              _buildErrorBanner(context, state.errorCode!),

            // Body content
            Expanded(child: _buildSurfaceContent(context, state, sourcesState)),

            // Persistent Mini Player (only standalone, MainShell hosts global mini player)
            if (activeItem != null && !inShell)
              NasMiniPlayer(
                item: activeItem,
                player: playerService?.player,
                isPlaying: isPlaying,
                onPlayPause: () async {
                  if (_miniPlayerCommandInProgress) return;
                  _miniPlayerCommandInProgress = true;
                  try {
                    if (playerService != null) {
                      await playerService.playOrPause();
                    }
                  } catch (_) {
                  } finally {
                    _miniPlayerCommandInProgress = false;
                  }
                },
                onClose: () async {
                  try {
                    await playerService?.stop();
                  } catch (_) {}
                },
                onExpand: () =>
                    _showFullPlayer(activeItem, playerService?.player),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    NasState state,
    NasSourcesState sourcesState,
    NasSource? currentSource,
  ) {
    final theme = Theme.of(context);
    final lastScanText = state.lastScan != null
        ? context.l10n.nasLastScan(_formatDateTime(state.lastScan!))
        : context.l10n.nasNotScanned;

    final downloadsAsync = ref.watch(nasDownloadsProvider);
    final activeDownloads =
        downloadsAsync.asData?.value
            .where(
              (t) =>
                  t.status == NasDownloadStatus.downloading ||
                  t.status == NasDownloadStatus.queued,
            )
            .length ??
        0;

    final isNarrow = MediaQuery.sizeOf(context).width < 500;

    final sourceWidget = sourcesState.sources.isNotEmpty
        ? PopupMenuButton<String>(
            key: const Key('nas_source_selector_button'),
            tooltip: context.nasSources,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    switch (currentSource?.type) {
                      NasSourceType.sftp => Icons.terminal,
                      NasSourceType.webdav => Icons.cloud_outlined,
                      NasSourceType.smb => Icons.folder_shared_outlined,
                      NasSourceType.jellyfin => Icons.tv,
                      NasSourceType.emby => Icons.live_tv,
                      _ => Icons.storage,
                    },
                    size: 16,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isNarrow ? 90 : 120),
                    child: Text(
                      currentSource?.name ?? context.nasSources,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ),
            onSelected: (val) {
              if (val == '__add__') {
                NasSourceDialog.show(context);
              } else if (val == '__install__') {
                NasInstallDialog.show(context);
              } else if (val == '__edit__') {
                if (currentSource != null) {
                  NasSourceDialog.show(context, source: currentSource);
                }
              } else {
                ref.read(nasSourcesProvider.notifier).select(val);
              }
            },
            itemBuilder: (ctx) => [
              for (final s in sourcesState.sources)
                PopupMenuItem(
                  value: s.id,
                  child: Row(
                    children: [
                      if (s.id == sourcesState.selectedId)
                        const Icon(Icons.check, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${s.name} (${s.type.name.toUpperCase()})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              if (currentSource != null)
                PopupMenuItem(
                  value: '__edit__',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 16),
                      const SizedBox(width: 8),
                      Text(context.nasEditSource),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: '__add__',
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 16),
                    const SizedBox(width: 8),
                    Text(context.nasAddSource),
                  ],
                ),
              ),
              PopupMenuItem(
                value: '__install__',
                child: Row(
                  children: [
                    const Icon(Icons.rocket_launch_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text(context.nasInstallTitle),
                  ],
                ),
              ),
            ],
          )
        : OutlinedButton.icon(
            key: const Key('nas_add_source_top_button'),
            icon: const Icon(Icons.add, size: 14),
            label: Text(
              context.nasAddSource,
              style: const TextStyle(fontSize: 11),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => NasSourceDialog.show(context),
          );

    final statusWidget = Text(
      state.isScanning
          ? '${context.l10n.nasScanning} (${state.scannedCount})'
          : lastScanText,
      style: theme.textTheme.bodySmall?.copyWith(
        color: state.isScanning
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      ),
      overflow: TextOverflow.ellipsis,
    );

    final downloadsBtn = IconButton(
      key: const Key('nas_downloads_button'),
      visualDensity: VisualDensity.compact,
      icon: Badge(
        isLabelVisible: activeDownloads > 0,
        label: Text('$activeDownloads'),
        child: const Icon(Icons.download_outlined, size: 18),
      ),
      tooltip: context.nasTabDownloads,
      onPressed: () => NasDownloadsSheet.show(context),
    );

    final configBtn = IconButton(
      key: const Key('nas_config_button'),
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.tune, size: 18),
      tooltip: context.l10n.nasConfigure,
      onPressed: () {
        final currentSource = ref.read(nasSourcesProvider).selected;
        NasScanConfigDialog.show(
          context,
          source: currentSource,
          sourceId: currentSource?.id ?? state.serverId,
          initialConfig: state.config,
          onSave: (cfg) => ref.read(nasProvider.notifier).saveConfig(cfg),
        );
      },
    );

    final settingsBtn = IconButton(
      key: const Key('nas_library_settings_button'),
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.settings_outlined, size: 18),
      tooltip: context.l10n.nasLibrarySettings,
      onPressed: () {
        final currentSource = ref.read(nasSourcesProvider).selected;
        final videoPolicy = _getOpenPolicy(NasMediaKind.video);
        final audioPolicy = _getOpenPolicy(NasMediaKind.audio);
        final imagePolicy = _getOpenPolicy(NasMediaKind.image);

        NasLibrarySettingsDialog.show(
          context,
          source: currentSource,
          sourceId: currentSource?.id ?? state.serverId,
          currentPolicy: _getOpenPolicy(switch (_currentTab) {
            NasMediaTab.photos => NasMediaKind.image,
            NasMediaTab.videos => NasMediaKind.video,
            NasMediaTab.music => NasMediaKind.audio,
            _ => NasMediaKind.video,
          }),
          onPolicyChanged: (policy) {
            _openPolicy = policy;
            switch (_currentTab) {
              case NasMediaTab.photos:
                _setOpenPolicy(NasMediaKind.image, policy);
                break;
              case NasMediaTab.videos:
                _setOpenPolicy(NasMediaKind.video, policy);
                break;
              case NasMediaTab.music:
                _setOpenPolicy(NasMediaKind.audio, policy);
                break;
              default:
                _setOpenPolicy(NasMediaKind.video, policy);
                _setOpenPolicy(NasMediaKind.audio, policy);
                _setOpenPolicy(NasMediaKind.image, policy);
                break;
            }
          },
          kindPolicies: {
            NasMediaKind.video: videoPolicy,
            NasMediaKind.audio: audioPolicy,
            NasMediaKind.image: imagePolicy,
          },
          onKindPolicyChanged: (kind, policy) {
            _setOpenPolicy(kind, policy);
          },
          scanConfig: state.config,
          onSaveScanConfig: (cfg) =>
              ref.read(nasProvider.notifier).saveConfig(cfg),
          isScanning: state.isScanning,
          onScan: () => ref.read(nasProvider.notifier).scan(),
          onCancelScan: () => ref.read(nasProvider.notifier).cancelScan(),
        );
      },
    );

    final scanBtn = state.isScanning
        ? IconButton.filledTonal(
            key: const Key('nas_cancel_scan_button'),
            tooltip: context.l10n.nasCancelScan,
            visualDensity: VisualDensity.compact,
            onPressed: () => ref.read(nasProvider.notifier).cancelScan(),
            icon: const Icon(Icons.stop, size: 18),
          )
        : IconButton.filled(
            key: const Key('nas_scan_button'),
            tooltip: context.l10n.nasScan,
            visualDensity: VisualDensity.compact,
            onPressed:
                (currentSource == null ||
                    (currentSource.type != NasSourceType.jellyfin &&
                        currentSource.type != NasSourceType.emby &&
                        state.config.includePaths.isEmpty))
                ? null
                : () => ref.read(nasProvider.notifier).scan(),
            icon: const Icon(Icons.sync, size: 18),
          );

    if (isNarrow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: theme.colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                sourceWidget,
                const SizedBox(width: 8),
                Expanded(child: statusWidget),
                const SizedBox(width: 4),
                scanBtn,
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [downloadsBtn, configBtn, settingsBtn],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          sourceWidget,
          const SizedBox(width: 8),
          Expanded(child: statusWidget),
          downloadsBtn,
          configBtn,
          settingsBtn,
          const SizedBox(width: 4),
          scanBtn,
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, NasState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: TextField(
        key: const Key('nas_search_field'),
        controller: _searchController,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          hintText: context.l10n.nasSearchHint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  key: const Key('nas_search_clear_button'),
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(nasProvider.notifier).setSearch('');
                  },
                )
              : null,
        ),
        onSubmitted: (val) {
          ref.read(nasProvider.notifier).setSearch(val);
        },
        onChanged: (val) {
          setState(() {});
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 300), () {
            ref.read(nasProvider.notifier).setSearch(val);
          });
        },
      ),
    );
  }

  Widget _buildScopeBreadcrumbs(BuildContext context, NasState state) {
    final theme = Theme.of(context);
    final String title;
    final IconData icon;

    if (state.playlistId != null) {
      final pl = state.playlists
          .where((p) => p.id == state.playlistId)
          .firstOrNull;
      title = pl?.name ?? 'Playlist';
      icon = Icons.queue_music;
    } else if (state.folder != null) {
      title = state.folder!;
      icon = Icons.folder;
    } else if (state.artist != null) {
      title = state.artist!;
      icon = Icons.person;
    } else if (state.album != null) {
      title = state.album!;
      icon = Icons.album;
    } else {
      title = '';
      icon = Icons.filter_list;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state.items.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.play_arrow, size: 16),
              label: Text(context.nasPlayAll),
              onPressed: () => _openInApp(state.items.first),
            ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            icon: const Icon(Icons.close, size: 14),
            label: Text(context.nasClearScope),
            onPressed: () => ref.read(nasProvider.notifier).setScope(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, NasState state) {
    final theme = Theme.of(context);

    final tabs = [
      (NasMediaTab.home, context.l10n.nasTabHome, Icons.home_outlined),
      (NasMediaTab.photos, context.l10n.nasFilterImages, Icons.image_outlined),
      (NasMediaTab.videos, context.l10n.nasFilterVideos, Icons.movie_outlined),
      (NasMediaTab.music, context.l10n.nasTabMusic, Icons.music_note_outlined),
      (NasMediaTab.folders, context.l10n.nasTabFolders, Icons.folder_outlined),
      (
        NasMediaTab.favorites,
        context.l10n.nasTabFavorites,
        Icons.favorite_outline,
      ),
      (
        NasMediaTab.playlists,
        context.l10n.nasTabPlaylists,
        Icons.queue_music_outlined,
      ),
      (NasMediaTab.downloads, context.nasTabDownloads, Icons.download_outlined),
    ];

    return Container(
      color: theme.colorScheme.surface,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: tabs.map((tabInfo) {
            final isSelected = _currentTab == tabInfo.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('nas_tab_${tabInfo.$1.name}'),
                selected: isSelected,
                avatar: Icon(
                  tabInfo.$3,
                  size: 16,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                ),
                label: Text(tabInfo.$2),
                onSelected: (selected) {
                  if (selected) _selectTab(tabInfo.$1);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String errorCode) {
    final theme = Theme.of(context);
    final errorText = errorCode == 'NAS_SCAN_CANCELLED'
        ? context.l10n.nasScanCancelled
        : context.l10n.nasScanFailed(errorCode);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorText,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurfaceContent(
    BuildContext context,
    NasState state,
    NasSourcesState sourcesState,
  ) {
    if (sourcesState.sources.isEmpty) {
      return _buildEmptySourcesView(context);
    }

    if (state.playlistId != null) {
      return _buildPlaylistDetailSurface(context, state);
    }

    if (_currentTab == NasMediaTab.playlists) {
      return _buildPlaylistsSurface(context, state);
    }

    if (_currentTab == NasMediaTab.downloads) {
      return const NasDownloadsSheet();
    }

    final currentSource = sourcesState.selected;
    final isMediaServer = currentSource?.isMediaServer ?? false;

    // Empty scan configuration guidance (for SFTP, SMB, WebDAV)
    if (!isMediaServer && state.config.includePaths.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_off_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.nasEmptyConfigTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.nasEmptyConfigDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('nas_empty_config_button'),
                icon: const Icon(Icons.settings, size: 18),
                label: Text(context.l10n.nasConfigureScanDirs),
                onPressed: () {
                  final currentSource = ref.read(nasSourcesProvider).selected;
                  NasScanConfigDialog.show(
                    context,
                    source: currentSource,
                    sourceId: currentSource?.id ?? state.serverId,
                    initialConfig: state.config,
                    onSave: (cfg) =>
                        ref.read(nasProvider.notifier).saveConfig(cfg),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    // Empty index prompt
    if (state.items.isEmpty &&
        !state.isLoading &&
        !state.isScanning &&
        _currentTab != NasMediaTab.folders &&
        !(_currentTab == NasMediaTab.music && _musicGroup != null)) {
      if (state.search.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.nasNoSearchResults,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    _searchController.clear();
                    ref.read(nasProvider.notifier).setSearch('');
                  },
                  child: Text(context.l10n.nasClearSearch),
                ),
              ],
            ),
          ),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.perm_media_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.nasNoIndexTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.nasNoIndexDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('nas_empty_scan_button'),
                icon: const Icon(Icons.sync, size: 18),
                label: Text(context.l10n.nasScan),
                onPressed: () => ref.read(nasProvider.notifier).scan(),
              ),
            ],
          ),
        ),
      );
    }

    // Surface router
    switch (_currentTab) {
      case NasMediaTab.home:
        return _buildHomeSurface(context, state);
      case NasMediaTab.photos:
        return _buildPhotosSurface(context, state);
      case NasMediaTab.videos:
        return _buildVideosSurface(context, state);
      case NasMediaTab.music:
        return _buildMusicSurface(context, state);
      case NasMediaTab.folders:
        return _buildFoldersSurface(context, state);
      case NasMediaTab.favorites:
        return _buildFavoritesSurface(context, state);
      case NasMediaTab.playlists:
        return _buildPlaylistsSurface(context, state);
      case NasMediaTab.downloads:
        return const NasDownloadsSheet();
    }
  }

  Widget _buildEmptySourcesView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storage_rounded,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              context.nasNoSources,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.nasNoSourcesDesc,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  key: const Key('nas_empty_sources_add_button'),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.nasAddSource),
                  onPressed: () => NasSourceDialog.show(context),
                ),
                OutlinedButton.icon(
                  key: const Key('nas_install_wizard_button'),
                  icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                  label: Text(context.nasInstallTitle),
                  onPressed: () => NasInstallDialog.show(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeSurface(BuildContext context, NasState state) {
    final theme = Theme.of(context);
    // Totals from SQLite repository, NEVER items.length!
    final totals = state.totals;

    return SingleChildScrollView(
      key: const Key('nas_unified_scroll'),
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick Stats Banner
          Container(
            key: const Key('nas_quick_stats'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.nasQuickStats,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatPill(
                      context,
                      label: context.l10n.nasStatTotal,
                      value: totals.total.toString(),
                      icon: Icons.all_inclusive,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      context,
                      label: context.l10n.nasStatPhotos,
                      value: totals.images.toString(),
                      icon: Icons.image,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      context,
                      label: context.l10n.nasStatVideos,
                      value: totals.videos.toString(),
                      icon: Icons.movie,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      context,
                      label: context.l10n.nasStatMusic,
                      value: totals.audio.toString(),
                      icon: Icons.audiotrack,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Items listing
          ...state.items.map((item) => _buildMediaListItem(context, item)),

          // Pagination Footer
          _buildPaginationFooter(context, state),

          if (state.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(BuildContext context, NasState state) {
    if (!state.hasMore && !state.hasPrevious) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            key: const Key('nas_previous_page_button'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text(context.nasPreviousPage),
            onPressed: state.hasPrevious
                ? () {
                    _scrollController.jumpTo(0);
                    ref.read(nasProvider.notifier).loadPrevious();
                  }
                : null,
          ),
          const SizedBox(width: 16),
          Text(
            '${state.items.length} / ${state.matchingCount}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.tonalIcon(
            key: const Key('nas_next_page_button'),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(context.nasNextPage),
            onPressed: state.hasMore
                ? () {
                    _scrollController.jumpTo(0);
                    ref.read(nasProvider.notifier).loadMore();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSurface(BuildContext context, NasState state) {
    final images = state.items
        .where((i) => i.kind == NasMediaKind.image)
        .toList();

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            key: const Key('nas_image_grid'),
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final item = images[index];
              return _buildImageGridTile(context, item, images, index);
            },
          ),
        ),
        _buildPaginationFooter(context, state),
      ],
    );
  }

  Widget _buildImageGridTile(
    BuildContext context,
    NasMediaItem item,
    List<NasMediaItem> images,
    int index,
  ) {
    final theme = Theme.of(context);

    return InkWell(
      key: Key('nas_item_${item.name}'),
      onTap: () {
        NasImageViewerDialog.show(
          context,
          item: item,
          items: images,
          initialIndex: index,
          thumbnailFuture: ref.read(nasProvider.notifier).thumbnailPath(item),
          isFavorite: item.isFavorite,
          onToggleFavorite: () => _toggleFavorite(item),
          onOpenExternal: () => _openExternal(item),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<String?>(
                future: ref.read(nasProvider.notifier).thumbnailPath(item),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final localPath = snapshot.data;
                  if (localPath != null && File(localPath).existsSync()) {
                    return Image.file(File(localPath), fit: BoxFit.cover);
                  }
                  return Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: theme.colorScheme.outline,
                  );
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  color: Colors.black54,
                  child: Text(
                    item.name,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideosSurface(BuildContext context, NasState state) {
    final videos = state.items
        .where((i) => i.kind == NasMediaKind.video)
        .toList();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            key: const Key('nas_media_list'),
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              return _buildMediaListItem(context, videos[index]);
            },
          ),
        ),
        _buildPaginationFooter(context, state),
      ],
    );
  }

  Widget _buildMusicSurface(BuildContext context, NasState state) {
    final theme = Theme.of(context);
    final tracks = state.items
        .where((i) => i.kind == NasMediaKind.audio)
        .toList();
    final metadataProgress = ref
        .watch(nasMetadataProgressProvider)
        .asData
        ?.value;

    final scopedTitle = state.artist ?? state.album;
    if (scopedTitle != null) {
      final displayTracks = tracks.isNotEmpty ? tracks : state.items;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  key: const Key('nas_music_scope_back_button'),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: context.nasClearScope,
                  onPressed: () => ref.read(nasProvider.notifier).setScope(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scopedTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        context.l10n.nasItemCount(displayTracks.length),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (displayTracks.isNotEmpty)
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: Text(context.nasPlayAll),
                    onPressed: () => _openInApp(displayTracks.first),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: displayTracks.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.nasNoSearchResults,
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: displayTracks.length,
                    itemBuilder: (context, index) {
                      return _buildMediaListItem(context, displayTracks[index]);
                    },
                  ),
          ),
          _buildPaginationFooter(context, state),
        ],
      );
    }

    return Column(
      children: [
        if (metadataProgress?.running == true)
          Container(
            key: const Key('nas_metadata_enriching_bar'),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.nasMetadataEnrichingStatus(
                      metadataProgress!.processed,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Sub-navigation: Tracks / Artists / Albums
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SegmentedButton<NasIndexGroup?>(
                segments: [
                  ButtonSegment(
                    value: null,
                    label: Text(context.nasAllTracks),
                    icon: const Icon(Icons.audiotrack, size: 16),
                  ),
                  ButtonSegment(
                    value: NasIndexGroup.byArtist,
                    label: Text(context.nasByArtist),
                    icon: const Icon(Icons.person, size: 16),
                  ),
                  ButtonSegment(
                    value: NasIndexGroup.byAlbum,
                    label: Text(context.nasByAlbum),
                    icon: const Icon(Icons.album, size: 16),
                  ),
                ],
                selected: {_musicGroup},
                onSelectionChanged: (val) {
                  final group = val.first;
                  if (group == null) {
                    setState(() => _musicGroup = null);
                    ref.read(nasProvider.notifier).setScope();
                    ref
                        .read(nasProvider.notifier)
                        .setFilter(NasMediaKind.audio);
                  } else {
                    ref.read(nasProvider.notifier).setScope();
                    _selectMusicGroup(group);
                  }
                },
              ),
              const Spacer(),
              if (_musicGroup == null && tracks.isNotEmpty)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: Text(context.nasPlayAll),
                  onPressed: () => _openInApp(tracks.first),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Content: Groups or Tracks List
        Expanded(
          child: _musicGroup != null
              ? (_loadingGroups && _musicGroups.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(8),
                              itemCount: _musicGroups.length,
                              itemBuilder: (context, index) {
                                final g = _musicGroups[index];
                                return Card(
                                  child: ListTile(
                                    leading: Icon(
                                      _musicGroup == NasIndexGroup.byArtist
                                          ? Icons.person
                                          : Icons.album,
                                      color: theme.colorScheme.primary,
                                    ),
                                    title: Text(g.name),
                                    subtitle: Text(
                                      context.l10n.nasItemCount(g.count),
                                    ),
                                    onTap: () {
                                      if (_musicGroup ==
                                          NasIndexGroup.byArtist) {
                                        ref
                                            .read(nasProvider.notifier)
                                            .setScope(artist: g.name);
                                      } else {
                                        ref
                                            .read(nasProvider.notifier)
                                            .setScope(album: g.name);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          _buildMusicGroupsPaginationFooter(context),
                        ],
                      ))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    return _buildMediaListItem(context, tracks[index]);
                  },
                ),
        ),
        if (_musicGroup == null) _buildPaginationFooter(context, state),
      ],
    );
  }

  Widget _buildMusicGroupsPaginationFooter(BuildContext context) {
    final hasPrev = _musicPageIndex > 0;
    if (!_hasMoreMusicGroups && !hasPrev) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            key: const Key('nas_music_groups_previous_page_button'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text(context.nasPreviousPage),
            onPressed: hasPrev && !_loadingGroups
                ? _previousMusicGroupsPage
                : null,
          ),
          const SizedBox(width: 16),
          Text(
            '${_musicGroups.length}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.tonalIcon(
            key: const Key('nas_music_groups_next_page_button'),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(context.nasNextPage),
            onPressed: _hasMoreMusicGroups && !_loadingGroups
                ? _nextMusicGroupsPage
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFoldersSurface(BuildContext context, NasState state) {
    final theme = Theme.of(context);

    if (state.folder != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  key: const Key('nas_folder_back_button'),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: context.nasClearScope,
                  onPressed: () => ref.read(nasProvider.notifier).setScope(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.folder!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        context.l10n.nasItemCount(state.items.length),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.items.isNotEmpty)
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: Text(context.nasPlayAll),
                    onPressed: () => _openInApp(state.items.first),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: state.items.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.nasNoSearchResults,
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      return _buildMediaListItem(context, state.items[index]);
                    },
                  ),
          ),
          _buildPaginationFooter(context, state),
        ],
      );
    }

    if (_loadingFolders && _folderGroups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_folderGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              context.l10n.nasNoIndexTitle,
              style: TextStyle(color: theme.colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: _folderGroups.length,
            itemBuilder: (context, index) {
              final g = _folderGroups[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: ListTile(
                  leading: Icon(Icons.folder, color: theme.colorScheme.primary),
                  title: Text(
                    g.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(context.l10n.nasItemCount(g.count)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    ref.read(nasProvider.notifier).setScope(folder: g.name);
                  },
                ),
              );
            },
          ),
        ),
        _buildFolderGroupsPaginationFooter(context),
      ],
    );
  }

  Widget _buildFolderGroupsPaginationFooter(BuildContext context) {
    final hasPrev = _folderPageIndex > 0;
    if (!_hasMoreFolderGroups && !hasPrev) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            key: const Key('nas_folders_previous_page_button'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text(context.nasPreviousPage),
            onPressed: hasPrev && !_loadingFolders
                ? _previousFolderGroupsPage
                : null,
          ),
          const SizedBox(width: 16),
          Text(
            '${_folderGroups.length}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.tonalIcon(
            key: const Key('nas_folders_next_page_button'),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(context.nasNextPage),
            onPressed: _hasMoreFolderGroups && !_loadingFolders
                ? _nextFolderGroupsPage
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesSurface(BuildContext context, NasState state) {
    final favItems = state.items.where((i) => i.isFavorite).toList();

    if (favItems.isEmpty && !state.hasPrevious && !state.hasMore) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_outline,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.nasNoFavorites,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: favItems.length,
            itemBuilder: (context, index) =>
                _buildMediaListItem(context, favItems[index]),
          ),
        ),
        _buildPaginationFooter(context, state),
      ],
    );
  }

  Widget _buildPlaylistsSurface(BuildContext context, NasState state) {
    // If a playlist scope is selected, display its detail surface
    if (state.playlistId != null) {
      return _buildPlaylistDetailSurface(context, state);
    }

    final playlists = ref.watch(nasProvider).playlists;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.nasTabPlaylists,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              FilledButton.icon(
                key: const Key('nas_create_playlist_button'),
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.l10n.nasCreatePlaylist),
                onPressed: _showCreatePlaylistDialog,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: playlists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.queue_music_outlined,
                        size: 56,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.nasNoPlaylists,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  key: const Key('nas_playlists_list'),
                  padding: const EdgeInsets.all(12),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return Card(
                      key: Key('nas_playlist_${playlist.id}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.playlist_play),
                        title: Text(playlist.name),
                        subtitle: Text(
                          context.l10n.nasItemCount(playlist.itemCount),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: context.nasRenamePlaylist,
                              onPressed: () =>
                                  _showRenamePlaylistDialog(playlist),
                            ),
                            IconButton(
                              key: Key('nas_delete_playlist_${playlist.id}'),
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: context.l10n.delete,
                              onPressed: () => ref
                                  .read(nasProvider.notifier)
                                  .deletePlaylist(playlist.id),
                            ),
                          ],
                        ),
                        onTap: () {
                          ref
                              .read(nasProvider.notifier)
                              .setScope(playlistId: playlist.id);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPlaylistDetailSurface(BuildContext context, NasState state) {
    final playlist = state.playlists
        .where((p) => p.id == state.playlistId)
        .firstOrNull;
    final items = state.items;
    final totalCount = playlist?.itemCount ?? items.length;
    final offset = state.playlistOffset;

    return Column(
      key: const Key('nas_playlist_detail_surface'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => ref.read(nasProvider.notifier).setScope(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist?.name ?? 'Playlist',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      context.l10n.nasItemCount(totalCount),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty)
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: Text(context.nasPlayAll),
                  onPressed: () => _openInApp(items.first),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    context.l10n.nasNoPlaylists,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final globalOrdinal = offset + index + 1;
                    final globalIndex = offset + index;
                    return Card(
                      key: Key('nas_playlist_entry_$index'),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('$globalOrdinal')),
                        title: Text(
                          item.title ?? item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.artist ?? item.folder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (globalIndex > 0)
                              IconButton(
                                key: Key('nas_playlist_move_up_${item.name}'),
                                icon: const Icon(Icons.arrow_upward, size: 18),
                                tooltip: context.nasMoveUp,
                                onPressed: () => ref
                                    .read(nasProvider.notifier)
                                    .movePlaylistItem(
                                      state.playlistId!,
                                      item,
                                      globalIndex - 1,
                                    ),
                              ),
                            if (globalIndex + 1 < totalCount)
                              IconButton(
                                key: Key('nas_playlist_move_down_${item.name}'),
                                icon: const Icon(
                                  Icons.arrow_downward,
                                  size: 18,
                                ),
                                tooltip: context.nasMoveDown,
                                onPressed: () => ref
                                    .read(nasProvider.notifier)
                                    .movePlaylistItem(
                                      state.playlistId!,
                                      item,
                                      globalIndex + 1,
                                    ),
                              ),
                            IconButton(
                              key: Key('nas_playlist_remove_item_${item.name}'),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 18,
                              ),
                              tooltip: context.nasRemoveFromPlaylist,
                              onPressed: () => ref
                                  .read(nasProvider.notifier)
                                  .removeFromPlaylist(state.playlistId!, item),
                            ),
                          ],
                        ),
                        onTap: () => _openInApp(item),
                      ),
                    );
                  },
                ),
        ),
        _buildPaginationFooter(context, state),
      ],
    );
  }

  Widget _buildMediaListItem(BuildContext context, NasMediaItem item) {
    final theme = Theme.of(context);
    final icon = switch (item.kind) {
      NasMediaKind.image => Icons.image_outlined,
      NasMediaKind.video => Icons.movie_outlined,
      NasMediaKind.audio => Icons.music_note_outlined,
    };
    final isFav = item.isFavorite;

    return Card(
      key: Key('nas_item_${item.name}'),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          child: Icon(icon, color: theme.colorScheme.primary, size: 18),
        ),
        title: Text(
          item.title ?? item.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${SftpFileItem.formatBytes(item.sizeBytes)} · ${_formatEpoch(item.modifiedEpoch)}',
          style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Builder(
          builder: (context) {
            final isNarrow = MediaQuery.sizeOf(context).width < 480;
            if (isNarrow) {
              return PopupMenuButton<String>(
                key: Key('nas_item_overflow_${item.name}'),
                icon: const Icon(Icons.more_vert, size: 20),
                tooltip: context.l10n.navMore,
                onSelected: (action) {
                  switch (action) {
                    case 'favorite':
                      _toggleFavorite(item);
                      break;
                    case 'download':
                      ref.read(nasProvider.notifier).download(item);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.nasDownloading(item.name)),
                        ),
                      );
                      break;
                    case 'cast':
                      NasCastSheet.show(context, item: item);
                      break;
                    case 'external':
                      _openExternal(item);
                      break;
                    case 'playlist':
                      _showAddToPlaylistDialog(item);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'favorite',
                    child: Row(
                      children: [
                        Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFav ? Colors.redAccent : null,
                        ),
                        const SizedBox(width: 8),
                        Text(ctx.l10n.nasTabFavorites),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        const Icon(Icons.download_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(ctx.nasTabDownloads),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'cast',
                    child: Row(
                      children: [
                        const Icon(Icons.cast, size: 18),
                        const SizedBox(width: 8),
                        Text(ctx.nasCast),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'external',
                    child: Row(
                      children: [
                        const Icon(Icons.open_in_new, size: 18),
                        const SizedBox(width: 8),
                        Text(ctx.l10n.nasOpenPolicyExternal),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'playlist',
                    child: Row(
                      children: [
                        const Icon(Icons.playlist_add, size: 18),
                        const SizedBox(width: 8),
                        Text(ctx.l10n.nasTabPlaylists),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: isFav ? Colors.redAccent : theme.colorScheme.outline,
                  ),
                  tooltip: context.l10n.nasTabFavorites,
                  onPressed: () => _toggleFavorite(item),
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined, size: 18),
                  tooltip: context.nasTabDownloads,
                  onPressed: () {
                    ref.read(nasProvider.notifier).download(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.nasDownloading(item.name)),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cast, size: 18),
                  tooltip: context.nasCast,
                  onPressed: () => NasCastSheet.show(context, item: item),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  tooltip: context.l10n.nasOpenPolicyExternal,
                  onPressed: () => _openExternal(item),
                ),
              ],
            );
          },
        ),
        onTap: () => _handleItemTap(item),
        onLongPress: () => _showAddToPlaylistDialog(item),
      ),
    );
  }
}
