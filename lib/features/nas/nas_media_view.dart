import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
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
import 'widgets/nas_deployment_chooser.dart';
import 'widgets/nas_diagnostics_dialog.dart';
import 'widgets/nas_downloads_sheet.dart';
import 'widgets/nas_full_player_dialog.dart';
import 'widgets/nas_image_viewer_dialog.dart';
import 'widgets/nas_library_settings_dialog.dart';
import 'widgets/nas_localizations.dart';
import 'widgets/nas_mini_player.dart';
import 'widgets/nas_scan_config_dialog.dart';
import 'widgets/nas_source_dialog.dart';
import 'widgets/nas_thumbnail_image.dart';

enum NasMediaTab {
  home,
  photos,
  videos,
  music,
  library,
  folders,
  favorites,
  playlists,
  downloads,
}

enum NasLibrarySection { folders, favorites, playlists, downloads, manage }

class NasMediaView extends ConsumerStatefulWidget {
  const NasMediaView({super.key});

  @override
  ConsumerState<NasMediaView> createState() => _NasMediaViewState();
}

class _NasMediaViewState extends ConsumerState<NasMediaView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _photoFolderScrollController = ScrollController();
  Timer? _searchDebounce;

  NasMediaTab _currentTab = NasMediaTab.home;
  NasLibrarySection _librarySection = NasLibrarySection.folders;
  String _currentCategory = 'home';
  bool _searchOpen = false;
  bool _selectionMode = false;
  bool _isBatchBusy = false;
  final Set<NasMediaItem> _selectedItems = {};
  final Map<String, double> _scrollOffsets = {};
  final Map<String, NasMediaTab> _sourceTabMemory = {};
  final Map<String, NasLibrarySection> _sourceLibrarySectionMemory = {};
  final Map<String, NasSource> _sourceOrigins = {};
  NasOpenPolicy _openPolicy = NasOpenPolicy.external;

  final Map<String, int> _photoDensityBySource = {};
  bool _photoAlbumsMode = false;
  double _photoAlbumsScrollOffset = 0.0;
  String? _photoAlbumsPreDrillFolder;
  NasSource? _photoAlbumsPreDrillSource;
  bool _photoAlbumsDrilledDown = false;
  List<NasIndexGroupCount> _photoFolderGroups = [];
  int _photoFolderPageIndex = 0;
  final List<String?> _photoFolderCursorHistory = [null];
  bool _hasMorePhotoFolderGroups = false;
  bool _loadingPhotoFolders = false;
  int _photoGroupGeneration = 0;

  bool _videoGridView = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final nasState = ref.read(nasProvider);
    if (nasState.search.isNotEmpty) {
      _searchController.text = nasState.search;
      _searchOpen = true;
    }
    final browse = nasState.browseCategory;
    if (browse.isNotEmpty) {
      _currentCategory = browse;
      _currentTab = switch (browse) {
        'photos' => NasMediaTab.photos,
        'videos' => NasMediaTab.videos,
        'music' => NasMediaTab.music,
        'folders' => NasMediaTab.folders,
        'favorites' => NasMediaTab.favorites,
        'playlists' => NasMediaTab.playlists,
        'downloads' => NasMediaTab.downloads,
        _ => NasMediaTab.home,
      };
      if (_currentTab == NasMediaTab.folders) {
        _librarySection = NasLibrarySection.folders;
      } else if (_currentTab == NasMediaTab.favorites) {
        _librarySection = NasLibrarySection.favorites;
      } else if (_currentTab == NasMediaTab.playlists) {
        _librarySection = NasLibrarySection.playlists;
      } else if (_currentTab == NasMediaTab.downloads) {
        _librarySection = NasLibrarySection.downloads;
      }
      if (_currentTab == NasMediaTab.photos) {
        final initSource = ref.read(nasSourcesProvider).selected;
        final initCat = _currentCategory;
        final initNavGen = _navigationGeneration;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _navigationGeneration == initNavGen &&
              _currentCategory == initCat &&
              ref.read(nasSourcesProvider).selected == initSource) {
            ref.read(nasProvider.notifier).enableGalleryWindow(true);
          }
        });
      }
    }
    final initialSource = ref.read(nasSourcesProvider).selected;
    if (initialSource != null) {
      _sourceOrigins[initialSource.id] = initialSource;
      _sourceTabMemory[initialSource.id] = _currentTab;
      _sourceLibrarySectionMemory[initialSource.id] = _librarySection;
    }
  }

  String _categoryForTab(NasMediaTab tab, NasLibrarySection section) {
    if (tab == NasMediaTab.library) {
      return switch (section) {
        NasLibrarySection.folders => 'folders',
        NasLibrarySection.favorites => 'favorites',
        NasLibrarySection.playlists => 'playlists',
        NasLibrarySection.downloads => 'downloads',
        NasLibrarySection.manage => 'manage',
      };
    }
    return switch (tab) {
      NasMediaTab.home => 'home',
      NasMediaTab.photos => 'photos',
      NasMediaTab.videos => 'videos',
      NasMediaTab.music => 'music',
      NasMediaTab.folders => 'folders',
      NasMediaTab.favorites => 'favorites',
      NasMediaTab.playlists => 'playlists',
      NasMediaTab.downloads => 'downloads',
      _ => 'home',
    };
  }

  bool _isItemSelected(NasMediaItem item) {
    return _selectedItems.any((e) {
      if (item.playlistEntryId != null && e.playlistEntryId != null) {
        return e.playlistEntryId == item.playlistEntryId;
      }
      return e.path == item.path;
    });
  }

  void _toggleSelection(NasMediaItem item) {
    setState(() {
      if (_isItemSelected(item)) {
        _selectedItems.removeWhere((e) {
          if (item.playlistEntryId != null && e.playlistEntryId != null) {
            return e.playlistEntryId == item.playlistEntryId;
          }
          return e.path == item.path;
        });
      } else {
        _selectedItems.add(item);
      }
    });
  }

  void _showItemMetadataDialog(NasMediaItem item) {
    final theme = Theme.of(context);
    final dur =
        item.duration ??
        (item.durationMillis != null
            ? Duration(milliseconds: item.durationMillis!)
            : null);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('nas-metadata-dialog'),
        title: Row(
          children: [
            Icon(
              switch (item.kind) {
                NasMediaKind.image => Icons.image_outlined,
                NasMediaKind.video => Icons.movie_outlined,
                NasMediaKind.audio => Icons.music_note_outlined,
              },
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ctx.nasMediaDetails,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetaRow(ctx, ctx.nasSortName, item.name),
              _buildMetaRow(ctx, 'Path', item.path),
              _buildMetaRow(
                ctx,
                ctx.nasSortSize,
                SftpFileItem.formatBytes(item.sizeBytes),
              ),
              _buildMetaRow(
                ctx,
                ctx.nasSortModified,
                _formatEpoch(item.modifiedEpoch),
              ),
              if (item.mimeType != null)
                _buildMetaRow(ctx, 'MIME', item.mimeType!),
              if (item.width != null && item.height != null)
                _buildMetaRow(
                  ctx,
                  ctx.nasMediaResolution,
                  '${item.width} × ${item.height}',
                ),
              if (dur != null)
                _buildMetaRow(ctx, ctx.nasMediaDuration, _formatDuration(dur)),
              if (item.artist != null)
                _buildMetaRow(ctx, ctx.nasByArtist, item.artist!),
              if (item.album != null)
                _buildMetaRow(ctx, ctx.nasByAlbum, item.album!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeBatchOperation(
    NasBatchOperation operation, {
    String? playlistId,
  }) async {
    if (_selectedItems.isEmpty || _isBatchBusy) return;
    final capturedSource = ref.read(nasSourcesProvider).selected;
    final items = _selectedItems.toList();
    setState(() => _isBatchBusy = true);
    try {
      final result = await ref
          .read(nasProvider.notifier)
          .runBatch(items, operation: operation, playlistId: playlistId);
      if (!mounted) return;
      if (ref.read(nasSourcesProvider).selected != capturedSource) {
        return;
      }
      if (result.failedItems.isNotEmpty) {
        _showBatchResultDialog(result, capturedSource);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.nasBatchSummary(result.successCount, 0)),
          ),
        );
        setState(() {
          _selectedItems.clear();
          _selectionMode = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (ref.read(nasSourcesProvider).selected != capturedSource) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.nasSanitizedError(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBatchBusy = false);
      }
    }
  }

  void _showBatchResultDialog(
    NasBatchResult result,
    NasSource? capturedSource,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          ctx.nasBatchSummary(result.successCount, result.failedItems.length),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: result.results.where((r) => !r.succeeded).length,
            itemBuilder: (_, idx) {
              final failure = result.results
                  .where((r) => !r.succeeded)
                  .elementAt(idx);
              return ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(failure.item.name),
                subtitle: Text(failure.errorCode ?? 'FAILED'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('nas-batch-retry'),
            onPressed: _isBatchBusy
                ? null
                : () async {
                    Navigator.pop(ctx);
                    final retrySource = ref.read(nasSourcesProvider).selected;
                    if (retrySource != capturedSource) return;
                    setState(() => _isBatchBusy = true);
                    try {
                      final retryResult = await ref
                          .read(nasProvider.notifier)
                          .retryBatch(result);
                      if (!mounted) return;
                      if (ref.read(nasSourcesProvider).selected !=
                          retrySource) {
                        return;
                      }
                      if (retryResult.failedItems.isNotEmpty) {
                        _showBatchResultDialog(retryResult, retrySource);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.nasBatchSummary(
                                retryResult.successCount,
                                0,
                              ),
                            ),
                          ),
                        );
                        setState(() {
                          _selectedItems.clear();
                          _selectionMode = false;
                        });
                      }
                    } catch (e) {
                      if (!mounted) return;
                      if (ref.read(nasSourcesProvider).selected !=
                          retrySource) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.nasSanitizedError(e)),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isBatchBusy = false);
                      }
                    }
                  },
            child: Text(ctx.nasBatchRetryFailed),
          ),
        ],
      ),
    );
  }

  void _showBatchAddToPlaylistDialog() {
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
                style: context.textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            for (final playlist in playlists)
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(playlist.name),
                onTap: () {
                  Navigator.pop(ctx);
                  _executeBatchOperation(
                    NasBatchOperation.addToPlaylist,
                    playlistId: playlist.id,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchBottomBar(BuildContext context, NasState state) {
    final theme = Theme.of(context);
    final count = _selectedItems.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        spacing: 8,
        runSpacing: 4,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                context.nasSelectedCount(count),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                key: const ValueKey('nas-select-loaded'),
                onPressed: _isBatchBusy
                    ? null
                    : () {
                        setState(() {
                          if (_selectedItems.length == state.items.length) {
                            _selectedItems.clear();
                          } else {
                            _selectedItems.addAll(state.items);
                          }
                        });
                      },
                child: Text(
                  _selectedItems.length == state.items.length
                      ? context.l10n.cancel
                      : context.nasSelectAll,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const ValueKey('nas-batch-favorite'),
                icon: const Icon(Icons.favorite, size: 20),
                tooltip: context.l10n.nasTabFavorites,
                onPressed: (count == 0 || _isBatchBusy)
                    ? null
                    : () => _executeBatchOperation(NasBatchOperation.favorite),
              ),
              IconButton(
                icon: const Icon(Icons.favorite_border, size: 20),
                tooltip: context.nasBatchUnfavorite,
                onPressed: (count == 0 || _isBatchBusy)
                    ? null
                    : () =>
                          _executeBatchOperation(NasBatchOperation.unfavorite),
              ),
              IconButton(
                key: const ValueKey('nas-batch-playlist'),
                icon: const Icon(Icons.playlist_add, size: 20),
                tooltip: context.nasAddToPlaylist,
                onPressed: (count == 0 || _isBatchBusy)
                    ? null
                    : _showBatchAddToPlaylistDialog,
              ),
              if (state.playlistId != null)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  tooltip: context.nasRemoveFromPlaylist,
                  onPressed: (count == 0 || _isBatchBusy)
                      ? null
                      : () => _executeBatchOperation(
                          NasBatchOperation.removeFromPlaylist,
                          playlistId: state.playlistId,
                        ),
                ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: context.l10n.cancel,
                onPressed: _isBatchBusy
                    ? null
                    : () {
                        setState(() {
                          _selectionMode = false;
                          _selectedItems.clear();
                        });
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

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
    _scrollController.removeListener(_onScroll);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _photoFolderScrollController.dispose();
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
      final idx = images.indexWhere(
        (i) => i.serverId == item.serverId && i.path == item.path,
      );
      if (idx >= 0) {
        await _openImageViewerDialog(
          item: item,
          images: images,
          initialIndex: idx,
        );
      } else {
        await _openImageViewerDialog(
          item: item,
          images: [item],
          initialIndex: 0,
        );
      }
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
                  style: context.textTheme.titleSmall,
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
                style: context.textTheme.titleMedium,
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

  Future<void> _selectTab(NasMediaTab tab) async {
    _searchDebounce?.cancel();
    _groupLoadGeneration++;
    final targetTab = switch (tab) {
      NasMediaTab.folders ||
      NasMediaTab.favorites ||
      NasMediaTab.playlists ||
      NasMediaTab.downloads => NasMediaTab.library,
      _ => tab,
    };
    final targetSection = switch (tab) {
      NasMediaTab.folders => NasLibrarySection.folders,
      NasMediaTab.favorites => NasLibrarySection.favorites,
      NasMediaTab.playlists => NasLibrarySection.playlists,
      NasMediaTab.downloads => NasLibrarySection.downloads,
      _ => _librarySection,
    };

    final activeSource = ref.read(nasSourcesProvider).selected;
    if (_scrollController.hasClients && activeSource != null) {
      _scrollOffsets['${activeSource.id}:$_currentCategory'] =
          _scrollController.offset;
    }

    final targetCategory = _categoryForTab(targetTab, targetSection);

    setState(() {
      _currentTab = targetTab;
      _librarySection = targetSection;
      _currentCategory = targetCategory;
      _selectionMode = false;
      _selectedItems.clear();
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
      _photoGroupGeneration++;
      _loadingPhotoFolders = false;
      _photoAlbumsDrilledDown = false;
      _photoAlbumsPreDrillFolder = null;
      _photoAlbumsPreDrillSource = null;
      _photoAlbumsScrollOffset = 0.0;
    });

    if (activeSource != null) {
      _sourceTabMemory[activeSource.id] = targetTab;
      _sourceLibrarySectionMemory[activeSource.id] = targetSection;
      _sourceOrigins[activeSource.id] = activeSource;
    }

    final navGen = ++_navigationGeneration;
    _pagingGeneration++;
    _lastGalleryLayout = null;
    _tileKeys.clear();
    _nearLeadingEdge = true;
    _nearTrailingEdge = false;
    _edgeLoading = false;
    _previousEdgeFailed = false;
    _nextEdgeFailed = false;

    final notifier = ref.read(nasProvider.notifier);
    if (targetCategory == 'photos') {
      await notifier.selectCategory('photos', filter: NasMediaKind.image);
      if (!mounted ||
          _navigationGeneration != navGen ||
          _currentCategory != targetCategory ||
          ref.read(nasSourcesProvider).selected != activeSource) {
        return;
      }
      await notifier.enableGalleryWindow(true);
    } else {
      switch (targetCategory) {
        case 'home':
          await notifier.selectCategory('home', filter: null);
          break;
        case 'videos':
          await notifier.selectCategory('videos', filter: NasMediaKind.video);
          break;
        case 'music':
          await notifier.selectCategory('music', filter: NasMediaKind.audio);
          break;
        case 'favorites':
          await notifier.selectCategory('favorites', favoritesOnly: true);
          break;
        case 'folders':
          await notifier.selectCategory('folders', filter: null);
          break;
        case 'playlists':
          await notifier.selectCategory('playlists', filter: null);
          break;
        default:
          await notifier.selectCategory(targetCategory);
          break;
      }
    }

    if (mounted &&
        _navigationGeneration == navGen &&
        _currentTab == targetTab &&
        _librarySection == targetSection &&
        ref.read(nasSourcesProvider).selected == activeSource) {
      _searchController.text = ref.read(nasProvider).search;
      final savedOffset =
          _scrollOffsets['${activeSource?.id ?? "none"}:$targetCategory'] ??
          0.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _navigationGeneration != navGen ||
            _currentTab != targetTab ||
            _librarySection != targetSection ||
            ref.read(nasSourcesProvider).selected != activeSource) {
          return;
        }
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            savedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    }

    if (targetTab == NasMediaTab.library &&
        targetSection == NasLibrarySection.folders) {
      _loadFolderGroupsPage();
    }
  }

  Future<void> _selectLibrarySection(NasLibrarySection section) async {
    _searchDebounce?.cancel();
    _groupLoadGeneration++;
    final activeSource = ref.read(nasSourcesProvider).selected;
    if (_scrollController.hasClients && activeSource != null) {
      _scrollOffsets['${activeSource.id}:$_currentCategory'] =
          _scrollController.offset;
    }

    final targetCategory = switch (section) {
      NasLibrarySection.folders => 'folders',
      NasLibrarySection.favorites => 'favorites',
      NasLibrarySection.playlists => 'playlists',
      NasLibrarySection.downloads => 'downloads',
      NasLibrarySection.manage => 'manage',
    };

    setState(() {
      _librarySection = section;
      _currentCategory = targetCategory;
      _selectionMode = false;
      _selectedItems.clear();
      _folderGroups = [];
      _folderPageIndex = 0;
      _folderCursorHistory
        ..clear()
        ..add(null);
      _hasMoreFolderGroups = false;
    });

    if (activeSource != null) {
      _sourceLibrarySectionMemory[activeSource.id] = section;
    }

    final navGen = ++_navigationGeneration;
    _pagingGeneration++;
    _lastGalleryLayout = null;
    _tileKeys.clear();
    _nearLeadingEdge = true;
    _nearTrailingEdge = false;
    _edgeLoading = false;
    _previousEdgeFailed = false;
    _nextEdgeFailed = false;

    final notifier = ref.read(nasProvider.notifier);
    if (section == NasLibrarySection.favorites) {
      await notifier.selectCategory('favorites', favoritesOnly: true);
    } else if (section == NasLibrarySection.folders) {
      await notifier.selectCategory('folders', filter: null);
    } else if (section == NasLibrarySection.playlists) {
      await notifier.selectCategory('playlists', filter: null);
    } else if (section != NasLibrarySection.downloads) {
      await notifier.selectCategory(targetCategory);
    }

    if (mounted &&
        _navigationGeneration == navGen &&
        _librarySection == section &&
        ref.read(nasSourcesProvider).selected == activeSource) {
      _searchController.text = ref.read(nasProvider).search;
      final savedOffset =
          _scrollOffsets['${activeSource?.id ?? "none"}:$targetCategory'] ??
          0.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _navigationGeneration != navGen ||
            _librarySection != section ||
            ref.read(nasSourcesProvider).selected != activeSource) {
          return;
        }
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            savedOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          );
        }
      });
    }

    if (section == NasLibrarySection.folders) {
      _loadFolderGroupsPage();
    }
  }

  Future<void> _loadFolderGroupsPage() async {
    final gen = ++_groupLoadGeneration;
    final expectedTab = _currentTab;
    final expectedSection = _librarySection;
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
          (_currentTab == NasMediaTab.library &&
              _librarySection != expectedSection) ||
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
    final lastCursor = _folderGroups.last.key;
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

  void _setPhotoDensity(int newDensity) {
    final currentSource = ref.read(nasSourcesProvider).selected?.id ?? '';
    final currentDensity = _photoDensityBySource[currentSource] ?? 4;
    if (currentDensity == newDensity) return;

    final oldAnchor = _captureVisibleAnchor();
    setState(() {
      _photoDensityBySource[currentSource] = newDensity;
    });

    if (oldAnchor != null) {
      final openGen = _pagingGeneration;
      final openNavGen = _navigationGeneration;
      final openSource = ref.read(nasSourcesProvider).selected;
      final openCategory = _currentCategory;
      final capturedUserSeq = _userScrollSequence;
      final targetRevision = ++_anchorRevision;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            openGen != _pagingGeneration ||
            openNavGen != _navigationGeneration ||
            _anchorRevision != targetRevision ||
            _userScrollSequence != capturedUserSeq ||
            ref.read(nasSourcesProvider).selected != openSource ||
            _currentCategory != openCategory ||
            !_scrollController.hasClients) {
          return;
        }
        final layout = _lastGalleryLayout;
        if (layout == null) return;
        final restoreKey = '${oldAnchor.serverId}:${oldAnchor.path}';
        final rowIndex = layout.itemToRowIndex[restoreKey];
        if (rowIndex != null && rowIndex < layout.prefixOffsets.length) {
          final rowOffset = layout.prefixOffsets[rowIndex];
          final targetOffset = (rowOffset - oldAnchor.viewportDy).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
          _restoringAnchor = true;
          _scrollController.jumpTo(targetOffset);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _restoringAnchor = false;
          });
        }
      });
    }
  }

  Future<void> _loadPhotoFolderGroupsPage() async {
    final gen = ++_photoGroupGeneration;
    final capturedSource = ref.read(nasSourcesProvider).selected;
    final capturedNavGen = _navigationGeneration;
    final capturedCat = _currentCategory;
    final capturedTab = _currentTab;

    setState(() {
      _loadingPhotoFolders = true;
      _hasMorePhotoFolderGroups = false;
    });

    try {
      final after = _photoFolderCursorHistory[_photoFolderPageIndex];
      final groups = await ref
          .read(nasProvider.notifier)
          .groups(
            NasIndexGroup.byFolder,
            kind: NasMediaKind.image,
            after: after,
          );
      if (!mounted ||
          gen != _photoGroupGeneration ||
          _navigationGeneration != capturedNavGen ||
          _currentCategory != capturedCat ||
          _currentTab != capturedTab ||
          !_photoAlbumsMode ||
          ref.read(nasSourcesProvider).selected != capturedSource ||
          ref.read(nasSourcesProvider).selected?.endpoint !=
              capturedSource?.endpoint) {
        return;
      }
      setState(() {
        _photoFolderGroups = groups;
        _hasMorePhotoFolderGroups = groups.length >= 200;
        _loadingPhotoFolders = false;
      });
      if (_photoFolderScrollController.hasClients) {
        _photoFolderScrollController.jumpTo(0);
      }
    } catch (_) {
      if (mounted &&
          gen == _photoGroupGeneration &&
          _navigationGeneration == capturedNavGen &&
          _currentCategory == capturedCat &&
          _currentTab == capturedTab &&
          ref.read(nasSourcesProvider).selected == capturedSource) {
        setState(() => _loadingPhotoFolders = false);
      }
    }
  }

  void _nextPhotoFolderGroupsPage() {
    if (!_hasMorePhotoFolderGroups ||
        _photoFolderGroups.isEmpty ||
        _loadingPhotoFolders) {
      return;
    }
    final lastCursor = _photoFolderGroups.last.key;
    _photoFolderPageIndex++;
    if (_photoFolderCursorHistory.length <= _photoFolderPageIndex) {
      _photoFolderCursorHistory.add(lastCursor);
    } else {
      _photoFolderCursorHistory[_photoFolderPageIndex] = lastCursor;
    }
    _photoAlbumsScrollOffset = 0.0;
    if (_photoFolderScrollController.hasClients) {
      _photoFolderScrollController.jumpTo(0);
    }
    _loadPhotoFolderGroupsPage();
  }

  void _previousPhotoFolderGroupsPage() {
    if (_photoFolderPageIndex <= 0 || _loadingPhotoFolders) {
      return;
    }
    _photoFolderPageIndex--;
    _photoAlbumsScrollOffset = 0.0;
    if (_photoFolderScrollController.hasClients) {
      _photoFolderScrollController.jumpTo(0);
    }
    _loadPhotoFolderGroupsPage();
  }

  Future<void> _addToQueue(NasMediaItem item) async {
    try {
      await ref.read(nasProvider.notifier).addToQueue(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.nasAddedToQueue),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.nasSanitizedError(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _confirmDeletePlaylist(BuildContext context, NasPlaylist playlist) {
    final capturedSource = ref.read(nasSourcesProvider).selected;
    final capturedServerId = ref.read(nasProvider).serverId;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.nasDeletePlaylistConfirmTitle),
        content: Text(
          dialogContext.nasDeletePlaylistConfirmDesc(playlist.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            key: const Key('nas_confirm_delete_playlist'),
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.vDanger,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final currentSource = ref.read(nasSourcesProvider).selected;
              final currentServerId = ref.read(nasProvider).serverId;

              if (currentSource == null ||
                  capturedSource == null ||
                  !identical(currentSource, capturedSource) ||
                  currentSource.endpoint != capturedSource.endpoint ||
                  currentServerId != capturedServerId ||
                  playlist.serverId != currentServerId ||
                  playlist.serverId != currentSource.id) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.nasSourceChangedError),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
                return;
              }

              try {
                await ref
                    .read(nasProvider.notifier)
                    .deletePlaylist(playlist.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.nasSanitizedError(e)),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: Text(dialogContext.l10n.delete),
          ),
        ],
      ),
    );
  }

  void _openLibrarySettings(BuildContext context, NasState state) {
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
      onSaveScanConfig: (cfg) => ref.read(nasProvider.notifier).saveConfig(cfg),
      isScanning: state.isScanning,
      onScan: () => ref.read(nasProvider.notifier).scan(),
      onCancelScan: () => ref.read(nasProvider.notifier).cancelScan(),
    );
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
    final lastCursor = _musicGroups.last.key;
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

    ref.listen(nasSourcesProvider.select((s) => s.selected), (
      prevSource,
      nextSource,
    ) {
      if (prevSource != nextSource ||
          prevSource?.endpoint != nextSource?.endpoint) {
        _searchDebounce?.cancel();
        _groupLoadGeneration++;
        _photoGroupGeneration++;
        final navGen = ++_navigationGeneration;
        _pagingGeneration++;
        _lastGalleryLayout = null;
        _tileKeys.clear();
        _nearLeadingEdge = true;
        _nearTrailingEdge = false;
        _edgeLoading = false;
        _previousEdgeFailed = false;
        _nextEdgeFailed = false;
        if (mounted) {
          final isSameIdentity =
              nextSource != null &&
              _sourceOrigins[nextSource.id] == nextSource &&
              _sourceOrigins[nextSource.id]?.endpoint == nextSource.endpoint;

          if (!isSameIdentity && nextSource != null) {
            _sourceTabMemory.remove(nextSource.id);
            _sourceLibrarySectionMemory.remove(nextSource.id);
            _sourceOrigins.remove(nextSource.id);
            _scrollOffsets.removeWhere(
              (k, _) => k.startsWith('${nextSource.id}:'),
            );
          }

          if (prevSource != null) {
            if (prevSource.id != nextSource?.id) {
              _sourceTabMemory[prevSource.id] = _currentTab;
              _sourceLibrarySectionMemory[prevSource.id] = _librarySection;
              _sourceOrigins[prevSource.id] = prevSource;
              if (_scrollController.hasClients) {
                _scrollOffsets['${prevSource.id}:$_currentCategory'] =
                    _scrollController.offset;
              }
            }
          }

          final restoredTab = isSameIdentity
              ? _sourceTabMemory[nextSource.id] ?? NasMediaTab.home
              : NasMediaTab.home;
          final restoredSection = isSameIdentity
              ? _sourceLibrarySectionMemory[nextSource.id] ??
                    NasLibrarySection.folders
              : NasLibrarySection.folders;
          final restoredCategory = _categoryForTab(
            restoredTab,
            restoredSection,
          );

          if (nextSource != null) {
            _sourceOrigins[nextSource.id] = nextSource;
            _sourceTabMemory[nextSource.id] = restoredTab;
            _sourceLibrarySectionMemory[nextSource.id] = restoredSection;
          }

          setState(() {
            _selectionMode = false;
            _selectedItems.clear();
            _currentTab = restoredTab;
            _librarySection = restoredSection;
            _currentCategory = restoredCategory;
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
            _photoFolderGroups = [];
            _photoFolderPageIndex = 0;
            _photoFolderCursorHistory
              ..clear()
              ..add(null);
            _hasMorePhotoFolderGroups = false;
            _loadingPhotoFolders = false;
            _photoAlbumsMode = false;
            _photoAlbumsScrollOffset = 0.0;
            _photoAlbumsPreDrillFolder = null;
            _photoAlbumsPreDrillSource = null;
            _photoAlbumsDrilledDown = false;
          });
          _searchController.text = ref.read(nasProvider).search;
          final savedOffset =
              _scrollOffsets['${nextSource?.id ?? "none"}:$restoredCategory'] ??
              0.0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                _navigationGeneration != navGen ||
                ref.read(nasSourcesProvider).selected != nextSource ||
                _currentCategory != restoredCategory ||
                !_scrollController.hasClients) {
              return;
            }
            _scrollController.jumpTo(
              savedOffset.clamp(
                0.0,
                _scrollController.position.maxScrollExtent,
              ),
            );
          });
          if ((_currentTab == NasMediaTab.library &&
                  _librarySection == NasLibrarySection.folders) ||
              _currentTab == NasMediaTab.folders) {
            _loadFolderGroupsPage();
          } else if (_currentTab == NasMediaTab.music && _musicGroup != null) {
            _loadMusicGroupsPage(_musicGroup!);
          }
        }
      }
    });

    ref.listen(
      nasProvider.select(
        (s) => (
          s.search,
          s.sortKey,
          s.sortAscending,
          s.folder,
          s.artist,
          s.album,
          s.albumKey,
          s.playlistId,
          s.modifiedFromEpoch,
          s.modifiedBeforeEpoch,
        ),
      ),
      (prev, next) {
        if (prev != next) {
          _pagingGeneration++;
          _lastGalleryLayout = null;
          _tileKeys.clear();
          _nearLeadingEdge = true;
          _nearTrailingEdge = false;
          _edgeLoading = false;
          _previousEdgeFailed = false;
          _nextEdgeFailed = false;
        }
      },
    );

    ref.listen(nasProvider.select((s) => s.search), (prev, next) {
      if (prev != next && _searchController.text != next) {
        _searchController.text = next;
      }
    });

    ref.listen<NasState>(nasProvider, (prev, next) {
      if (prev == null) return;
      if (!next.galleryWindowEnabled ||
          _currentTab != NasMediaTab.photos ||
          _isViewerOpen ||
          next.isLoading ||
          next.errorCode != null) {
        return;
      }
      if (prev.serverId != next.serverId ||
          prev.search != next.search ||
          prev.sortKey != next.sortKey ||
          prev.sortAscending != next.sortAscending ||
          prev.folder != next.folder ||
          prev.artist != next.artist ||
          prev.album != next.album ||
          prev.albumKey != next.albumKey ||
          prev.playlistId != next.playlistId ||
          prev.modifiedFromEpoch != next.modifiedFromEpoch ||
          prev.modifiedBeforeEpoch != next.modifiedBeforeEpoch) {
        return;
      }
      if (prev.items == next.items || next.items.isEmpty) return;

      _handleGalleryItemsReplacement(prev, next);
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

    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    final mainContent = Column(
      children: [
        if (state.isScanning)
          const LinearProgressIndicator(
            key: Key('nas_scanning_indicator'),
            minHeight: 2,
          ),

        // Search Bar Row (collapsible, explicit toggle)
        if (_searchOpen ||
            _searchController.text.isNotEmpty ||
            state.search.isNotEmpty) ...[
          Entrance(index: 1, child: _buildSearchBar(context, state)),
          const Divider(height: 1),
        ],

        // Active Scope Breadcrumbs (if folder, artist, album, albumKey, or playlist is set)
        if (state.folder != null ||
            state.artist != null ||
            state.album != null ||
            state.albumKey != null ||
            state.playlistId != null)
          Entrance(index: 2, child: _buildScopeBreadcrumbs(context, state)),

        // Media Center Tabs (Mobile only; desktop uses sidebar rail)
        if (!isDesktop) ...[
          Entrance(index: 3, child: _buildTabBar(context, state)),
          const Divider(height: 1),
        ],

        // Error Banner (if any)
        if (state.errorCode != null)
          _buildErrorBanner(context, state.errorCode!),

        // Body content
        Expanded(child: _buildSurfaceContent(context, state, sourcesState)),

        if (_selectionMode) _buildBatchBottomBar(context, state),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Action Toolbar
            Entrance(
              index: 0,
              child: _buildTopBar(context, state, sourcesState, activeSource),
            ),
            const Divider(height: 1),

            Expanded(
              child: isDesktop
                  ? Row(
                      children: [
                        _buildDesktopRail(context, state),
                        const VerticalDivider(width: 1),
                        Expanded(child: mainContent),
                      ],
                    )
                  : mainContent,
            ),

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

    final isNarrow = MediaQuery.sizeOf(context).width < 600;

    final sourceWidget = sourcesState.sources.isNotEmpty
        ? PopupMenuButton<String>(
            key: const Key('nas_source_selector_button'),
            tooltip: context.nasSources,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(VRadius.input),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      switch (currentSource?.type) {
                        NasSourceType.sftp => Icons.terminal,
                        NasSourceType.webdav => Icons.cloud_outlined,
                        NasSourceType.smb => Icons.folder_shared_outlined,
                        NasSourceType.jellyfin => Icons.tv,
                        NasSourceType.emby => Icons.live_tv,
                        _ => Icons.storage,
                      },
                      size: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isNarrow ? 76 : 120),
                    child: Text(
                      currentSource?.name ?? context.nasSources,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
            onSelected: (val) {
              if (val == '__add__') {
                NasSourceDialog.show(context);
              } else if (val == '__install__') {
                NasDeploymentChooser.show(context);
              } else if (val == '__diagnostics__') {
                if (currentSource != null) {
                  NasDiagnosticsDialog.show(context, source: currentSource);
                }
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
              if (currentSource != null)
                PopupMenuItem(
                  value: '__diagnostics__',
                  child: Row(
                    children: [
                      const Icon(Icons.monitor_heart_outlined, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(context.l10n.nasDiagnosticsTitle)),
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

    final statusWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state.isScanning
                ? theme.colorScheme.primary
                : (currentSource != null
                      ? theme.colorScheme.primary.withValues(alpha: 0.8)
                      : theme.colorScheme.outline),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            state.isScanning
                ? '${context.l10n.nasScanning} (${state.scannedCount})'
                : lastScanText,
            style: monoTextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: state.isScanning
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
                : () {
                    ref.invalidate(nasHomeProvider);
                    ref.read(nasProvider.notifier).scan();
                  },
            icon: const Icon(Icons.sync, size: 18),
          );

    final searchToggleBtn = IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(
        _searchOpen ||
                _searchController.text.isNotEmpty ||
                state.search.isNotEmpty
            ? Icons.search_off
            : Icons.search,
        size: 18,
      ),
      tooltip: context.l10n.nasSearchHint,
      onPressed: () {
        setState(() {
          _searchOpen = !_searchOpen;
          if (!_searchOpen && _searchController.text.isNotEmpty) {
            _searchController.clear();
            ref.read(nasProvider.notifier).setSearch('');
          }
        });
      },
    );

    final showSort = state.playlistId == null;
    final sortBtn = showSort
        ? PopupMenuButton<(NasSortKey, bool)>(
            key: const ValueKey('nas-sort'),
            icon: const Icon(Icons.sort, size: 18),
            tooltip: context.nasSort,
            padding: EdgeInsets.zero,
            onSelected: (val) {
              ref.read(nasProvider.notifier).setSort(val.$1, ascending: val.$2);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: (NasSortKey.modified, false),
                child: Row(
                  children: [
                    if (state.sortKey == NasSortKey.modified &&
                        !state.sortAscending)
                      const Icon(Icons.check, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${ctx.nasSortModified} (${ctx.nasSortDescending})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: (NasSortKey.modified, true),
                child: Row(
                  children: [
                    if (state.sortKey == NasSortKey.modified &&
                        state.sortAscending)
                      const Icon(Icons.check, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${ctx.nasSortModified} (${ctx.nasSortAscending})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: (NasSortKey.name, true),
                child: Row(
                  children: [
                    if (state.sortKey == NasSortKey.name && state.sortAscending)
                      const Icon(Icons.check, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${ctx.nasSortName} (${ctx.nasSortAscending})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: (NasSortKey.name, false),
                child: Row(
                  children: [
                    if (state.sortKey == NasSortKey.name &&
                        !state.sortAscending)
                      const Icon(Icons.check, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${ctx.nasSortName} (${ctx.nasSortDescending})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: (NasSortKey.size, false),
                child: Row(
                  children: [
                    if (state.sortKey == NasSortKey.size &&
                        !state.sortAscending)
                      const Icon(Icons.check, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${ctx.nasSortSize} (${ctx.nasSortDescending})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: (NasSortKey.size, true),
                child: Row(
                  children: [
                    if (state.sortKey == NasSortKey.size && state.sortAscending)
                      const Icon(Icons.check, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${ctx.nasSortSize} (${ctx.nasSortAscending})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : null;

    final selectModeBtn = IconButton(
      key: const ValueKey('nas-selection'),
      visualDensity: VisualDensity.compact,
      icon: Icon(
        _selectionMode ? Icons.check_circle : Icons.checklist_outlined,
        size: 18,
        color: _selectionMode ? theme.colorScheme.primary : null,
      ),
      tooltip: context.nasSelectMode,
      onPressed: () {
        setState(() {
          _selectionMode = !_selectionMode;
          if (!_selectionMode) _selectedItems.clear();
        });
      },
    );

    if (isNarrow) {
      final moreMenuBtn = PopupMenuButton<String>(
        key: const Key('nas_mobile_more_button'),
        icon: const Icon(Icons.more_vert, size: 20),
        tooltip: context.l10n.navMore,
        padding: EdgeInsets.zero,
        onSelected: (val) {
          switch (val) {
            case 'scan':
              if (state.isScanning) {
                ref.read(nasProvider.notifier).cancelScan();
              } else {
                ref.invalidate(nasHomeProvider);
                ref.read(nasProvider.notifier).scan();
              }
              break;
            case 'selection':
              setState(() {
                _selectionMode = !_selectionMode;
                if (!_selectionMode) _selectedItems.clear();
              });
              break;
            case 'downloads':
              NasDownloadsSheet.show(context);
              break;
            case 'config':
              final currentSource = ref.read(nasSourcesProvider).selected;
              NasScanConfigDialog.show(
                context,
                source: currentSource,
                sourceId: currentSource?.id ?? state.serverId,
                initialConfig: state.config,
                onSave: (cfg) => ref.read(nasProvider.notifier).saveConfig(cfg),
              );
              break;
            case 'settings':
              _openLibrarySettings(context, state);
              break;
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'scan',
            child: Row(
              children: [
                Icon(
                  state.isScanning ? Icons.stop : Icons.sync,
                  size: 18,
                  color: state.isScanning ? ctx.vDanger : null,
                ),
                const SizedBox(width: 8),
                Text(
                  state.isScanning ? ctx.l10n.nasCancelScan : ctx.l10n.nasScan,
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'selection',
            child: Row(
              children: [
                Icon(
                  _selectionMode
                      ? Icons.check_circle
                      : Icons.checklist_outlined,
                  size: 18,
                  color: _selectionMode ? theme.colorScheme.primary : null,
                ),
                const SizedBox(width: 8),
                Text(ctx.nasSelectMode),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'downloads',
            child: Row(
              children: [
                const Icon(Icons.download_outlined, size: 18),
                const SizedBox(width: 8),
                Text('${ctx.nasTabDownloads} ($activeDownloads)'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'config',
            child: Row(
              children: [
                const Icon(Icons.tune, size: 18),
                const SizedBox(width: 8),
                Text(ctx.l10n.nasConfigure),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'settings',
            child: Row(
              children: [
                const Icon(Icons.settings_outlined, size: 18),
                const SizedBox(width: 8),
                Text(ctx.l10n.nasLibrarySettings),
              ],
            ),
          ),
        ],
      );

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: theme.colorScheme.surfaceContainerLow,
        child: Row(
          children: [
            sourceWidget,
            const SizedBox(width: 8),
            Expanded(child: statusWidget),
            searchToggleBtn,
            ?sortBtn,
            moreMenuBtn,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          sourceWidget,
          const SizedBox(width: 10),
          Expanded(child: statusWidget),
          searchToggleBtn,
          ?sortBtn,
          selectModeBtn,
          downloadsBtn,
          configBtn,
          settingsBtn,
          const SizedBox(width: 6),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VRadius.input),
          ),
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
          final capturedSource = ref.read(nasSourcesProvider).selected;
          final capturedCategory = _currentCategory;
          _searchDebounce = Timer(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            if (ref.read(nasSourcesProvider).selected != capturedSource) return;
            if (_currentCategory != capturedCategory) return;
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
      title = state.artist!.isEmpty
          ? context.l10n.hardwareUnknown
          : state.artist!;
      icon = Icons.person;
    } else if (state.album != null || state.albumKey != null) {
      final albumName =
          state.album ??
          state.items.firstOrNull?.album ??
          _musicGroups
              .where((g) => g.key == state.albumKey)
              .firstOrNull
              ?.name ??
          context.l10n.nasTabMusic;
      title = albumName;
      icon = Icons.album;
    } else {
      title = '';
      icon = Icons.filter_list;
    }

    final showPlayAll =
        state.items.isNotEmpty && _currentTab != NasMediaTab.photos;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (showPlayAll)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: Text(context.nasPlayAll),
                      onPressed: () => _openInApp(state.items.first),
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.close, size: 14),
                    label: Text(context.nasClearScope),
                    onPressed: () {
                      _photoAlbumsDrilledDown = false;
                      _photoAlbumsPreDrillFolder = null;
                      _photoAlbumsPreDrillSource = null;
                      ref.read(nasProvider.notifier).setScope();
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDesktopRail(BuildContext context, NasState state) {
    final theme = Theme.of(context);
    final tabs = [
      (
        NasMediaTab.home,
        context.l10n.nasTabHome,
        Icons.home_outlined,
        Icons.home,
      ),
      (
        NasMediaTab.photos,
        context.l10n.nasFilterImages,
        Icons.image_outlined,
        Icons.image,
      ),
      (
        NasMediaTab.videos,
        context.l10n.nasFilterVideos,
        Icons.movie_outlined,
        Icons.movie,
      ),
      (
        NasMediaTab.music,
        context.l10n.nasTabMusic,
        Icons.music_note_outlined,
        Icons.music_note,
      ),
      (
        NasMediaTab.library,
        context.nasTabLibrary,
        Icons.video_library_outlined,
        Icons.video_library,
      ),
    ];

    int? getTabCount(NasMediaTab tab) => switch (tab) {
      NasMediaTab.photos => state.totals.images,
      NasMediaTab.videos => state.totals.videos,
      NasMediaTab.music => state.totals.audio,
      _ => null,
    };

    return Container(
      width: 80,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          const SizedBox(height: 8),
          for (final tabInfo in tabs) ...[
            Builder(
              builder: (ctx) {
                final isSelected = _currentTab == tabInfo.$1;
                final count = getTabCount(tabInfo.$1);
                return Tooltip(
                  message: count != null && count > 0
                      ? '${tabInfo.$2} ($count)'
                      : tabInfo.$2,
                  child: InkWell(
                    key: Key('nas_tab_${tabInfo.$1.name}'),
                    onTap: () => _selectTab(tabInfo.$1),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 68,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.4,
                                ),
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? tabInfo.$4 : tabInfo.$3,
                            size: 20,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tabInfo.$2,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
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
      (
        NasMediaTab.library,
        context.nasTabLibrary,
        Icons.video_library_outlined,
      ),
    ];

    int? getTabCount(NasMediaTab tab) => switch (tab) {
      NasMediaTab.photos => state.totals.images,
      NasMediaTab.videos => state.totals.videos,
      NasMediaTab.music => state.totals.audio,
      _ => null,
    };

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: tabs.map((tabInfo) {
            final isSelected = _currentTab == tabInfo.$1;
            final count = getTabCount(tabInfo.$1);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('nas_tab_${tabInfo.$1.name}'),
                selected: isSelected,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  tabInfo.$3,
                  size: 15,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabInfo.$2,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 12,
                        color: isSelected
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (count != null && count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 0.5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.18,
                                )
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count > 999
                              ? '${(count / 1000).toStringAsFixed(1)}k'
                              : '$count',
                          style: monoTextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                selectedColor: theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.55)
                      : theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.45,
                        ),
                  width: isSelected ? 1.2 : 0.8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
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
    final playlistUnavailable = errorCode == 'NAS_PLAYLIST_LOAD_FAILED';
    final errorText = playlistUnavailable
        ? context.l10n.nasPlaylistLoadFailed
        : errorCode == 'NAS_SCAN_CANCELLED'
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
              maxLines: playlistUnavailable ? 3 : null,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (playlistUnavailable)
            IconButton(
              key: const Key('nas_playlist_retry_button'),
              tooltip: context.l10n.refresh,
              onPressed: () => ref.read(nasProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
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
    if (_currentTab == NasMediaTab.downloads) {
      return const NasDownloadsSheet();
    }

    if (_currentTab == NasMediaTab.library) {
      return _buildLibrarySurface(context, state, sourcesState);
    }

    if (sourcesState.sources.isEmpty) {
      return _buildEmptySourcesView(context);
    }

    if (state.playlistId != null) {
      return _buildPlaylistDetailSurface(context, state);
    }

    if (_currentTab == NasMediaTab.playlists) {
      return _buildPlaylistsSurface(context, state);
    }

    final currentSource = sourcesState.selected;
    final isMediaServer = currentSource?.isMediaServer ?? false;

    // Empty scan configuration guidance (for SFTP, SMB, WebDAV)
    if (!isMediaServer && state.config.includePaths.isEmpty) {
      return _buildEmptyConfigGuidance(context, state);
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
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.nasNoIndexDesc,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
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
      case NasMediaTab.library:
        return _buildLibrarySurface(context, state, sourcesState);
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

  Widget _buildLibrarySurface(
    BuildContext context,
    NasState state,
    NasSourcesState sourcesState,
  ) {
    return Column(
      children: [
        _buildLibrarySubNavBar(context, state),
        Expanded(
          child: _buildLibrarySectionContent(context, state, sourcesState),
        ),
      ],
    );
  }

  Widget _buildLibrarySectionContent(
    BuildContext context,
    NasState state,
    NasSourcesState sourcesState,
  ) {
    if (_librarySection == NasLibrarySection.downloads) {
      return const NasDownloadsSheet();
    }
    if (_librarySection == NasLibrarySection.manage) {
      return _buildLibraryManagementSurface(context, state, sourcesState);
    }

    // Online subsections require at least one configured media source
    if (sourcesState.sources.isEmpty) {
      return _buildEmptySourcesView(context);
    }

    final currentSource = sourcesState.selected;
    final isMediaServer = currentSource?.isMediaServer ?? false;

    switch (_librarySection) {
      case NasLibrarySection.downloads:
        return const NasDownloadsSheet();
      case NasLibrarySection.manage:
        return _buildLibraryManagementSurface(context, state, sourcesState);
      case NasLibrarySection.playlists:
        return _buildPlaylistsSurface(context, state);
      case NasLibrarySection.folders:
        if (!isMediaServer && state.config.includePaths.isEmpty) {
          return _buildEmptyConfigGuidance(context, state);
        }
        return _buildFoldersSurface(context, state);
      case NasLibrarySection.favorites:
        if (!isMediaServer && state.config.includePaths.isEmpty) {
          return _buildEmptyConfigGuidance(context, state);
        }
        return _buildFavoritesSurface(context, state);
    }
  }

  Widget _buildLibraryManagementSurface(
    BuildContext context,
    NasState state,
    NasSourcesState sourcesState,
  ) {
    final theme = Theme.of(context);
    final currentSource = sourcesState.selected;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Sources Card
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VRadius.card),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.dns_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  context.l10n.nasSources,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  currentSource != null
                      ? '${currentSource.name} (${currentSource.type.name.toUpperCase()})'
                      : context.l10n.nasNoSources,
                  style: monoTextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.outline,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => NasSourceDialog.show(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(context.l10n.nasAddSource),
                      onPressed: () => NasSourceDialog.show(context),
                    ),
                    const SizedBox(width: 8),
                    if (currentSource != null)
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(context.l10n.nasEditSource),
                        onPressed: () => NasSourceDialog.show(
                          context,
                          source: currentSource,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Scan & Indexing
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VRadius.card),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(
                Icons.sync_rounded,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(
              context.l10n.nasConfigureScanDirs,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              state.config.includePaths.isEmpty
                  ? context.l10n.nasEmptyConfigTitle
                  : '${state.config.includePaths.length} ${context.l10n.nasIncludePaths.toLowerCase()}',
              style: monoTextStyle(
                fontSize: 12,
                color: theme.colorScheme.outline,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              NasScanConfigDialog.show(
                context,
                source: currentSource,
                sourceId: currentSource?.id ?? state.serverId,
                initialConfig: state.config,
                onSave: (cfg) => ref.read(nasProvider.notifier).saveConfig(cfg),
              );
            },
          ),
        ),

        // Open Behavior & Library Settings
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VRadius.card),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
            ),
            title: Text(
              context.l10n.nasLibrarySettings,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.nasManageLibrary,
              style: monoTextStyle(
                fontSize: 12,
                color: theme.colorScheme.outline,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => _openLibrarySettings(context, state),
          ),
        ),

        // Diagnostics
        if (currentSource != null)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VRadius.card),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.health_and_safety_outlined,
                  color: theme.colorScheme.tertiary,
                ),
              ),
              title: Text(
                context.l10n.nasDiagnosticsTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                currentSource.name,
                style: monoTextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () =>
                  NasDiagnosticsDialog.show(context, source: currentSource),
            ),
          ),

        // Media Server Deployment
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VRadius.card),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.rocket_launch_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            title: Text(
              context.l10n.nasInstallTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.l10n.nasDeployDockerTitle,
              style: monoTextStyle(
                fontSize: 12,
                color: theme.colorScheme.outline,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => NasDeploymentChooser.show(context),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyConfigGuidance(BuildContext context, NasState state) {
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.nasEmptyConfigDesc,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
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

  Widget _buildLibrarySubNavBar(BuildContext context, NasState state) {
    final theme = Theme.of(context);
    final sections = [
      (
        NasLibrarySection.folders,
        context.l10n.nasTabFolders,
        Icons.folder_outlined,
        'nas_tab_folders',
      ),
      (
        NasLibrarySection.favorites,
        context.l10n.nasTabFavorites,
        Icons.favorite_outline,
        'nas_tab_favorites',
      ),
      (
        NasLibrarySection.playlists,
        context.l10n.nasTabPlaylists,
        Icons.queue_music_outlined,
        'nas_tab_playlists',
      ),
      (
        NasLibrarySection.downloads,
        context.nasTabDownloads,
        Icons.download_outlined,
        'nas_tab_downloads',
      ),
      (
        NasLibrarySection.manage,
        context.nasManageLibrary,
        Icons.settings_suggest_outlined,
        'nas_tab_manage',
      ),
    ];

    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: sections.map((sec) {
            final isSelected = _librarySection == sec.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                key: Key(sec.$4),
                selected: isSelected,
                showCheckmark: false,
                avatar: Icon(
                  sec.$3,
                  size: 16,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                label: Text(
                  sec.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                onSelected: (_) => _selectLibrarySection(sec.$1),
              ),
            );
          }).toList(),
        ),
      ),
    );
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
            Text(context.nasNoSources, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              context.nasNoSourcesDesc,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
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
                  onPressed: () => NasDeploymentChooser.show(context),
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
    final totals = state.totals;
    final isDesktop =
        context.isDesktop || MediaQuery.sizeOf(context).width >= 720;
    final activeSource = ref.watch(nasSourcesProvider).selected;

    final homeSectionsAsync = ref.watch(nasHomeProvider);
    final homeSections = homeSectionsAsync.asData?.value;
    final homePlaybackByPath = homeSections?.playbackByPath;

    final continueWatching =
        homeSections?.continueWatching ?? const <NasMediaItem>[];
    final continueListening =
        homeSections?.continueListening ?? const <NasMediaItem>[];
    final photoItems = homeSections != null
        ? homeSections.photos
        : state.items.where((i) => i.kind == NasMediaKind.image).toList();
    final videoItems = homeSections != null
        ? homeSections.videos
        : state.items.where((i) => i.kind == NasMediaKind.video).toList();
    final musicItems = homeSections != null
        ? homeSections.music
        : state.items.where((i) => i.kind == NasMediaKind.audio).toList();

    final hasShelves =
        continueWatching.isNotEmpty ||
        continueListening.isNotEmpty ||
        videoItems.isNotEmpty ||
        photoItems.isNotEmpty ||
        musicItems.isNotEmpty ||
        totals.videos > 0 ||
        totals.images > 0 ||
        totals.audio > 0;

    return SingleChildScrollView(
      key: PageStorageKey('nas_scroll_${activeSource?.id}_home'),
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (homeSectionsAsync.isLoading && homeSections == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          // Shelf 1: Continue Watching (Videos with explicit progress)
          if (continueWatching.isNotEmpty) ...[
            Entrance(
              index: 0,
              child: _buildHomeSectionHeader(
                context,
                title: context.nasContinueWatching,
                color: theme.colorScheme.primary,
                count: continueWatching.length,
                onTapAll: () => _selectTab(NasMediaTab.videos),
              ),
            ),
            const SizedBox(height: 8),
            isDesktop
                ? Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: continueWatching
                        .take(4)
                        .map(
                          (item) => _buildHomeVideoCard(
                            context,
                            item,
                            isDesktop,
                            playbackByPath: homePlaybackByPath,
                          ),
                        )
                        .toList(),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: continueWatching.take(4).map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildHomeVideoCard(
                            context,
                            item,
                            isDesktop,
                            playbackByPath: homePlaybackByPath,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
            const SizedBox(height: 20),
          ],

          // Shelf 2: Continue Listening (Audio tracks with explicit progress)
          if (continueListening.isNotEmpty) ...[
            Entrance(
              index: 1,
              child: _buildHomeSectionHeader(
                context,
                title: context.nasContinueListening,
                color: theme.colorScheme.tertiary,
                count: continueListening.length,
                onTapAll: () => _selectTab(NasMediaTab.music),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: continueListening.take(6).map((item) {
                  final savedPlayback = homePlaybackByPath?[item.path];
                  final progress =
                      (savedPlayback != null &&
                          savedPlayback.duration != null &&
                          savedPlayback.duration!.inMilliseconds > 0)
                      ? (savedPlayback.position.inMilliseconds /
                                savedPlayback.duration!.inMilliseconds)
                            .clamp(0.0, 1.0)
                      : null;

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      key: Key('nas_home_listening_${item.name}'),
                      borderRadius: BorderRadius.circular(VRadius.card),
                      onTap: () => _openInApp(item),
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(VRadius.card),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: NasThumbnailImage(
                                        item: item,
                                        fit: BoxFit.cover,
                                        fallbackIcon: Icons.music_note_rounded,
                                      ),
                                    ),
                                    if (progress != null && progress > 0)
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 3,
                                          backgroundColor: Colors.black38,
                                          valueColor: AlwaysStoppedAnimation(
                                            theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title ?? item.name,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.artist != null && item.artist!.isNotEmpty)
                              Text(
                                item.artist!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Shelf 3: Recent Photos
          if (photoItems.isNotEmpty || totals.images > 0) ...[
            Entrance(
              index: 2,
              child: _buildHomeSectionHeader(
                context,
                title: context.nasRecentPhotos,
                color: theme.colorScheme.secondary,
                count: totals.images > 0 ? totals.images : photoItems.length,
                onTapAll: () => _selectTab(NasMediaTab.photos),
              ),
            ),
            const SizedBox(height: 8),
            if (photoItems.isNotEmpty)
              isDesktop
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: photoItems
                          .take(10)
                          .map(
                            (item) =>
                                _buildHomePhotoTile(context, item, isDesktop),
                          )
                          .toList(),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: photoItems.take(10).map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildHomePhotoTile(
                              context,
                              item,
                              isDesktop,
                            ),
                          );
                        }).toList(),
                      ),
                    )
            else
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VRadius.card),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.image_outlined,
                    color: theme.colorScheme.secondary,
                  ),
                  title: Text(context.l10n.nasFilterImages),
                  subtitle: Text(context.l10n.nasItemCount(totals.images)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _selectTab(NasMediaTab.photos),
                ),
              ),
            const SizedBox(height: 20),
          ],

          // Shelf 3: Recent Videos
          if (videoItems.isNotEmpty || totals.videos > 0) ...[
            Entrance(
              index: 3,
              child: _buildHomeSectionHeader(
                context,
                title: context.nasRecentVideos,
                color: theme.colorScheme.primary,
                count: totals.videos > 0 ? totals.videos : videoItems.length,
                onTapAll: () => _selectTab(NasMediaTab.videos),
              ),
            ),
            const SizedBox(height: 8),
            if (videoItems.isNotEmpty)
              isDesktop
                  ? Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: videoItems
                          .take(6)
                          .map(
                            (item) => _buildHomeVideoCard(
                              context,
                              item,
                              isDesktop,
                              playbackByPath: homePlaybackByPath,
                            ),
                          )
                          .toList(),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: videoItems.take(6).map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _buildHomeVideoCard(
                              context,
                              item,
                              isDesktop,
                              playbackByPath: homePlaybackByPath,
                            ),
                          );
                        }).toList(),
                      ),
                    )
            else
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VRadius.card),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.movie_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(context.l10n.nasFilterVideos),
                  subtitle: Text(context.l10n.nasItemCount(totals.videos)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _selectTab(NasMediaTab.videos),
                ),
              ),
            const SizedBox(height: 20),
          ],

          // Shelf 4: Recent Music
          if (musicItems.isNotEmpty || totals.audio > 0) ...[
            Entrance(
              index: 4,
              child: _buildHomeSectionHeader(
                context,
                title: context.nasRecentMusic,
                color: theme.colorScheme.tertiary,
                count: totals.audio > 0 ? totals.audio : musicItems.length,
                onTapAll: () => _selectTab(NasMediaTab.music),
              ),
            ),
            const SizedBox(height: 8),
            if (musicItems.isNotEmpty)
              ...musicItems
                  .take(4)
                  .map((item) => _buildMediaListItem(context, item))
            else
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VRadius.card),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.music_note_outlined,
                    color: theme.colorScheme.tertiary,
                  ),
                  title: Text(context.l10n.nasTabMusic),
                  subtitle: Text(context.l10n.nasItemCount(totals.audio)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _selectTab(NasMediaTab.music),
                ),
              ),
            const SizedBox(height: 20),
          ],

          // Fallback if no media items found
          if (!hasShelves) ...[
            ...state.items.map((item) => _buildMediaListItem(context, item)),
            const SizedBox(height: 16),
          ],

          // Shelf 5: Library Quick Access
          Entrance(index: 5, child: _buildHomeLibrarySection(context, state)),
          const SizedBox(height: 16),
          if (state.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Shimmer(
                child: Column(
                  children: const [
                    SkeletonListTile(),
                    SkeletonListTile(),
                    SkeletonListTile(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeLibrarySection(BuildContext context, NasState state) {
    final theme = Theme.of(context);
    final items = [
      (
        NasLibrarySection.folders,
        context.l10n.nasTabFolders,
        Icons.folder_outlined,
        'nas_tab_folders',
      ),
      (
        NasLibrarySection.favorites,
        context.l10n.nasTabFavorites,
        Icons.favorite_outline,
        'nas_tab_favorites',
      ),
      (
        NasLibrarySection.playlists,
        context.l10n.nasTabPlaylists,
        Icons.queue_music_outlined,
        'nas_tab_playlists',
      ),
      (
        NasLibrarySection.downloads,
        context.nasTabDownloads,
        Icons.download_outlined,
        'nas_tab_downloads',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 3.5,
              height: 16,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.nasTabLibrary,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            return ActionChip(
              key: Key(item.$4),
              avatar: Icon(item.$3, size: 16, color: theme.colorScheme.primary),
              label: Text(
                item.$2,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              onPressed: () {
                _selectTab(NasMediaTab.library);
                _selectLibrarySection(item.$1);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHomeVideoCard(
    BuildContext context,
    NasMediaItem item,
    bool isDesktop, {
    Map<String, NasPlaybackState>? playbackByPath,
  }) {
    final theme = Theme.of(context);
    final ext = item.name.contains('.')
        ? item.name.split('.').last.toUpperCase()
        : 'VIDEO';
    final isSelected = _selectedItems.contains(item);

    final playbackSnapshot = ref.watch(nasPlaybackProvider).asData?.value;
    final isCurrent =
        playbackSnapshot?.current?.path == item.path &&
        playbackSnapshot?.current?.serverId == item.serverId;

    final batchPlayback =
        playbackByPath ?? ref.watch(nasProvider).playbackByPath;
    final savedPlayback = batchPlayback[item.path];
    final isSavedMatch =
        savedPlayback != null &&
        savedPlayback.serverId == item.serverId &&
        savedPlayback.path == item.path &&
        savedPlayback.duration != null &&
        savedPlayback.duration!.inMilliseconds > 0;

    final progress =
        (isCurrent &&
            playbackSnapshot != null &&
            playbackSnapshot.duration.inMilliseconds > 0)
        ? (playbackSnapshot.position.inMilliseconds /
                  playbackSnapshot.duration.inMilliseconds)
              .clamp(0.0, 1.0)
        : (isSavedMatch
              ? (savedPlayback.position.inMilliseconds /
                        savedPlayback.duration!.inMilliseconds)
                    .clamp(0.0, 1.0)
              : null);

    return Container(
      key: Key('nas_item_${item.name}'),
      width: isDesktop ? 220 : 160,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(VRadius.card),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: isSelected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: _selectionMode
                ? () => _toggleSelection(item)
                : () => _handleItemTap(item),
            borderRadius: BorderRadius.circular(VRadius.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: NasThumbnailImage(
                          item: item,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.movie_outlined,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Text(
                            ext,
                            style: monoTextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      if (progress != null && progress > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: Colors.black26,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title ?? item.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        SftpFileItem.formatBytes(item.sizeBytes),
                        style: monoTextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_selectionMode)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.black54,
                ),
                padding: const EdgeInsets.all(2),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  item.isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: item.isFavorite ? context.vDanger : Colors.white,
                ),
                tooltip: context.l10n.nasTabFavorites,
                onPressed: () => _toggleFavorite(item),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomePhotoTile(
    BuildContext context,
    NasMediaItem item,
    bool isDesktop,
  ) {
    final theme = Theme.of(context);
    final ext = item.name.contains('.')
        ? item.name.split('.').last.toUpperCase()
        : 'IMG';
    final isSelected = _selectedItems.contains(item);

    return Semantics(
      label: item.title ?? item.name,
      button: true,
      child: InkWell(
        key: Key('nas_item_${item.name}'),
        onTap: _selectionMode
            ? () => _toggleSelection(item)
            : () => _openInApp(item),
        borderRadius: BorderRadius.circular(VRadius.input),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VRadius.input),
          child: Container(
            width: isDesktop ? 120 : 96,
            height: isDesktop ? 120 : 96,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: isSelected
                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                  : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                NasThumbnailImage(
                  item: item,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.image_outlined,
                ),
                if (_selectionMode)
                  Positioned(
                    top: 3,
                    left: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.black54,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      ext,
                      style: monoTextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                    ),
                    child: Text(
                      item.title ?? item.name,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeSectionHeader(
    BuildContext context, {
    required String title,
    required Color color,
    required int count,
    required VoidCallback onTapAll,
  }) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          onPressed: onTapAll,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.nasItemCount(count),
                style: monoTextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 16, color: color),
            ],
          ),
        ),
      ],
    );
  }

  /// 组列表 / 分页加载骨架屏 (替代转圈)。
  Widget _buildSkeletonList() {
    return Shimmer(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: 6,
        itemBuilder: (_, _) => const SkeletonListTile(),
      ),
    );
  }

  int _navigationGeneration = 0;
  int _pagingGeneration = 0;
  bool _edgeLoading = false;
  bool _previousEdgeFailed = false;
  bool _nextEdgeFailed = false;
  bool _isViewerOpen = false;
  bool _nearLeadingEdge = true;
  bool _nearTrailingEdge = false;
  bool _restoringAnchor = false;
  int _userScrollSequence = 0;
  int _anchorRevision = 0;
  final Map<String, GlobalKey> _tileKeys = {};
  _GalleryLayout? _lastGalleryLayout;

  void _pruneTileKeys(List<NasMediaItem> items) {
    final itemKeys = items.map((i) => "${i.serverId}:${i.path}").toSet();
    _tileKeys.removeWhere((k, _) => !itemKeys.contains(k));
  }

  void _onScroll() {
    if (!mounted) return;
    if (_restoringAnchor) return;
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      if (position.userScrollDirection != ScrollDirection.idle) {
        _userScrollSequence++;
      }
      final nearLeading = position.pixels <= 300;
      final nearTrailing = position.extentAfter <= 300;
      if (nearLeading != _nearLeadingEdge ||
          nearTrailing != _nearTrailingEdge) {
        setState(() {
          _nearLeadingEdge = nearLeading;
          _nearTrailingEdge = nearTrailing;
        });
      }
    }

    if (_isViewerOpen || _restoringAnchor) return;
    final state = ref.read(nasProvider);
    if (!state.galleryWindowEnabled || _currentTab != NasMediaTab.photos) {
      return;
    }
    if (state.isLoading || _edgeLoading) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.userScrollDirection == ScrollDirection.forward) {
      if (position.pixels <= 300 && state.hasPrevious && !_previousEdgeFailed) {
        _loadPreviousPage();
      }
    } else if (position.userScrollDirection == ScrollDirection.reverse) {
      if (position.extentAfter <= 300 && state.hasMore && !_nextEdgeFailed) {
        _loadNextPage();
      }
    }
  }

  void _handleGalleryItemsReplacement(NasState prev, NasState next) {
    if (!_scrollController.hasClients) return;

    final scrollBox =
        _scrollController.position.context.storageContext.findRenderObject()
            as RenderBox?;
    if (scrollBox == null || !scrollBox.hasSize) return;
    final scrollOrigin = scrollBox.localToGlobal(Offset.zero);
    final viewportHeight = scrollBox.size.height;

    String? bestServerId;
    String? bestPath;
    double bestDy = double.infinity;

    for (final item in prev.items) {
      final key = _tileKeys["${item.serverId}:${item.path}"];
      if (key == null) continue;
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) continue;

      final tileOrigin = box.localToGlobal(Offset.zero);
      final dy = tileOrigin.dy - scrollOrigin.dy;
      final bottom = dy + box.size.height;

      if (bottom > 0 && dy < viewportHeight) {
        if (dy < bestDy) {
          bestDy = dy;
          bestServerId = item.serverId;
          bestPath = item.path;
        }
      }
    }

    if (bestServerId == null || bestPath == null || bestDy == double.infinity) {
      return;
    }

    final captureGen = _pagingGeneration;
    final capturedUserSeq = _userScrollSequence;
    final targetRevision = ++_anchorRevision;
    final targetItems = next.items;
    final capturedSourceId = ref.read(nasSourcesProvider).selected?.id;
    final capturedCat = _currentCategory;
    final capturedSearch = next.search;
    final capturedSortKey = next.sortKey;
    final capturedSortAscending = next.sortAscending;
    final capturedFolder = next.folder;
    final capturedArtist = next.artist;
    final capturedAlbum = next.album;
    final capturedAlbumKey = next.albumKey;
    final capturedPlaylistId = next.playlistId;
    final capturedModifiedFrom = next.modifiedFromEpoch;
    final capturedModifiedBefore = next.modifiedBeforeEpoch;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          captureGen != _pagingGeneration ||
          _anchorRevision != targetRevision ||
          _userScrollSequence != capturedUserSeq ||
          ref.read(nasSourcesProvider).selected?.id != capturedSourceId ||
          _currentCategory != capturedCat ||
          !_scrollController.hasClients) {
        return;
      }
      final curState = ref.read(nasProvider);
      if (!identical(curState.items, targetItems) ||
          !curState.galleryWindowEnabled ||
          curState.search != capturedSearch ||
          curState.sortKey != capturedSortKey ||
          curState.sortAscending != capturedSortAscending ||
          curState.folder != capturedFolder ||
          curState.artist != capturedArtist ||
          curState.album != capturedAlbum ||
          curState.albumKey != capturedAlbumKey ||
          curState.playlistId != capturedPlaylistId ||
          curState.modifiedFromEpoch != capturedModifiedFrom ||
          curState.modifiedBeforeEpoch != capturedModifiedBefore) {
        return;
      }

      final layout = _lastGalleryLayout;
      final anchorKey = "$bestServerId:$bestPath";
      final targetRowIndex = layout?.itemToRowIndex[anchorKey];

      if (layout != null && targetRowIndex != null) {
        final rowOffset = layout.offsetOfRow(targetRowIndex);
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetOffset = (rowOffset - bestDy).clamp(0.0, maxScroll);

        _restoringAnchor = true;
        _scrollController.jumpTo(targetOffset);
        _restoringAnchor = false;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              captureGen != _pagingGeneration ||
              _anchorRevision != targetRevision ||
              _userScrollSequence != capturedUserSeq ||
              ref.read(nasSourcesProvider).selected?.id != capturedSourceId ||
              _currentCategory != capturedCat ||
              !_scrollController.hasClients) {
            return;
          }
          final frame2State = ref.read(nasProvider);
          if (!identical(frame2State.items, targetItems) ||
              !frame2State.galleryWindowEnabled ||
              frame2State.search != capturedSearch ||
              frame2State.sortKey != capturedSortKey ||
              frame2State.sortAscending != capturedSortAscending ||
              frame2State.folder != capturedFolder ||
              frame2State.artist != capturedArtist ||
              frame2State.album != capturedAlbum ||
              frame2State.albumKey != capturedAlbumKey ||
              frame2State.playlistId != capturedPlaylistId ||
              frame2State.modifiedFromEpoch != capturedModifiedFrom ||
              frame2State.modifiedBeforeEpoch != capturedModifiedBefore) {
            return;
          }

          final key = _tileKeys[anchorKey];
          final ctx = key?.currentContext;
          final box = ctx?.findRenderObject() as RenderBox?;
          final frame2ScrollBox =
              _scrollController.position.context.storageContext
                      .findRenderObject()
                  as RenderBox?;
          if (box != null &&
              box.hasSize &&
              box.attached &&
              frame2ScrollBox != null &&
              frame2ScrollBox.hasSize) {
            final currentDy =
                box.localToGlobal(Offset.zero).dy -
                frame2ScrollBox.localToGlobal(Offset.zero).dy;
            final delta = currentDy - bestDy;
            if (delta.abs() > 0.5) {
              final newMax = _scrollController.position.maxScrollExtent;
              final refined = (_scrollController.offset + delta).clamp(
                0.0,
                newMax,
              );
              _restoringAnchor = true;
              _scrollController.jumpTo(refined);
              _restoringAnchor = false;
            }
          }
        });
      }
    });
  }

  _VisibleAnchor? _captureVisibleAnchor() {
    if (!_scrollController.hasClients) return null;
    final scrollBox =
        _scrollController.position.context.storageContext.findRenderObject()
            as RenderBox?;
    if (scrollBox == null || !scrollBox.hasSize) return null;
    final scrollOrigin = scrollBox.localToGlobal(Offset.zero);
    final viewportHeight = scrollBox.size.height;

    String? bestServerId;
    String? bestPath;
    double bestDy = double.infinity;

    final state = ref.read(nasProvider);
    for (final item in state.items) {
      final key = _tileKeys["${item.serverId}:${item.path}"];
      if (key == null) continue;
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) continue;

      final tileOrigin = box.localToGlobal(Offset.zero);
      final dy = tileOrigin.dy - scrollOrigin.dy;
      final bottom = dy + box.size.height;

      if (bottom > 0 && dy < viewportHeight) {
        if (dy < bestDy) {
          bestDy = dy;
          bestServerId = item.serverId;
          bestPath = item.path;
        }
      }
    }

    if (bestServerId != null && bestPath != null && bestDy != double.infinity) {
      return _VisibleAnchor(
        serverId: bestServerId,
        path: bestPath,
        viewportDy: bestDy,
      );
    }
    return null;
  }

  Future<void> _openImageViewerDialog({
    required NasMediaItem item,
    required List<NasMediaItem> images,
    required int initialIndex,
  }) async {
    final isGallery =
        ref.read(nasProvider).galleryWindowEnabled &&
        _currentTab == NasMediaTab.photos;
    final openGen = _pagingGeneration;
    final openNavGen = _navigationGeneration;
    final openSource = ref.read(nasSourcesProvider).selected;
    final openQuery = ref.read(nasProvider);
    final openServerId = openQuery.serverId;
    final openCategory = openQuery.browseCategory;
    final openFilter = openQuery.filter;
    final openFavorites = openQuery.favoritesOnly;
    final openSearch = openQuery.search;
    final openSortKey = openQuery.sortKey;
    final openSortAsc = openQuery.sortAscending;
    final openFolder = openQuery.folder;
    final openArtist = openQuery.artist;
    final openAlbum = openQuery.album;
    final openAlbumKey = openQuery.albumKey;
    final openPlaylistId = openQuery.playlistId;
    final openModFrom = openQuery.modifiedFromEpoch;
    final openModBefore = openQuery.modifiedBeforeEpoch;
    final openGallery = openQuery.galleryWindowEnabled;

    final oldAnchor = isGallery ? _captureVisibleAnchor() : null;
    NasMediaItem activeViewerItem = item;

    _isViewerOpen = true;
    try {
      final popped = await NasImageViewerDialog.show(
        context,
        item: item,
        items: images,
        initialIndex: initialIndex,
        thumbnailFuture: ref.read(nasProvider.notifier).thumbnailPath(item),
        isFavorite: item.isFavorite,
        onOpenExternal: () => _openExternal(activeViewerItem),
        onCurrentItemChanged: (latest) {
          activeViewerItem = latest;
        },
      );
      if (popped != null) {
        activeViewerItem = popped;
      }
    } finally {
      _isViewerOpen = false;
      if (isGallery) {
        _scheduleViewerReturnRestoration(
          openGen: openGen,
          openNavGen: openNavGen,
          openSource: openSource,
          openServerId: openServerId,
          openCategory: openCategory,
          openFilter: openFilter,
          openFavorites: openFavorites,
          openSearch: openSearch,
          openSortKey: openSortKey,
          openSortAsc: openSortAsc,
          openFolder: openFolder,
          openArtist: openArtist,
          openAlbum: openAlbum,
          openAlbumKey: openAlbumKey,
          openPlaylistId: openPlaylistId,
          openModFrom: openModFrom,
          openModBefore: openModBefore,
          openGallery: openGallery,
          oldAnchor: oldAnchor,
          activeViewerItem: activeViewerItem,
        );
      }
    }
  }

  void _scheduleViewerReturnRestoration({
    required int openGen,
    required int openNavGen,
    required NasSource? openSource,
    required String? openServerId,
    required String openCategory,
    required NasMediaKind? openFilter,
    required bool openFavorites,
    required String openSearch,
    required NasSortKey openSortKey,
    required bool openSortAsc,
    required String? openFolder,
    required String? openArtist,
    required String? openAlbum,
    required String? openAlbumKey,
    required String? openPlaylistId,
    required int? openModFrom,
    required int? openModBefore,
    required bool openGallery,
    required _VisibleAnchor? oldAnchor,
    required NasMediaItem activeViewerItem,
  }) {
    final capturedUserSeq = _userScrollSequence;
    final targetRevision = ++_anchorRevision;
    final targetItems = ref.read(nasProvider).items;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          openGen != _pagingGeneration ||
          openNavGen != _navigationGeneration ||
          _anchorRevision != targetRevision ||
          _userScrollSequence != capturedUserSeq ||
          ref.read(nasSourcesProvider).selected != openSource ||
          _currentCategory != openCategory ||
          !_scrollController.hasClients) {
        return;
      }
      final curState = ref.read(nasProvider);
      if (!identical(curState.items, targetItems) ||
          curState.serverId != openServerId ||
          curState.browseCategory != openCategory ||
          curState.filter != openFilter ||
          curState.favoritesOnly != openFavorites ||
          curState.search != openSearch ||
          curState.sortKey != openSortKey ||
          curState.sortAscending != openSortAsc ||
          curState.folder != openFolder ||
          curState.artist != openArtist ||
          curState.album != openAlbum ||
          curState.albumKey != openAlbumKey ||
          curState.playlistId != openPlaylistId ||
          curState.modifiedFromEpoch != openModFrom ||
          curState.modifiedBeforeEpoch != openModBefore ||
          curState.galleryWindowEnabled != openGallery) {
        return;
      }

      final layout = _lastGalleryLayout;
      if (layout == null) return;

      String restoreKey;
      double targetOffset;
      double? desiredDy;

      final oldAnchorKey = oldAnchor != null
          ? "${oldAnchor.serverId}:${oldAnchor.path}"
          : null;
      final oldRowIndex = oldAnchorKey != null
          ? layout.itemToRowIndex[oldAnchorKey]
          : null;

      if (oldAnchor != null && oldRowIndex != null) {
        restoreKey = oldAnchorKey!;
        desiredDy = oldAnchor.viewportDy;
        final rowOffset = layout.offsetOfRow(oldRowIndex);
        final maxScroll = _scrollController.position.maxScrollExtent;
        targetOffset = (rowOffset - desiredDy).clamp(0.0, maxScroll);
      } else {
        final currentKey =
            "${activeViewerItem.serverId}:${activeViewerItem.path}";
        final currentRowIndex = layout.itemToRowIndex[currentKey];
        if (currentRowIndex == null) return;
        restoreKey = currentKey;
        desiredDy = 0.0;
        final rowOffset = layout.offsetOfRow(currentRowIndex);
        final maxScroll = _scrollController.position.maxScrollExtent;
        targetOffset = rowOffset.clamp(0.0, maxScroll);
      }

      _restoringAnchor = true;
      _scrollController.jumpTo(targetOffset);
      _restoringAnchor = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            openGen != _pagingGeneration ||
            openNavGen != _navigationGeneration ||
            _anchorRevision != targetRevision ||
            _userScrollSequence != capturedUserSeq ||
            ref.read(nasSourcesProvider).selected != openSource ||
            _currentCategory != openCategory ||
            !_scrollController.hasClients) {
          return;
        }
        final frame2State = ref.read(nasProvider);
        if (!identical(frame2State.items, targetItems) ||
            frame2State.serverId != openServerId ||
            frame2State.browseCategory != openCategory ||
            frame2State.filter != openFilter ||
            frame2State.favoritesOnly != openFavorites ||
            frame2State.search != openSearch ||
            frame2State.sortKey != openSortKey ||
            frame2State.sortAscending != openSortAsc ||
            frame2State.folder != openFolder ||
            frame2State.artist != openArtist ||
            frame2State.album != openAlbum ||
            frame2State.albumKey != openAlbumKey ||
            frame2State.playlistId != openPlaylistId ||
            frame2State.modifiedFromEpoch != openModFrom ||
            frame2State.modifiedBeforeEpoch != openModBefore ||
            frame2State.galleryWindowEnabled != openGallery) {
          return;
        }

        final key = _tileKeys[restoreKey];
        final ctx = key?.currentContext;
        final box = ctx?.findRenderObject() as RenderBox?;
        final frame2ScrollBox =
            _scrollController.position.context.storageContext.findRenderObject()
                as RenderBox?;
        if (box != null &&
            box.hasSize &&
            box.attached &&
            frame2ScrollBox != null &&
            frame2ScrollBox.hasSize &&
            desiredDy != null) {
          final currentDy =
              box.localToGlobal(Offset.zero).dy -
              frame2ScrollBox.localToGlobal(Offset.zero).dy;
          final delta = currentDy - desiredDy;
          if (delta.abs() > 0.5) {
            final newMax = _scrollController.position.maxScrollExtent;
            final refined = (_scrollController.offset + delta).clamp(
              0.0,
              newMax,
            );
            _restoringAnchor = true;
            _scrollController.jumpTo(refined);
            _restoringAnchor = false;
          }
        }
      });
    });
  }

  Future<void> _loadPreviousPage() async {
    final state = ref.read(nasProvider);
    if (!state.hasPrevious || state.isLoading || _edgeLoading) return;
    if (state.galleryWindowEnabled) {
      if (_isViewerOpen) return;
      if (_scrollController.hasClients &&
          _scrollController.position.pixels > 300) {
        return;
      }
    }

    final gen = ++_pagingGeneration;
    final capturedSource = ref.read(nasSourcesProvider).selected;
    final capturedCat = _currentCategory;

    if (!state.galleryWindowEnabled) {
      await ref.read(nasProvider.notifier).loadPrevious();
      if (!mounted ||
          gen != _pagingGeneration ||
          ref.read(nasSourcesProvider).selected != capturedSource ||
          _currentCategory != capturedCat) {
        return;
      }
      final postState = ref.read(nasProvider);
      if (postState.errorCode != null) {
        return;
      }
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      return;
    }

    setState(() => _edgeLoading = true);

    try {
      await ref.read(nasProvider.notifier).loadPrevious();
      if (!mounted ||
          gen != _pagingGeneration ||
          ref.read(nasSourcesProvider).selected != capturedSource ||
          _currentCategory != capturedCat) {
        return;
      }
      final postState = ref.read(nasProvider);
      if (postState.errorCode != null) {
        setState(() => _previousEdgeFailed = true);
        return;
      }
      setState(() => _previousEdgeFailed = false);
    } catch (_) {
      if (mounted &&
          gen == _pagingGeneration &&
          ref.read(nasSourcesProvider).selected == capturedSource &&
          _currentCategory == capturedCat) {
        setState(() => _previousEdgeFailed = true);
      }
    } finally {
      if (mounted && gen == _pagingGeneration) {
        setState(() => _edgeLoading = false);
      }
    }
  }

  Future<void> _loadNextPage() async {
    final state = ref.read(nasProvider);
    if (!state.hasMore || state.isLoading || _edgeLoading) return;
    if (state.galleryWindowEnabled) {
      if (_isViewerOpen) return;
      if (_scrollController.hasClients &&
          _scrollController.position.extentAfter > 300) {
        return;
      }
    }

    final gen = ++_pagingGeneration;
    final capturedSource = ref.read(nasSourcesProvider).selected;
    final capturedCat = _currentCategory;

    if (!state.galleryWindowEnabled) {
      await ref.read(nasProvider.notifier).loadMore();
      if (!mounted ||
          gen != _pagingGeneration ||
          ref.read(nasSourcesProvider).selected != capturedSource ||
          _currentCategory != capturedCat) {
        return;
      }
      final postState = ref.read(nasProvider);
      if (postState.errorCode != null) {
        return;
      }
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      return;
    }

    setState(() => _edgeLoading = true);

    try {
      await ref.read(nasProvider.notifier).loadMore();
      if (!mounted ||
          gen != _pagingGeneration ||
          ref.read(nasSourcesProvider).selected != capturedSource ||
          _currentCategory != capturedCat) {
        return;
      }
      final postState = ref.read(nasProvider);
      if (postState.errorCode != null) {
        setState(() => _nextEdgeFailed = true);
        return;
      }
      setState(() => _nextEdgeFailed = false);
    } catch (_) {
      if (mounted &&
          gen == _pagingGeneration &&
          ref.read(nasSourcesProvider).selected == capturedSource &&
          _currentCategory == capturedCat) {
        setState(() => _nextEdgeFailed = true);
      }
    } finally {
      if (mounted && gen == _pagingGeneration) {
        setState(() => _edgeLoading = false);
      }
    }
  }

  Widget _buildPaginationFooter(BuildContext context, NasState state) {
    if (!state.hasMore && !state.hasPrevious) return const SizedBox.shrink();

    final isGallery =
        state.galleryWindowEnabled && _currentTab == NasMediaTab.photos;
    final canPrev =
        state.hasPrevious &&
        !state.isLoading &&
        !_edgeLoading &&
        (!isGallery || (!_isViewerOpen && _nearLeadingEdge));
    final canNext =
        state.hasMore &&
        !state.isLoading &&
        !_edgeLoading &&
        (!isGallery || (!_isViewerOpen && _nearTrailingEdge));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: OutlinedButton.icon(
              key: const Key('nas_previous_page_button'),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: Text(context.nasPreviousPage),
              onPressed: canPrev
                  ? () {
                      setState(() => _previousEdgeFailed = false);
                      _loadPreviousPage();
                    }
                  : null,
            ),
          ),
          Text(
            '${state.items.length} / ${state.matchingCount}',
            style: monoTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: FilledButton.tonalIcon(
              key: const Key('nas_next_page_button'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(context.nasNextPage),
              onPressed: canNext
                  ? () {
                      setState(() => _nextEdgeFailed = false);
                      _loadNextPage();
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  InlineSpan _buildGalleryHeaderSpan(
    ThemeData theme,
    String dateKey,
    int count,
  ) {
    return TextSpan(
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      children: [
        TextSpan(text: dateKey),
        const TextSpan(text: '  '),
        TextSpan(
          text: '($count)',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  _GalleryLayout _buildGalleryLayout(
    BuildContext context,
    List<NasMediaItem> images,
    double maxWidth,
  ) {
    final theme = Theme.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final textHeightBehavior = DefaultTextHeightBehavior.maybeOf(context);
    final contentWidth = (maxWidth - 24.0).clamp(1.0, double.infinity);
    final currentSource = ref.watch(nasSourcesProvider).selected?.id ?? '';
    final density = _photoDensityBySource[currentSource] ?? 4;
    final columns = maxWidth < 320 ? 2 : density.clamp(3, 5);
    final spacing = 8.0;
    final itemSize = (contentWidth - (columns - 1) * spacing) / columns;
    final rowHeight = itemSize + spacing;
    final availableHeaderWidth = (maxWidth - 52.0).clamp(1.0, double.infinity);

    final dateGroups = <String, List<NasMediaItem>>{};
    for (final img in images) {
      final dateKey = _formatEpochDate(context, img.modifiedEpoch);
      (dateGroups[dateKey] ??= []).add(img);
    }

    final rows = <_GalleryRow>[];
    final prefixOffsets = <double>[];
    final itemToRowIndex = <String, int>{};
    var currentOffset = 0.0;
    var globalIndex = 0;

    for (final entry in dateGroups.entries) {
      final groupImages = entry.value;
      final headerSpan = _buildGalleryHeaderSpan(
        theme,
        entry.key,
        groupImages.length,
      );
      final textPainter = TextPainter(
        text: headerSpan,
        textScaler: textScaler,
        textDirection: textDirection,
        locale: locale,
        textHeightBehavior: textHeightBehavior,
      )..layout(maxWidth: availableHeaderWidth);
      final measuredHeight = textPainter.height.ceilToDouble();
      textPainter.dispose();
      final headerHeight = 20.0 + math.max(14.0, measuredHeight);

      prefixOffsets.add(currentOffset);
      rows.add(
        _GalleryHeaderRow(
          dateKey: entry.key,
          count: groupImages.length,
          extent: headerHeight,
        ),
      );
      currentOffset += headerHeight;

      for (var i = 0; i < groupImages.length; i += columns) {
        final chunk = groupImages.sublist(
          i,
          (i + columns > groupImages.length) ? groupImages.length : i + columns,
        );
        final rowIndex = rows.length;
        prefixOffsets.add(currentOffset);
        rows.add(
          _GalleryItemRow(
            items: chunk,
            startIndex: globalIndex,
            extent: rowHeight,
          ),
        );
        for (final item in chunk) {
          itemToRowIndex["${item.serverId}:${item.path}"] = rowIndex;
        }
        currentOffset += rowHeight;
        globalIndex += chunk.length;
      }
    }

    return _GalleryLayout(
      rows: rows,
      prefixOffsets: prefixOffsets,
      columns: columns,
      itemSize: itemSize,
      totalExtent: currentOffset,
      itemToRowIndex: itemToRowIndex,
    );
  }

  Widget _buildPhotoFolderGroupsPaginationFooter(BuildContext context) {
    if (_photoFolderPageIndex == 0 && !_hasMorePhotoFolderGroups) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _photoFolderPageIndex > 0 && !_loadingPhotoFolders
                ? _previousPhotoFolderGroupsPage
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${_photoFolderPageIndex + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _hasMorePhotoFolderGroups && !_loadingPhotoFolders
                ? _nextPhotoFolderGroupsPage
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSurface(BuildContext context, NasState state) {
    final images = state.items
        .where((i) => i.kind == NasMediaKind.image)
        .toList();

    _pruneTileKeys(images);

    final currentSource = ref.watch(nasSourcesProvider).selected?.id ?? '';
    final currentDensity = _photoDensityBySource[currentSource] ?? 4;

    final densityButton = PopupMenuButton<int>(
      tooltip: context.nasPhotoDensity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(VRadius.input),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_column_outlined,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              '$currentDensity',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      onSelected: (d) => _setPhotoDensity(d),
      itemBuilder: (ctx) => [
        for (final d in [3, 4, 5])
          PopupMenuItem(
            value: d,
            child: Row(
              children: [
                if (d == currentDensity)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text('$d ${ctx.nasPhotoDensity}'),
              ],
            ),
          ),
      ],
    );

    final photosHeader = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChoiceChip(
              selected: !_photoAlbumsMode,
              showCheckmark: false,
              avatar: const Icon(Icons.grid_on, size: 14),
              label: Text(
                context.nasPhotoTimeline,
                style: const TextStyle(fontSize: 12),
              ),
              onSelected: (val) {
                if (val) {
                  if (_photoFolderScrollController.hasClients) {
                    _photoAlbumsScrollOffset =
                        _photoFolderScrollController.offset;
                  }
                  setState(() => _photoAlbumsMode = false);
                }
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              selected: _photoAlbumsMode,
              showCheckmark: false,
              avatar: const Icon(Icons.folder_outlined, size: 14),
              label: Text(
                context.nasPhotoAlbums,
                style: const TextStyle(fontSize: 12),
              ),
              onSelected: (val) async {
                if (val) {
                  if (_photoAlbumsDrilledDown) {
                    _photoAlbumsDrilledDown = false;
                    final preDrill = _photoAlbumsPreDrillFolder;
                    final preDrillSource = _photoAlbumsPreDrillSource;
                    final capturedNavGen = _navigationGeneration;
                    _photoAlbumsPreDrillFolder = null;
                    _photoAlbumsPreDrillSource = null;
                    if (ref.read(nasProvider).folder != preDrill) {
                      await ref
                          .read(nasProvider.notifier)
                          .setScope(folder: preDrill);
                    }
                    if (!mounted ||
                        _navigationGeneration != capturedNavGen ||
                        (preDrillSource != null &&
                            ref.read(nasSourcesProvider).selected?.id !=
                                preDrillSource.id)) {
                      return;
                    }
                  }
                  setState(() {
                    _photoAlbumsMode = true;
                    if (_photoFolderGroups.isEmpty) {
                      _loadPhotoFolderGroupsPage();
                    }
                  });
                  final targetOffset = _photoAlbumsScrollOffset;
                  final capturedNavGen = _navigationGeneration;
                  final capturedSource = ref.read(nasSourcesProvider).selected;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted ||
                        !_photoAlbumsMode ||
                        _navigationGeneration != capturedNavGen ||
                        ref.read(nasSourcesProvider).selected?.id !=
                            capturedSource?.id) {
                      return;
                    }
                    if (_photoFolderScrollController.hasClients) {
                      final maxScroll =
                          _photoFolderScrollController.position.maxScrollExtent;
                      final effectiveOffset = maxScroll > 0
                          ? targetOffset.clamp(0.0, maxScroll)
                          : targetOffset;
                      _photoFolderScrollController.jumpTo(effectiveOffset);
                    }
                  });
                }
              },
            ),
            if (!_photoAlbumsMode) ...[const SizedBox(width: 8), densityButton],
          ],
        ),
      ),
    );

    if (_photoAlbumsMode) {
      if (_loadingPhotoFolders && _photoFolderGroups.isEmpty) {
        return Column(
          children: [
            photosHeader,
            const Divider(height: 1),
            Expanded(child: _buildSkeletonList()),
          ],
        );
      }
      if (_photoFolderGroups.isEmpty) {
        return Column(
          children: [
            photosHeader,
            const Divider(height: 1),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_off_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.nasNoSearchResults,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      return Column(
        children: [
          photosHeader,
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              controller: _photoFolderScrollController,
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 4 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.9,
              ),
              itemCount: _photoFolderGroups.length,
              itemBuilder: (ctx, index) {
                final group = _photoFolderGroups[index];
                return Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VRadius.card),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      _photoAlbumsScrollOffset =
                          _photoFolderScrollController.hasClients
                          ? _photoFolderScrollController.offset
                          : 0.0;
                      _photoAlbumsPreDrillFolder = ref.read(nasProvider).folder;
                      _photoAlbumsPreDrillSource = ref
                          .read(nasSourcesProvider)
                          .selected;
                      _photoAlbumsDrilledDown = true;
                      ref
                          .read(nasProvider.notifier)
                          .setScope(folder: group.key);
                      setState(() => _photoAlbumsMode = false);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: group.representative != null
                              ? NasThumbnailImage(
                                  item: group.representative!,
                                  fit: BoxFit.cover,
                                  fallbackIcon: Icons.folder,
                                )
                              : Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.folder,
                                    size: 40,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name.isEmpty ? '/' : group.name,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                context.l10n.nasItemCount(group.count),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                      fontSize: 10.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildPhotoFolderGroupsPaginationFooter(context),
        ],
      );
    }

    if (images.isEmpty && !state.isLoading) {
      return Column(
        children: [
          photosHeader,
          const Divider(height: 1),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.nasNoSearchResults,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        photosHeader,
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = _buildGalleryLayout(
                context,
                images,
                constraints.maxWidth,
              );
              _lastGalleryLayout = layout;

              return Column(
                children: [
                  if (_previousEdgeFailed)
                    Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.nasOperationFailed,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed:
                                (!state.isLoading &&
                                    !_edgeLoading &&
                                    !_isViewerOpen &&
                                    (!state.galleryWindowEnabled ||
                                        _nearLeadingEdge))
                                ? () {
                                    setState(() => _previousEdgeFailed = false);
                                    _loadPreviousPage();
                                  }
                                : null,
                            child: Text(context.l10n.stateRetry),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (_restoringAnchor) return false;
                        if (notification is UserScrollNotification) {
                          if (notification.direction != ScrollDirection.idle) {
                            _userScrollSequence++;
                          }
                        } else if (notification is ScrollUpdateNotification) {
                          if (notification.dragDetails != null) {
                            _userScrollSequence++;
                          }
                        }
                        return false;
                      },
                      child: CustomScrollView(
                        key: const Key('nas_image_grid'),
                        controller: _scrollController,
                        slivers: [
                          SliverVariedExtentList.builder(
                            itemCount: layout.rows.length,
                            itemExtentBuilder: (index, _) =>
                                layout.rows[index].extent,
                            itemBuilder: (context, index) {
                              final row = layout.rows[index];
                              if (row is _GalleryHeaderRow) {
                                return _buildGalleryHeaderRow(context, row);
                              } else if (row is _GalleryItemRow) {
                                return _buildGalleryItemRow(
                                  context,
                                  row,
                                  images,
                                  layout.columns,
                                  layout.itemSize,
                                );
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_nextEdgeFailed)
                    Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.nasOperationFailed,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed:
                                (!state.isLoading &&
                                    !_edgeLoading &&
                                    !_isViewerOpen &&
                                    (!state.galleryWindowEnabled ||
                                        _nearTrailingEdge))
                                ? () {
                                    setState(() => _nextEdgeFailed = false);
                                    _loadNextPage();
                                  }
                                : null,
                            child: Text(context.l10n.stateRetry),
                          ),
                        ],
                      ),
                    ),
                  _buildPaginationFooter(context, state),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryHeaderRow(BuildContext context, _GalleryHeaderRow row) {
    final theme = Theme.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final textHeightBehavior = DefaultTextHeightBehavior.maybeOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 14,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: _buildGalleryHeaderSpan(theme, row.dateKey, row.count),
              textDirection: textDirection,
              textScaler: textScaler,
              locale: locale,
              textHeightBehavior: textHeightBehavior,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryItemRow(
    BuildContext context,
    _GalleryItemRow row,
    List<NasMediaItem> allImages,
    int columns,
    double itemSize,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < columns; i++)
            if (i < row.items.length) ...[
              if (i > 0) const SizedBox(width: 8),
              SizedBox(
                width: itemSize,
                height: itemSize,
                child: _buildImageGridTile(
                  context,
                  row.items[i],
                  allImages,
                  row.startIndex + i,
                ),
              ),
            ] else ...[
              if (i > 0) const SizedBox(width: 8),
              SizedBox(width: itemSize, height: itemSize),
            ],
        ],
      ),
    );
  }

  String _formatEpochDate(BuildContext context, int epoch) {
    if (epoch <= 0) return context.l10n.hardwareUnknown;
    final dt = DateTime.fromMillisecondsSinceEpoch(
      epoch > 10000000000 ? epoch : epoch * 1000,
      isUtc: true,
    );
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d (UTC)';
  }

  Widget _buildImageGridTile(
    BuildContext context,
    NasMediaItem item,
    List<NasMediaItem> images,
    int index,
  ) {
    final theme = Theme.of(context);
    final isSelected = _isItemSelected(item);
    final tileKey = _tileKeys.putIfAbsent(
      "${item.serverId}:${item.path}",
      () => GlobalKey(),
    );

    return KeyedSubtree(
      key: tileKey,
      child: InkWell(
        key: Key('nas_item_${item.name}'),
        onTap: _selectionMode
            ? () => _toggleSelection(item)
            : () async {
                final foundIndex = images.indexWhere(
                  (i) => i.serverId == item.serverId && i.path == item.path,
                );
                final initialIndex = foundIndex >= 0 ? foundIndex : 0;
                await _openImageViewerDialog(
                  item: item,
                  images: images,
                  initialIndex: initialIndex,
                );
              },
        onLongPress: () {
          if (!_selectionMode) {
            setState(() => _selectionMode = true);
          }
          _toggleSelection(item);
        },
        borderRadius: BorderRadius.circular(VRadius.input),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VRadius.input),
          child: Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NasThumbnailImage(
                  item: item,
                  fit: BoxFit.cover,
                  placeholder: Shimmer(child: const SkeletonBox()),
                  fallbackIcon: Icons.image_outlined,
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
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('nas-metadata-action'),
                          icon: const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.white70,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          tooltip: context.nasMediaDetails,
                          onPressed: () => _showItemMetadataDialog(item),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectionMode)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.black54,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideosSurface(BuildContext context, NasState state) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final videos = state.items
        .where((i) => i.kind == NasMediaKind.video)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                context.l10n.nasItemCount(videos.length),
                style: monoTextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              IconButton(
                key: const Key('nas_video_view_toggle_button'),
                icon: Icon(
                  _videoGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  size: 20,
                ),
                tooltip: _videoGridView
                    ? context.nasViewList
                    : context.nasViewGrid,
                onPressed: () =>
                    setState(() => _videoGridView = !_videoGridView),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: videos.isEmpty
              ? Center(
                  child: Text(
                    context.l10n.nasNoSearchResults,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                )
              : Builder(
                  builder: (context) {
                    final isLargeFont =
                        MediaQuery.textScalerOf(context).scale(1) > 1.3;
                    final showGrid = _videoGridView && !isLargeFont;
                    return showGrid
                        ? GridView.builder(
                            key: const Key('nas_media_list'),
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isDesktop ? 3 : 2,
                                  childAspectRatio: isDesktop ? 0.90 : 0.74,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: videos.length,
                            itemBuilder: (context, index) {
                              return _buildVideoCard(
                                context,
                                videos[index],
                                isGrid: true,
                              );
                            },
                          )
                        : ListView.builder(
                            key: const Key('nas_media_list'),
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8),
                            itemCount: videos.length,
                            itemBuilder: (context, index) {
                              return _buildMediaListItem(
                                context,
                                videos[index],
                              );
                            },
                          );
                  },
                ),
        ),
        _buildPaginationFooter(context, state),
      ],
    );
  }

  Widget _buildVideoCard(
    BuildContext context,
    NasMediaItem item, {
    bool isGrid = false,
  }) {
    final theme = Theme.of(context);
    final ext = item.name.contains('.')
        ? item.name.split('.').last.toUpperCase()
        : 'VIDEO';

    final playbackSnapshot = ref.watch(nasPlaybackProvider).asData?.value;
    final isCurrent =
        playbackSnapshot?.current?.path == item.path &&
        playbackSnapshot?.current?.serverId == item.serverId;

    final nasState = ref.watch(nasProvider);
    final savedPlayback = nasState.playbackByPath[item.path];
    final isSavedMatch =
        savedPlayback != null &&
        savedPlayback.serverId == item.serverId &&
        savedPlayback.path == item.path &&
        savedPlayback.duration != null &&
        savedPlayback.duration!.inMilliseconds > 0;

    final dur =
        item.duration ??
        (item.durationMillis != null
            ? Duration(milliseconds: item.durationMillis!)
            : savedPlayback?.duration);
    final durStr = dur != null ? _formatDuration(dur) : null;

    final progress =
        (isCurrent &&
            playbackSnapshot != null &&
            playbackSnapshot.duration.inMilliseconds > 0)
        ? (playbackSnapshot.position.inMilliseconds /
                  playbackSnapshot.duration.inMilliseconds)
              .clamp(0.0, 1.0)
        : (isSavedMatch
              ? (savedPlayback.position.inMilliseconds /
                        savedPlayback.duration!.inMilliseconds)
                    .clamp(0.0, 1.0)
              : null);

    return Card(
      key: Key('nas_item_${item.name}'),
      margin: isGrid
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VRadius.card),
        side: BorderSide(
          color: isCurrent
              ? theme.colorScheme.primary.withValues(alpha: 0.6)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _selectionMode
            ? () => _toggleSelection(item)
            : () => _handleItemTap(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: NasThumbnailImage(
                      item: item,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.movie_outlined,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        ext,
                        style: monoTextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  if (durStr != null)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 10,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              durStr,
                              style: monoTextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (progress != null && progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.black45,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  if (_selectionMode)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isItemSelected(item)
                              ? theme.colorScheme.primary
                              : Colors.black54,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          _isItemSelected(item)
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: isGrid
                    ? const EdgeInsets.fromLTRB(8, 4, 8, 6)
                    : const EdgeInsets.all(10),
                child: isGrid
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title ?? item.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  durStr ??
                                      SftpFileItem.formatBytes(item.sizeBytes),
                                  style: monoTextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  item.isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 16,
                                  color: item.isFavorite
                                      ? context.vDanger
                                      : null,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 26,
                                  minHeight: 26,
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip: context.l10n.nasTabFavorites,
                                onPressed: () => _toggleFavorite(item),
                              ),
                              PopupMenuButton<String>(
                                key: Key('nas_item_overflow_${item.name}'),
                                icon: const Icon(Icons.more_vert, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 22,
                                  minHeight: 26,
                                ),
                                tooltip: context.l10n.navMore,
                                onSelected: (action) {
                                  switch (action) {
                                    case 'info':
                                      _showItemMetadataDialog(item);
                                      break;
                                    case 'download':
                                      ref
                                          .read(nasProvider.notifier)
                                          .download(item);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.nasDownloading(item.name),
                                          ),
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
                                    key: const ValueKey('nas-metadata-action'),
                                    value: 'info',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            ctx.nasMediaDetails,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'download',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.download_outlined,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            ctx.nasTabDownloads,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'cast',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.cast, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            ctx.nasCast,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'external',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.open_in_new, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            ctx.l10n.nasOpenPolicyExternal,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'playlist',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.playlist_add,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            ctx.nasAddToPlaylist,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title ?? item.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${SftpFileItem.formatBytes(item.sizeBytes)} · ${_formatEpoch(item.modifiedEpoch)}',
                                  style: monoTextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              item.isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 20,
                              color: item.isFavorite ? context.vDanger : null,
                            ),
                            tooltip: context.l10n.nasTabFavorites,
                            onPressed: () => _toggleFavorite(item),
                          ),
                          PopupMenuButton<String>(
                            key: Key('nas_item_overflow_${item.name}'),
                            icon: const Icon(Icons.more_vert, size: 20),
                            tooltip: context.l10n.navMore,
                            onSelected: (action) {
                              switch (action) {
                                case 'info':
                                  _showItemMetadataDialog(item);
                                  break;
                                case 'download':
                                  ref.read(nasProvider.notifier).download(item);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.nasDownloading(item.name),
                                      ),
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
                                key: const ValueKey('nas-metadata-action'),
                                value: 'info',
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 18),
                                    const SizedBox(width: 8),
                                    Text(ctx.nasMediaDetails),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'download',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.download_outlined,
                                      size: 18,
                                    ),
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
                                    Text(ctx.nasAddToPlaylist),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
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

    final scopedTitle = state.artist != null
        ? (state.artist!.isEmpty ? context.l10n.hardwareUnknown : state.artist!)
        : (state.album ??
              (state.albumKey != null
                  ? (state.items.firstOrNull?.album ??
                        _musicGroups
                            .where((g) => g.key == state.albumKey)
                            .firstOrNull
                            ?.name ??
                        context.l10n.nasTabMusic)
                  : null));
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
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        context.l10n.nasItemCount(displayTracks.length),
                        style: theme.textTheme.bodySmall?.copyWith(
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
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
              borderRadius: BorderRadius.circular(VRadius.input),
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                showCheckmark: false,
                avatar: const Icon(Icons.audiotrack, size: 16),
                label: Text(context.nasAllTracks),
                selected: _musicGroup == null,
                onSelected: (selected) {
                  if (selected && _musicGroup != null) {
                    setState(() => _musicGroup = null);
                    ref.read(nasProvider.notifier).setScope();
                    ref
                        .read(nasProvider.notifier)
                        .setFilter(NasMediaKind.audio);
                  }
                },
              ),
              ChoiceChip(
                showCheckmark: false,
                avatar: const Icon(Icons.person, size: 16),
                label: Text(context.nasByArtist),
                selected: _musicGroup == NasIndexGroup.byArtist,
                onSelected: (selected) {
                  if (selected && _musicGroup != NasIndexGroup.byArtist) {
                    ref.read(nasProvider.notifier).setScope();
                    _selectMusicGroup(NasIndexGroup.byArtist);
                  }
                },
              ),
              ChoiceChip(
                showCheckmark: false,
                avatar: const Icon(Icons.album, size: 16),
                label: Text(context.nasByAlbum),
                selected: _musicGroup == NasIndexGroup.byAlbum,
                onSelected: (selected) {
                  if (selected && _musicGroup != NasIndexGroup.byAlbum) {
                    ref.read(nasProvider.notifier).setScope();
                    _selectMusicGroup(NasIndexGroup.byAlbum);
                  }
                },
              ),
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
                    ? _buildSkeletonList()
                    : Column(
                        children: [
                          Expanded(
                            child: _musicGroup == NasIndexGroup.byAlbum
                                ? GridView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(12),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount:
                                              MediaQuery.sizeOf(
                                                    context,
                                                  ).width >=
                                                  600
                                              ? 4
                                              : 2,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          childAspectRatio:
                                              MediaQuery.sizeOf(
                                                    context,
                                                  ).width >=
                                                  600
                                              ? 0.78
                                              : 0.70,
                                        ),
                                    itemCount: _musicGroups.length,
                                    itemBuilder: (context, index) {
                                      final g = _musicGroups[index];
                                      return Card(
                                        key: Key('nas_album_${g.key}'),
                                        elevation: 0,
                                        clipBehavior: Clip.antiAlias,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            VRadius.card,
                                          ),
                                          side: BorderSide(
                                            color: theme
                                                .colorScheme
                                                .outlineVariant
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            ref
                                                .read(nasProvider.notifier)
                                                .setScope(albumKey: g.key);
                                          },
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              AspectRatio(
                                                aspectRatio: 1,
                                                child: g.representative != null
                                                    ? NasThumbnailImage(
                                                        item: g.representative!,
                                                        fit: BoxFit.cover,
                                                        fallbackIcon:
                                                            Icons.album_rounded,
                                                      )
                                                    : Container(
                                                        color: theme
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        child: Icon(
                                                          Icons.album_rounded,
                                                          size: 40,
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                        ),
                                                      ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        8,
                                                        6,
                                                        8,
                                                        6,
                                                      ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        g.name,
                                                        style: theme
                                                            .textTheme
                                                            .titleSmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 12,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        context.l10n
                                                            .nasItemCount(
                                                              g.count,
                                                            ),
                                                        style: monoTextStyle(
                                                          fontSize: 10,
                                                          color: theme
                                                              .colorScheme
                                                              .outline,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(8),
                                    itemCount: _musicGroups.length,
                                    itemBuilder: (context, index) {
                                      final g = _musicGroups[index];
                                      return Card(
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.person,
                                            color: theme.colorScheme.primary,
                                          ),
                                          title: Text(
                                            g.name.isEmpty
                                                ? context.l10n.hardwareUnknown
                                                : g.name,
                                          ),
                                          subtitle: Text(
                                            context.l10n.nasItemCount(g.count),
                                          ),
                                          trailing: const Icon(
                                            Icons.chevron_right,
                                            size: 18,
                                          ),
                                          onTap: () {
                                            if (_musicGroup ==
                                                NasIndexGroup.byArtist) {
                                              ref
                                                  .read(nasProvider.notifier)
                                                  .setScope(
                                                    artist: g.key.isEmpty
                                                        ? ''
                                                        : g.name,
                                                  );
                                            } else {
                                              ref
                                                  .read(nasProvider.notifier)
                                                  .setScope(folder: g.key);
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
            style: monoTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
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
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        context.l10n.nasItemCount(state.items.length),
                        style: theme.textTheme.bodySmall?.copyWith(
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
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
      return _buildSkeletonList();
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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
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
                  borderRadius: BorderRadius.circular(VRadius.card),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: ListTile(
                  leading: Icon(Icons.folder, color: theme.colorScheme.primary),
                  title: Text(g.name, style: theme.textTheme.titleSmall),
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
            style: monoTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
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
    final favItems = state.items;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  key: const Key('nas_fav_filter_all'),
                  showCheckmark: false,
                  label: Text(context.nasFilterAll),
                  selected: state.filter == null,
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(nasProvider.notifier)
                          .setFilter(null, favoritesOnly: true);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('nas_fav_filter_photos'),
                  showCheckmark: false,
                  avatar: const Icon(Icons.photo_outlined, size: 14),
                  label: Text(context.l10n.nasTabPhotos),
                  selected: state.filter == NasMediaKind.image,
                  onSelected: (selected) {
                    ref
                        .read(nasProvider.notifier)
                        .setFilter(
                          selected ? NasMediaKind.image : null,
                          favoritesOnly: true,
                        );
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('nas_fav_filter_videos'),
                  showCheckmark: false,
                  avatar: const Icon(Icons.movie_outlined, size: 14),
                  label: Text(context.l10n.nasTabVideos),
                  selected: state.filter == NasMediaKind.video,
                  onSelected: (selected) {
                    ref
                        .read(nasProvider.notifier)
                        .setFilter(
                          selected ? NasMediaKind.video : null,
                          favoritesOnly: true,
                        );
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('nas_fav_filter_music'),
                  showCheckmark: false,
                  avatar: const Icon(Icons.music_note_outlined, size: 14),
                  label: Text(context.l10n.nasTabMusic),
                  selected: state.filter == NasMediaKind.audio,
                  onSelected: (selected) {
                    ref
                        .read(nasProvider.notifier)
                        .setFilter(
                          selected ? NasMediaKind.audio : null,
                          favoritesOnly: true,
                        );
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: favItems.isEmpty
              ? Center(
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  key: const Key('nas_media_list'),
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
                style: Theme.of(context).textTheme.titleMedium,
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                        borderRadius: BorderRadius.circular(VRadius.card),
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
                              onPressed: () =>
                                  _confirmDeletePlaylist(context, playlist),
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      context.l10n.nasItemCount(totalCount),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                        leading: _selectionMode
                            ? Checkbox(
                                value: _isItemSelected(item),
                                onChanged: (_) => _toggleSelection(item),
                              )
                            : CircleAvatar(child: Text('$globalOrdinal')),
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
                        onTap: _selectionMode
                            ? () => _toggleSelection(item)
                            : () => _openInApp(item),
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
        borderRadius: BorderRadius.circular(VRadius.input),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: _selectionMode
            ? Checkbox(
                value: _isItemSelected(item),
                onChanged: (_) => _toggleSelection(item),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(VRadius.input),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: NasThumbnailImage(
                    item: item,
                    fit: BoxFit.cover,
                    fallbackIcon: icon,
                  ),
                ),
              ),
        title: Text(
          item.title ?? item.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Builder(
          builder: (context) {
            final audioDetails = <String>[];
            if (item.kind == NasMediaKind.audio) {
              if (item.artist != null && item.artist!.isNotEmpty) {
                audioDetails.add(item.artist!);
              }
              if (item.album != null && item.album!.isNotEmpty) {
                audioDetails.add(item.album!);
              }
              if (item.durationMillis != null && item.durationMillis! > 0) {
                audioDetails.add(
                  _formatDuration(Duration(milliseconds: item.durationMillis!)),
                );
              }
            }
            audioDetails.add(SftpFileItem.formatBytes(item.sizeBytes));

            final text = item.kind == NasMediaKind.audio
                ? audioDetails.join(' · ')
                : '${SftpFileItem.formatBytes(item.sizeBytes)} · ${_formatEpoch(item.modifiedEpoch)}';

            return Text(
              text,
              style: monoTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.outline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        trailing: Builder(
          builder: (context) {
            final isNarrow = MediaQuery.sizeOf(context).width < 480;
            final playbackSnapshot = ref
                .watch(nasPlaybackProvider)
                .asData
                ?.value;
            final canAddToQueue =
                item.kind == NasMediaKind.audio &&
                playbackSnapshot != null &&
                playbackSnapshot.queue.isNotEmpty &&
                playbackSnapshot.current?.kind == NasMediaKind.audio &&
                playbackSnapshot.current?.serverId == item.serverId;

            if (isNarrow) {
              return PopupMenuButton<String>(
                key: Key('nas_item_overflow_${item.name}'),
                icon: const Icon(Icons.more_vert, size: 20),
                tooltip: context.l10n.navMore,
                onSelected: (action) {
                  switch (action) {
                    case 'info':
                      _showItemMetadataDialog(item);
                      break;
                    case 'favorite':
                      _toggleFavorite(item);
                      break;
                    case 'queue':
                      if (canAddToQueue) _addToQueue(item);
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
                    key: const ValueKey('nas-metadata-action'),
                    value: 'info',
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ctx.nasMediaDetails,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'favorite',
                    child: Row(
                      children: [
                        Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFav ? ctx.vDanger : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ctx.l10n.nasTabFavorites,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.kind == NasMediaKind.audio)
                    PopupMenuItem(
                      value: 'queue',
                      enabled: canAddToQueue,
                      child: Row(
                        children: [
                          Icon(
                            Icons.queue_music,
                            size: 18,
                            color: canAddToQueue ? null : theme.disabledColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ctx.nasAddToQueue,
                              overflow: TextOverflow.ellipsis,
                              style: canAddToQueue
                                  ? null
                                  : TextStyle(color: theme.disabledColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        const Icon(Icons.download_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ctx.nasTabDownloads,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'cast',
                    child: Row(
                      children: [
                        const Icon(Icons.cast, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ctx.nasCast,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'external',
                    child: Row(
                      children: [
                        const Icon(Icons.open_in_new, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ctx.l10n.nasOpenPolicyExternal,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'playlist',
                    child: Row(
                      children: [
                        const Icon(Icons.playlist_add, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ctx.l10n.nasTabPlaylists,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                  key: const ValueKey('nas-metadata-action'),
                  icon: const Icon(Icons.info_outline, size: 18),
                  tooltip: context.nasMediaDetails,
                  onPressed: () => _showItemMetadataDialog(item),
                ),
                IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: isFav ? context.vDanger : theme.colorScheme.outline,
                  ),
                  tooltip: context.l10n.nasTabFavorites,
                  onPressed: () => _toggleFavorite(item),
                ),
                if (item.kind == NasMediaKind.audio)
                  IconButton(
                    icon: const Icon(Icons.queue_music, size: 18),
                    tooltip: context.nasAddToQueue,
                    onPressed: canAddToQueue ? () => _addToQueue(item) : null,
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
        onTap: _selectionMode
            ? () => _toggleSelection(item)
            : () => _handleItemTap(item),
        onLongPress: () => _showAddToPlaylistDialog(item),
      ),
    );
  }
}

abstract class _GalleryRow {
  double get extent;
}

class _GalleryHeaderRow extends _GalleryRow {
  final String dateKey;
  final int count;
  @override
  final double extent;

  _GalleryHeaderRow({
    required this.dateKey,
    required this.count,
    required this.extent,
  });
}

class _GalleryItemRow extends _GalleryRow {
  final List<NasMediaItem> items;
  final int startIndex;
  @override
  final double extent;

  _GalleryItemRow({
    required this.items,
    required this.startIndex,
    required this.extent,
  });
}

class _GalleryLayout {
  final List<_GalleryRow> rows;
  final List<double> prefixOffsets;
  final int columns;
  final double itemSize;
  final double totalExtent;
  final Map<String, int> itemToRowIndex;

  const _GalleryLayout({
    required this.rows,
    required this.prefixOffsets,
    required this.columns,
    required this.itemSize,
    required this.totalExtent,
    required this.itemToRowIndex,
  });

  double offsetOfRow(int rowIndex) {
    if (rowIndex >= 0 && rowIndex < prefixOffsets.length) {
      return prefixOffsets[rowIndex];
    }
    return 0.0;
  }
}

class _VisibleAnchor {
  final String serverId;
  final String path;
  final double viewportDy;

  const _VisibleAnchor({
    required this.serverId,
    required this.path,
    required this.viewportDy,
  });
}
