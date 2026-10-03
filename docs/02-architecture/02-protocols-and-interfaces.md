# Valhalla - 标准协议与通信接口规范

## 2026-10-03 AgY ACP OAuth 桥接

`ACPClientAdapter.authenticateNow(methodId)` 仅 initialize + 广告 authenticate，
不创建/加载聊天会话。`AcpSshTransport.authorizationRequests` 在完整 stderr
行脱敏前提取官方 Google HTTPS 授权请求，诊断仍经过统一脱敏。请求仅存
`AiChatState.authRequest`；`isAuthenticating/authError` 用于局部进度/错误。
`authenticationConfirmed` 仅在真实 authenticate/会话 RPC 成功时置真，
initialize、选择认证方式、取消或发现凭据文件均不能视为认证成功。
`claimAuthBrowserLaunch(request)` 为同一 provider 的同步抢占，防止保留的
主界面与弹出的聊天页重复打开浏览器；手动重新打开不受自动抢占限制。
`requestAuthentication()` 可在草稿或待认证历史中重新发现方式；
`respondAuth()` 立即认证；`submitAuthCallback()` 校验当前请求并发送到原
执行目标。`AcpOAuthLoopback` 镜像手机回环端口，curl 仅从 stdin 接收 URL，
不跟随远端重定向，不输出响应体。代理不获取或保存 OAuth token，凭据仍
由官方 ACP 存放；取消、重连、换目标按 epoch/adapter 隔离并关闭监听。
默认检查只读取 settings.json 的 auth.type 及凭据文件存在性，结果与真实
认证成功分离。具体边界及验证记录见本轮登录交接。
管理入口等待 `switchAgent()` 的本地会话选择完成，再 initialize 发现认证
方式；调用前后校验当前服务器与 Agent，不隐式切换服务器、不自动发送消息。
回调手机监听失败可手动粘贴本次完整回环 URL（必须匹配 state/端口/路径）；
转发仍需要原目标宿主机或容器用户环境的 `curl`，不是把授权码换成手机登录。
远端不具备此命令或回调不可达时报告失败，不自动安装依赖或复制 CLI 凭据。
授权回调 exec 通道打开后，发送前就接管 stdout、stderr 与 done；stdout /
stderr 均处理完毕、stdin 已关闭、通道结束且 curl 返回有效成功状态，才算
转发完成。任一路流异常均立即返回失败，不让正常完成抢先掩盖 stderr
异常；20 秒限时覆盖通道打开后的写入/读取/完成等待。即使 session.close
抛错，仍取消 stderr 监听。该结果仅表示转发完成，认证仍以官方 RPC
成功为准；不把模拟回归视为真实账号授权或实际网络断线根因证明。

## 2026-10-02 ACP 输出顺序与恢复兼容

`ChatMessage.contentBlocks` 为可选 JSON 数组：text(start,end) 引用 `content`
UTF-16 偏移，tool(toolId) 引用现有工具数组，无重复文本、无数据库迁移。
文本相邻合并，工具首次出现定位、后续仅更新；非法/旧字段整段退回旧展示。
`ChatTurnStatus.unknown` 表示丢失传输后的结果未知，`interrupted` 保留用户
取消含义。回放成功复用同一 ACP adapter，结束捕获后恢复现有 session ID；
不额外启进程、prompt/new/cancel，不自动重放审批。未声明回放或身份歧义
保留本地内容并报告不完整，失败后仅显式重试。
Antigravity 默认 `agy_acp_server.par`，Linux 使用 registry 的 `--uid=` 参数，
安装保留完整 runtime；官方认证由 ACP 广告能力处理，不复用 CLI 登录假设。
Codex 模型发现仍为独立 CLI app-server `model/list`，不从历史会话发现。

## 2026-09-21 NAS Range 流与会话启动接口

`ChatLaunchPreference` 按 `<serverId>::<cli|acp>::<agentId>` 保存 `rememberLast`、`fixed(sessionId)` 或 `blankDraft`，最后选择的会话另存且不得跨服务器/Agent 复用。解析不到指定会话时回退空白草稿。

NAS 内置播放器通过 loopback HTTP URI 读取 SFTP：URI 只含随机 token，不含凭据；仅允许 GET/HEAD，响应 `Accept-Ranges` 并将单字节范围转为 `SftpFile.read(offset, length)`。外部应用始终使用本地完整文件，不能把 loopback token 交给系统 chooser。缓存键必须包含服务器、路径、大小和 mtime，远端文件变化后旧缓存不可复用。

## 2026-09-20 CLI 长历史读取

CLI 会话消息统一按最新窗口读取，向上滚动才请求更早一页；`NativeCliMessagePage.olderCursor` 仅标识下一段旧消息。Codex 使用 `thread/items/list` 倒序游标，且因协议 limit 统计工具等全部原始 item，客户端须继续读取后续 item 页直到凑够目标数量的用户 / 助手消息或游标结束；OpenCode 使用 `/session/:id/message?limit=&before=`。不再为显示窗口调用 Codex `thread/read(includeTurns: true)`。旧版 CLI 不支持分页时返回 `CLI_VERSION_UNSUPPORTED`，不得默默退回全量读取或自动升级。Claude Code 保持官方 SDK：在远端取历史后只输出所需窗口，避免全量 SSH 传输，但其官方 offset 从最早消息计算，远端扫描成本仍可能随历史增长。切换服务器、Agent 或会话必须使旧请求结果失效；生成过程的最新页刷新不得丢失已加载的旧页。Codex / OpenCode 会话目录首屏为 15 条，旧 Agent 目录在切换回来时复用内存缓存，用户主动刷新或会话完成后再同步。

## 2026-09-19 原生 CLI 与运维接口

新增 `cliChatProvider` 与 `infrastructure/cli`：Codex 官方 SSH stdio app-server 复用 acpd 的请求关联，仅薄适配版本头；OpenCode 官方回环 HTTP/SSE 经 dartssh2 转发、临时认证和运行时 OpenAPI 能力检查；Claude 官方 SDK 一次性读历史；其他使用 xterm 真实 PTY。不把原生 ID 写成本地 ACP ChatSession。`serverPowerProvider` 区分受理 / 未知 / 失败 / 验证，重连只读 boot_id。后台 exec 退出码按执行独立，未知为 -1，输出 drain 后返回。后台历史策略未修改。详情见 [接口与边界](../handoffs/2026-09-19-cli-reboot-performance.md)。

## 2026-09-20 Agent Docker 执行目标

`AgentProfile` 持久化 `executionTarget`（`host` / `docker`）、`containerBinding`（`id` / `name`）、`containerReference` 与可选 `containerUser`；缺失字段兼容为 `host` 和镜像默认用户。`agentTargetCommand` 是唯一的命令包装边界：主机命令不变，容器后台与 ACP 协议使用 `docker exec -i [--user user] <container> sh -lc <quoted-command>`，只有交互终端使用 `-it`。登录 Shell 使用户的正常登录环境可参与 CLI 探测；若 CLI 只写入交互 `.bashrc`，用户应设置绝对可执行路径。显式用户会先运行 `id -u` 验证，失败返回 `AGENT_CONTAINER_USER_UNAVAILABLE`。在 SSH 宿主机先探测容器运行态，再执行容器内 CLI/ACP/认证命令；不通过宿主机 Shell 保存代理进程。OpenCode 服务绑定容器可访问地址，端口仅经已有 SSH 转发连接，不发布 Docker 端口；无法发现可路由地址时返回 `CLI_CONTAINER_NETWORK_UNSUPPORTED`。

Codex 原生删除由客户端确认框确认后执行 `codex delete --force <session>`；能力检测同时要求帮助信息包含 `--force`，失败保留稳定 `CLI_DELETE_FAILED` 与已脱敏、截断的远端详情，不把远端输出误报为成功。

Docker Agent 表单可查询所选运行容器的 `/etc/passwd`，返回全部有效 `name:uid:gid` 条目供选择；手工 `containerUser` 始终优先并允许最小镜像或目录服务用户。每次 Agent 环境检测生成仅存在于内存的 `diagnosticLog`：记录稳定步骤名、退出码和脱敏输出尾部，最多 32 条，禁止记录原始安装/认证命令或未脱敏凭据；管理页可查看并复制该日志。

## ACP 会话身份修订（2026-09-18）

### ACP 权限响应边界（2026-09-22）

`session/request_permission` 的 JSON-RPC response `result` 必须直接采用 ACP
`RequestPermissionOutcome` 对象，例如：

```json
{"jsonrpc":"2.0","id":"perm-1","result":{"outcome":"selected","optionId":"allow"}}
```

禁止再包一层 `{ "outcome": { ... } }`。客户端必须对 allow、reject、cancel
三种结果做 wire-level 回归测试。

每个本地 `ChatSession` 持有 `serverId`、`agentId`、`workingDirectory`、`remoteSessionId`。Adapter 缓存身份为服务器 + Agent + 本地会话，不再从旧服务器 + Agent 全局键恢复会话。`session/load` 仅在 JSON-RPC -32601 时尝试 `session/resume`；两者均不支持返回显式重启要求，网络、认证、会话不存在等错误不得自动新建。取消与断线使请求 epoch 失效，以屏蔽迟到回调。

当前持久化仍是 SharedPreferences JSON，本文 Drift Schema 是迁移目标而非当前实现。配置/模式 SDK 接口已暴露，但远端历史与配置业务接入尚未完成。

NAS SQLite 由单一 Riverpod repository provider 初始化，播放器与索引服务不得各自
创建并迁移同一数据库文件；写事务仍通过全局串行队列执行。

本轮共享接续使用 `agentContexts[agentId]` 保存独立远端 ID 和文本同步位置，旧单 ID 只作为原 Agent 的兼容数据。审批结果必须采用 ACP v1 嵌套 outcome，SDK 1.0.0 的扁平序列化在边界做兼容修正。下载通道、旧数据归属及验证状态见 [最新接口交接](../handoffs/2026-09-18-agent-sharing-downloads.md)。

| 文档版本 | 发布日期 | 核心协议 |
| :--- | :--- | :--- |
| v1.0.0 | 2026-09-13 | SSHv2, SFTP v3, ACP (Agent Client Protocol), JSON-RPC 2.0, Docker CLI |

---

## 1. SSH & SFTP 通信规范

### 1.1 SSH 客户端配置与连接通道
基于 `dartssh2` 纯 Dart 实现建立安全信道：

```dart
final client = SSHClient(
  await SSHSocket.connect(host, port, timeout: Duration(seconds: 10)),
  username: username,
  onPasswordRequest: () => storedPassword,
  identities: [
    ...parsePrivateKey(privateKeyPem, passphrase: passphrase),
  ],
  onVerifyHostKey: (type, fingerprint) async {
    return await verifyKnownHostKey(host, port, type, fingerprint);
  },
  keepAliveInterval: Duration(seconds: 15),
);
```

### 1.2 PTY 终端仿真参数
终端 Shell 通道打开规范：

| 参数项 | 标准设定值 | 说明 |
| :--- | :--- | :--- |
| `term` | `xterm-256color` | 声明 256 色终端能力 |
| `width` / `height` | 动态由 `xterm.dart` 视图大小计算 | 随视图 Resize 事件实时发送 `session.resizeTerminal(cols, rows)` |
| `pixelWidth` / `pixelHeight` | `0, 0` | 忽略像素级大小 |

### 1.3 SFTP v3 文件传输操作映射
* 文件浏览：`client.sftp().listdir(path)`
* 文件下载：`client.sftp().open(remotePath, mode: SftpFileOpenMode.read)` -> 流式分块（64KB Chunk）写入本地。
* 文件上传：`client.sftp().open(remotePath, mode: SftpFileOpenMode.write | SftpFileOpenMode.create)` -> 本地 Stream 灌入。
* 状态查询：`client.sftp().stat(path)` 读取文件大小、修改时间与权限位。

---

## 2. ACP (Agent Client Protocol) over SSH 规范

### 2.1 物理信道桥接模型
通过 SSH Session 直接拉起目标 Agent 的 ACP 进程，将 `stdout` 与 `stdin` 绑定为 Dart `StreamChannel<String>`：

```text
Flutter App (acpd Client)
      │  ndjson / JSON-RPC 2.0
      ▼
StreamChannel<String> (utf8.decoder / utf8.encoder)
      │
SSH Exec Channel (dartssh2)
      │  encrypted SSH payload
      ▼
Linux Host -> bash -l -c "claude-code-acp"
```

### 2.2 核心 JSON-RPC 请求规范

#### 1. `initialize` (协议握手)
```json
// Client -> Agent
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "1.0",
    "clientInfo": { "name": "Valhalla-Client", "version": "1.0.0" },
    "capabilities": {
      "roots": true,
      "sampling": false
    }
  }
}
```

#### 2. `session/new` (创建会话)
```json
// Client -> Agent
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "session/new",
  "params": {
    "cwd": "/data/projects/my-app",
    "options": {
      "model": "claude-3-7-sonnet",
      "mode": "code"
    }
  }
}
```

#### 3. `session/prompt` (发送消息与流式响应)
```json
// Client -> Agent
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "session/prompt",
  "params": {
    "sessionId": "sess_01JHGK...",
    "prompt": "帮我检查当前 Docker 运行状态"
  }
}
```

#### 4. `session/resume` 与 `session/list` (会话恢复与列表)
```json
// Client -> Agent (列出会话)
{ "jsonrpc": "2.0", "id": 4, "method": "session/list" }

// Client -> Agent (恢复会话)
{ "jsonrpc": "2.0", "id": 5, "method": "session/resume", "params": { "sessionId": "sess_01JHGK..." } }
```

### 2.3 关键双向通知与权限事件

#### 1. `session/update` (Agent 增量内容输出)
```json
// Agent -> Client (Notification)
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "sess_01JHGK...",
    "update": {
      "type": "content_block_delta",
      "delta": { "type": "text_delta", "text": "我正在检查 Docker 进程..." }
    }
  }
}
```

#### 2. `permission/request` (Agent 请求执行权限)
```json
// Agent -> Client (Bidirectional Request)
{
  "jsonrpc": "2.0",
  "id": "perm_01",
  "method": "permission/request",
  "params": {
    "sessionId": "sess_01JHGK...",
    "toolName": "Bash",
    "description": "执行容器重启命令",
    "command": "docker restart nginx"
  }
}

// Client -> Agent (Response)
{
  "jsonrpc": "2.0",
  "id": "perm_01",
  "result": {
    "decision": "allow_once" // 或 "allow_always", "deny"
  }
}
```

---

## 3. Docker 远程管理数据接口规范

### 3.1 容器查询规范
* 执行指令：
  ```bash
  docker ps -a --no-trunc --format '{"id":"{{.ID}}","names":"{{.Names}}","image":"{{.Image}}","status":"{{.Status}}","state":"{{.State}}","ports":"{{.Ports}}","created":"{{.CreatedAt}}"}'
  ```
* 转换 Model：
  ```dart
  class ContainerModel {
    final String id;
    final String name;
    final String image;
    final String status;
    final String state; // running, exited, paused
    final String ports;
    final DateTime createdAt;
  }
  ```

---

## 4. 本地数据库 (Drift SQLite) 数据表规范

```sql
-- 1. 服务器配置表 (不含密码和私钥明文)
CREATE TABLE servers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    host TEXT NOT NULL,
    port INTEGER NOT NULL DEFAULT 22,
    username TEXT NOT NULL,
    auth_type TEXT NOT NULL, -- 'password', 'key', 'interactive'
    key_storage_id TEXT,     -- 关联 secure storage key
    group_name TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- 2. Known Host Keys 表 (防中间人攻击)
CREATE TABLE known_host_keys (
    id TEXT PRIMARY KEY,
    server_id TEXT NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    host TEXT NOT NULL,
    port INTEGER NOT NULL,
    key_type TEXT NOT NULL,
    fingerprint_sha256 TEXT NOT NULL,
    trusted INTEGER NOT NULL DEFAULT 1,
    first_seen INTEGER NOT NULL
);

-- 3. 快捷命令表
CREATE TABLE quick_commands (
    id TEXT PRIMARY KEY,
    server_id TEXT, -- NULL 代表全局通用
    category TEXT NOT NULL,
    title TEXT NOT NULL,
    command TEXT NOT NULL,
    description TEXT,
    requires_sudo INTEGER NOT NULL DEFAULT 0,
    is_dangerous INTEGER NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 0
);

-- 4. 会话元数据缓存表 (用于离线秒开，真实状态以 Agent 为准)
CREATE TABLE session_cache (
    session_id TEXT PRIMARY KEY,
    server_id TEXT NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    agent_id TEXT NOT NULL,
    title TEXT NOT NULL,
    cwd TEXT,
    model TEXT,
    updated_at INTEGER NOT NULL
);
```

---

## 5. 安全存储 (Secure Storage) 键位映射规则

敏感凭证统一以结构化 Key 写入平台安全存储库（Keystore/Keychain）：

* SSH 密码：`valhalla_server_{serverId}_password`
* SSH 私钥明文：`valhalla_server_{serverId}_private_key`
* SSH 私钥 Passphrase：`valhalla_server_{serverId}_passphrase`
* Sudo 提权预存密码：`valhalla_server_{serverId}_sudo_password`

## 当前实现：容器终端与 CLI 草稿目录

- `LocalStorageService.getContainerShell/setContainerShell` 以服务器 ID 和容器名称保存非敏感 Bash/Sh 偏好；缺键默认 Bash，不改变旧数据。
- `DockerCliService.openTerminal` 先非交互探测所选 Shell，再返回独立 PTY 的 `bridge` 与实际 `shell`。Bash 探测失败才尝试 Sh；显式 Sh 不探测 Bash。两个都不可用时抛错，不启动终端，也不改变容器状态。
- `CliChatState.cwd` 只表示历史列表筛选目录，`draftCwd` 只表示未发送草稿的工作目录；`createDraft()` 清空 `draftCwd`，Codex/OpenCode 首次发送将其传给远端新建会话。已存在会话使用自身保存的 `cwd`。
- `systemHardwareProvider` 仅在当前服务器连接时按需取一次硬件快照，字段缺失可为 `null`；切换服务器或连接状态变化使快照失效。此快照不替代实时资源指标。

## 当前实现：会话运行配置与 NAS 索引

- `ChatRunSettings` 包含可空的 `modelId`、`reasoningId` 和默认
  `askEveryTime` 的权限策略。ACP 配置保存在 `ChatSession.agentRunSettings`
  并按 Agent 隔离；CLI 原生会话以 `serverId::agentId::sessionId` 保存，草稿
  使用 `draft` 键，同时维护 `serverId::agentId` 默认值。
- ACP 仅映射 Agent 声明的 `model`、`model_config`、`thought_level`；Codex
  映射 `model/list` 与 `turn/start`；OpenCode 映射 `/provider` 和原生审批接口。
  能力查询失败不阻断聊天，回退到 Agent 默认值。
- `NasScanService` 对绝对路径进行规范化和 Shell 引号处理，使用 NUL 分隔的
  GNU `find -printf` 输出，解析为 `NasMediaItem`。服务器必须支持 GNU find；
  不满足时返回 `NAS_SCAN_FAILED`，不尝试自动安装。
- `NasIndexRepository` 的唯一键为 `(server_id, path)`；成功扫描在事务中替换
  当前服务器索引，失败与取消不提交。查询支持服务器、媒体类型、名称、分页，
  通过后台 isolate 访问应用支持目录中的 `valhalla_nas.sqlite3`。
- NAS 媒体打开复用 SFTP 传输队列。图片缩略源文件最大 20 MiB，缓存键包含
  服务器、路径与修改时间；超限或解码失败由界面显示类型占位图。
# 2026-10-03 ACP 认证与中断状态补充

`ChatTurnStatus.awaitingAuthentication` 表示远端实际认证请求，不能显示为用户
停止（`interrupted`）。新状态沿用 JSON 名称解析，不改库表、不批量重写旧记录。
initialize/CLI 安装不是 ACP 登录证明；只有实际 authenticate RPC、会话建立或
prompt RPC 成功后，才清理当前 adapter/agent/server 匹配的旧认证挑战及单一
`ACP_AUTH_REQUIRED` 错误，不能清除无关错误。再次认证失败撤回确认。
用户明确重试时复用待认证的空助手消息，并重置 streaming；完成后 completed，
不自动重发、不创建替代远端会话、不复制 CLI token。未知检测不算未登录。
# 2026-10-03 恢复与授权增量接口

- `AgentRegistryNotifier.refresh` 按环境 epoch 合并，单 Agent 检测去重；每批最多两个，结果逐个发布。连接层挂载 Registry，Registry 负责已连接初态与后续重连。旧环境/旧配置结果不得回写。
- 已保存 AgY OAuth 凭据通过独立 `probeAgySavedAuth` 执行官方 initialize/authenticate 复验，20 秒上限。新授权链接或 auth-required 即结束并标记需登录，网络故障保留待验证状态，不弹浏览器、不建会话、不复制令牌。
- `AgyModelCatalog.query/parse`：在 profile 指定宿主机或容器用户内执行 `agy models`，20 秒限时、256 KiB 输出上限，保留 Gemini 完整 ID。目录不声明账号授权，实际选择由 ACP 校验。
- `AcpOAuthLoopback.bind` 接受可选展示 renderer，由应用层注入；回调成功需远端交付及官方认证完成。`valhalla://oauth-return` 仅导航，不能设置认证状态，不接收 code/state/token。监听失败不可发布浏览器启动请求。
- 下载使用独立 SFTP 子通道，目录超时不能销毁下载通道；已知长度提前 EOF 为不完整。原任务临时文件只在成功后提交，网络错误单次重试，不跨服务器恢复。

本轮实现与实际验收状态见 `agent-workflow/2026-10-03-recovery-auth-download.md`，未验证不能视为交付完成。
