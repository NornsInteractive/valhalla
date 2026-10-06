import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app/theme.dart';
import 'core/providers/ai_chat_provider.dart';
import 'core/providers/auto_connect_provider.dart';
import 'core/providers/connection_lifecycle_provider.dart';
import 'core/providers/reconnect_provider.dart';
import 'core/providers/server_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/sftp_provider.dart';
import 'core/providers/storage_providers.dart';
import 'core/providers/nas_metadata_provider.dart';
import 'core/services/keep_alive_service.dart';
import 'core/services/app_diagnostics.dart';
import 'core/logging/sanitizer.dart';
import 'features/agents/oauth_callback_page.dart';
import 'features/settings/widgets/startup_failure_app.dart';
import 'core/services/window_service.dart';
import 'core/localization/app_locales.dart';
import 'features/shell/main_shell.dart';
import 'l10n/app_localizations.dart';

import 'data/models/server_profile.dart';
import 'data/storage/local_storage_service.dart';

/// 启动自动连接开关。
///
/// 由 `main()` 在生产环境覆盖为 true；默认关闭，避免测试或未初始化环境下
/// 意外发起真实连接（与 [reconnectEnabledProvider] 同一套约定）。
final autoConnectEnabledProvider = Provider<bool>((ref) => false);

/// 按设置解析出启动时要自动连接的服务器；没有则返回 null。
///
/// 抽成顶层函数是为了能脱离 widget 直接测：启动钩子本身跑在
/// `initState` 里，很难单独驱动，而「选哪台服务器」才是真正有分支的逻辑。
///
/// 关键点：这里**必须**自己按 id 过滤，不能靠 `activeServerProvider` 兜底。
/// `ActiveServerNotifier.build()` 在找不到匹配 id 时会回落到 `servers.first`，
/// 所以「指定了一台已删除的服务器」会让自动连接静默连到另一台上去。
ServerProfile? resolveAutoConnectTarget({
  required AutoConnectSettings settings,
  required List<ServerProfile> servers,
  required String? lastConnectedServerId,
}) {
  final String? targetId;
  switch (settings.mode) {
    case AutoConnectMode.fixed:
      targetId = settings.fixedServerId;
    case AutoConnectMode.lastConnected:
      // 每次启动都从存储现读，而不是吃 settings 里的快照：
      // 设置页那份 state 是启动时构建的，而连接可能发生在之后。
      targetId = lastConnectedServerId;
  }
  if (targetId == null) return null;

  for (final server in servers) {
    if (server.id == targetId) return server;
  }
  return null;
}

/// 启动钩子是否应该真正发起自动连接。
///
/// 抽成纯函数是为了能测：真正的调用点在私有 State 里，测试够不着，
/// 而这两条守卫恰恰是最容易在重构中被弄丢的——丢了以后测试环境会真的
/// 去拨 SSH，或启动后多连一次。
bool shouldAutoConnect({
  required bool alreadyAttempted,
  required bool enabled,
}) => enabled && !alreadyAttempted;

/// 解析并执行一次启动自动连接。
///
/// 返回是否真的发起了连接，方便测试断言，也便于将来加日志。
///
/// 参数是 [WidgetRef] 而不是 [Ref]：调用点在 `ConsumerState` 里，手上只有
/// WidgetRef；两者在 read/invalidate 这些用到的能力上一致。
Future<bool> runAutoConnect(WidgetRef ref) async {
  final repo = ref.read(serverRepositoryProvider);
  final settings = ref.read(autoConnectSettingsProvider);

  final target = resolveAutoConnectTarget(
    settings: settings,
    servers: repo.getAllServers(),
    lastConnectedServerId: repo.getLastConnectedServerId(),
  );
  if (target == null) return false;

  // 先把 active id 落到存储再走 connect：connect() 自己读 activeServerProvider，
  // 不落盘的话它连的还是启动时那台。
  await repo.setActiveServerId(target.id);
  ref.invalidate(activeServerProvider);

  await ref.read(serverConnectionProvider.notifier).connect();
  return true;
}

/// 把「传输完成」事件攒起来合并成一条通知。
///
/// 一次选中十个文件下载会连续完成十个任务；每个都发一条通知会把通知栏
/// 刷爆。这里在一个很短的窗口内合并计数，用户只会看到「3 个传输已完成」。
///
/// 抽成独立类而不是内联在 `main()` 里，是为了能脱离 Android 单测：
/// 合并窗口的边界（第一批立刻发、窗口内累加、窗口结束后重新计数）
/// 才是真正容易写错的地方。
class TransferNotificationBatcher {
  TransferNotificationBatcher({
    required this.send,
    this.window = const Duration(seconds: 2),
  });

  /// 真正发通知的回调，注入以方便测试。
  final void Function(int completedCount) send;

  /// 合并窗口：窗口内完成的传输会累加到同一条通知上。
  final Duration window;

  int _pending = 0;
  Timer? _timer;

  /// 记录一次完成。窗口到期后把累计数发出去。
  void add() {
    _pending++;
    _timer ??= Timer(window, _flush);
  }

  /// 供 provider 的 `void Function(SftpTransfer)` 回调直接用。
  ///
  /// 计数与时序都不需要那单个任务的信息，但签名必须对得上，
  /// 否则 `main.dart` 里会多出一层只做透传的闭包。
  void addTransfer(SftpTransfer _) => add();

  void _flush() {
    _timer = null;
    final count = _pending;
    _pending = 0;
    if (count == 0) return;
    send(count);
  }

  /// 立即发出待发的计数，不等窗口到期。
  ///
  /// 退出时调用，否则窗口内最后几条完成会随进程一起消失。
  void flushNow() {
    _timer?.cancel();
    _flush();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostics = AppDiagnostics.instance;
  FlutterError.onError = (details) {
    diagnostics.unhandled(
      'flutter.framework',
      details.exception,
      details.stack ?? StackTrace.current,
    );
    FlutterError.presentError(
      FlutterErrorDetails(
        exception: LogSanitizer.sanitize(details.exceptionAsString()),
        stack: details.stack,
        library: details.library,
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    diagnostics.unhandled('dart.unhandled', error, stack);
    return true;
  };
  await diagnostics.initialize();
  try {
    MediaKit.ensureInitialized();
    final localStorage = await LocalStorageService.init();

    if (!kIsWeb &&
        (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      final windowService = DesktopWindowService(storage: localStorage);
      await windowService.initialize();
    }

    runApp(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(localStorage),
          // 生产环境启用自动重连。默认值必须是 false，否则测试或未初始化
          // 环境会意外发起真实连接。
          reconnectEnabledProvider.overrideWithValue(true),
          // 同上：启动自动连接也只在生产环境开启。
          autoConnectEnabledProvider.overrideWithValue(true),
          // 传输完成通知。默认是 null（测试环境不该碰 MethodChannel），
          // 这里接上真实的 Android 通知。
          transferNotificationCallbackProvider.overrideWithValue(
            _notificationBatcher.addTransfer,
          ),
          // 生产环境注入 ACP OAuth 回调页面渲染器。
          acpOAuthPageRendererProvider.overrideWithValue(acpOAuthCallbackPage),
        ],
        // 生命周期观察者必须在 ProviderScope 之外无法取得 ref，
        // 因此包在 scope 内部。
        child: const _LifecycleHost(child: ValhallaApp()),
      ),
    );
  } catch (error, stack) {
    await diagnostics.record('startup.failed', error, stack);
    runApp(StartupFailureApp(retry: main));
  }
}

/// 生产环境的通知合并器。
///
/// 全局单例而不是挂在 widget 上：传输不依赖任何界面还活着——
/// 用户切到后台时界面可能已经被回收，但传输和通知必须照常。
final _notificationBatcher = TransferNotificationBatcher(
  send: (count) =>
      const MethodChannelKeepAliveService().notifyTransferCompleted(count),
);

/// 把 `WidgetsBindingObserver` 的生命周期回调翻译成连接层动作。
///
/// 单独抽出来是因为 `ValhallaApp` 是 `ConsumerWidget`（无状态），
/// 而生命周期观察需要 State。
class _LifecycleHost extends ConsumerStatefulWidget {
  const _LifecycleHost({required this.child});

  final Widget child;

  @override
  ConsumerState<_LifecycleHost> createState() => _LifecycleHostState();
}

class _LifecycleHostState extends ConsumerState<_LifecycleHost>
    with WidgetsBindingObserver {
  /// 启动自动连接只允许跑一次。
  ///
  /// `initState` 在正常情况下也只会跑一次，但热重载/父级重建都可能让它
  /// 再跑，而「自动连接」重复执行的代价是凭空多一次 SSH 握手——
  /// 每多一次就可能多弹一次未知主机指纹确认。
  bool _autoConnectAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoConnectOnce();
  }

  void _autoConnectOnce() {
    // 判定逻辑走 [shouldAutoConnect]：它是纯函数，能被单测直接压，
    // 而这里只剩「读开关 + 记标记」的接线。
    final enabled = ref.read(autoConnectEnabledProvider);
    if (!shouldAutoConnect(
      alreadyAttempted: _autoConnectAttempted,
      enabled: enabled,
    )) {
      return;
    }
    _autoConnectAttempted = true;
    // 不 await：initState 不能异步，而连接状态由 connectionStatusBanner
    // 自行展示，失败时静默即可（不弹对话框）。
    unawaited(runAutoConnect(ref));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lifecycle = ref.read(connectionLifecycleProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(lifecycle.onResumed());
        break;
      case AppLifecycleState.inactive:
        // 过渡态（来电、通知栏下拉等）：属于短暂的生命周期状态，自身绝不能触发断连。
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (ref.exists(aiChatProvider)) {
          unawaited(ref.read(aiChatProvider.notifier).checkpoint());
        }
        unawaited(lifecycle.onPaused());
        break;
      case AppLifecycleState.detached:
        if (ref.exists(aiChatProvider)) {
          unawaited(ref.read(aiChatProvider.notifier).checkpoint());
        }
        unawaited(lifecycle.onDetached());
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ValhallaApp extends ConsumerWidget {
  const ValhallaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nasMetadataServiceProvider);
    final settings = ref.watch(settingsProvider);

    ThemeMode themeMode;
    switch (settings.themeMode) {
      case AppThemeMode.light:
        themeMode = ThemeMode.light;
        break;
      case AppThemeMode.system:
        themeMode = ThemeMode.system;
        break;
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
        themeMode = ThemeMode.dark;
        break;
    }

    final isAmoled = settings.themeMode == AppThemeMode.amoled;

    return MaterialApp(
      title: 'Valhalla',
      debugShowCheckedModeBanner: false,
      locale: settings.locale.languageCode == 'system' ? null : settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolveAppLocale,
      theme: AppTheme.buildTheme(
        brightness: Brightness.light,
        seedColor: settings.lightAccentColor,
      ),
      darkTheme: AppTheme.buildTheme(
        brightness: Brightness.dark,
        seedColor: isAmoled
            ? settings.amoledAccentColor
            : settings.darkAccentColor,
        isAmoled: isAmoled,
      ),
      themeMode: themeMode,
      home: const MainShell(),
    );
  }
}
