# Valhalla 1.0.33+34

## 智能会话底部输入框全面升级为 Google Chat 原生风格
- **左侧操作区**：改为单一独立的 40x40 紧凑圆形加号按钮（`+`，`chat_attachments_button`），采用 Material 3 `surfaceContainerHigh` 表面背景与圆形容器，支持选择图片、本地文本、远程文件以及快捷调用命令与技能面板。
- **中央输入容器**：升级为圆角胶囊状（Pill Container，24dp 圆角），浅底微边框（`outlineVariant` 35% 不透明度），内嵌无边框自适应高度输入框（`chatPromptInput`），打字视野与横向有效空间大幅拓展。
- **胶囊内联快捷动作**：将斜杠命令与技能入口（`chat_commands_menu_button`）内嵌至胶囊右下侧，紧凑精致（32x32dp），不额外占用外部横向间距。
- **右侧发送/停止动作**：40x40 独立圆形操作按钮（`sendMessageButton` / `stopGenerationButton`），生成过程中平滑切换为红色终止按键。
- **自动化测试**：更新组件回归测试 `test/features/composer_context_widget_test.dart`，全面断言圆形加号按钮、胶囊内联命令按钮与发送按钮尺寸几何及交互行为。

## 构建与发布
- 正式证书签名发布 Android 各架构包（arm64-v8a、armeabi-v7a、x86_64）、AAB 与 Linux x64 包。
- 零静态分析警告（`flutter analyze` 2 items clean），全量组件测试通过。
