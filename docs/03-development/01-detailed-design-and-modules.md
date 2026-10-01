# Valhalla - 模块详细设计与分层架构说明书

## 2026-10-01 模型发现（覆盖下方旧的会话配置发现约定）

`agentModelQueryProvider` 是可注入的独立API查询入口，Codex复用
`CodexNativeClient.queryCapabilities`，与对话所用ACP session解耦。
模型刷新只进行ACP initialize + 独立模型查询，不恢复/加载/创建会话；
保留已有工作连接。模式、当前选项、用户主动应用设置仍使用ACP配置接口。
未知独立接口不猜测，不从历史配置回退。云端实时账号目录尚未接入，接口目录
与账号权限验证不得混淆。见[交接与来源](../handoffs/2026-10-01-independent-model-discovery.md)。

## 2026-09-30 前后台连接与会话恢复

复用现有 SSH manager、生命周期协调器和重连控制器：单一心跳、探活与握手合并，
后台超时不主动销毁连接；前台探活有一次宽限，用户断开/换目标使旧异步结果失效。
聊天 provider 仅随连接目标变化重建，不随连接布尔值或 Agent 检测状态重建。
`SessionRecoveryStatus` 独立于已有会话内容；断线停止本地接收而非发送取消指令。
ACP 复用 load/resume 和导入解析器，在 DB isolate 中50条一批事务合并，保留本地 ID；
单次可见窗口补齐有界，歧义或不支持回放标 incomplete，绝不 fallback 到 session/new。
CLI 复用官方历史分页；草稿/消息在进程内保留。ACP 生命周期检查点另持久化消息、
文字草稿和附件描述，图片存私有文件。无新增依赖、远端 Daemon 或强制 WakeLock。
详细限制、分工及门禁见[本轮交接](../handoffs/2026-09-30-background-session-recovery.md)。

## 2026-09-30 ACP 可用性第二轮（优先于下方旧契约）

沿用 acpd v1 的消息 ID 与通知分发，事件保留角色/ID/资源块；账号通过已声明
authStatus 扩展接收。草稿只 initialize，首次发送才 new；已有会话优先 resume
获取最新配置，必要时 load，失败保留工作连接并标记旧配置。
ChatMessage 扩展可选 remoteMessageId/attachments，旧 JSON 不变；图片不入消息 JSON，
通过 AcpAttachmentStore 在后台保存内容寻址私有文件。导入仍50条批写和背压，
重新导入新本地副本，原记录和远端不改。
AcpWorkspaceFiles 按 Agent 执行目标复用 SFTP/已有 docker exec 封装，读取有界、
可取消，预览串行且8MiB缓存，单个预览源最多2MiB；大图浏览显示占位，选中附件
仍遵守20MiB图片/1MiB文本总量。目录超过10000项明确报错，不静默截断。
默认导航采用读时兼容映射旧默认值，显式保存记录迁移标识，自定义和空列表不变。
图片渲染使用 Flutter 原生 ResizeImagePolicy.fit 同时限定宽高（不拉伸、不访问远端URL），
草稿按已限额bytes预览，历史按私有文件加载；损坏/缺失图片显示占位。
目录浏览用请求代次丢弃迟到结果，目录失败禁确认；选择多个文件时逐项核验当前目标。
自动化及APK/安装结果以[实施状态](04-implementation-status.md)和
[本轮交接](../handoffs/2026-09-30-acp-usability.md)为准，不能代替真实ACP验收。

## 2026-09-30 ACP 增量架构

- 协议仍使用acpd v1类型化ClientRole/ClientContext，避免Session高层封装重复缓存整轮流事件；不自研RPC。
- 权限结果保持原始optionId或取消，wire为 `result.outcome = {outcome, optionId?}`；旧扁平断言无效。
- 工具按ID合并可选更新，配置按远端确认值联动，普通设置打开不重建进程。
- ChatRepository使用独立SQLite，所有SQL固定且参数绑定，在后台isolate执行；摘要与消息分开，messageOffset为绝对序号。
- 旧JSON保留、幂等事务导入并核验归属/数量；失败可回读旧记录且不把损坏JSON视为空历史。新数据通过exportAll导出。
- 每2秒保存生成中检查点，终态立即保存；重启后streaming转interrupted，不自动重发。
- 远端session/list只初始化连接；导入session/load分批50条落盘，待写批次达到2时暂停SSH输入，下降后恢复。
- 附件仅显式发送，按promptCapabilities启用；本地文件限长读取，Docker文本文件在目标容器用户环境读取。
- stderr通过共享LogSanitizer按流脱敏并保留8KiB尾部；生成采用无进展超时，审批等待不计时。

详见[接口与验收交接](../handoffs/2026-09-30-acp-client-completion.md)。本节是本轮实现契约，不替代测试结果。

| 文档版本 | 发布日期 | 适用阶段 | 核心架构 |
| :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-09-13 | 开发实施阶段 | Clean Architecture + Riverpod Provider Pattern |

---

## 1. 源码目录工程结构规范

工程遵循高内聚、低耦合的特性导向模块化划分（Feature-First）：

```text
lib/
├── app/                                # 应用层全局入口
│   ├── app.dart                        # MaterialApp 根组件 (Theme, Locale)
│   ├── router.dart                     # go_router 路由定义与导航守卫
│   └── theme.dart                      # Material 3 主题配色与字体定义
│
├── core/                               # 核心跨模块基础库
│   ├── constants/                      # 系统常量与预设枚举
│   ├── errors/                         # 全局异常体系 (AppException, SSHError 等)
│   ├── extensions/                     # Dart/Flutter 语法糖扩展
│   ├── logging/                        # 脱敏日志输出器 (LogSanitizer)
│   └── utils/                          # 工具函数 (格式化, 校验器等)
│
├── data/                               # 数据访问与持久化层
│   ├── database/                       # Drift SQLite 表定义与 Database 实例
│   │   ├── app_database.dart           # Drift 数据库主类
│   │   ├── daos/                       # 数据访问对象 (ServerDao, CommandDao)
│   │   └── tables/                     # 表结构定义 (servers.dart, commands.dart)
│   ├── secure_storage/                 # flutter_secure_storage 凭证封装
│   └── repositories/                   # Repository 实现 (聚合 DB 与 Storage)
│
├── infrastructure/                     # 底层 SDK 封装与远程通信实现 (防污染业务层)
│   ├── ssh/                            # SSH 连接池与会话管理
│   │   ├── ssh_client_manager.dart     # 核心 SSHClient 管理器
│   │   ├── ssh_command_executor.dart   # 带 Login Shell & PATH 包装的命令执行器
│   │   └── ssh_host_key_verifier.dart  # Host Key SHA256 验签器
│   ├── sftp/                           # SFTP 文件操作封装
│   │   ├── sftp_file_manager.dart      # 文件上传、下载、CRUD 操作流
│   │   └── sftp_transfer_tracker.dart  # 传输进度与速率监听
│   ├── acp/                            # ACP 协议交互层
│   │   ├── acp_client_adapter.dart     # stdio over SSH Channel 桥接器
│   │   ├── acp_event_dispatcher.dart   # JSON-RPC 事件分发器
│   │   └── acp_permission_handler.dart # 权限审批拦截与回调
│   ├── docker/                         # Docker 远程操作封装
│   │   ├── docker_cli_executor.dart    # 结构化参数调用与 JSON 反序列化
│   │   └── docker_log_streamer.dart    # 容器实时日志流
│   ├── terminal/                       # 终端仿真核心
│   │   └── terminal_session_bridge.dart# xterm.dart 与 SSH PTY 双向字节流绑定
│   └── system/                         # 系统监控流
│       └── system_metrics_sampler.dart # 资源占用自适应流式采样器
│
├── features/                           # 业务功能特性模块 (按业务垂直切片)
│   ├── dashboard/                      # 首页状态概览 (CPU/内存/卡片聚合)
│   ├── servers/                        # 服务器管理 (添加/编辑/测试连接/列表)
│   ├── agents/                         # Agent 首页与管理 (Claude/Codex/OpenCode)
│   ├── sessions/                       # ACP 聊天会话 (Markdown流/Tool Call/审批)
│   ├── files/                          # 文件管理器 (浏览/多选/编辑器)
│   ├── terminal/                       # SSH 终端视图 (Tab管理/辅助键栏)
│   ├── docker/                         # Docker 管理 (容器/镜像/日志/Exec)
│   ├── processes/                      # 进程管理器 (列表/搜索/杀死进程)
│   ├── commands/                       # 快捷命令 (参数模版/危险操作拦截)
│   ├── services/                       # Systemd 服务管理
│   └── settings/                       # 应用设置 (主题/字体/安全选项)
│
└── widgets/                            # 跨业务通用 UI 组件
    ├── cards/                          # 统一卡片样式
    ├── dialogs/                        # 危险操作确认框, 密码输入框
    ├── markdown/                       # 增强富文本 Markdown 渲染器
    ├── terminal/                       # 移动端 Accessory Keyboard Bar
    └── status_badge.dart               # 状态徽标 (Online/Offline/Running)
```

---

## 2. 核心服务设计与数据流转

### 2.1 SSHManager：物理连接池管理
```dart
class SSHManager {
  // 单台服务器复用单条物理 SSH 连接，按需建立 Channel
  final Map<String, SSHClient> _activeClients = {};

  Future<SSHClient> getOrCreateClient(ServerEntity server) async {
    if (_activeClients.containsKey(server.id)) {
      return _activeClients[server.id]!;
    }
    final client = await _connect(server);
    _activeClients[server.id] = client;
    return client;
  }

  Future<void> disconnect(String serverId) async {
    _activeClients.remove(serverId)?.close();
  }
}
```

### 2.2 ACPClientAdapter：stdio over SSH Channel
```dart
class ACPClientAdapter {
  final SSHClient sshClient;
  final String agentCommand; // 如 "bash -l -c 'claude-code-acp'"
  SSHSession? _session;
  StreamChannel<String>? _acpChannel;

  Future<StreamChannel<String>> start() async {
    _session = await sshClient.execute(agentCommand);
    
    // 将 SSHSession 的字节流包装为行分隔的 UTF-8 字符串管道
    final inStream = _session!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final outSink = StreamController<String>();
    outSink.stream.listen((line) {
      _session!.stdin.add(utf8.encode('$line\n'));
    });

    return StreamChannel<String>(inStream, outSink.sink);
  }
}
```

### 2.3 TerminalSessionBridge：xterm.dart 与 SSH PTY 桥接
```dart
class TerminalSessionBridge {
  final SSHClient sshClient;
  final Terminal terminal;
  SSHSession? _shellSession;

  Future<void> attach() async {
    _shellSession = await sshClient.shell(
      pty: SSHPtyConfig(
        terminalType: 'xterm-256color',
        width: terminal.viewWidth,
        height: terminal.viewHeight,
      ),
    );

    // 远端输出 -> xterm 终端屏幕
    _shellSession!.stdout.listen((data) {
      terminal.write(utf8.decode(data, allowMalformed: true));
    });

    // 用户键盘输入 -> SSH 管道
    terminal.onOutput = (input) {
      _shellSession!.stdin.add(utf8.encode(input));
    };

    // 监听视图 Resize 事件
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _shellSession!.resizeTerminal(width, height);
    };
  }
}
```

---

## 3. Riverpod 状态流向规范

在任一 Feature 内部，严格遵循单向数据流动：

```text
┌─────────────────────────┐
│     UI Widget (View)    │
└────────────┬────────────┘
             │ 1. ref.watch(provider) / ref.read(provider.notifier).action()
             ▼
┌─────────────────────────┐
│ StateNotifier / Provider │  (管理纯内存状态，不持具体 Widget)
└────────────┬────────────┘
             │ 2. 调用业务 Service 或 Repository
             ▼
┌─────────────────────────┐
│ Repository / Service    │  (聚合数据库持久化与 Infrastructure 通信)
└────────────┬────────────┘
             │ 3. 操作底层 SDK (dartssh2 / acpd / drift)
             ▼
┌─────────────────────────┐
│ Infrastructure SDKs     │
└─────────────────────────┘
```
