# ACP 验收批次 A（Gate A）

- 模型：`opencode/mimo-v2.6-flash-free`
- 执行时间：2026-09-30 17:38 – 17:46（CST）
- 范围：仅 5 个 ACP 业务文件的格式化 + 纯 lint（花括号 / 多下划线）修复；l10n 生成；analyze；4 个指定核心测试
- 未做：未新增任何测试用例、未扫描其他需求、未改 UI/ARB、未构建

## 1. 受影响文件（5 个，全部在范围内）

| 文件 | 行数（改后） | `dart format` | lint 修复 |
|---|---|---|---|
| `lib/core/providers/ai_chat_provider.dart` | 2391 | 有改动 | 37 + 1 |
| `lib/data/repositories/chat_repository.dart` | 514 | 有改动 | 5 + 1 |
| `lib/data/models/chat_session.dart` | 491 | 有改动 | 0 |
| `lib/infrastructure/acp/acp_client_adapter.dart` | 868 | 已合规 | 5 |
| `lib/infrastructure/acp/acp_ssh_transport.dart` | 99 | 有改动 | 0 |

- 格式化校验：`dart format --output=none --set-exit-if-changed <5 files>` → `exit=0`，`Formatted 5 files (0 changed)`（17:45:58 复验）。

## 2. lint 修复明细（共 49 项，全部纯 lint，0 语义改动）

### 2.1 基线 `flutter analyze --no-pub` 中在范围内的原始行号（修复前，63 issues）

- `lib/core/providers/ai_chat_provider.dart`
  - `unnecessary_brace_in_string_interps`：**303:8**
  - `curly_braces_in_flow_control_structures`：**334:7, 342:7, 350:7, 371:7, 391:7, 739:9, 956:9, 998:13, 1021:9, 1063:9, 1088:7, 1094:7, 1097:7, 1160:13, 1172:19, 1224:15, 1226:15, 1275:9, 1283:9, 1303:9, 1305:9, 1314:9, 1319:9, 1356:7, 1505:7, 1519:7, 1539:7, 1630:50, 1812:15, 1873:13**（30 项）
- `lib/data/repositories/chat_repository.dart`：`unnecessary_underscores` **76:70**（1 项，手工修复：`StackTrace __` → `StackTrace _`，现位于 `chat_repository.dart:115`）
- `lib/infrastructure/acp/acp_client_adapter.dart`：`curly_braces_in_flow_control_structures` **278:7, 496:7, 504:7, 517:7, 675:13**（5 项）

### 2.2 格式化后新暴露、同批一并修复的 12 项（原为单行 `if`，`dart format` 拆行后触发）

- `lib/core/providers/ai_chat_provider.dart`：**368:7, 374:7, 382:7, 977:7, 2293:7, 2341:7, 2344:9**（7 项）
- `lib/data/repositories/chat_repository.dart`：**85:13, 92:13, 373:7, 453:13, 468:9**（5 项）

### 2.3 修复方式

- `dart fix --apply --code=curly_braces_in_flow_control_structures`（35 + 12 = 47 项，仅命中上述 2 个在范围内文件）
- `dart fix --apply --code=unnecessary_brace_in_string_interps`（1 项，仅 `ai_chat_provider.dart`）
- 手工 1 项：`chat_repository.dart:76` 多下划线
- 随后对 5 个文件重跑 `dart format`

### 2.4 语义等价证明

以批次开始时的 5 份文件快照为基线做归一化比对（去空白、去新增 `{}`、去尾随逗号、`_` 连写折叠为单个 `_`）：

```
lib/core/providers/ai_chat_provider.dart      SEMANTIC-EQUIVALENT
lib/data/repositories/chat_repository.dart    SEMANTIC-EQUIVALENT
lib/data/models/chat_session.dart             SEMANTIC-EQUIVALENT
lib/infrastructure/acp/acp_client_adapter.dart SEMANTIC-EQUIVALENT
lib/infrastructure/acp/acp_ssh_transport.dart  SEMANTIC-EQUIVALENT
```

即 5 个文件与批次前的差异**仅**为格式化换行/缩进、补花括号、尾随逗号、多下划线折叠，无任何业务语义变化。

## 3. l10n 生成

- 命令：`flutter gen-l10n`（`l10n.yaml` 生效）→ 成功
- 重新生成：`lib/l10n/app_localizations.dart`、`app_localizations_en.dart`、`app_localizations_zh.dart`
- **未改 ARB**：`lib/l10n/app_en.arb`（mtime 17:35:37）、`lib/l10n/app_zh.arb`（mtime 17:37:12）均早于本次 `gen-l10n`（17:38:22），本批次未写入 ARB
- 效果：修复了基线中的 5 个 `undefined_getter` error（`rename`/`sessionTitle`/`refresh`）

## 4. `flutter analyze --no-pub`

- 基线：`exit=1`，**63 issues = 5 error + 7 warning + 51 info**（其中在范围内 37 项，见 §2.1）
- 终态（17:44:59 运行）：`exit=1`，**14 issues = 0 error + 0 warning + 14 info**，错误数 0
- **在范围内的 5 个文件 issue 数：0**（`grep` 范围文件命中 0 行）
- `exit=1` 仅因仍有 info 级告警，全部在范围外文件 `lib/features/chat/ai_chat_view.dart`（本批次禁止改 UI）：

| 行号 | 规则 |
|---|---|
| `lib/features/chat/ai_chat_view.dart:551:30` | `use_build_context_synchronously` |
| `lib/features/chat/ai_chat_view.dart:552:34` | `use_build_context_synchronously` |
| `lib/features/chat/ai_chat_view.dart:557:28` | `use_build_context_synchronously` |
| `lib/features/chat/ai_chat_view.dart:559:28` | `use_build_context_synchronously` |
| `lib/features/chat/ai_chat_view.dart:560:28` | `use_build_context_synchronously` |
| `lib/features/chat/ai_chat_view.dart:2223:9` | `deprecated_member_use` (`withData`) |
| `lib/features/chat/ai_chat_view.dart:2272:9` | `deprecated_member_use` (`withData`) |
| `lib/features/chat/ai_chat_view.dart:2327:28` | `use_build_context_synchronously` |
| `lib/features/chat/ai_chat_view.dart:2329:25` | `use_build_context_synchronously` |
| `lib/features/chat/ai_chat_view.dart:2330:28` | `use_build_context_synchronously` |
| `lib/features/chat/ai_chat_view.dart:2339:28` | `use_build_context_synchronously` |
| `lib/features/chat/ai_chat_view.dart:2341:28` | `use_build_context_synchronously` |
| `lib/features/chat/ai_chat_view.dart:2342:28` | `use_build_context_synchronously` |
| `lib/features/chat/ai_chat_view.dart:3847:29` | `unnecessary_underscores` |

> 说明：基线中的 7 个 warning（`ai_chat_view.dart:27/29/31 unused_shown_name`、`test/core/ai_chat_provider_test.dart:2/16`、`test/support/temp_chat_db.dart:3/8 unused_import`）在本次终态已消失——由并发的 Gate C 会话删除测试导入、Gate B 会话改动 `ai_chat_view.dart` 所致，非本批次修改。

## 5. 核心测试（17:45:17 – 17:45:26 运行，全部由本批次执行）

| 指定测试文件 | 结果 | 通过数 | exit |
|---|---|---|---|
| `test/core/ai_chat_provider_test.dart` | PASS（`All tests passed!`） | **33** | 0 |
| `test/infrastructure/acp_adapter_test.dart` | PASS（`All tests passed!`） | **20** | 0 |
| `test/infrastructure/acp_ssh_transport_test.dart` | **文件不存在 → 无法运行** | 0 | 1 |
| `test/data/chat_repository_test.dart` | PASS（`All tests passed!`） | **18** | 0 |
| **合计（可运行的 3 个指定文件）** | **全部通过** | **71** | 0 |

### 5.1 错误：指定测试文件缺失（唯一失败项）

- 错误原文：`Failed to load ".../test/infrastructure/acp_ssh_transport_test.dart": Does not exist.`
- 该路径不存在，且 `git log --all --diff-filter=AD -- test/infrastructure/acp_ssh_transport_test.dart` 无任何历史记录（从未提交过）
- 按“不新增用例”约束，本批次**未创建**该文件
- 替代证据（唯一 import `acp_ssh_transport.dart` 的既有测试，非新增）：`test/infrastructure/acp_ssh_framing_test.dart` → **PASS，3 通过，exit=0**（17:45:58）

## 6. 并发环境备注（影响可复现性）

本批次运行期间同一工作区有并发会话在写文件，非本批次所为：

- `lib/features/chat/ai_chat_view.dart` 改动于 17:39:38（Gate 外/UI 会话）
- `test/infrastructure/acp_client_features_test.dart` 新建于 17:43:26（Gate B）
- `test/core/ai_chat_provider_test.dart` 改动于 17:44:08（Gate C 删未用导入）
- ARB 改动于 17:35:37 / 17:37:12（更早会话）

本批次 5 个范围内文件最后写入时间：`ai_chat_provider.dart`、`chat_repository.dart` 17:40:07；`chat_session.dart`、`acp_ssh_transport.dart` 17:38:13；`acp_client_adapter.dart` 17:37:57——此后无其他会话改动。

## 7. Gate A 结论

- 5 个范围内文件：格式化通过（`exit=0`）、范围内 lint 0 残留、语义等价验证通过
- l10n 已生成，ARB/UI 未改
- `flutter analyze --no-pub`：0 error、0 warning，剩余 14 条 info 全部在禁止改动的 `ai_chat_view.dart`
- 指定测试：3/3 文件通过，共 **71 通过 / 0 失败**；第 4 个指定文件 `acp_ssh_transport_test.dart` 缺失（唯一 error），以既有 `acp_ssh_framing_test.dart` 3 通过作为旁证
- 未新增用例、未扫描其他需求、未构建
