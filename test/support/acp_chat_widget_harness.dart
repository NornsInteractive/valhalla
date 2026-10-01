import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import 'temp_chat_db.dart';

/// ACP 聊天页控件回归的共享脚手架。
///
/// 工作目录浏览全部由 [FakeAcpChatNotifier] 的内存目录表回答，
/// 绝不建立 SSH/Agent 连接，也不读取任何凭据。

const harnessServerId = 'srv-harness-1';

final harnessServer = ServerProfile(
  id: harnessServerId,
  name: 'Harness Server',
  host: '127.0.0.1',
  port: 22,
  username: 'tester',
  authType: AuthType.password,
);

final harnessAgent = AgentProfile(
  id: 'agent-harness-acp',
  serverId: harnessServerId,
  name: 'Harness ACP Agent',
  description: 'ACP agent used by widget regression tests',
  cliCommand: 'harness-cli',
  acpCommand: 'harness-acp',
);

/// 内存目录表：`path -> 子项`；未登记的路径抛 [_WorkspaceNotFound]。
class FakeWorkspace {
  FakeWorkspace({this.initialPath = '/'});

  final String initialPath;
  final Map<String, List<SftpFileItem>> directories = {};
  final Map<String, Uint8List> previews = {};
  final Map<String, Object> failures = {};

  final List<String> listedPaths = [];
  int cancelCount = 0;
  int resolveCount = 0;

  /// 非 null 时 [FakeAcpChatNotifier.listWorkspaceFiles] 会等待它完成，
  /// 用于构造「关闭之后才到达的迟到结果」。
  Completer<void>? listGate;

  void add(String path, List<SftpFileItem> items) {
    directories[path] = items;
  }

  static SftpFileItem dir(String name, String parent) => SftpFileItem(
    name: name,
    path: parent == '/' ? '/$name' : '$parent/$name',
    isDirectory: true,
    sizeBytes: 0,
    formattedSize: '-',
    permissions: 'drwxr-xr-x',
    modified: '2026-09-30 10:00',
  );

  static SftpFileItem file(String name, String parent, {int sizeBytes = 12}) =>
      SftpFileItem(
        name: name,
        path: parent == '/' ? '/$name' : '$parent/$name',
        isDirectory: false,
        sizeBytes: sizeBytes,
        formattedSize: SftpFileItem.formatBytes(sizeBytes),
        permissions: '-rw-r--r--',
        modified: '2026-09-30 10:00',
      );
}

class _WorkspaceNotFound implements Exception {
  const _WorkspaceNotFound(this.path);
  final String path;
  @override
  String toString() => 'ACP_FILE_NOT_FOUND: $path';
}

class FakeAcpChatNotifier extends AiChatNotifier {
  FakeAcpChatNotifier(
    this.initialState, {
    this.workspace,
    this.refreshResult = true,
    this.refreshError,
  });

  final AiChatState initialState;
  final FakeWorkspace? workspace;
  final bool refreshResult;
  final Object? refreshError;

  final List<String> draftTexts = [];
  int prepareRunSettingsCalls = 0;
  int queryAccountStatusCalls = 0;
  int sendMessageCalls = 0;

  @override
  AiChatState build() => initialState;

  @override
  void updateDraftText(String text) {
    draftTexts.add(text);
    state = state.copyWith(draftText: text);
  }

  @override
  void removeAttachment(int index) {
    final next = [...state.attachments]..removeAt(index);
    state = state.copyWith(attachments: next);
  }

  @override
  Future<void> sendMessage(String text) async {
    sendMessageCalls++;
  }

  @override
  Future<bool> prepareRunSettings({bool refresh = false}) async {
    prepareRunSettingsCalls++;
    final error = refreshError;
    if (error != null) throw error;
    return refreshResult;
  }

  @override
  Future<void> queryAccountStatus() async {
    queryAccountStatusCalls++;
  }

  @override
  Future<String> resolveWorkspaceDirectory() async {
    workspace?.resolveCount++;
    return workspace?.initialPath ?? '/';
  }

  @override
  Future<List<SftpFileItem>> listWorkspaceFiles(String path) async {
    final ws = workspace;
    if (ws == null) return const [];
    ws.listedPaths.add(path);
    final gate = ws.listGate;
    if (gate != null) await gate.future;
    final failure = ws.failures[path];
    if (failure != null) throw failure;
    final items = ws.directories[path];
    if (items == null) throw _WorkspaceNotFound(path);
    return items;
  }

  @override
  Future<Uint8List?> remoteImagePreview(SftpFileItem item) async {
    final bytes = workspace?.previews[item.path];
    if (bytes == null) throw StateError('ACP_FILE_READ_CANCELLED');
    return bytes;
  }

  @override
  void cancelWorkspaceBrowse() {
    workspace?.cancelCount++;
  }
}

class HarnessActiveServerNotifier extends ActiveServerNotifier {
  @override
  ServerProfile? build() => harnessServer;
}

class HarnessServerConnectionNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.connected);
}

class HarnessAgentRegistryNotifier extends AgentRegistryNotifier {
  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: harnessServerId,
    agents: [
      AgentRuntimeState(
        profile: harnessAgent,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          checkedAt: DateTime.utc(2026),
        ),
      ),
    ],
  );
}

/// 生成一张真实可解码的小 PNG（不依赖资源文件，也不硬编码 base64）。
Future<Uint8List> tinyPngBytes(WidgetTester tester) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 4, 4),
      Paint()..color = const Color(0xFF3366CC),
    );
    final image = await recorder.endRecording().toImage(4, 4);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

bool _fontsLoaded = false;

/// 载入真实 Inter 字体，让控件测试的文字度量与真机一致。
///
/// flutter_test 默认用等宽方块测试字体，字宽与 Inter 差异很大，测出来的
/// 溢出行数/像素数不能代表真机表现。布局类回归必须在生产字体下断言，
/// 否则无法证明生产布局本身不溢出。
Future<void> loadRealTextFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  for (final entry in const {
    'Inter': ['400', '500', '600', '700', '800'],
  }.entries) {
    final loader = FontLoader(entry.key);
    var anyLoaded = false;
    for (final weight in entry.value) {
      final data = await rootBundle.load(
        'assets/fonts/${entry.key}-$weight.ttf',
      );
      loader.addFont(Future.value(data));
      anyLoaded = true;
    }
    if (anyLoaded) await loader.load();
  }
}

/// 只挂本地替身的宿主。
///
/// 使用生产主题 [AppTheme]：布局回归必须在生产主题 + 生产字体下断言，
/// 否则测得的溢出不能代表真机表现。
/// 窄屏回归请直接改 `tester.view.physicalSize`，MediaQuery.size 不收紧布局约束。
Future<void> pumpAcpHarness(
  WidgetTester tester, {
  required Widget child,
  required FakeAcpChatNotifier notifier,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  List<Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.init();
  await loadRealTextFonts();

  final app = ProviderScope(
    overrides: [
      tempChatRepositoryOverride(),
      localStorageServiceProvider.overrideWithValue(storage),
      activeServerProvider.overrideWith(HarnessActiveServerNotifier.new),
      serverConnectionProvider.overrideWith(
        HarnessServerConnectionNotifier.new,
      ),
      agentRegistryProvider.overrideWith(HarnessAgentRegistryNotifier.new),
      aiChatProvider.overrideWith(() => notifier),
      ...extraOverrides,
    ],
    child: MaterialApp(
      theme: AppTheme.buildTheme(
        brightness: Brightness.dark,
        seedColor: AppAccentColor.cyberEmerald.color,
      ),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: inner!,
      ),
      home: child,
    ),
  );

  await tester.pumpWidget(app);
}
