# ACP 可用性第二轮 — 生产逻辑缺陷报告（OpenCode 验证）

范围：`lib/core/providers/{ai_chat_provider,settings_provider}.dart`、
`lib/data/models/{chat_session,acp_account_info}.dart`、`lib/data/repositories/chat_repository.dart`、
`lib/data/storage/local_storage_service.dart`、
`lib/infrastructure/acp/{acp_client_adapter,acp_attachment_store,acp_workspace_files}.dart`。

只做了格式化与定向分析，未改动任何生产语义、未触碰 UI/ARB：

- `dart format <9 个指定文件>` → `Formatted 9 files (7 changed)`。
- `dart analyze <9 个指定文件>` → **0 error / 0 warning / 3 info**（`curly_braces_in_flow_control_structures`
  于 `ai_chat_provider.dart:365/1458/2180`；这三处随后已被主 Agent 修掉，复查为 `No issues found!`）。

行号基于工作区当前内容（主 Agent 与 AgY 在并行改动，文件 mtime 见各条）。

---

## P0 · 阻断整个测试集（跨 Agent 契约缺口）—— **已解决**

### P0-1 UI 读取 `AcpPromptAttachment.sizeBytes`，但该字段不存在（19:25 由 AgY 修复）

- `lib/features/chat/ai_chat_view.dart`（附件卡片 `_formatBytes(att.sizeBytes)`，AgY 仍在编辑，
  19:25 时位于第 3381 行）—— 引用了不存在的 `sizeBytes`。
- `lib/infrastructure/acp/acp_client_adapter.dart:105-121` — `AcpPromptAttachment`
  只有 `name / mimeType / bytes / uri / localPath`，**没有 `sizeBytes`**。

后果：任何传递 import `ai_chat_view.dart` 的测试都无法编译。
已实测失败：

```
flutter test test/core/auto_connect_boot_test.dart
  → lib/features/chat/ai_chat_view.dart:3381:56: Error: The getter 'sizeBytes'
    isn't defined for the type 'AcpPromptAttachment'.
```

两个修法二选一（不要两边都改）：
1. **主 Agent**（`acp_client_adapter.dart`，本轮属于主 Agent 文件）加只读派生字段
   `int get sizeBytes => bytes.length;` —— 纯增量、不改语义；
2. **AgY** 把 `att.sizeBytes` 改成 `att.bytes.length`。

19:25 复查：`lib/features/chat/ai_chat_view.dart:3381` 已改为 `_formatBytes(att.bytes.length)`，
`AcpPromptAttachment` 保持不变（未新增字段），符合「不改生产语义」的约束；
`test/core` / `test/features` 已可正常编译运行。

### P0-2 生成代码曾落后于 ARB（已按授权生成一次）

`flutter gen-l10n` 之前 `lib/l10n/app_localizations*.dart` 缺少 AgY 新增的
`chatAccountAndQuotaTitle`、`chatAttachmentMissing`、`chatAccount*` 等键，导致 provider 测试无法编译。
两个 ARB 均可正常解析且键数一致（各 1032），已按授权执行 **一次** `flutter gen-l10n`
（`exit=0`，新增 474 + 244 + 240 行）。ARB 本身未被修改。

---

## P1 · 本轮已由主 Agent 修复（回归测试已锁住行为）

以下缺陷在报告后被主 Agent 修复，当前代码已正确；对应行为已有回归测试，
**请勿回退**：

| 原缺陷 | 现位置 | 现状 | 锁定测试 |
|--------|--------|------|----------|
| `/status` 被「既往对话上下文」包裹，agent 不识别为命令 | `ai_chat_provider.dart:2337` | `pendingHistory.isEmpty \|\| text.trimLeft().startsWith('/')` 时不注入历史；:2357 同步修正 `syncedMessageCount` | `ai_chat_usability_test.dart`「已声明 status 时发送 /status 并记录原文与获取时间」 |
| 刷新失败用旧快照整体回滚 state，吞掉并发更新 | `ai_chat_provider.dart:797-813` | 只回填 `runSettings/capabilities/commands/account` 四个字段，不再整体替换；并补了 `else` 分支清理新 adapter | — |
| `findRemoteSession` 不等待已入队写，可能重复导入 | `chat_repository.dart:301` | 已补 `await _writes;` | `ai_chat_usability_test.dart`「没有新副本时重复导入复用同一条本地记录」 |
| 损坏 base64 图片抛 `FormatException`（非稳定错误码） | `acp_attachment_store.dart:64-69` | 翻译为 `StateError('ACP_ATTACHMENT_CORRUPT')` | `acp_attachment_store_test.dart`「损坏的 base64 图片抛稳定的 ACP_ATTACHMENT_CORRUPT」 |
| 单个坏附件导致整段历史导入失败 | `ai_chat_provider.dart:1436-1451` | per-block catch，坏块降级为占位附件，其余消息照常导入 | 附件店测试 + 导入测试（副本/失败用例） |
| `remoteImagePreview` 取消后抛错而非丢弃迟到响应 | `ai_chat_provider.dart:377-381` | 取消态下 read 失败返回 `null`，其余错误照抛 | `acp_workspace_files_test.dart`「close 之后所有读取立即以 ACP_FILE_READ_CANCELLED 失败」 |
| `ChatAttachment.fromJson` 必填字段硬转，一处坏数据毁掉整段历史 | `chat_session.dart:245` | 改为 `is num` 判定 + 兜底 | `chat_message_contract_test.dart`（旧 JSON 兼容用例） |
| 附件大小限额在建立远端会话之后才校验 | `acp_client_adapter.dart:468-477` | 大小校验已前移到 `_ensureSession()` 之前 | `acp_usability_adapter_test.dart`「图片能力未声明时拒绝图片附件」（**能力**校验仍在会话之后，见 P3-5） |

---

## P2 · 仍然开放（需主 Agent 处理）

### P2-1 草稿刷新后设置仍显示「过期 / 无获取时间」—— **已修复（19:28）**

- 原状：草稿分支（`initializeOnly`）只写 `account / agentVersion / 能力`，
  没写 `settingsFetchedAt`，也没把 `settingsStale` 置回 `false`；
  而 `ACPSettingsChangedEvent` 只在 `_prepareSession()` 成功后触发，草稿永远走不到。
- 现状：`ai_chat_provider.dart:907-911` 已补
  `settingsFetchedAt: refresh || state.settingsFetchedAt == null ? DateTime.now() : state.settingsFetchedAt`
  与 `settingsStale: false`。回归测试见
  `ai_chat_usability_test.dart`「草稿刷新后写入获取时间并清除过期标记」。

回归测试：`ai_chat_usability_test.dart`「草稿刷新后写入获取时间并清除过期标记」。

### P2-2 启动页没有跟着默认导航一起迁移

- `local_storage_service.dart:616-624` — `getBottomNavigationSections()` 对旧默认值
  `dashboard,cliChat,docker,files` 做读时迁移为 `aiChat`。
- `local_storage_service.dart:631` — `getStartupSection()` 原样返回，未迁移。

后果：从未自定义过的老用户，底部导航已是 ACP，但冷启动仍直接进入 CLI 会话页
（`settings_provider.dart:203-205` → `AppSection.cliChat`），
「默认导航以 ACP 替换 CLI」只落地了一半。

建议修法：`getStartupSection()` 同样做读时迁移（仅当存储值为 `cliChat` 且迁移标志未置位时改为 `aiChat`）。
注意现有测试 `settings_persistence_test.dart:93-110` 断言「显式保存 cliChat 后回读仍是 cliChat」，
迁移必须只覆盖读时且不写回，改完请保持该断言成立。

### P2-3 `ChatLaunchMode.fixed` 指向的会话被删除后静默降级

- `ai_chat_provider.dart:1093-1099` — `fixed` 模式的 candidate 不存在时，
  直接回落到 `current` / `sessions.firstOrNull`，只有 `blankDraft` 才有「无会话」语义。

后果：用户钉住的会话被删除后，界面静默打开另一个会话，没有任何提示。

---

## P3 · 稳健性 / 一致性（低）

| # | 位置 | 问题 |
|---|------|------|
| P3-1 | `ai_chat_provider.dart:536` | `await file.length()` 对缺失/不可读文件抛原始 `FileSystemException`，UI 无法映射 ARB 码；:539 `openRead(0, limit + 1)` 在并发写入时可能超限且不复查长度。 |
| P3-2 | `acp_client_adapter.dart:478-483` | **能力**校验（`ACP_ATTACHMENT_UNSUPPORTED`）仍在 `_ensureSession()` 之后：给不支持图片的 agent 发图片会先建出一个空远端会话再报错。大小限额已前移，能力校验也应一并前移。 |
| P3-3 | `acp_client_adapter.dart:402` / `:429` | 既不支持 load 也不支持 resume 的 agent，每次刷新会重复发两次 `session/resume` 才抛 `ACP_SESSION_RESTART_REQUIRED`。 |
| P3-4 | `local_storage_service.dart:690` | `getAcpSessionId()` 只写不读：生产代码没有任何读取方（`ai_chat_provider.dart:640` 只用本地会话的 `agentContexts`）。本地库丢失时「断线不丢上下文」的兜底实际不生效；要么接上，要么删掉避免误解。 |
| P3-5 | `acp_account_info.dart:22-27` | `account['email'] == ''` 被当作有效值存下（空串而非 null），UI 会出现「有字段但为空」的不一致行。 |
| P3-6 | `chat_session.dart:279-307` / `:430-467` | `copyWith` 全用 `??`，不存在「显式清空可选字段」的语义。当前无调用方依赖清空，但 `copyWith(agentId: null)` 会静默保留旧值，属易踩的坑。 |
| P3-7 | `ai_chat_provider.dart:1496` | 重新导入回放期间仍调用 `_handleControlEvent(event, adapter!)`，因 `_currentAdapter != adapter` 而全部丢弃（符合预期）。依赖 `:1334` 的 `_resetAdapter()` 已先执行，建议加注释避免后续误删。 |
| P3-8 | `chat_session.dart:526-528` | `toJson()` 不再写 `agentType`，旧记录重新落盘后 `agentType` 恒为 null。`agentId` 迁移表已覆盖，属**有意为之**，仅记录以免误判为回归。 |
| P3-9 | `local_storage_service.dart:616-624` | 迁移只匹配**恰好**等于旧默认的列表；用户自定义过顺序（仍含 `cliChat`）的会保留 CLI 入口。与「自定义保留」一致，仅记录。 |

---

## 与交接契约逐条核对结论（当前代码状态）

| 契约项 | 实现位置 | 结论 |
|--------|----------|------|
| `AcpAccountInfo? account` + `kind/label/email/plan/updatedAt` | `ai_chat_provider.dart:71`、`acp_account_info.dart` | ✅ |
| 账号推送需 agent 声明 `_meta.authStatus` | `acp_client_adapter.dart:247` | ✅（已按 gating 实现，AgY 须按「未声明即未提供」实现降级） |
| `accountStatusText` / `accountStatusFetchedAt` 只读渲染 | `ai_chat_provider.dart:75/73`、`406-409` | ✅（P1 已修复斜杠前缀问题） |
| `queryAccountStatus()` 不偷建会话 | `ai_chat_provider.dart:391-397` | ✅（无会话 / 忙碌 / 有附件 / 无 `status` 命令均抛 `ACP_STATUS_QUERY_UNAVAILABLE`，且不发任何请求） |
| `isSkill` / `insertion` | `acp_client_adapter.dart:128-130` | ✅ |
| 草稿仅 initialize，不 session/new | `acp_client_adapter.dart:255`、`ai_chat_provider.dart:902-916` | ✅（含获取时间与过期标记） |
| 附件字段 + 旧 JSON 兼容 | `chat_session.dart:219-248` | ✅ |
| `resolveWorkspaceDirectory` 真实绝对路径 | `ai_chat_provider.dart:332-346` | ✅ |
| `listWorkspaceFiles` → `List<SftpFileItem>` | `ai_chat_provider.dart:348-358`、`acp_workspace_files.dart:94-152` | ✅（根目录不列 `.`/`..`，10k 上限，NUL 字段保真） |
| `attachRemoteFile` 有界读取 | `ai_chat_provider.dart:549-578`、`acp_workspace_files.dart:154-178` | ✅ |
| `remoteImagePreview` + 取消 | `ai_chat_provider.dart:360-393` | ✅ |
| `openRemoteSession(reimport: true)` 出副本 | `ai_chat_provider.dart:1349`（`local = null` → 新 uuid） | ✅ 不覆盖原记录 |
| 默认导航 ACP 化 | `local_storage_service.dart:616-624` | ⚠️ 底栏已迁移，启动页未迁移（P2-2） |

---

## 验证记录（OpenCode，2026-09-30）

### STEP1 格式化 / 定向分析（仅限指定文件）

```
dart format lib/core/providers/ai_chat_provider.dart lib/core/providers/settings_provider.dart \
  lib/data/models/chat_session.dart lib/data/models/acp_account_info.dart \
  lib/data/repositories/chat_repository.dart lib/data/storage/local_storage_service.dart \
  lib/infrastructure/acp/acp_client_adapter.dart lib/infrastructure/acp/acp_attachment_store.dart \
  lib/infrastructure/acp/acp_workspace_files.dart
→ 首轮：Formatted 9 files (7 changed in 0.10 seconds)
→ 末轮（主 Agent 改完后复核）：Formatted 9 files (2 changed in 0.14 seconds)

dart analyze <同上 9 个文件>
→ 首轮：3 issues（curly_braces_in_flow_control_structures @ ai_chat_provider.dart:365/1458/2180）
→ 末轮：No issues found!
```

未触碰任何 UI/ARB 语义，未执行 build/install/git 操作。

### STEP2 l10n 生成（按授权，仅一次）

```
python3 -c "json.load(app_en.arb / app_zh.arb)"  → 两者均可解析，各 1032 个键
flutter gen-l10n                              → exit=0
  lib/l10n/app_localizations.dart  +474 行
  lib/l10n/app_localizations_en.dart +244 行
  lib/l10n/app_localizations_zh.dart +240 行
```
生成原因：AgY 新增的 `chatAccount*` / `chatAccountAndQuotaTitle` / `chatAttachmentMissing`
在 ARB 中存在但生成类缺失，导致任何传递 import `ai_chat_view.dart` 的测试编译失败。
ARB 文件本身未被本轮修改。

### STEP2 新增 / 更新的回归测试

新增（5 个文件，54 个用例）：

| 文件 | 覆盖 |
|------|------|
| `test/data/chat_message_contract_test.dart` | 消息 ID / 角色 / 附件往返、无 ID 旧回放、system 中性降级、旧 JSON 缺字段、多 Agent `agentContexts`、`AcpAccountInfo` 解析、`AcpSlashCommand.insertion` |
| `test/infrastructure/acp_usability_adapter_test.dart` | `initializeOnly` 不建会话、并发共享、能力解析、dispose 后失败、`_auth/status_update` 三态 gating、`session/load` 按 (role, messageId) 分片 / 无 ID 按角色切分 / 附件事件 / 非回放模式忽略正文、命令与技能前缀、附件能力校验 |
| `test/infrastructure/acp_attachment_store_test.dart` | 真实临时文件写入、sha256 内容寻址向量、复用、限额（文本 1MB / 图片 20MB / 边界等值）、`.part` 不残留、内联文本/二进制/资源链接/未知块、损坏 base64 |
| `test/infrastructure/acp_workspace_files_test.dart` | `normalize` 边界（相对路径、NUL、换行、`..` 折叠）、MIME 判定与伪装绕过、docker 目标 NUL 字段解析与排序、根目录不列 `.`/`..`、特殊字符 shell 引号、残缺记录、读取限额与失败码、close 后取消语义 |
| `test/core/acp_navigation_and_preferences_test.dart` | 默认导航读时迁移 `cliChat→aiChat`、显式自定义与空列表保留、迁移标志、迁移不改写原始备份、ACP 启动偏好与上次会话按服务器/Agent/模式隔离 |
| `test/core/ai_chat_usability_test.dart` | 草稿 `prepareRunSettings` 不建会话不落盘、草稿能力/账号/获取时间、未连接错误码、切换 Agent 清空账号、`queryAccountStatus` 三种拒绝路径与原文记录、草稿保留、远端历史首次导入 / reimport 副本 / 重复导入复用 / 导入失败留痕 / 目标不匹配拒绝、重连走 load、远端会话 id 按服务器隔离 |

更新（2 个文件，因「有意变更的契约」而改，非削弱断言）：

| 文件 | 变更 |
|------|------|
| `test/features/settings_navigation_test.dart` | 默认底栏条目由 `cliChat` 改为 `aiChat`，并**新增** `cliChat findsNothing` 反向断言 |
| `test/features/ai_chat_session_isolation_test.dart` | 删除入口移入「更多」菜单后，用例先点 `session_more_menu_*` 再点 `delete_session_*`；确认弹窗与删除回调断言全部保留 |

### 测试执行记录

```
# 定向集合（既有 ACP/provider/repository/settings + 新增）
flutter test test/core/ai_chat_provider_test.dart test/core/ai_chat_usability_test.dart \
  test/core/acp_navigation_and_preferences_test.dart test/core/settings_persistence_test.dart \
  test/data/models_test.dart test/data/chat_message_contract_test.dart \
  test/data/chat_repository_test.dart test/data/chat_launch_preference_test.dart \
  test/data/acp_session_storage_test.dart test/infrastructure/acp_adapter_test.dart \
  test/infrastructure/acp_client_features_test.dart test/infrastructure/acp_session_resume_test.dart \
  test/infrastructure/acp_usability_adapter_test.dart test/infrastructure/acp_attachment_store_test.dart \
  test/infrastructure/acp_workspace_files_test.dart
→ 00:05 +206: All tests passed!   （0 失败）

# 分片
flutter test test/core test/data test/infrastructure → 00:32 +846 ~17: All tests passed!
flutter test test/features                            → 修完 2 个过时用例后全绿

# 全量
flutter test → 01:02 +1269 ~17: All tests passed!   （1269 通过 / 17 跳过 / 0 失败）

# 分析（新增测试文件）
dart analyze <8 个新增/更新的测试文件> → No issues found!
```

执行过程中被本轮修复连带作废、并已按新契约更新的用例：

1. `acp_attachment_store_test.dart`「损坏的 base64 图片」：原按 `FormatException` 锁定现状，
   主 Agent 改为 `ACP_ATTACHMENT_CORRUPT` 后，改为断言稳定错误码（**加强**）。
2. `ai_chat_usability_test.dart`「草稿刷新后仍标记为过期」：原按缺陷 P2-1 锁定现状，
   主 Agent 修复后改为断言 `settingsStale == false` 且 `settingsFetchedAt != null`（**加强**）。
3. `acp_usability_adapter_test.dart`「图片能力未声明时拒绝图片附件」：大小限额已前移到建会话之前，
   能力校验仍在之后；断言保留 `newSessionCount == 1` 并注明修复后应改为 0（见 P3-2）。

### 本轮未做（按约束）

- 未运行真实 agent / SSH 会话，未读取任何凭据。
- 未执行 `git commit` / `git add` / `git push`，未做 build、install、APK/ADB 操作。
- 未修改任何 UI 语义、ARB 文案与生产代码语义。
