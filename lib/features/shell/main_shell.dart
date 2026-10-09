// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/layout_breakpoints.dart';
import '../../core/design/motion.dart';
import '../../core/design/motion_widgets.dart';
import '../../core/design/tokens.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/diagnostics_provider.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/sftp_provider.dart';
import '../../core/providers/storage_providers.dart';
import '../../data/models/server_profile.dart';
import '../../widgets/context_inspector.dart';
import '../../widgets/delete_server_dialog.dart';
import '../../widgets/valhalla_app_icon.dart';
import '../settings/widgets/diagnostics_view.dart';
import '../chat/ai_chat_view.dart';
import '../chat/cli_chat_view.dart';
import '../commands/quick_commands_view.dart';
import '../dashboard/dashboard_view.dart';
import '../docker/docker_view.dart';
import '../files/sftp_file_view.dart';
import '../../core/providers/nas_provider.dart';
import '../../core/providers/nas_sources_provider.dart';
import '../nas/nas_media_view.dart';
import '../nas/widgets/nas_full_player_dialog.dart';
import '../nas/widgets/nas_mini_player.dart';
import '../nas/widgets/nas_source_dialog.dart';
import '../servers/server_form_dialog.dart';
import '../settings/settings_view.dart';
import '../settings/widgets/windows_appearance_actions.dart';
import '../system/system_view.dart';
import '../terminal/terminal_view.dart';
import 'widgets/connection_status_banner.dart';

int appSectionToViewIndex(AppSection section) => switch (section) {
  AppSection.dashboard => 0,
  AppSection.aiChat => 1,
  AppSection.terminal => 2,
  AppSection.files => 3,
  AppSection.docker => 4,
  AppSection.system => 5,
  AppSection.commands => 6,
  AppSection.settings => 7,
  AppSection.cliChat => 8,
  AppSection.nas => 9,
};

AppSection viewIndexToAppSection(int index) => switch (index) {
  0 => AppSection.dashboard,
  1 => AppSection.aiChat,
  2 => AppSection.terminal,
  3 => AppSection.files,
  4 => AppSection.docker,
  5 => AppSection.system,
  6 => AppSection.commands,
  7 => AppSection.settings,
  8 => AppSection.cliChat,
  9 => AppSection.nas,
  _ => AppSection.dashboard,
};

IconData appSectionIcon(
  AppSection section, {
  bool selected = false,
}) => switch (section) {
  AppSection.dashboard => selected ? Icons.dashboard : Icons.dashboard_outlined,
  AppSection.aiChat => selected ? Icons.smart_toy : Icons.smart_toy_outlined,
  AppSection.terminal => selected ? Icons.terminal : Icons.terminal_outlined,
  AppSection.files => selected ? Icons.folder : Icons.folder_outlined,
  AppSection.docker =>
    selected ? Icons.directions_boat : Icons.directions_boat_outlined,
  AppSection.system => selected ? Icons.memory : Icons.memory_outlined,
  AppSection.commands => selected ? Icons.bolt : Icons.bolt_outlined,
  AppSection.settings => selected ? Icons.settings : Icons.settings_outlined,
  AppSection.cliChat => selected ? Icons.forum : Icons.forum_outlined,
  AppSection.nas => selected ? Icons.perm_media : Icons.perm_media_outlined,
};

String localizedAppSectionName(BuildContext context, AppSection section) =>
    switch (section) {
      AppSection.dashboard => context.l10n.navDashboard,
      AppSection.aiChat => context.l10n.navAiChat,
      AppSection.terminal => context.l10n.navTerminal,
      AppSection.files => context.l10n.navFiles,
      AppSection.docker => context.l10n.navDocker,
      AppSection.system => context.l10n.navSystem,
      AppSection.commands => context.l10n.navCommands,
      AppSection.settings => context.l10n.navSettings,
      AppSection.cliChat => context.l10n.navCliChat,
      AppSection.nas => context.l10n.navNas,
    };

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  /// `_views` 里文件页的下标。返回键行为需要按它判断当前是否在文件 tab，
  /// 所以抽成常量，避免字面量 3 散落在 build 与测试里。
  static const _sftpTabIndex = 3;

  int _currentIndex = 0;
  bool _isInspectorOpen = false;
  bool _globalMiniPlayerCommandInProgress = false;

  /// 由「点传输完成通知」发起的跳转请求，供文件页消费一次。
  ///
  /// 放在 shell 上而不是文件页里：点通知可能发生在 app 冷启动、当前不在
  /// 文件 tab 的时候，得先把 tab 切过去，文件页才有机会看到这个请求。
  final _openTransfersRequest = ValueNotifier<int>(0);
  final Set<String> _deletingServerIds = {};
  static const _downloadsChannel = MethodChannel('valhalla/downloads');

  late final Widget _dashboardView = DashboardView(
    onNavigate: _navigateToSectionIndex,
    onConnect: () => _handleConnect(),
  );

  late final Widget _sftpView = SftpFileView(
    openTransfersRequest: _openTransfersRequest,
  );

  List<Widget> _buildViews(SettingsState settings) => [
    _dashboardView,
    const AiChatView(),
    const SshTerminalView(),
    _sftpView,
    const DockerView(),
    const SystemView(),
    const QuickCommandsView(),
    const SettingsView(),
    if (settings.isSectionEnabled(AppSection.cliChat))
      const CliChatView()
    else
      const SizedBox.shrink(key: Key('cli_chat_disabled_placeholder')),
    if (settings.isSectionEnabled(AppSection.nas))
      const NasMediaView()
    else
      const SizedBox.shrink(key: Key('nas_disabled_placeholder')),
  ];

  void _navigateToSectionIndex(int idx) {
    if (!mounted) return;
    final targetSection = viewIndexToAppSection(idx);
    final settings = ref.read(settingsProvider);
    final safeIndex = settings.isSectionEnabled(targetSection)
        ? idx
        : appSectionToViewIndex(AppSection.dashboard);
    setState(() => _currentIndex = safeIndex);
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = appSectionToViewIndex(
      ref.read(settingsProvider).effectiveStartupSection,
    );
    _downloadsChannel.setMethodCallHandler(_handleDownloadsMethodCall);
    unawaited(_consumeLaunchAction());
  }

  Future<dynamic> _handleDownloadsMethodCall(MethodCall call) async {
    if (call.method == 'openTransfers') {
      if (!mounted) return null;
      setState(() => _currentIndex = _sftpTabIndex);
      _openTransfersRequest.value++;
      return null;
    }
    throw MissingPluginException('Not implemented: ${call.method}');
  }

  /// 冷启动时询问原生侧「这次是不是从通知点进来的」，是的话切到文件 tab。
  ///
  /// 原生侧是读后即清的，所以这里只可能拿到一次 `true`；拿不到实现
  /// （非 Android / 测试环境）时会静默返回 false，不影响正常启动。
  Future<void> _consumeLaunchAction() async {
    final service = ref.read(keepAliveServiceProvider);
    final shouldOpen = await service.consumeOpenTransfersAction();
    if (!mounted || !shouldOpen) return;
    setState(() => _currentIndex = _sftpTabIndex);
    _openTransfersRequest.value++;
  }

  @override
  void dispose() {
    _downloadsChannel.setMethodCallHandler(null);
    _openTransfersRequest.dispose();
    super.dispose();
  }

  Future<void> _handleConnect({ServerProfile? targetServer}) async {
    try {
      final initialTarget = targetServer ?? ref.read(activeServerProvider);
      if (initialTarget == null) return;
      final targetId = initialTarget.id;

      bool isStillTarget() {
        if (!mounted) return false;
        final existsInList = ref
            .read(serverListProvider)
            .any((s) => s.id == targetId);
        if (!existsInList) return false;
        final currentActive = ref.read(activeServerProvider);
        return currentActive?.id == targetId;
      }

      final exists = ref.read(serverListProvider).any((s) => s.id == targetId);
      if (!exists) return;

      if (targetServer != null) {
        await ref
            .read(activeServerProvider.notifier)
            .selectServer(targetServer.id);
      }
      if (!mounted || !isStillTarget()) return;

      final activeServer = ref.read(activeServerProvider);
      if (activeServer == null || activeServer.id != targetId) return;

      final repo = ref.read(serverRepositoryProvider);
      final storedPwd = await repo.getPassword(targetId);
      final storedKey = await repo.getPrivateKey(targetId);

      if (!mounted || !isStillTarget()) return;

      String? pwd = storedPwd;
      String? key = storedKey;

      if (activeServer.authType == AuthType.password &&
          (pwd == null || pwd.isEmpty)) {
        if (!mounted || !isStillTarget()) return;
        final ctrl = TextEditingController();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.l10n.enterPasswordTitle(activeServer.name)),
            content: TextField(
              controller: ctrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: ctx.l10n.serverPassword,
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.l10n.confirm),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        if (!mounted || !isStillTarget()) return;

        pwd = ctrl.text;
        await repo.addOrUpdateServer(activeServer, password: pwd);
      }

      if (!mounted || !isStillTarget()) return;

      final ok = await ref
          .read(serverConnectionProvider.notifier)
          .connect(
            password: pwd,
            privateKey: key,
            onConfirmHostKey: (host, type, fp) async {
              if (!mounted || !isStillTarget()) return false;
              return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(ctx.l10n.trustHostFingerprintTitle),
                      content: Text(
                        ctx.l10n.trustHostFingerprintMessage(fp, host, type),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(ctx.l10n.reject),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(ctx.l10n.trustAndConnect),
                        ),
                      ],
                    ),
                  ) ??
                  false;
            },
          );

      if (!mounted || !isStillTarget()) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      if (ok) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.sshConnectedSuccess(
                '${activeServer.name} (${activeServer.host})',
              ),
            ),
            backgroundColor: context.vSuccess,
          ),
        );
      } else {
        final err =
            ref.read(serverConnectionProvider).errorMessage ??
            'Connection Error';
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.sshConnectionFailed(err)),
            backgroundColor: context.vDanger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.serverConnectionFailed(e.toString())),
          backgroundColor: context.vDanger,
        ),
      );
    }
  }

  Future<void> _openAddServerDialog(BuildContext context) async {
    final newServer = await showDialog<ServerProfile>(
      context: context,
      builder: (_) => const ServerFormDialog(),
    );
    if (newServer != null) {
      await ref.read(activeServerProvider.notifier).selectServer(newServer.id);
    }
  }

  void _showNasSourceSelector(BuildContext context) {
    final parentContext = context;
    final parentRef = ref;
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      constraints: const BoxConstraints(
        maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
      ),
      builder: (ctx) {
        return SafeArea(
          child: Consumer(
            builder: (sheetCtx, sheetRef, _) {
              final sourcesState = sheetRef.watch(nasSourcesProvider);
              final sources = sourcesState.sources;
              final selectedId = sourcesState.selectedId;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          sheetCtx.l10n.nasTitle,
                          style: sheetCtx.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: sheetCtx.l10n.nasAddSource,
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (parentContext.mounted) {
                              NasSourceDialog.show(parentContext);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (sources.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                sheetCtx.l10n.nasNoSources,
                                style: TextStyle(
                                  color: sheetCtx.colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(sheetCtx.l10n.nasAddSource),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  if (parentContext.mounted) {
                                    NasSourceDialog.show(parentContext);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...sources.map((s) {
                        final isSelected = s.id == selectedId;
                        return ListTile(
                          leading: Icon(
                            Icons.storage_outlined,
                            color: isSelected
                                ? sheetCtx.colorScheme.primary
                                : null,
                          ),
                          title: Text(
                            s.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${s.type.name.toUpperCase()} • ${s.endpoint}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: sheetCtx.colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: sheetCtx.l10n.nasEditSource,
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  if (parentContext.mounted) {
                                    NasSourceDialog.show(
                                      parentContext,
                                      source: s,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await parentRef
                                .read(nasSourcesProvider.notifier)
                                .select(s.id);
                          },
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showServerSelector(BuildContext context) {
    final parentContext = context;
    final parentRef = ref;
    final serverListNotifier = parentRef.read(serverListProvider.notifier);
    final scaffoldMessenger = ScaffoldMessenger.of(parentContext);

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      constraints: const BoxConstraints(
        maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
      ),
      builder: (ctx) {
        return SafeArea(
          child: Consumer(
            builder: (sheetCtx, sheetRef, _) {
              final servers = sheetRef.watch(serverListProvider);
              final activeServer = sheetRef.watch(activeServerProvider);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          sheetCtx.l10n.selectServerTitle,
                          style: sheetCtx.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: sheetCtx.l10n.addServer,
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (parentContext.mounted) {
                              _openAddServerDialog(parentContext);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (servers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            sheetCtx.l10n.noServersFound,
                            style: TextStyle(
                              color: sheetCtx.colorScheme.outline,
                            ),
                          ),
                        ),
                      )
                    else
                      ...servers.map((s) {
                        final isSelected = s.id == activeServer?.id;
                        return ListTile(
                          leading: Icon(
                            Icons.dns,
                            color: isSelected
                                ? sheetCtx.colorScheme.primary
                                : null,
                          ),
                          title: Text(
                            s.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('${s.username}@${s.host}:${s.port}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: sheetCtx.colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: sheetCtx.l10n.editServer,
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  if (parentContext.mounted) {
                                    showDialog(
                                      context: parentContext,
                                      builder: (_) =>
                                          ServerFormDialog(serverToEdit: s),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: _deletingServerIds.contains(s.id)
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFEF4444),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Color(0xFFEF4444),
                                      ),
                                tooltip: sheetCtx.l10n.delete,
                                onPressed: _deletingServerIds.contains(s.id)
                                    ? null
                                    : () async {
                                        final confirmed =
                                            await showDeleteServerConfirmDialog(
                                              parentContext,
                                              s,
                                            );
                                        if (!confirmed ||
                                            !mounted ||
                                            !parentContext.mounted) {
                                          return;
                                        }
                                        setState(() {
                                          _deletingServerIds.add(s.id);
                                        });
                                        try {
                                          await serverListNotifier.deleteServer(
                                            s.id,
                                          );
                                        } catch (e) {
                                          if (parentContext.mounted) {
                                            scaffoldMessenger.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  parentContext.l10n
                                                      .serverDeleteFailed(
                                                        e.toString(),
                                                      ),
                                                ),
                                                backgroundColor:
                                                    parentContext.vDanger,
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _deletingServerIds.remove(s.id);
                                            });
                                          }
                                        }
                                      },
                              ),
                            ],
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            try {
                              await _handleConnect(targetServer: s);
                            } catch (e) {
                              if (!mounted || !parentContext.mounted) {
                                return;
                              }
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    parentContext.l10n.serverConnectionFailed(
                                      e.toString(),
                                    ),
                                  ),
                                  backgroundColor: parentContext.vDanger,
                                ),
                              );
                            }
                          },
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final availableSections = ref.watch(settingsProvider).availableSections;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const ValhallaAppIcon(size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.navMore,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ...availableSections.map((section) {
              final idx = appSectionToViewIndex(section);
              return Entrance(
                index: appSectionToViewIndex(section),
                offset: const Offset(-14, 0),
                child: ListTile(
                  key: section == AppSection.cliChat
                      ? const Key('drawer_cli_chat_tile')
                      : (section == AppSection.nas
                            ? const Key('drawer_nas_tile')
                            : null),
                  leading: Icon(
                    appSectionIcon(section, selected: _currentIndex == idx),
                  ),
                  title: Text(localizedAppSectionName(context, section)),
                  selected: _currentIndex == idx,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = idx);
                  },
                ),
              );
            }),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.add_circle_outline,
                color: context.colorScheme.primary,
              ),
              title: Text(
                context.l10n.addServer,
                style: TextStyle(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _openAddServerDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 文件 tab 是 IndexedStack 里的第 3 项，它有自己的目录层级。系统返回键在
    // 该 tab 又有上级目录时应该回上一级，而不是直接退出 app；其余情况一律
    // 保持「返回即退出」的原行为。
    //
    // 注意：PopScope 只作用于最近的 ModalRoute，所以编辑器/密码等弹窗会先被
    // 返回键关掉，弹窗全部消失后才会走到这里。
    ref.listen<AsyncValue<String>>(diagnosticsIncidentProvider, (
      previous,
      next,
    ) {
      next.whenData((category) {
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.diagnosticsIncidentNotice(category)),
            action: SnackBarAction(
              label: context.l10n.viewDiagnostics,
              onPressed: () => DiagnosticsView.show(context),
            ),
          ),
        );
      });
    });

    ref.listen<SettingsState>(settingsProvider, (previous, next) {
      final currentSection = viewIndexToAppSection(_currentIndex);
      if (!next.isSectionEnabled(currentSection)) {
        setState(() {
          _currentIndex = appSectionToViewIndex(AppSection.dashboard);
        });
      }
    });

    final sftpState = ref.watch(sftpProvider);
    final onFilesTab = _currentIndex == _sftpTabIndex;
    final backGoesUp = onFilesTab && !sftpState.isAtRoot;

    return PopScope(
      // canPop=false 会拦住根路由（即阻止 app 退出）并以 didPop=false 回调。
      canPop: !backGoesUp,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (backGoesUp) {
          ref.read(sftpProvider.notifier).navigateUp();
        }
      },
      child: _buildResponsiveShell(),
    );
  }

  Widget _buildResponsiveShell() {
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (screenWidth > LayoutBreakpoints.expandedMin) {
      return _buildExpandedDesktopShell();
    } else if (screenWidth >= LayoutBreakpoints.compactMax) {
      return _buildMediumRailShell();
    }
    return _buildCompactMobileShell();
  }

  Widget _buildExpandedDesktopShell() {
    final settings = ref.watch(settingsProvider);
    final hasRail = settings.visibleBottomNavigationSections.isNotEmpty;

    return Scaffold(
      drawer: _buildDrawer(context),
      body: Row(
        children: [
          if (hasRail) ...[
            _buildNavigationRail(extended: false, showLabels: true),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: Column(
              children: [
                _buildTopBar(showInspectorToggle: true),
                const Divider(height: 1),
                const ConnectionStatusBanner(),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedIndexedStack(
                          index: _currentIndex,
                          children: _buildViews(settings),
                        ),
                      ),
                      if (_isInspectorOpen)
                        // Keep the panel bounded even if its content fails to
                        // build; a fallback ErrorWidget must not collapse the
                        // page stack (including offstage terminal canvases).
                        SizedBox(
                          width: 320,
                          child: ContextInspector(
                            activeTabIndex: _currentIndex,
                            onClose: () =>
                                setState(() => _isInspectorOpen = false),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildGlobalMiniPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediumRailShell() {
    final settings = ref.watch(settingsProvider);
    final hasRail = settings.visibleBottomNavigationSections.isNotEmpty;

    return Scaffold(
      drawer: _buildDrawer(context),
      body: Row(
        children: [
          if (hasRail) ...[
            _buildNavigationRail(extended: false, showLabels: false),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: Column(
              children: [
                _buildTopBar(showInspectorToggle: false),
                const Divider(height: 1),
                const ConnectionStatusBanner(),
                Expanded(
                  child: AnimatedIndexedStack(
                    index: _currentIndex,
                    children: _buildViews(settings),
                  ),
                ),
                _buildGlobalMiniPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail({
    required bool extended,
    required bool showLabels,
  }) {
    final settings = ref.watch(settingsProvider);
    final visibleSections = settings.visibleBottomNavigationSections;
    if (visibleSections.isEmpty) return const SizedBox.shrink();
    final currentSection = viewIndexToAppSection(_currentIndex);
    final railIndex = visibleSections.indexOf(currentSection);

    return NavigationRail(
      selectedIndex: railIndex >= 0 ? railIndex : null,
      extended: extended,
      scrollable: true,
      trailingAtBottom: true,
      labelType: showLabels
          ? NavigationRailLabelType.all
          : NavigationRailLabelType.none,
      onDestinationSelected: (index) {
        if (index >= 0 && index < visibleSections.length) {
          final targetSection = visibleSections[index];
          setState(() => _currentIndex = appSectionToViewIndex(targetSection));
        }
      },
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Entrance(
          index: 0,
          offset: const Offset(-12, 0),
          child: const ValhallaAppIcon(),
        ),
      ),
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: IconButton(
          icon: const Icon(Icons.power_settings_new),
          tooltip: context.l10n.quickDisconnect,
          onPressed: () {
            ref.read(serverConnectionProvider.notifier).disconnect();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.sshDisconnectedSuccess)),
            );
          },
        ),
      ),
      destinations: visibleSections.map((section) {
        return NavigationRailDestination(
          icon: Icon(appSectionIcon(section)),
          selectedIcon: Icon(appSectionIcon(section, selected: true)),
          label: Text(localizedAppSectionName(context, section)),
        );
      }).toList(),
    );
  }

  Widget _buildTopBar({required bool showInspectorToggle}) {
    final activeServer = ref.watch(activeServerProvider);
    final connState = ref.watch(serverConnectionProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTight = screenWidth < 720;

    final isNasSection = viewIndexToAppSection(_currentIndex) == AppSection.nas;
    final nasSourcesState = isNasSection ? ref.watch(nasSourcesProvider) : null;
    final activeNasSource = nasSourcesState?.selected;

    Color statusColor;
    String statusText;
    switch (connState.status) {
      case ConnectionStateEnum.connected:
        statusColor = context.vSuccess;
        statusText = context.l10n.serverConnected;
        break;
      case ConnectionStateEnum.connecting:
        statusColor = context.vWarning;
        statusText = context.l10n.serverConnecting;
        break;
      case ConnectionStateEnum.disconnected:
        statusColor = context.colorScheme.outline;
        statusText = context.l10n.serverDisconnected;
        break;
      case ConnectionStateEnum.error:
        statusColor = context.vDanger;
        statusText = context.l10n.stateError;
        break;
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: context.colorScheme.surface,
      child: Row(
        children: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: context.l10n.navMore,
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: AnimatedSwitcher(
                duration: VTiming.base,
                switchInCurve: VCurves.decelerate,
                switchOutCurve: VCurves.accelerate,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  localizedAppSectionName(
                    context,
                    viewIndexToAppSection(_currentIndex),
                  ),
                  key: const Key('main_shell_page_title'),
                  style: context.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ),
          const Spacer(),
          if (showInspectorToggle) ...[
            IconButton(
              icon: Icon(
                Icons.tune_rounded,
                color: _isInspectorOpen ? context.colorScheme.primary : null,
              ),
              tooltip: context.l10n.inspectorTitle,
              onPressed: () =>
                  setState(() => _isInspectorOpen = !_isInspectorOpen),
            ),
            const SizedBox(width: 4),
          ],
          if (!isNasSection) ...[
            Flexible(
              flex: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _showServerSelector(context),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTight ? 6 : 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulseDot(color: statusColor, size: 8),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          activeServer?.name ?? context.l10n.noServerSelected,
                          style: context.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                      if (activeServer != null &&
                          screenWidth > LayoutBreakpoints.topBarHostInfo) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: context.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              '${activeServer.host}:${activeServer.port} ($statusText)',
                              style: monoTextStyle(
                                fontSize: 11,
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (connState.isConnecting)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (!connState.isConnected)
              isTight
                  ? IconButton(
                      icon: const Icon(Icons.link, size: 18),
                      tooltip: context.l10n.connectNow,
                      onPressed: () => _handleConnect(),
                    )
                  : FilledButton.icon(
                      icon: const Icon(Icons.link, size: 14),
                      label: Text(
                        context.l10n.connectNow,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _handleConnect(),
                    )
            else
              isTight
                  ? IconButton(
                      icon: const Icon(Icons.sync, size: 18),
                      tooltip: context.l10n.reconnect,
                      onPressed: () => _handleConnect(),
                    )
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.sync, size: 14),
                      label: Text(
                        context.l10n.reconnect,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _handleConnect(),
                    ),
          ] else ...[
            Flexible(
              flex: 2,
              child: InkWell(
                key: const Key('main_shell_nas_source_selector'),
                borderRadius: BorderRadius.circular(6),
                onTap: () => _showNasSourceSelector(context),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTight ? 6 : 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.storage_outlined,
                        size: 17,
                        color: activeNasSource != null
                            ? context.vSuccess
                            : context.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          activeNasSource?.name ?? context.l10n.nasNoSources,
                          style: context.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                      if (activeNasSource != null &&
                          screenWidth > LayoutBreakpoints.topBarHostInfo) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: context.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              activeNasSource.type.name.toUpperCase(),
                              style: monoTextStyle(
                                fontSize: 11,
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
            const WindowsAppearanceActions(),
        ],
      ),
    );
  }

  Widget _buildCompactMobileShell() {
    final activeServer = ref.watch(activeServerProvider);
    final connState = ref.watch(serverConnectionProvider);
    final isNasSection = viewIndexToAppSection(_currentIndex) == AppSection.nas;
    final nasSourcesState = isNasSection ? ref.watch(nasSourcesProvider) : null;
    final activeNasSource = nasSourcesState?.selected;

    Color statusColor;
    switch (connState.status) {
      case ConnectionStateEnum.connected:
        statusColor = context.vSuccess;
        break;
      case ConnectionStateEnum.connecting:
        statusColor = context.vWarning;
        break;
      case ConnectionStateEnum.disconnected:
        statusColor = context.colorScheme.outline;
        break;
      case ConnectionStateEnum.error:
        statusColor = context.vDanger;
        break;
    }

    final settings = ref.watch(settingsProvider);
    final bottomSections = settings.visibleBottomNavigationSections;

    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: context.l10n.navMore,
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: AnimatedSwitcher(
          duration: VTiming.base,
          switchInCurve: VCurves.decelerate,
          switchOutCurve: VCurves.accelerate,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.5),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            localizedAppSectionName(
              context,
              viewIndexToAppSection(_currentIndex),
            ),
            key: const Key('main_shell_page_title'),
            style: context.textTheme.titleMedium,
          ),
        ),
        actions: [
          if (!isNasSection) ...[
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _showServerSelector(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulseDot(color: statusColor, size: 8),
                    const SizedBox(width: 7),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                            !kIsWeb &&
                                defaultTargetPlatform == TargetPlatform.windows
                            ? 70
                            : 130,
                      ),
                      child: Text(
                        activeServer?.name ?? context.l10n.noServerSelected,
                        style: context.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
            if (connState.isConnecting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  connState.isConnected ? Icons.sync : Icons.link,
                  size: 20,
                ),
                tooltip: connState.isConnected
                    ? context.l10n.reconnect
                    : context.l10n.connectNow,
                onPressed: () => _handleConnect(),
              ),
          ] else ...[
            InkWell(
              key: const Key('main_shell_nas_source_selector_compact'),
              borderRadius: BorderRadius.circular(6),
              onTap: () => _showNasSourceSelector(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storage_outlined,
                      size: 17,
                      color: activeNasSource != null
                          ? context.vSuccess
                          : context.colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        activeNasSource?.name ?? context.l10n.nasNoSources,
                        style: context.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
          ],
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
            const WindowsAppearanceActions(),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const ConnectionStatusBanner(),
          Expanded(
            child: AnimatedIndexedStack(
              index: _currentIndex,
              children: _buildViews(settings),
            ),
          ),
          _buildGlobalMiniPlayer(),
        ],
      ),
      bottomNavigationBar: bottomSections.isEmpty
          ? null
          : MainBottomNavigationBar(
              sections: bottomSections,
              currentIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
            ),
    );
  }

  Widget _buildGlobalMiniPlayer() {
    return Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(settingsProvider);
        final isNasEnabled = settings.isSectionEnabled(AppSection.nas);
        if (!isNasEnabled && !ref.exists(nasMediaPlayerProvider)) {
          return const SizedBox.shrink();
        }
        final playbackAsync = ref.watch(nasPlaybackProvider);
        return playbackAsync.when(
          data: (snapshot) {
            final current = snapshot.current;
            if (current == null) return const SizedBox.shrink();
            return NasMiniPlayer(
              item: current,
              isPlaying: snapshot.playing,
              onPlayPause: () async {
                if (_globalMiniPlayerCommandInProgress) return;
                _globalMiniPlayerCommandInProgress = true;
                try {
                  final playerService = await ref.read(
                    nasMediaPlayerProvider.future,
                  );
                  await playerService.playOrPause();
                } catch (_) {
                } finally {
                  _globalMiniPlayerCommandInProgress = false;
                }
              },
              onClose: () async {
                try {
                  final playerService = await ref.read(
                    nasMediaPlayerProvider.future,
                  );
                  await playerService.stop();
                } catch (_) {}
              },
              onExpand: () async {
                try {
                  final playerService = await ref.read(
                    nasMediaPlayerProvider.future,
                  );
                  if (context.mounted) {
                    NasFullPlayerDialog.show(
                      context,
                      item: current,
                      isPlaying: snapshot.playing,
                      progress: snapshot.duration.inMilliseconds > 0
                          ? (snapshot.position.inMilliseconds /
                                    snapshot.duration.inMilliseconds)
                                .clamp(0.0, 1.0)
                          : 0.0,
                      player: playerService.player,
                      isFavorite: current.isFavorite,
                      onPlayPause: (_) async {
                        try {
                          await playerService.playOrPause();
                        } catch (_) {}
                      },
                      onSeek: (val) async {
                        try {
                          if (snapshot.duration > Duration.zero) {
                            await playerService.seek(snapshot.duration * val);
                          }
                        } catch (_) {}
                      },
                      onToggleFavorite: () {
                        ref
                            .read(nasProvider.notifier)
                            .setFavorite(current, !current.isFavorite);
                      },
                      onOpenExternal: () {
                        ref.read(nasProvider.notifier).openExternal(current);
                      },
                    );
                  }
                } catch (_) {}
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
    );
  }
}

class MainBottomNavigationBar extends StatelessWidget {
  final List<AppSection> sections;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const MainBottomNavigationBar({
    super.key,
    required this.sections,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();

    final currentSection = viewIndexToAppSection(currentIndex);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final barBg =
        theme.navigationBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final height = theme.navigationBarTheme.height ?? 72.0;

    return Container(
      key: const Key('main_bottom_nav_bar'),
      height: height,
      decoration: BoxDecoration(
        color: barBg,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final count = sections.length;
            final canFitAll = (constraints.maxWidth / count) >= 64.0;
            final slotWidth = canFitAll ? constraints.maxWidth / count : 68.0;
            final selectedIndex = sections.indexOf(currentSection);
            final trackWidth = slotWidth * count;

            final children = sections.map((sec) {
              final isSelected = currentSection == sec;
              final targetIndex = appSectionToViewIndex(sec);

              return SizedBox(
                key: Key('bottom_nav_item_${sec.name}'),
                width: slotWidth,
                height: height,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onDestinationSelected(targetIndex),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 图标微跳: 选中时轻微上浮 + 缩放, spring 收尾。
                        AnimatedScale(
                          scale: isSelected ? 1.12 : 1.0,
                          duration: VTiming.base,
                          curve: VCurves.springish,
                          child: AnimatedSlide(
                            offset: isSelected
                                ? const Offset(0, -0.08)
                                : Offset.zero,
                            duration: VTiming.base,
                            curve: VCurves.springish,
                            child: Icon(
                              appSectionIcon(sec, selected: isSelected),
                              size: 21,
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: VTiming.base,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                            fontFamily: 'Inter',
                            height: 1.2,
                          ),
                          child: Text(
                            localizedAppSectionName(context, sec),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList();

            Widget bar;
            if (canFitAll) {
              bar = Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: children,
              );
            } else {
              bar = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: children),
              );
            }

            // 滑动指示条: 选中项下方的强调色胶囊, 随切页平移 (spring)。
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: bar),
                if (canFitAll && selectedIndex >= 0)
                  Positioned(
                    top: 2,
                    left: 0,
                    width: trackWidth,
                    child: AnimatedAlign(
                      alignment: Alignment(
                        -1 + (2 * selectedIndex + 1) / count,
                        0,
                      ),
                      duration: VTiming.base,
                      curve: VCurves.springish,
                      child: Container(
                        width: 18,
                        height: 3,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(VRadius.pill),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
