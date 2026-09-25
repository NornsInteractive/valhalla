# Valhalla - 系统架构设计说明书 (SAD)

| 文档版本 | 发布日期 | 适用系统 | 架构基准 |
| :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-09-13 | Valhalla 客户端核心 | 5 层架构模型 / Clean Architecture |

---

## 1. 总体架构拓扑与分层原则

Valhalla 严格遵循 **分层架构与单向依赖** 模式，保证业务逻辑与底层通信实现高度解耦：

```text
┌─────────────────────────────────────────────────────────────┐
│                    1. Presentation Layer (UI)               │
│   Material 3 UI, Adaptive Widgets, NavigationRail / Bar     │
└──────────────────────────────┬──────────────────────────────┘
                               │ UI Reads State & Emits Events
┌──────────────────────────────▼──────────────────────────────┐
│                  2. State Management (Riverpod)             │
│   AsyncNotifier, StateNotifier, StreamProvider, UI State     │
└──────────────────────────────┬──────────────────────────────┘
                               │ Invokes Service / Repository
┌──────────────────────────────▼──────────────────────────────┐
│                 3. Domain & Service Layer (Logic)           │
│   SSHManager, ACPManager, SessionManager, DockerManager     │
└──────────────────────────────┬──────────────────────────────┘
                               │ Encapsulates Standard SDKs
┌──────────────────────────────▼──────────────────────────────┐
│                    4. Existing SDK Layer                    │
│   dartssh2, acpd, xterm.dart, drift, flutter_secure_storage │
└──────────────────────────────┬──────────────────────────────┘
                               │ Standard Protocol Communication
┌──────────────────────────────▼──────────────────────────────┐
│                  5. Standard Protocols & Remote             │
│   SSH / SFTP / ACP (JSON-RPC) / Docker Engine / SQLite      │
└─────────────────────────────────────────────────────────────┘
```

### 架构依赖禁止原则：
* **严禁** UI Widget 直接依赖或调用 `SSHClient`、`SSHSession` 或原生 Socket。
* **严禁** UI Widget 直接拼装或解析底层 ACP JSON-RPC 报文。
* **严禁** 在服务端部署私有监听 Daemon（零侵入服务端设计）。

---

## 2. 6 大关键技术暗坑与核心解决方案

针对前期设计文档审查中识别出的 6 个潜在风险，架构确立以下确定性方案：

### 2.1 暗坑 1：Docker 在移动端（Android/iOS）的跨平台执行方案
* **问题本质**：移动设备操作系统不包含本地 `docker` 二进制可执行程序，无法像桌面端一样执行 `docker -H ssh://...`。
* **架构解法**：
  1. **远端命令结构化流式解析（Primary）**：
     * 客户端通过 `dartssh2` 在远端宿主机上直接执行 Docker 原生指令，强制附加 `--format '{{json .}}'`。
     * Dart 侧封装流式与 JSON 反序列化器，将其转化为强类型 `ContainerModel`、`ImageModel`。
  2. **容器终端与日志直连**：
     * 容器日志流通过 `docker logs -f --tail=100 <id>` 经由 SSH Channel stdout 接收。
     * 交互式终端通过 `docker exec -it <id> /bin/sh` 分配 PTY 直连 `xterm.dart`。
  3. **Unix Socket 隧道代理（Advanced/Phase 2）**：
     * 利用 `dartssh2` 的端口转发特性，将远端 `/var/run/docker.sock` 映射至本地 Stream，直接调用标准 Docker Engine HTTP REST API。

### 2.2 暗坑 2：SSH 管道生命周期与 ACP 会话持久化机制
* **问题本质**：当客户端 App 关闭或断网导致 SSH 断开时，SSH Server 会向下级进程传递 `SIGHUP` 信号，杀死直连的 `claude-code-acp` 子进程。
* **架构解法**：
  1. **分层状态恢复机制**：
     * 会话历史与上下文依靠 Agent 在服务器本地的标准文件持久化（如 `~/.claude/sessions`）。
     * App 重连成功后，SSH 重新拉起对应 Agent 的 ACP Adapter，客户端调用标准 `session/list` 获取历史，调用 `session/resume` 无缝复原历史会话上下文。
  2. **瞬时流被打断处理**：
     * 明确断线会导致当前单次未生成的流中断，客户端在 UI 上标记最后一条消息为 `interrupted`，并在重连后提示用户是否一键重试发送该 Prompt。
  3. **长时任务可选守护（进阶扩展）**：
     * 后续对于长达数十分钟的编译/自动化任务，提供轻量 `nohup` 或 `systemd --user` 托管运行模式。

### 2.3 暗坑 3：SSH 非交互式 Shell 的环境变量与 PATH 丢失
* **问题本质**：`dartssh2.execute()` 执行非交互式会话，Linux 默认不加载 `~/.bashrc`、`~/.zshrc`，导致通过 `nvm`, `fnm`, `pnpm`, `cargo`, `conda` 等安装在用户主目录的 Agent CLI 无法被识别。
* **架构解法**：
  1. **统一登录 Shell 包装器 (Login Shell Wrapper)**：
     * 所有执行命令统一通过 `bash -l -c "<command>"` 唤起，强制读取 `/etc/profile`、`~/.bash_profile` 或 `~/.profile`。
  2. **智能 PATH 探测与注入**：
     * 首次成功连接主机时，后台自动执行 `echo $PATH` 并扫描常见安装路径（如 `~/.nvm/versions/node/.../bin`, `~/.cargo/bin`, `~/.local/bin`）。
     * 在每次执行重要 Agent 或命令时，在命令前置自动拼接用户专用环境路径：`export PATH=$PATH:...; <cmd>`。

### 2.4 暗坑 4：Sudo 提权与 TTY 缺失处理
* **问题本质**：执行 `sudo systemctl restart xxx` 或快捷命令时，无终端环境执行将报错 `sudo: a terminal is required to read the password`。
* **架构解法**：
  1. **`sudo -S` 自动安全输入**：
     * 当执行标记需要 sudo 的命令时，执行器自动改写为 `sudo -S <command>`，从本地安全存储 `flutter_secure_storage` 中读取安全密码通过 stdin 管道送入，避免 TTY 阻断。
  2. **PTY 动态交互回退**：
     * 若未配置免密且未预存密码，执行器以分配 PTY 的伪终端模式启动，捕获到 `[sudo] password:` 提示后在前端触发优雅的密码输入 BottomSheet。

### 2.5 暗坑 5：系统监控采集的资源保护与节流
* **问题本质**：高频并发 SSH exec 轮询会导致服务器高频 fork 进程，浪费 CPU 算力与手机流量电量。
* **架构解法**：
  1. **生命周期绑定 (Lifecycle-Aware)**：
     * 仅当用户处于 Dashboard 或 System 页面且 App 处于前台活跃状态时才启动采集；页面切换或退至后台时立即销毁 Channel。
  2. **轻量持久流 vs 批量延时**：
     * 优先采用单通道流式输出（例如：维持一个长连接管道循环读取 `/proc/stat` 与 `vmstat 3`），而非每秒创建销毁新的 SSH 进程。
     * 默认采样间隔设置为 3~5 秒。

### 2.6 暗坑 6：移动端 Terminal 的软键盘与 CJK 输入法对齐
* **问题本质**：手机系统软键盘缺少 Esc、Ctrl、Alt、方向键，且输入法联想输入（IME）的拼音合成状态直接向终端抛送字符会导致终端光标和指令乱码。
* **架构解法**：
  1. **定制 Accessory Keyboard Bar**：
     * 固定在移动端软键盘上方，提供带有状态记忆的 `Ctrl`, `Alt`, `Esc`, `Tab`, `↑`, `↓`, `←`, `→` 键位以及剪贴板粘帖。
  2. **IME 合成区防抖过滤**：
     * 在字符写入 `xterm.dart` 前，监听 Flutter `RawKeyEvent` / `TextInputClient`，确保在用户按下回车或候选词上屏确认后再将终态 UTF-8 字节送入 SSH PTY。

---

## 3. 安全架构设计

```text
┌─────────────────────────────────────────────────────────────┐
│                      Client Security                        │
├─────────────────────────────────────────────────────────────┤
│  SQLite (Drift)           : 服务器信息, Known Hosts, 配置     │
│  Secure Storage (Keystore): SSH 密码, 私钥, Passphrase, Sudo│
│  Memory / Sanitizer       : 日志脱敏, 禁止 Token/Key 落盘   │
└──────────────────────────────┬──────────────────────────────┘
                               │ SSH 22 (Encrypted Traffic)
┌──────────────────────────────▼──────────────────────────────┐
│                      Server Security                        │
├─────────────────────────────────────────────────────────────┤
│  Host Key 校验            : 抵御中间人攻击 (MITM)           │
│  普通非 Root 用户运行     : 通过 docker 用户组或按需 sudo   │
│  零公网监听端口           : 完全基于现有 SSH 端口复用       │
└─────────────────────────────────────────────────────────────┘
```

1. **凭证隔离**：非敏感的服务器元数据保存在 Drift 本地 SQLite，所有密码、私钥明文和 Passphrase 必须进入 `flutter_secure_storage`。
2. **日志脱敏过滤器**：建立全局 `LogSanitizer`，所有发往控制台或本地文件的日志，自动过滤识别类似 Private Key、Password、Bearer Token、API Key 等特征字符串。
3. **高危命令熔断**：快捷命令库设置安全级别（Safe, Warning, Danger），对 `rm -rf`, `mkfs`, `docker system prune -a`, `reboot` 等关键词实施客户端双重校验。
