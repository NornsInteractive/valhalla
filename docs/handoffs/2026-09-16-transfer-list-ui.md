# Valhalla UI Handoff — 传输列表 + 后台完成通知（第二批 · 批次 2 of 2）

> 这是用户第二批需求里剩下的一半。批次 1（文件排序 + 顶栏主题快切）
> 的 brief 在 `2026-09-16-file-sort-theme-quick-switch-ui.md`。
> **如果批次 1 还没做完，先把批次 1 做完再做这个。**

## Antigravity session

```text
conversation: ec81a4be-7543-45ee-8658-f68966f57d3b
title: valhalla
workspace: /workspace/projects/valhalla
```

## Allowed files（严格）

- `lib/features/files/sftp_file_view.dart` — 加传输列表入口与列表本身
- `lib/features/shell/main_shell.dart` — 只在需要响应「点通知进传输列表」时改
- `lib/l10n/app_en.arb` + `lib/l10n/app_zh.arb` — 新键
- `test/features/` — 新增/调整用例

**不要动** `lib/core/`、`lib/data/`、`lib/infrastructure/`、`lib/features/settings/`、
`android/`。

---

## 0. 先做一件事：确认基线是绿的

**批次 1 已完成并验收**（2026-09-17），那 6 条 `state.transfer` deprecation info
**已经清零**（`sftp_file_view.dart` 现在读 `state.activeTransfer`，
残留 `state.transfer` 读取为 0）。所以第 0 节原有的活儿不用再做了。

**当前基线（我实测过）**：

```
dart format --set-exit-if-changed .   → 136 files (0 changed)
flutter analyze                       → No issues found!
flutter test -j 1                     → +539: All tests passed
ARB                                   → en=369 / zh=369
```

你不应该让任何一个数字变差。改完 `flutter analyze` 必须 **0 issue**（包括 info）。

`SftpState` 上同时有 `transfers`（全部任务，按入队顺序）和
`activeTransfer`（正在跑的那个，可能为 null），别用混。

---

## 1. 后端契约（已实现、已变异验证，直接用）

### 1.1 传输队列

```dart
enum SftpTransferStatus { queued, running, paused, completed, failed, canceled }

extension SftpTransferStatusX on SftpTransferStatus {
  bool get isTerminal;   // completed / failed / canceled
}

class SftpTransfer {
  final String id;                    // 任务唯一 id（同名文件靠它区分）
  final SftpTransferKind kind;        // upload / download
  final String remotePath;
  final String localPath;
  final int transferredBytes;
  final int totalBytes;               // 未知时为 0
  final SftpTransferStatus status;
  final String? errorMessage;         // 失败时的 reason code

  double? get progress;               // totalBytes <= 0 时返回 null，别显示假进度
  String get fileName;                // 展示用文件名（已处理路径）
}
```

`SftpState` 上：

```dart
final List<SftpTransfer> transfers;      // 全部任务，按入队顺序
SftpTransfer? get activeTransfer;        // 正在跑的那个（仅 running）；没有则 null
bool get hasActiveTransfer;              // == activeTransfer != null，**不含 paused**
int get pendingTransferCount;            // 未结束的任务数（running + paused + queued）
bool get hasFinishedTransfers;           // 有可清除的终态任务
SftpTransfer? transferById(String id);   // 找不到返回 null，调用方必须处理
```

⚠️ **注意 `hasActiveTransfer` 的语义**：它只看 `running`，**暂停中的任务不算**。
如果你要「还有活儿没干完」这个含义，用 `pendingTransferCount > 0`
（它把 queued / paused 都算进去）。Badge 上用 `pendingTransferCount` 更合适。

`transfer` 这个 getter 仍存在但已 `@Deprecated`，**不要用**。

**用户已确认的语义**：

- **排队串行，一次一个。** 用户连续点十个下载会排成队列，自动一个个跑。
  界面上要能看出「哪些在排队、哪个在跑」。
- **暂停/继续只在本次运行内有效。** 不做断点续传，app 重启或断线后
  队列会清空。**不要写「重启后继续」这类文案**，那是另一个特性。

### 1.2 操作接口（`SftpNotifier`）

```dart
Future<void> pauseTransfer(String id);
Future<void> resumeTransfer(String id);
Future<void> cancelTransfer(String id);       // 停掉传输，留下一條 canceled 记录
Future<void> removeTransfer(String id);       // 从列表移除（未结束的会先中止）
void clearFinishedTransfers();                // 清掉所有终态任务
```

几个必须遵守的细节：

- `resumeTransfer` 对 `queued` 状态的任务也能用（放回队列重新调度）。
- 四个方法对**已结束**的任务都是安全的空操作，不存在抛异常的情况。
- `cancelTransfer` 不会写 `errorMessage`（用户主动取消不是错误），
  但 `failed` 会写。**别把 canceled 也显示成错误。**

### 1.3 id 是必须的

暂停/继续/取消/删除都要精确指向某一个任务，**不能用路径或下标当 key**：
队列里完全可能同时有两个 `/root/a.txt`。UI 必须按 `transfer.id` 回调。

### 1.4 失败原因

`errorMessage` 是稳定 code，需要你映射成 ARB 文案（**不要直接显示 code**）。
已有的三个：

```dart
SftpNotifier.uploadFailedCode      // 'SFTP_UPLOAD_FAILED'
SftpNotifier.downloadFailedCode    // 'SFTP_DOWNLOAD_FAILED'
```

（这两个键名与批次 1 无关，是既有常量，直接引用。）

### 1.5 后台完成通知（后端已接好，你只需要不挡路）

传输完成时后端会调一个回调，`main.dart` 里已接到 Android 通知。
**通知的发出完全不依赖界面存在**——用户切后台时界面可能已经被回收，
传输和通知照常。所以：

- 不要在 `dispose` 里取消或暂停队列。
- 不要假设传输期间页面一定在树上。

---

## 2. 需求一：传输列表界面

在文件页（`sftp_file_view.dart`）加一个传输列表。要求：

1. **入口**：`_buildActionBar` 里加一个 `IconButton`（建议
   `Icons.swap_vert` 或 `Icons.downloading`），tooltip 用新键 `transferList`。
   **有未结束任务时要有可见提示**（例如 `Badge` 显示 `pendingTransferCount`，
   参考 Material 3 的 `Badge`）——否则用户不知道后台还在传。
2. **打开方式**：可以是 `showModalBottomSheet` 或整页。你自己选，
   但要满足下一条。
3. **列表项**至少要显示：文件名（`fileName`）、方向（上传/下载）、
   状态（排队中/传输中/已暂停/已完成/失败/已取消）、进度
   （`transferredBytes` / `totalBytes`，`progress` 为 null 时显示
   「大小未知」而不是 0%）、以及失败时的原因文案。
4. **每项的操作按钮**按状态决定（这是这个界面的核心，别偷懒）：

   | 状态 | 可用操作 |
   |---|---|
   | `queued` | 暂停、取消、删除 |
   | `running` | 暂停、取消 |
   | `paused` | 继续、取消、删除 |
   | `completed` | 删除 |
   | `failed` | 删除 |
   | `canceled` | 删除 |

5. **「清除已完成」**：顶部一个按钮，仅在 `hasFinishedTransfers` 为真时启用，
   调 `clearFinishedTransfers()`。
6. **空态**：没有任务时不要显示一个空白列表，给一句文案（新键 `transferEmpty`）。
7. **删除要有确认**吗？——**不需要**。删除只影响列表记录，不动远端也不动本地
   文件，误删的代价是没了进度显示，不值得弹窗打断。但**取消**也不要弹窗
   （既然列表里能看见结果）。保持轻量。

## 3. 需求二：点通知打开传输列表

`main.dart` 里 Android 通知已经带了一个 extra（`open_transfers = true`），
但**读取它的接线还没有做**。你需要在 `main_shell.dart` 里：

1. 通过 `MethodChannel('valhalla/keepalive')` 的 `getLaunchAction`（**这个原生方法
   我还没加，见下**）拿到「是否由通知点击启动」。
2. 如果是，切到文件页并打开传输列表。

**但是**：原生侧这个方法我还没来得及加。所以本轮**先做 1 和 2 的 Dart 侧骨架**，
用一个可注入的 provider 包起来，让它在拿不到原生结果时静默降级：

```dart
// 建议加在 main_shell.dart 里（或问我在 lib/core/ 加，别自己往 core 里塞东西）
final pendingTransferLaunchProvider = ...
```

**如果这块你觉得依赖太多、不好收尾，可以只做需求一（传输列表本身），
把「点通知打开」留给我，直接告诉我。** 这一点提前说清楚比做到一半卡住好。

---

## 4. ARB 新键（en/zh **必须成对**，不要 `git checkout` 任一个 arb 文件）

**先自己确认批次 1 已经完成**：批次 1 加了 7 个键，完成后是 369/369。
本轮的键在此基础上再加。

| key | en | zh |
|---|---|---|
| `transferList` | Transfers | 传输列表 |
| `transferEmpty` | No transfers yet | 暂无传输任务 |
| `transferUpload` | Upload | 上传 |
| `transferDownload` | Download | 下载 |
| `transferStatusQueued` | Queued | 排队中 |
| `transferStatusRunning` | Transferring | 传输中 |
| `transferStatusPaused` | Paused | 已暂停 |
| `transferStatusCompleted` | Completed | 已完成 |
| `transferStatusFailed` | Failed | 失败 |
| `transferStatusCanceled` | Canceled | 已取消 |
| `transferPause` | Pause | 暂停 |
| `transferResume` | Resume | 继续 |
| `transferCancel` | Cancel | 取消 |
| `transferRemove` | Remove | 删除 |
| `transferClearFinished` | Clear finished | 清除已完成 |
| `transferSizeUnknown` | Size unknown | 大小未知 |
| `transferFailedUpload` | Upload failed | 上传失败 |
| `transferFailedDownload` | Download failed | 下载失败 |

**不要重复添加**批次 1 已经加过的键。

---

## 5. 硬性要求

1. **先写定义再写引用**，每改完一处 `flutter analyze` 确认 0 issue。
2. 完成后必须跑并**贴出真实输出**：
   - `dart format --set-exit-if-changed .`
   - `flutter analyze`（**必须 0 issue，包括 info 和 deprecated**）
   - `flutter test -j 1`（**全量**，不只跑新文件）
3. **基线（我实测过，按这个核对）**：
   - `dart format --set-exit-if-changed .` → 136 files, 0 changed
   - `flutter analyze` → No issues found!（做完必须还是 0）
   - `flutter test -j 1` → **+539: All tests passed**
   - ARB → **369/369**（批次 1 已加完 7 个键，本轮在此基础上再加 18 个）

   你不应该让任何一个数字变差。每改完一处就 `flutter analyze` 一次。
4. ARB 改完自己核对 en/zh 键数相等，两侧数字必须一样。
5. **测试要有牙**：至少对你的传输列表做一次变异验证——例如把
   `pauseTransfer` 的回调从按钮上删掉，确认测试真的会红，再改回来。
   在报告里说明你变异了什么、红了几条。
6. **别信「已验证测试有效性」这种话**。历史教训：之前有几次报告说测试
   有效，我自己一变异发现错误分支根本没测到。你要给出具体的变异动作和
   失败输出。

## 6. 如果卡住了

传输列表比我之前给你的几次都大（6 个状态 × 4 个操作 = 24 条路径）。
**卡住就告诉我卡在哪，不要硬凑一个只覆盖 happy path 的版本交上来。**
尤其注意：

- `progress` 为 null（`totalBytes == 0`）时的显示。
- `queued` 状态点暂停后，它不该被调度起来（后端已保证，但你得能显示对）。
- 任务在用户看着列表时从 running 变 completed，列表要跟着刷新。

---

# 验收记录（2026-09-17）

**结论：批次 2 通过验收。** 传输列表 + 后台完成通知均落地，
通知点击链路两端接通，release APK 已重建并核验内容。

## A. 交付物落盘核对

不看报告，只认磁盘。

| 检查项 | 命令 | 结果 |
|---|---|---|
| 传输列表入口 | `grep -n "transferListView\|transferEmptyView" lib/features/files/sftp_file_view.dart` | 命中（`:780` / `:800`） |
| 列表项 key | `grep -n "transfer_item_\|transfer_error_" ...` | 命中（`:970`） |
| 操作矩阵 | 读取 `:879-889` | 6 个状态分支齐全 |
| deprecated getter | `grep -c "state\.transfer\b" lib/features/files/sftp_file_view.dart` | **0**（已全量换用 `activeTransfer`） |
| 通知 extra | `grep -n "open_transfers" android/.../TransferNotifier.kt` | 命中 |
| 原生读取 | `grep -n "getLaunchAction" android/.../MainActivity.kt` | 命中 |
| ARB | 逐键解析 en/zh | **387 / 387** |

通知点击链路的原生侧本轮补齐（brief 第 3 节当时留的缺口）：

```kotlin
private var pendingOpenTransfers = false

override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    consumeLaunchExtras(intent)
}

private fun consumeLaunchExtras(intent: Intent?) {
    if (intent?.getBooleanExtra(TransferNotifier.EXTRA_OPEN_TRANSFERS, false) == true) {
        pendingOpenTransfers = true
    }
}
```

`getLaunchAction` 是**读后即清**的：

```kotlin
"getLaunchAction" -> {
    val openTransfers = pendingOpenTransfers
    pendingOpenTransfers = false
    result.success(if (openTransfers) "openTransfers" else null)
}
```

刻意**不**从 `getIntent` 每次现取：启动 intent 的 extra 在整个进程生命周期里
都会一直报同一份，热恢复会导致用户每次从应用切换器回来都重开传输列表。
Dart 侧对应 `KeepAliveService.consumeOpenTransfersAction()`，只在结果
**严格等于** `'openTransfers'` 时返回 true（未知字符串返回 false，有测试守着）。

## B. 门禁输出

```
dart format --set-exit-if-changed .   → 137 files (0 changed)
flutter analyze                       → No issues found!
flutter test -j 1                     → +568: All tests passed
ARB                                   → en=387 / zh=387
./gradlew :app:compileDebugKotlin -q  → EXIT=0
release APK                           → 63,074,871 bytes
```

APK 内容核验（解包 dex 直接搜字符串，因为 release 经过 R8，
最终以 dex 里是否存在原生方法名/常量为准）：

```
getLaunchAction         -> True
openTransfers           -> True
open_transfers          -> True
notifyTransferCompleted -> True
pendingOpenTransfers    -> False   # 私有字段被 R8 改名/内联，预期内
```

manifest：`INTERNET` + `POST_NOTIFICATIONS` 均在；`resources.arsc`
含 `Transfer results` / `transfer_complete`。

## C. 我独立跑的变异（不看 agy 的自我报告）

6 条变异，**5 条被抓住**，1 条存活后修复，1 条判定为良性存活。

| # | 变异 | 结果 |
|---|---|---|
| 1 | `canResume` 从 `== paused` 放宽到含 `running` | 抓住 |
| 2 | `canRemove = transfer.status != running` 改成恒 `true` | 抓住 |
| 3 | Badge `isLabelVisible` 恒 `true` | 抓住 |
| 4 | 暂停按钮 `onPressed: null` | 抓住（agy 自报） |
| 5 | `resumeTransfer(remotePath)` 传路径而非 id | 抓住（agy 自报） |
| 6 | `hasError = status == failed` 改成 `failed \|\| canceled` | **先存活，后修复** |
| — | 去掉 `errorMessage != null` 短路守卫 | 存活，**判定良性** |

### C.6 是这轮最重要的发现：一条真空断言

移除/放宽「canceled 不算错误」的变异最初显示
`+20: All tests passed!` —— 也就是说这条规则**根本没有被守住**。

根因是断言写法本身：

```dart
final hasError = transfer.status == SftpTransferStatus.failed;
final errorText = hasError && transfer.errorMessage != null
    ? _mapTransferError(context, transfer.errorMessage)
    : null;
```

agy 的 fixture 里那条 `canceled` 任务 `errorMessage: null`，于是
`hasError && errorMessage != null` 在 `errorMessage != null` 处短路，
断言恒真。**它守的是「errorMessage 为 null 时不渲染错误行」，
而不是「canceled 不渲染错误行」。** 变异改成 `failed || canceled` 后，
`canceled` 任务依旧因为 `errorMessage == null` 走不到渲染分支。

我先用一条独立探针证实缺陷路径真实存在——造一个
`status: canceled, errorMessage: 'SFTP_UPLOAD_FAILED'` 的任务，
在变异下这条探针**会红**（错误行真的渲染出来了）。
然后把它换成两条正式用例（我自己补进 `sftp_transfer_list_test.dart`）：

```dart
testWidgets('canceled with an errorMessage still renders no error row', ...);
testWidgets('failed with an errorMessage DOES render the error row', ...);
```

复跑变异 → `00:02 +21 -1: Some tests failed.` 抓住。

**探针踩坑**：第一版探针写在同一个 `testWidgets` 里，第二次
`pumpWidget` 会复用元素树，导致探针假绿。拆成独立 `testWidgets` 才准。

### C.7 为什么那条守卫判良性

去掉 `errorMessage != null` 后测试仍全绿。分析：`_mapTransferError`
只在 `hasError`（即 `failed`）成立时才会被求值，而每个真实
`failed` 任务都必定带 code，所以该守卫是纯防御性的，不是产品缺陷。
**不为了凑变异数去改代码。**

## D. 从上一轮继承的两条经验（批次 1 遗留，本轮继续生效）

1. **存在性断言 ≠ 位置断言。** 断言「元素在树上」对位置类需求毫无牙力，
   必须 `getCenter` / `getRect` 比大小，且断言间隙时用
   `inInclusiveRange` 而不是下限。
2. **布局类变异要防误抓。** 插入一个 400px 占位符会让 RenderFlex
   溢出、测试整体变红，那是崩溃不是断言命中。位置变异必须保持元素
   齐全、可点、不溢出，只改相对次序。
3. **先自己跑一遍变异再派活。** 我曾预测删除 `RadioListTile` 的
   `setThemeMode` 调用会保持绿，实际会红（`main_shell_top_layout_test.dart:412`），
   白费一次派单。

## E. 已收口：`_openTransfersRequest` 的消费者（2026-09-17 追加）

上一节列的遗留已由我接好契约，UI 侧监听与测试派给 agy 补。

**契约位置：`SftpFileView` 构造函数新增可选参数**

```dart
class SftpFileView extends ConsumerStatefulWidget {
  const SftpFileView({super.key, this.openTransfersRequest});

  /// 语义是**单调递增的计数器**，不是布尔值。
  final ValueListenable<int>? openTransfersRequest;
```

三处接线：

1. **shell 侧传入**（`main_shell.dart` 的 `_views`）：
   `SftpFileView(openTransfersRequest: _openTransfersRequest)`
2. **文件页监听 + 缓存已处理值**：`_handledOpenTransfersRequest`，
   只在**值变化**时动作。
3. **`didUpdateWidget` 换绑** + **`dispose` 解绑**。

**为什么必须用计数器而不是布尔/一次性开关**：
用户可能点通知 A → 看到面板 → 手动关掉 → 又点通知 B。
布尔量无法区分「第二次请求」和「第一次的残留」，
计数器才能表达「又发生了一次」。

**为什么必须缓存 `_handledOpenTransfersRequest`**：
`IndexedStack` 的子项在切 tab 时会重建，若不比对值，
每次重建都会重新弹一次面板——用户手动关掉后就再也关不掉了。

**为什么 `didUpdateWidget` 要换绑**：
`_views` 是 `late final` 列表、元素不会被替换，但测试与其它调用方
可以传入不同的 `ValueNotifier`。换绑是廉价的正确性保证。

**`openTransfersRequest == null` 时的行为**：完全无自动打开，
`const SftpFileView()` 的既有调用方（测试）不受影响。

### E.1 agy 补的测试（`test/features/sftp_open_transfers_request_test.dart`，新增 5 条）

| # | 用例 | 守住什么 |
|---|---|---|
| 1 | `openTransfers: true` 经 `MainShell` 切到文件页并弹面板 | 端到端链路（含 `transferSheetCloseButton` 关闭） |
| 2 | `openTransfers: false` 不弹 | 对照组，防「无论如何都弹」 |
| 3 | 同一个值不重复响应 | **核心守卫**：值不变时不弹；关掉后值仍不变也不弹；值递增才再弹 |
| 4 | `openTransfersRequest` 为 null 直接渲染不崩 | 空安全路径 + `dispose` 的 `?.removeListener` |
| 5 | `didUpdateWidget` 换绑解绑旧通知器 | 旧 notifier 递增不弹，新 notifier 递增才弹 |

用例 3 用了一个 `_TestValueNotifier.forceNotify()` 强制触发
`notifyListeners()` 而**不改变值**——这正是能戳穿「只看值不看变化」
实现的关键手法，比单纯递增更能暴露缺陷。agy 这条写得好。

### E.2 我独立复核的 4 条变异（不信 agy 的自我报告）

| # | 变异 | 结果 |
|---|---|---|
| **M1** | 删掉 `if (request == _handledOpenTransfersRequest) return;` | **抓住** `+4 -1`（用例 3 红） |
| **M2** | 删掉 `if (!mounted) return;` | **存活**（`+5`），判定良性 |
| **M3** | 清空 `_handleOpenTransfersRequest` 方法体 | **抓住** `+2 -3`（用例 1/3/5 红） |
| **M4** | shell 改回 `const SftpFileView()`（不传 notifier） | **抓住** `+4 -1`（用例 1 红） |

**M4 是我额外加的、brief 里没要求的一条**：agy 的 5 条用例里有 4 条是直接
构造 `SftpFileView` 测试的，只有用例 1 走 `MainShell`。M4 证明用例 1 真的
锁住了 shell 那一行接线——这是我写的代码，我必须自己确认它被守住了。

**M2 存活的原因（认同 agy 的分析）**：`_handleOpenTransfersRequest` 由
`ValueNotifier.notifyListeners()` **同步**调用，而组件卸载时 `dispose`
会先执行 `?.removeListener` 注销。因此不存在「监听器在 `mounted == false`
时仍被回调」的真实路径。属纯防御性守卫。

**agy 的诚实值得记录**：它主动报告 M2 存活并解释了原因，没有为了让变异
「全红」去编造场景。这与上一轮我发现的真空断言形成对比。

### E.3 门禁（我复跑，非引用 agy 报告）

```
dart format --set-exit-if-changed .   → 138 files (0 changed)
flutter analyze                       → No issues found!
flutter test -j 1                     → +573: All tests passed
ARB                                   → en=387 / zh=387
```

无变异残留（`grep -rn "MUT\|PROBE"` 为空），`sftp_file_view.dart` 与
`main_shell.dart` 在变异后均与备份**逐字节一致**（`diff` 无输出）。

