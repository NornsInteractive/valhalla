# Valhalla - 模块详细设计与分层架构说明书

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
