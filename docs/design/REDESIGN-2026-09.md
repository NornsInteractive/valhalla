# Valhalla "Norse Steel" 重设计指南 (durandal 分支)

本指南约束本次全量 UI 重做。目标是: 钢灰冷色表面 + 单一强调色 + 克制而充分的动效,
视觉层级靠表面明度阶梯与 1px 冷描边, 数字与主机信息一律等宽字体。

## 0. 硬性约束 (违反即返工)

1. **禁止硬编码状态色**。`Color(0xFF10B981)` / `0xFFEF4444` / `Colors.red` /
   `Colors.orange` / `Colors.grey` 一律替换为语义色:
   `context.vSuccess` / `context.vInfo` / `context.vWarning` / `context.vDanger`
   (来自 `core/design/tokens.dart` 的 extension)。品牌强调色用 `context.colorScheme.primary`。
2. **圆角体系锁定**: 输入/小容器 12 (`VRadius.input`), 按钮 12, 卡片 16
   (`VRadius.card`), 大卡 20, 弹窗 20 (`VRadius.dialog`), 底部弹层顶 24
   (`VRadius.sheet`), 胶囊 `VRadius.pill`。禁止出现 4/6/8 等游离值;
   装饰性小方块 (图标底座) 可用 8。
3. **零硬编码文案**: 任何界面文字必须走 `context.l10n.xxx`。没有的 key 就去
   `lib/l10n/app_en.arb` + `app_zh.arb` 成对新增, 然后跑
   `flutter gen-l10n` 生成 (或保持 generate:true 由构建生成)。
   **禁止**改动既有 key 的语义; 新增 key 命名用 camelCase。
4. **测试 Key 全部保留**: `Key('...')` 是集成测试锚点, 重构时原样搬运。
5. **不碰业务逻辑**: 不修改 provider / service / repository / 状态机;
   不改方法签名; 不改路由结构。只动表现层 (build 方法、私有 _buildXxx、样式)。
6. **减少动态效果**: 自定义动画一律用 `core/design/motion_widgets.dart` 里
   的现成组件 (已内置 `MediaQuery.disableAnimationsOf` 处理), 不要手写裸的
   `AnimationController.repeat()`。
7. **性能红线**: 只动画 transform/opacity; 不用 `window.addEventListener` 等价物
   (raw scroll listener); 长列表不用全量 Entrance 包裹 (只包可见区块或前 12 项)。
8. **等宽字体**: 数字 / 主机 / 路径 / 进度 / 指标 / 时间戳用
   `monoTextStyle(...)` (替代 `TextStyle(fontFamily: 'JetBrains Mono', ...)` 手写)。

## 1. 设计令牌

```dart
import '../../core/design/tokens.dart';
import '../../core/design/motion.dart';
import '../../core/design/motion_widgets.dart';

VRadius.input / VRadius.button / VRadius.card / VRadius.dialog / VRadius.sheet / VRadius.pill
VSpace.xs/sm/md/lg/xl/xxl/xxxl            // 4/8/12/16/20/24/32
context.vSuccess / vInfo / vWarning / vDanger
monoTextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ...)
vElevation(Theme.of(context).brightness)  // 冷调阴影, 只给浮层用
```

## 2. 动效组件 (已内置 reduced-motion 处理)

### Entrance — 一次性入场 (fade + slide + 微缩放)
```dart
Entrance(index: 0, child: Text(...))          // index 交错步长 42ms, 上限 12
Entrance(index: 2, offset: Offset(-14, 0), child: ListTile(...))
```
用于: 区块标题、卡片、弹窗内容、抽屉项。**列表项只在前 12 项内用,
超过则不包或只包 `index: 0`**。频繁 rebuild 的行 (进度条行) 不要包,
Entrance 只在首次挂载播放, 不会重复。

### AnimatedIndexedStack — 页面切换转场 (shell 已接)
保持全部子页存活, 自带 fade+slide+scale。

### PressableScale — 按压缩放
```dart
PressableScale(child: Card(...))   // 纯装饰包装, 不拦截手势
```
ValhallaCard 在传入 `onTap` 时已自动带按压反馈, 无需再包。

### PulseDot — 语义状态点 (只用于真实状态: 在线/连接中/错误)
```dart
PulseDot(color: context.vSuccess, size: 8)
```

### CountUp — 数值滚动 (指标数字)
```dart
CountUp(value: ratio * 100, formatter: (v) => '${v.toStringAsFixed(1)}%',
        style: monoTextStyle(fontSize: 21, fontWeight: FontWeight.w700))
```

### AnimatedProgressBar / AnimatedRingProgress — 平滑进度
```dart
AnimatedProgressBar(value: 0.6, color: context.vSuccess, height: 5)
AnimatedRingProgress(value: 0.6, color: context.vInfo, size: 56,
                     child: Text('60%'))
```

### Shimmer / SkeletonBox / SkeletonListTile / SkeletonMetricGrid — 骨架屏
替代转圈: loading 状态按最终布局形状铺骨架。

### VTiming / VCurves / VSpring — 原始令牌
```dart
AnimatedContainer(duration: VTiming.base, curve: VCurves.emphasized, ...)
AnimatedScale(scale: pressed ? 0.97 : 1, duration: VTiming.fast,
              curve: VCurves.springish, ...)
```

## 3. 布局与文案

* 章节标题: `Text(title, style: context.textTheme.titleMedium)` — 不要再手写
  `copyWith(fontWeight: FontWeight.bold)`; 主题已配好字重与字距。
* 正文: `context.textTheme.bodyMedium` / `bodySmall`。
* 图标底座: 26-40 方块, `BorderRadius.circular(8~12)` + 语义色 12% 底。
* 状态徽标: 统一用 `StatusBadge` (已升级), 不要自绘。
* 危险操作: `DangerConfirmDialog.show(...)` (已升级)。
* 空态/错误态/离线态: `EmptyStateView / ErrorStateView / OfflineStateView`
  (已升级, 自带入场)。

## 4. 每个视图的验收清单

- [ ] 全文无 `Color(0xFF10B981)` / `0xFFEF4444` / `0xFFF59E0B` / `Colors.red|orange|grey` 等状态色硬编码
- [ ] 无 `fontFamily: 'JetBrains Mono'` 手写 (改 monoTextStyle)
- [ ] 无游离圆角值 (4/6/8 出现在容器层级)
- [ ] 关键区块有 Entrance 编排 (首屏 3-5 档交错)
- [ ] loading 用骨架屏, 空态用 EmptyStateView
- [ ] 测试 Key 无一丢失
- [ ] 无新增硬编码字符串 (l10n 双语补齐)
- [ ] `flutter analyze` 零新增告警
