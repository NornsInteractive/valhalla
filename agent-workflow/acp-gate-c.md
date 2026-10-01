# ACP 验收批次 C — 全量门禁报告

- 模型：`opencode/mimo-v2.6-flash-free`
- 日期：2026-09-30
- 仓库状态：工作区含其他 agent 未提交改动（新 `test/infrastructure/acp_client_features_test.dart`、`fake_acp_transport` 改动、业务格式化/lint），本轮为初轮全量，最终将重跑。

## 执行命令

| 步骤 | 命令 | 退出码 |
| --- | --- | --- |
| 1 | `flutter gen-l10n` | 0 |
| 2 | `flutter test --no-pub --reporter expanded` | 0 |

- 全量日志：`agent-workflow/acp-full-tests.log`（1242 行；收尾行 1241 `01:06 +1188 ~17: All tests passed!`，行 1242 `EXIT=0`）
- 运行时长：约 1 分 06 秒

## 精确结果

| 指标 | 数量 |
| --- | --- |
| 通过 (passed, `+`) | **1188** |
| 失败 (failed, `-`) | **0** |
| 跳过 (skipped, `~`) | **17** |
| 执行合计 (passed + skipped) | 1205 |

**失败文件行号：无（0 失败，日志中无 `[E]` / `Expected:` / `Actual:` / `Some tests failed`）。**

日志收尾计数行：

```
01:06 +1188 ~17: All tests passed!
```

## 17 条跳过明细（均为既有条件跳过，非本轮新增）

| 数量 | 文件 | 跳过原因 | 日志行号 |
| --- | --- | --- | --- |
| 7 | `test/infrastructure/app_operations_vm_test.dart` | `Set VALHALLA_OPERATIONS_VM_CREDENTIALS for the disposable VM` | 433, 436, 439, 442, 445, 448, 451 |
| 8 | `test/infrastructure/nas_install_vm_test.dart` | 1× `Requires the explicit existing device WebDAV fixture port.`；7× `Requires explicit disposable VM credentials; never runs on user servers.` | 504；507, 510, 513, 516, 519, 522, 525 |
| 1 | `test/infrastructure/ssh_sftp_vm_test.dart` | `Requires the disposable VM fixture` | 600 |
| 1 | `test/infrastructure/server_power_vm_test.dart` | `Requires separate VALHALLA_VM_POWER_TEST=1 and isolated VM credentials` | 716 |

全部 17 条跳过原因均为环境/凭据类前置条件（一次性 VM、WebDAV 端口、专用凭据），与本轮异步 SQLite 变更无关。
文件归属由源码中的skip条件校正；并发reporter当时显示的运行中文件前缀不代表该skip的所属文件。

## 本轮文件改动（仅 2 个测试文件，删除未用 import）

| 文件 | 改动 |
| --- | --- |
| `test/core/ai_chat_provider_test.dart` | 删除未用 `dart:io`、`package:valhalla/data/repositories/chat_repository.dart` 两个 import |
| `test/support/temp_chat_db.dart` | 删除未用 `package:flutter_riverpod/flutter_riverpod.dart`、`package:valhalla/data/storage/local_storage_service.dart` 两个 import |

验证：

- `dart format` 上述 2 文件 → `Formatted 2 files (0 changed)`
- `flutter analyze --no-pub test/core/ai_chat_provider_test.dart test/support/temp_chat_db.dart` → `No issues found!`（退出码 0）

## 边界遵守

- 未修改 `lib/` 业务代码与 UI；未修改他人持有的新 features/adapter/provider/repository 测试。
- 未删除任何断言，未新增 `skip`；`fake_acp_transport`、features 测试交由对应 agent。
- 未安装依赖、未构建、未做真实 ACP 连接；未重跑全量（import 删除仅由 analyze 校验，全量以最终重跑为准）。
