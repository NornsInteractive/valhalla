# Valhalla - 项目工程规则与开发铁律

## 2026-09-29 测试与打包职责

后续新增或维护测试用例、运行格式/静态分析和测试、打包各平台产物及核验构建结果，统一交给 OpenCode 执行，CLI 固定显式指定模型 `opencode/mimo-v2.6-flash-free` 并核对输出；模型不可用时报告，不能擅自替换。需要 Android 设备验证时，由 OpenCode 指定 ADB 设备序列号，覆盖安装须保留应用数据；遇到签名不兼容时停止，不得为完成安装而卸载或清空用户数据。业务 Agent 检查 OpenCode 的命令、产物和结果并更新文档，不把未执行的检查记为通过。展示层仍由指定 Valhalla `agy` 会话负责。

## 2026-09-19 仪表盘与主题增量规则

- 重启和关机都必须确认当前服务器身份与运行中的终端、Agent、传输数量；命令发出后 SSH 断线属于结果未知，不能自动重复执行，也不能将关机误判为已验证重启。
- 网络速率只能由同一网卡连续两次非负流量计数和实际采样间隔计算；首采样、计数器回退及断线不得显示虚构速率。主卡使用默认路由网卡，虚拟网卡不求和，避免双重计数。
- 主题色按浅色、深色、极客黑暗独立保存；跟随系统只解析到浅色或深色。旧单色设置是新键缺失时的回退数据，升级不得删除旧键。
- 展示层、ARB 和 Widget 测试仍只由指定 Valhalla `agy` 历史会话以 `gemini-3.8-flash-high` / high 修改；业务方只修改状态、存储、SSH 服务和非 UI 测试。

## 2026-09-19 原生 CLI 与运维补充

ACP / CLI 生命周期独立；原生历史只使用官方接口或真实终端，不构造私有 Daemon、不静默跳过审批。安装 / 登录 / SDK / 远端历史删除显式确认并捕获服务器与 Agent 身份。危险重启必须确认；未收到退出状态不得视作成功，unknown 不自动重复重启，仅 boot_id 改变可验证完成。后台命令历史隔离本轮只设计，不修改用户 Shell / 历史。界面仍仅由指定 Valhalla agy 会话维护，Gemini 3.8 Flash / high。细则见 [本轮契约](../handoffs/2026-09-19-cli-reboot-performance.md)。

## 2026-09-18 接手约束补充

展示层只能交由 `agy` 的历史 Valhalla 会话修改，使用 Gemini 3.8 Flash / high；后端开发者不得自行修改 UI。安装、登录、删除会话和丢失上下文后的重启必须显式确认。Agent 自动归属当前服务器，不采用用户手动绑定；共享会话不得跨服务器或共享远端认证/审批状态。版本输出不是认证证明；不得把 CLI 存在当作 ACP 协议可用。实现状态以测试与源码为准，设计目标不能标记为已交付；真实平台与服务器未验证时必须注明。

| 文档版本 | 制定日期 | 适用范围 | 效力级别 |
| :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-09-13 | 全体研发人员 / AI Agent / Code Reviewer | **强制执行 (Mandatory)** |

---

## 1. 核心治理理念

本项目（Valhalla）是一款高度综合、追求工业级稳定性的跨平台服务器与 AI Agent 管理客户端。为避免陷入低质量开发泥潭，全工程确立以下两项根本治理原则：
1. **工程克制**：做正确的架构拼装，不做盲目的重复发明。
2. **规范先行**：任何代码提交必须无条件遵从本规范中约定的技术栈边界与架构约束。

---

## 2. 铁律一：严禁重复造轮子 (Zero Wheel-Reinventing Policy)

### 2.1 依赖库复用红线
严禁任何人自行开发已经有成熟工业级实现的底层模块。必须无条件复用经技术委员会审查认定的官方及开源生态 SDK：

| 功能模块 | 官方/行业选定成熟库 | 严禁行为（违规红线） |
| :--- | :--- | :--- |
| **SSH / SFTP 协议** | `dartssh2` | 严禁自研 Socket 加解密、SSH 握手或 SFTP 协议解析器 |
| **AI Agent 通信** | `acpd` / `acp_dart` | 严禁自研 ACP 协议封包、自创私有 Agent 交互 JSON 协议 |
| **终端仿真与 ANSI** | `xterm` (`xterm.dart`) | 严禁使用普通 TextField/RichText 拼凑终端界面 |
| **代码语法高亮** | `syntax_highlight` | 严禁自写正则表达式解析多语言语法高亮 |
| **Markdown 渲染** | `flutter_markdown_plus` | 严禁自行手写正则或 HTML 渲染引擎来解析 Markdown |
| **本地结构化数据库**| `drift` + `drift_flutter` | 严禁手写 raw SQL 字符串拼接或无类型安全持久化 |
| **安全密钥存储** | `flutter_secure_storage` | 严禁自行实现文件加解密（必须使用系统原生 Keystore/Keychain）|
| **本地文件选择** | `file_picker` | 严禁通过命令行或手写 PlatformChannel 唤起系统文件选择 |
| **状态管理** | `flutter_riverpod` | 严禁混用 Provider, GetX, Bloc 等第三方库，保持全工程统一 |
| **路由与导航** | `go_router` | 严禁使用老旧 Navigator 1.0 命令式路由 |

> 当前 SDK 兼容例外：NAS 媒体索引允许使用 `sqlite3` 的固定参数化 SQL，直到
> Drift 依赖矩阵可与 Flutter 3.44.2 同时解析。例外仅限
> `NasIndexRepository`，所有输入必须使用绑定参数，数据库访问必须在后台
> isolate 执行；不得把此例外扩散到凭证、服务器或会话数据。

### 2.2 通用工具类复用
* 数据单位换算（如 `B/KB/MB/GB`）、时间格式化、Cron 表达式解析、Shell 参数转义等，**统一抽取至 `core/utils/` 并在工程内复用**，严禁在不同页面或 Feature 中重复手写转换逻辑。

---

## 3. 铁律二：严格分层架构与单向数据流

```text
┌─────────────────────────┐
│     UI Layer (Widget)   │
└────────────┬────────────┘
             │ ref.watch / ref.read
             ▼
┌─────────────────────────┐
│ State Layer (Riverpod)  │
└────────────┬────────────┘
             │ invoke
             ▼
┌─────────────────────────┐
│  Service / Repository   │
└────────────┬────────────┘
             │ call
             ▼
┌─────────────────────────┐
│   Infrastructure SDK    │  (dartssh2, acpd, drift 等)
└─────────────────────────┘
```

### 违规模式警示（Code Review 一票否决）：
1. **严禁越级直接通信**：禁止在 Widget 中直接实例化或调用 `SSHClient`, `acpd`, `Database`。Widget 必须仅能与 Riverpod 的 Provider 交互。
2. **严禁在 ViewModel / State 中保留 Widget 引用**：Riverpod Notifier 严禁持有 `BuildContext`、Widget 引用，确保业务逻辑具备纯净的可单测性。
3. **不可变状态规则**：所有状态类必须声明为 `@immutable`，状态变更必须通过 `copyWith()` 产生新实例，禁止直接对原有 List/Map 原地执行 `add()` 或修改字段。

---

## 4. 铁律三：零服务端侵入原则 (Zero Server Intrusion)

1. **零服务端常驻后台**：Valhalla 客户端在设计与实现上，**绝对不要求目标 Linux 服务器安装专有的 Server 监听端、Daemon 或网关代理**。
2. **复用系统原生设施**：
   * 连接与文件管理复用标准的 `OpenSSH Server` (sshd)；
   * 容器管理直接复用宿主机的 `docker` CLI；
   * 系统运维直接使用标准的 `systemctl`、`ps`、`procfs` 工具；
   * AI Agent 接入复用本地安装的官方 CLI（如 `claude-code`、`codex`）所附带的标准 ACP 适配管道。

---

## 5. 铁律四：安全第一与凭证隔离准则

1. **敏感凭证绝不明文落盘**：
   * 密码、SSH 私钥明文、Passphrase、Token 严禁写入 SQLite 数据库（Drift）。
   * 必须全部使用 `flutter_secure_storage` 调用操作系统级安全硬件进行持久化。
2. **日志强制脱敏**：
   * 日志框架必须全局集成 `LogSanitizer`；
   * 任何在控制台输出（`debugPrint`）、文件日志或崩溃上报中包含私钥块、密码字串、认证 Token 的行为均属严重安全故障。
3. **高危指令双重防线**：
   * 凡涉及 `rm -rf`, `docker system prune`, `mkfs`, `reboot`, `shutdown` 等危险操作，代码中必须强制接入统一的 `DangerConfirmDialog`，禁止绕过确认直接静默执行。

---

## 6. 铁律五：全局异常体系与质量门禁

1. **统一异常层级**：所有底层抛出的 I/O、网络、SSH、ACP 异常，必须在 Repository / Service 层转化为标准 `AppException` 领域异常树，明确区分网络超时、认证失败、权限不足、进程退出等类型。
2. **严禁吞掉异常（Empty Catch）**：
   ```dart
   // 严禁以下写法！
   try { ... } catch (e) {} 
   
   // 必须捕获、记录日志并转化为用户可理解的失败状态
   try { ... } on SocketException catch (e, st) {
     AppLogger.error('SSH connection failed', e, st);
     throw SSHConnectionException('Network unreachable', e, st);
   }
   ```
3. **静态分析零容忍**：提交的代码必须通过 `flutter analyze` 检查，不允许存在未使用的导入、弃用 API 调用或死代码。
