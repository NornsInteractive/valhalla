# Valhalla 1.0.35+36

## 智能会话底部输入框圆角胶囊完美包裹与背景冲突消除
- **输入框背景冲突根治**：彻底消除 `TextField` 默认继承全局 `inputDecorationTheme` 导致的 `filled: true` 尖角长方体背景覆盖，显式指定 `filled: false` 与透明背景色，避免 90 度尖角遮挡椭圆胶囊。
- **胶囊容器严格抗锯齿裁剪**：为中央输入框 `AnimatedContainer` 注入 `clipBehavior: Clip.antiAlias`，并为内层 `Row` 增加 `ClipRRect(borderRadius: BorderRadius.circular(24))` 双重裁切，确保任何文字、光标与组件均被外层 24dp 圆角完整包裹。
- **真机/模拟器 ADB 渲染实测验证**：已通过 ADB 部署并在实体/模拟器界面实测验证，原长方体与椭圆形冲突完全消除，底栏胶囊呈现平滑圆润质感。

## 构建与测试
- 静态分析 `flutter analyze` 零告警。
- 全量组件与控制器测试（`acp_usability_widget_controls_test.dart`、`composer_context_widget_test.dart`、`composer_command_preferences_widget_test.dart`）33 项测试全部通过。
