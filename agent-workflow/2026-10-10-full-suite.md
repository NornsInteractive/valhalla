# 2026-10-10 Full Suite Execution Report

Executor: Valhalla final whole-suite EXECUTOR (authorized verification via OpenCode only).

Current status (2026-10-10): the original failure and fixture-fix evidence below
is preserved for audit. A later complete single-concurrency run passed all 2165
executed tests, with 18 opt-in integration skips and zero failures, actual exit 0.
Whole analysis and diff check also exited 0. See
[final validation](2026-10-10-final-validation.md); the first-run red snapshot
below is not the current acceptance verdict.

---

## 1. First Run — `flutter test --reporter expanded`

Command (run unmasked, no pipe, no timeout wrapper):

```
flutter test --reporter expanded > /tmp/opencode/full_suite.log 2>&1
```

**Actual exit code: `1`** (recorded verbatim at the end of `/tmp/opencode/full_suite.log`, appended line: `ACTUAL_EXIT=1`).

### Final summary line (exact, last line of run output)

```
01:12 +2115 ~18 -46: Some tests failed.
ACTUAL_EXIT=1
```

### ACTUAL TOTAL from the final test summary

| Metric | Value |
|---|---|
| Passed | **2115** |
| Skipped (`~`) | **18** |
| Failed (`-`) | **46** |
| **Total tests run** | **2179** (2115 + 18 + 46) |
| Wall clock | ~01:12 (72 s) |
| Log size | 226 094 lines |
| Overall verdict | **NOT GREEN** (`Some tests failed.`) |

### `git diff --check` (read-only)

```
git diff --check > /tmp/opencode/diff_check.log 2>&1
```

**Actual exit code: `2`.** Exceptions reported (3 files, all trailing-EOF-newline issues, no whitespace/conflict markers):

```
docs/00-rules/01-project-engineering-rules.md:281: new blank line at EOF.
docs/01-requirements/01-prd-product-requirements.md:255: new blank line at EOF.
docs/03-development/01-detailed-design-and-modules.md:261: new blank line at EOF.
ACTUAL_EXIT=2
```

---

## 2. The 46 Failures — Exact Names, Causes, Stacks

Log line numbers below are from `/tmp/opencode/full_suite.log`. Grouped by root cause.

### 2A. `test/core/l10n_key_parity_test.dart` — 2 failures (owner: AgY, NEW)

1. **`@metadata placeholder names follow the EN template, explicit or not`** — log line 279

   ```
   Expected: Set:['count']
     Actual: Set:[]
      Which: does not contain 'count'
   zh: sftpSelectedCount @-metadata names must equal en

   package:matcher                                     expect
   package:flutter_test/src/widget_tester.dart 473:18  expect
   test/core/l10n_key_parity_test.dart 159:11          main.<fn>
   ```

2. **`no non-en catalog clones English for non-identity messages`** — log line 315

   ```
   Expected: <0>
     Actual: <1>
   fr identical to EN (non-identity): [configImportAgentsCount]

   package:matcher                                     expect
   package:flutter_test/src/widget_tester.dart 473:18  expect
   test/core/l10n_key_parity_test.dart 231:7           main.<fn>
   ```

### 2B. Settings UI — 3 failures (owner: AgY, NEW)

3. `test/features/settings_navigation_test.dart: SettingsView Navigation Settings experimental features dialog toggles CLI chat and persists` — log line 25138

   ```
   The following assertion was thrown running a test:
   RenderBox was not laid out: RenderIndexedSemantics#97d0b relayoutBoundary=up3 NEEDS-PAINT
   'package:flutter/src/rendering/box.dart':
   Failed assertion: line 2251 pos 12: 'hasSize'

   When the exception was thrown, this was the stack:
   #2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
   #3      RenderBox.paintBounds (package:flutter/src/rendering/box.dart:3108:41)
   #4      SliverMultiBoxAdaptorElement.debugVisitOnstageChildren.<anonymous closure> (package:flutter/src/widgets/sliver.dart:1276:50)
   #5      WhereIterator.moveNext (dart:_internal/iterable.dart:468:13)
   ```

   Also preceded by an aggregation: `Multiple exceptions (24) were detected during the running of the current test, and at least one was unexpected.`

4. `test/features/settings_navigation_test.dart: SettingsView Navigation Settings experimental dialog keeps CLI and NAS checkboxes independent` — log line 27327

   ```
   The following assertion was thrown running a test:
   RenderBox was not laid out: RenderIndexedSemantics#4297f relayoutBoundary=up3 NEEDS-PAINT
   'package:flutter/src/rendering/box.dart':
   Failed assertion: line 2251 pos 12: 'hasSize'

   When the exception was thrown, this was the stack:
   #2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
   #3      RenderBox.paintBounds (package:flutter/src/rendering/box.dart:3108:41)
   #4      SliverMultiBoxAdaptorElement.debugVisitOnstageChildren.<anonymous closure> (package:flutter/src/widgets/sliver.dart:1276:50)
   #5      WhereIterator.moveNext (dart:_internal/iterable.dart:468:13)
   ```

   Also: `Multiple exceptions (24) were detected ...`

5. `test/features/settings_auto_connect_test.dart: SettingsView auto connect card reads autoConnectSettingsProvider via ref.read (external provider update does not trigger rebuild)` — log line 88406

   ```
   The following TestFailure was thrown running a test:
   Expected: no matching candidates
     Actual: _TextContainingWidgetFinder:<Found 1 widget with text containing Server 1: [
               Text("Server 1 · Automatic (first available)", inherit: true, size: 11.0, dependencies:
   [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
             ]>
      Which: means one was found but none were expected

   When the exception was thrown, this was the stack:
   #4      main.<anonymous closure>.<anonymous closure> (file:///workspace/projects/valhalla/test/features/settings_auto_connect_test.dart:426:9)
   <asynchronous suspension>
   #5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
   <asynchronous suspension>
   #6      TestWidgetsFlutterBinding._runTestBody (package:flutter/src/widget_tester.dart 1059:5)
   ```

### 2C. SFTP widget tests — 41 failures (fixture-only regression, fixed by this executor)

Root cause: `SftpFileView` now watches `fileBookmarksProvider`, which watches `activeServerProvider` and reads `localStorageServiceProvider`. `lib/core/providers/storage_providers.dart:15-19` throws `UnimplementedError('LocalStorageService must be initialized before runApp')` until overridden. Old standalone SFTP harnesses only overrode `sftpProvider` / `serverConnectionProvider`, so the whole subtree failed to build.

Dominant stack:

```
══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═══════════════════════
The following ProviderException was thrown building SftpFileView(dirty, dependencies: [...], state:
_SftpFileViewState#...):
Tried to use a provider that is in error state.

A provider threw the following exception:
UnimplementedError: LocalStorageService must be initialized before runApp

The stack trace of the exception:
#0      localStorageServiceProvider.<anonymous closure>
        (package:valhalla/core/providers/storage_providers.dart:16:3)
#1      Provider.create (package:riverpod/src/providers/provider.dart:59:36)
#2      $ProviderElement.create (package:riverpod/src/providers/provider.dart:343:33)
#3      ProviderElement.buildState (package:riverpod/src/core/element.dart:743:28)
#4      ProviderElement.mount (package:riverpod/src/core/element.dart:587:7)
#5      ProviderElement.flush (package:riverpod/src/core/element.dart:699:7)
#6      $ProviderBaseImpl._addListener (package:riverpod/src/core/provider/provider.dart:119:24)
#7      ProviderElement.listen (package:riverpod/src/core/element.dart:974:28)
#8      Ref.watch (package:riverpod/src/core/ref.dart:726:20)
#9      serverRepositoryProvider.<anonymous closure>
        (package:valhalla/core/providers/storage_providers.dart:26:21)
```

Exact failing test names (41):

**`test/features/sftp_open_transfers_request_test.dart`** (3)

| # | Test name | Log line | Error |
|---|---|---|---|
| 6 | `openTransfersRequest 链路测试 3. 同一个值不会被重复响应（防重复弹出与页面重建重弹）` | 6926 | `ProviderException` → `UnimplementedError: LocalStorageService must be initialized before runApp` |
| 7 | `openTransfersRequest 链路测试 4. openTransfersRequest 为 null 时直接渲染不崩且生命周期清理正常` | 12184 | `ProviderException` → same |
| 8 | `openTransfersRequest 链路测试 5. didUpdateWidget 换绑 openTransfersRequest 时正确解绑旧通知器并监听新通知器` | 22915 | `Test failed. See exception logs above.` + `Multiple exceptions (2) were detected during the running of the current test, and at least one was unexpected.` |

**`test/features/remote_files_ui_contract_test.dart`** (12)

| # | Test name | Log line | Error |
|---|---|---|---|
| 9 | `320dp 与 2x 文字不溢出` | 33777 | `TestFailure: Expected: null / Actual: ProviderException:<... UnimplementedError: LocalStorageService must be initialized before runApp ...>` |
| 10 | `360dp 面包屑一屏可见超过两个段` | 43465 | `TestFailure: Expected: <3> / Actual: <0>` at `remote_files_ui_contract_test.dart:204:5` |
| 11 | `导航后末尾段可见` | 56228 | `The finder "Found 0 widgets with text "gmore": []" (used in a call to "getTopLeft()") could not find any matching widgets.` at `remote_files_ui_contract_test.dart:229:19` |
| 12 | `refresh 不强制滚回末尾` | 61575 | `The finder "Found 0 widgets with type "Scrollable" that are ancestors of widgets with key [<'sftp_breadcrumb_seg_0'>]: []" (used in a call to "drag()") could not find any matching widgets.` at `remote_files_ui_contract_test.dart:246:18` |
| 13 | `RTL 下路径保持 LTR` | 66928 | `StateError: Bad state: No element` at `remote_files_ui_contract_test.dart:273:14` |
| 14 | `hidden 开关离线可用且 pending 时不可重复提交` | 72278 | `The finder "Found 0 widgets with key [<'sftpToggleHiddenButton'>]: []" (used in a call to "tap()") could not find any matching widgets.` at `remote_files_ui_contract_test.dart:288:18` |
| 15 | `捕获的 onPressed 先调两次再重建帧不重复提交` | 77623 | `StateError: Bad state: No element` at `remote_files_ui_contract_test.dart:309:10` |
| 16 | `搜索行与操作行保持两行布局` | 82972 | `TestFailure: Expected exactly one matching candidate / Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'sftp_search_field'>]: []>` at `remote_files_ui_contract_test.dart:327:5` |
| 17 | `目录链接按别名导航；坏链弹错误且无预览/下载选项` | 88320 | `The finder "Found 0 widgets with text "linkdir": []" (used in a call to "tap()") could not find any matching widgets.` at `remote_files_ui_contract_test.dart:355:18` |

**`test/features/multi_column_lists_test.dart`** (3)

| # | Test name | Log line | Error |
|---|---|---|---|
| 18 | `Multi-column Layout & Zero Regression (Task B) SFTP File List: 1 column on compact (<600)` | 35948 | `The finder "Found 0 widgets with text "folder_0": []" (used in a call to "getTopLeft()") could not find any matching widgets.` at `multi_column_lists_test.dart:272:26` |
| 19 | `Multi-column Layout & Zero Regression (Task B) SFTP File List: multi-column on wide (>=600)` | 38122 | `The finder "Found 0 widgets with text "folder_0": []" (used in a call to "getTopLeft()") could not find any matching widgets.` at `multi_column_lists_test.dart:315:26` |
| 20 | `Multi-column Layout & Zero Regression (Task B) SFTP File View: all action bar, breadcrumb, search, sort, and transfer list interactions are preserved` | 45639 | `TestFailure: Expected: exactly one matching candidate / Actual: _IconWidgetFinder:<Found 0 widgets with icon "IconData(U+0E696)": []>` at `multi_column_lists_test.dart:358:9` |

**`test/features/sftp_two_row_header_test.dart`** (4)

| # | Test name | Log line | Error |
|---|---|---|---|
| 21 | `SFTP Two-Row Header and Special Navigation renders Row 1 search and Row 2 actions without overflow on 320px screen` | 93821 | `TestFailure: Expected exactly one matching candidate / Actual: _TypeWidgetFinder:<Found 0 widgets with type "TextField": []>` at `sftp_two_row_header_test.dart:147:9` |
| 22 | `SFTP Two-Row Header and Special Navigation typing search updates query and clear button resets it` | 99117 | `StateError: Bad state: No element` in `WidgetTester.enterText` at `sftp_two_row_header_test.dart:182:20` |
| 23 | `SFTP Two-Row Header and Special Navigation special .. navigates up and . refreshes without showing context menu` | 104410 | `TestFailure: Expected exactly one matching candidate / Actual: _TextWidgetFinder:<Found 0 widgets with text "..": []>` at `sftp_two_row_header_test.dart:228:9` |
| 24 | `SFTP Two-Row Header and Special Navigation root directory hides both . and ..` | 109697 | `TestFailure: Expected exactly one matching candidate / Actual: _TextWidgetFinder:<Found 0 widgets with text "root_file.txt": []>` at `sftp_two_row_header_test.dart:273:7` |

**`test/features/sftp_file_view_test.dart`** (19)

| # | Test name | Log line | Error |
|---|---|---|---|
| 25 | `SftpFileView unsupported files (.zip, .png) hide open menu item and do not read file or open editor on tap` | 115017 | `StateError: Bad state: No element` at `sftp_file_view_test.dart:281:22` |
| 26 | `SftpFileView supported file (.txt) shows Open in menu and opens editor on tap/open and can save` | 120308 | `The finder "Found 0 widgets with icon "IconData(U+0E404)": []" (used in a call to "tap()") could not find any matching widgets.` at `sftp_file_view_test.dart:315:22` |
| 27 | `SftpFileView read failure does not open an empty editor and surfaces the error` | 125597 | `The finder "Found 0 widgets with text "notes.txt": []" (used in a call to "tap()") could not find any matching widgets.` at `sftp_file_view_test.dart:351:22` |
| 28 | `SftpFileView file larger than 1MB surfaces localized preview too large message with download instruction and does not open editor` | 130888 | `The finder "Found 0 widgets with text "big_log.txt": []" (used in a call to "tap()") could not find any matching widgets.` at `sftp_file_view_test.dart:383:22` |
| 29 | `SftpFileView editor save failure catches error locally, shows error banner, does not dismiss dialog, and preserves unsaved content` | 136180 | `The finder "Found 0 widgets with text "document.txt": []" (used in a call to "tap()") could not find any matching widgets.` at `sftp_file_view_test.dart:408:22` |
| 30 | `SftpFileView displays localized error banner for read failed` | 141431 | `TestFailure: Found 0 widgets with key [<'sftpErrorBanner'>]` at `sftp_file_view_test.dart:463:7` |
| 31 | `SftpFileView displays localized error banner for upload failed` | 146679 | `TestFailure: Found 0 widgets with key [<'sftpErrorBanner'>]` at `sftp_file_view_test.dart:479:7` |
| 32 | `SftpFileView displays localized error banner for download failed` | 151928 | `TestFailure: Found 0 widgets with key [<'sftpErrorBanner'>]` at `sftp_file_view_test.dart:495:7` |
| 33 | `SftpFileView disables upload while keeping download action enabled for continuous queueing when transfer != null` | 157215 | `TestFailure: Found 0 widgets with key [<'sftpTransferBanner'>]` at `sftp_file_view_test.dart:529:9` |
| 34 | `SftpFileView tapping completed download or open button calls openCompletedTransfer` | 162504 | `The finder "Found 0 widgets with key [<'sftpTransferListButton'>]: []" (used in a call to "tap()") could not find any matching widgets.` at `sftp_file_view_test.dart:588:22` |
| 35 | `SftpFileView shows non-blocking banner when downloadNotificationsUnavailable is true` | 167794 | `TestFailure: Found 0 widgets with key [<'downloadNotificationsUnavailableBanner'>]` at `sftp_file_view_test.dart:633:9` |
| 36 | `SftpFileView up arrow button is disabled at root` | 173083 | `StateError: Bad state: No element` at `sftp_file_view_test.dart:645:32` |
| 37 | `SftpFileView up arrow button is enabled in subfolder` | 178378 | `StateError: Bad state: No element` at `sftp_file_view_test.dart:656:31` |
| 38 | `SftpFileView shows sort button and changes sort key and direction` | 188959 | `TestFailure: Found 0 widgets with type "PopupMenuButton<Object>" that are ancestors of widgets with icon "IconData(U+0E5D2)"` at `sftp_file_view_test.dart:679:7` |
| 39 | `SftpFileView runs 300ms fly-in animation to transfer icon and respects reduced motion` | 199528 | `The finder "Found 0 widgets with icon "IconData(U+0E404)": []" (used in a call to "tap()") could not find any matching widgets.` at `sftp_file_view_test.dart:797:22` |
| 40 | `SftpFileView skips fly-in animation when reduced motion (disableAnimations) is enabled` | 204847 | `The finder "Found 0 widgets with icon "IconData(U+0E404)": []" (used in a call to "tap()") could not find any matching widgets.` at `sftp_file_view_test.dart:835:22` |
| 41 | `SftpFileView does not trigger fly-in animation when downloadFile returns null` | 210139 | `The finder "Found 0 widgets with icon "IconData(U+0E404)": []" (used in a call to "tap()") could not find any matching widgets.` at `sftp_file_view_test.dart:870:22` |
| 42 | `SftpFileView disposes in-flight animation and removes overlay entry cleanly` | 215432 | `The finder "Found 0 widgets with icon "IconData(U+0E404)": []" (used in a call to "tap()") could not find any matching widgets.` at `sftp_file_view_test.dart:898:22` |
| 43 | `SftpFileView Special dot navigation clean-up root directory hides both . and ..` | 220725 | `TestFailure: Found 0 widgets with text "etc"` at `sftp_file_view_test.dart:941:9` |
| 44 | `SftpFileView Special dot navigation clean-up subdirectory hides . but shows .. for navigating up` | 226015 | `TestFailure: Found 0 widgets with text ".."` at `sftp_file_view_test.dart:975:9` |

**`test/features/sftp_transfer_list_test.dart`** (2)

| # | Test name | Log line | Error |
|---|---|---|---|
| 45 | `Sftp Transfer List UI action bar entry button shows tooltip and badge reflecting pendingTransferCount` | 183669 | `TestFailure: Found 0 widgets with key [<'sftpTransferListButton'>]` at `sftp_transfer_list_test.dart:189:9` |
| 46 | `Sftp Transfer List UI action bar entry button hides badge count when pendingTransferCount is 0` | 194242 | `StateError: Bad state: No element` at `sftp_transfer_list_test.dart:220:30` |

---

## 3. Second Action — SFTP Fixture-Only Fixes (this executor)

No production code was edited. Fixtures only, in the six authorized SFTP test files. **No assertion, no navigation contract, no layout tolerance, and no fly-in/timing expectation was changed.** No real SSH is ever initiated (connection notifiers remain overridden to a canned `connected` state).

### What was added per file

| File | Change |
|---|---|
| `test/features/sftp_open_transfers_request_test.dart` | Added `setUpAll` doing `SharedPreferences.setMockInitialValues({})` + `LocalStorageService.init()` into a `late final _storage`; `_buildSftpApp` now overrides `localStorageServiceProvider` with `_storage` and `activeServerProvider` with a real `ServerProfile` (`srv-1`, `10.0.0.1:22`, `root`, password). `_TestActiveServerNotifier` took an optional profile so the existing `MainShell` `_pumpShell` path (already initialized storage) is untouched. |
| `test/features/remote_files_ui_contract_test.dart` | Same `setUpAll` storage init; `_app` now overrides `localStorageServiceProvider` + `activeServerProvider` (`srv-1`). |
| `test/features/multi_column_lists_test.dart` | The three SFTP cases (`SFTP File List: 1 column on compact`, `SFTP File List: multi-column on wide`, `SFTP File View: all action bar...`) each got inline `SharedPreferences.setMockInitialValues({})` + `LocalStorageService.init()` and a `localStorageServiceProvider` override — matching the file's existing convention for every other group. Existing `activeServerProvider` / `serverConnectionProvider` overrides preserved. |
| `test/features/sftp_two_row_header_test.dart` | Same `setUpAll` storage init; `_buildApp` now overrides `localStorageServiceProvider` + `activeServerProvider` (`srv-1`). |
| `test/features/sftp_file_view_test.dart` | Same `setUpAll` storage init; `_buildTestApp` now overrides `localStorageServiceProvider` + `activeServerProvider` (`srv-1`). |
| `test/features/sftp_transfer_list_test.dart` | Same `setUpAll` storage init; `_buildTestApp` now overrides `localStorageServiceProvider` + `activeServerProvider` (`srv-1`). |

Every pinned profile uses `id: 'srv-1'` to match the original connected-server metadata already referenced by this suite (`remote_files_ui_contract_test.dart` declares `activeServerId: 'srv-1'`).

Not touched: `test/features/completion_dialogs_test.dart` (owned by another agent), `lib/**` (production), all assertions in the six files, and every other test file.

### Verification

```
flutter test --reporter expanded \
  test/features/sftp_open_transfers_request_test.dart \
  test/features/remote_files_ui_contract_test.dart \
  test/features/multi_column_lists_test.dart \
  test/features/sftp_two_row_header_test.dart \
  test/features/sftp_file_view_test.dart \
  test/features/sftp_transfer_list_test.dart \
  > /tmp/opencode/sftp_fixture_final.log 2>&1
```

**Actual exit code: `0`** (log tail: `00:04 +76: All tests passed!` + `ACTUAL_EXIT=0`).

**76/76 tests passed, 0 skipped, 0 failed, in ~4 s.** This covers all 41 previously-failing SFTP tests plus the 35 that were already green in these files.

Pre-run check: `flutter analyze` on the six files → `No issues found! (ran in 1.7s)`.

**No UI edit was required.** Once the dependency chain (`localStorageServiceProvider` / `activeServerProvider` → `fileBookmarksProvider`) resolved, every layout, navigation, breadcrumb-scroll, overflow and fly-in assertion passed unchanged. No new UI overflow emerged after the dependency fix.

---

## 4. Verdict

| | First run | After fixture fix |
|---|---|---|
| Command | `flutter test --reporter expanded` | `flutter test` (6 SFTP files) |
| Exit | **1** | **0** |
| Pass | 2115 | 76 |
| Skip | 18 | 0 |
| Fail | **46** | 0 |
| `git diff --check` | exit 2 (3 EOF blank lines) | — |
| Status | **NOT GREEN** | target files green |

**The full suite is NOT green.** First run recorded 2115 pass / 18 skip / **46 fail** with actual exit `1`.

Remaining 5 failures are outside this executor's authorized scope and stay with their owners:
- 2 × `test/core/l10n_key_parity_test.dart` (ARB metadata + FR clone) — **AgY**
- 3 × Settings UI ListTile (`settings_navigation_test.dart` ×2, `settings_auto_connect_test.dart` ×1) — **AgY**

Remaining hygiene: 3 extra blank-line-at-EOF issues flagged by `git diff --check` (exit 2) — **Main** to fix in the three docs files.

Full re-run of `flutter test --reporter expanded` is required after AgY's fixes and the docs whitespace cleanup; this executor has not run it.

---

## 5. Artifacts

| Artifact | Path |
|---|---|
| First full-suite stdout+stderr (226 094 lines) | `/tmp/opencode/full_suite.log` |
| `git diff --check` output | `/tmp/opencode/diff_check.log` |
| Six-file SFTP verification run | `/tmp/opencode/sftp_fixture_final.log` |
| Prior gates: flutter analyze (exit 0) | `/tmp/opencode/analyze_final.log` |
| Prior gates: ACP focused72 (exit 0) | `/tmp/opencode/acp_10_10.log` |

Work performed in this report: SFTP test fixtures only (6 files under `test/features/`). No build, packaging, ADB, live SSH, Agent, install, commit, push, workflow, or credential/history access. No global config change.
