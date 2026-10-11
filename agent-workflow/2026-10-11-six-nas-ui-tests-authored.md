# 2026-10-11 NAS 缩略图生命周期 Widget 测试（仅撰写，未执行）

**状态更新：UNRUN → FAIL（编译期失败，0/4 用例执行，`TEST_EXIT=1`）。**
撰写阶段未执行任何验证；本轮仅按指令格式化本任务自有文件后执行了单次
`flutter test test/features/nas_thumbnail_lifecycle_test.dart`（见 §6 实际输出）。
没有改动任何生产代码、UI、ARB 或其它测试文件，没有重跑、没有 git/build/ADB/子代理。
断言按目标契约书写、**不迁就当前实现**。

- 新增文件（唯一测试文件）：`test/features/nas_thumbnail_lifecycle_test.dart`（4 个用例）
- 模型：MiMo free 主会话（`opencode/mimo-v2.6-flash-free`）；未启动任何 small/子代理。

## 1. 读取范围（刻意最小化）

只读了撰写所需的四个文件 + 一个既有 widget 测试的 harness 写法 + 服务构造函数签名：

- `lib/features/nas/widgets/nas_thumbnail_image.dart`（被测件）
- `lib/data/models/nas_media.dart`（`NasMediaItem` 字段）
- `lib/core/providers/nas_provider.dart` 的 `nasImageCacheProvider` 声明（`Provider<NasImageCacheService>`）
- `lib/core/services/nas_image_cache_service.dart` 仅构造函数与两个方法签名
  （`NasImageCacheService(this.adapterFor, this.budget)`、`thumbnail`、`releaseThumbnail`）
- `test/features/nas_media_view_test.dart` 的 harness 写法（`ProviderContainer` + overrides）
- `pubspec.yaml`/既有测试确认 riverpod 3.x 的 `overrideWithValue` / `overrideWith((ref) => …)` /
  `container.invalidate` 均为仓库既有用法

没有展开 NAS/client 目录树或其它依赖。

## 2. 替身设计（零文件系统 / 零网络 / 零后端）

`_FakeNasImageCacheService extends NasImageCacheService`，只覆写两个方法：

- `thumbnail` → 记录 `(item, owner)` + 有序事件串，返回 `Future.value(null)`；
  FutureBuilder 拿到 null 走 placeholder 分支，永远不会触碰 `File(...)`。
- `releaseThumbnail` → 记录 `(item, owner)` + 有序事件串。
- 构造传入 `( _) => throw UnimplementedError(), () => 0` 两个占位闭包，基类内部逻辑
  （队列、`_pump`、适配器、path_provider）永不执行。

覆盖方式：`nasImageCacheProvider.overrideWithValue(fake)` / `overrideWith((ref) => current)` +
`UncontrolledProviderScope`。Provider 本体是惰性的，真实 provider 构造函数（adapter、
localStorage）不会运行；`overrideWithValue` 不注册 `onDispose`，fake 不会被基类 dispose 波及。

## 3. 四个用例与断言意图

1. **无关重建不再发起请求**：host 里放一个每次 pump 变化的 `Text('tick n')` 逼迫父级重建，
   `NasThumbnailImage` 每次是新实例（`didUpdateWidget` 必然执行）但 item 字段不变。
   断言 `thumbnailCalls` 恒为 1、`releaseCalls` 为空。
2. **同 server/path 下 `modifiedEpoch` 或 `sizeBytes` 变化**：先取 `100/1000`，再换成
   `200/1000`，再换成 `200/2000`。每次断言：旧 item 被 release（字段为旧值）、
   新 item 被请求（字段为新值）、**owner 与当初发起该请求的 owner 是同一对象**（`same`），
   并用有序 `events` 列表断言「先 release 旧、再请求新」。
3. **卸载释放捕获的服务且无 disposed WidgetRef 异常**：先挂载再 pump `SizedBox.expand()`
   （保持 `UncontrolledProviderScope` 不动，只移除被测件）。断言恰好 1 次 release、
   owner 与请求方一致、`tester.takeException()` 为 null——任何在 dispose 里
   `ref.read(...)` 的写法都会在这里显形。
4. **替换服务覆盖**：`overrideWith((ref) => current)` + `container.invalidate` 把 current
   从 `oldService` 换成 `newService`，再以 epoch 变化触发一次 widget 更新。断言：
   OLD 服务只被 release **一次**（且是旧 item）、OLD 不再收到新请求、NEW 服务收到新 item
   的 thumbnail 且没有多余 release。

## 4. 与当前实现的关系（未削弱断言）

- 用例 1–3 按契约书写；当前实现恰好也能满足这三条，不因此放宽任何断言。
- 用例 4 针对的正是被修正的问题：当前 `didUpdateWidget` 走
  `_capturedService ?? ref.read(...)`，一旦 initState 捕获就永远钉死旧服务，
  **不会采纳新服务**——在 AgY 修正落地前用例 4 预期失败；修正后（任何一次 widget 更新时
  重读 provider、发现服务实例变化即对旧服务 release 一次并改用新实例）应转绿。
  断言刻意只用「item 变化」这一最保守触发方式，不额外要求「无关重建也要采纳新服务」，
  避免过度约束实现细节。

## 5. 验证命令

```
dart format test/features/nas_thumbnail_lifecycle_test.dart   # 已执行，exit 0，仅此一个自有文件
flutter test test/features/nas_thumbnail_lifecycle_test.dart  # 单次执行（pipefail），见 §6
```

## 6. 实际执行结果（UNRUN → FAIL，单次运行、未重跑）

执行方式：`set -o pipefail; flutter test test/features/nas_thumbnail_lifecycle_test.dart 2>&1 | tee …`，
完整未过滤日志保留，**实际退出码 `TEST_EXIT=1`**（`00:05 +0 -1: Some tests failed`，
loading 阶段即失败，`+0` 表示 **4 个用例一个都没有跑到**，因此不存在断言级 expected/actual，
失败信息必须按下面原文保留，不得改写断言、不打补丁）：

```
lib/features/nas/widgets/nas_thumbnail_image.dart:71:35: Error: The argument type 'NasImageCacheService?' can't be assigned to the parameter type 'NasImageCacheService'.
 - 'NasImageCacheService' is from 'package:valhalla/core/services/nas_image_cache_service.dart' ('lib/core/services/nas_image_cache_service.dart').
      _loadThumbnail(widget.item, service);
                                  ^
Failed to load ".../test/features/nas_thumbnail_lifecycle_test.dart":
Compilation failed for testPath=... : lib/features/nas/widgets/nas_thumbnail_image.dart:71:35 (同上)
```

- **失败位置在生产文件 `nas_thumbnail_image.dart:71:35`，不在测试文件内**；按指令未做任何
  prod/UI 修复。
- 编译快照期的类型证据：`nasImageCacheProvider` 现为 `Provider<NasImageCacheService>`（非空），
  `initState` 42–44 行（同为 `ref.read` 结果直传 `_loadThumbnail`）**没有**报错，
  说明快照里 `didUpdateWidget` 赋给 `service` 的表达式（69 行位置）类型为可空
  `NasImageCacheService?`——即快照代码是直接使用 `_capturedService`、没有可空收窄的重读。
- 运行结束后再读该文件，69 行已是
  `final service = _capturedService ?? ref.read(nasImageCacheProvider);`
  （该写法静态类型非空，可让 71 行通过）——即快照与运行后文件内容不一致，
  **存在 AgY 在本次编译快照之后落笔的时序**。按「no reruns」指令未重跑，不替 AgY 断言现状。
- **服务替换用例（用例 4）本次根本没有执行**：关于「`didUpdateWidget` 先用旧服务、
  `build` 才 watch 新服务」的猜想**未经测试证实也未证伪**，须由 AgY 授权的下一次执行给出。
  快照期 71 行的可空类型是「didUpdateWidget 只用了捕获的旧服务」的编译器侧旁证，
  但不等价于用例 4 的实测结论。
- 建议 AgY 授权后重跑同一条命令（无需改任何期望）：`flutter test test/features/nas_thumbnail_lifecycle_test.dart`。

执行约束自查：仅格式化并执行自有测试文件；无 broader research、无重跑、无核心代码改动、
无 build/ADB/git、无子代理（MiMo free 主会话执行，未启用 small/付费回退）。
