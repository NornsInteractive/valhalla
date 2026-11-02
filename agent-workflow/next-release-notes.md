# Valhalla 1.0.34+35

## 智能会话底部输入栏高级美学优化与动效系统注入（Taste Skill Polish）
- **底栏浮动停靠质感**：底部操作区新增 `outlineVariant` 发丝分隔线与漫反射顶阴影，舒适内边距布局，与历史消息流形成清晰的高端停靠层次。
- **中央胶囊呼吸聚焦态**：输入框胶囊容器支持聚焦动效（`AnimatedContainer`，`VCurves.emphasized`），失焦态温润内敛，聚焦态平滑切换至高亮背景与品牌主色边框，外侧投射 10px 柔光氛围光晕。
- **全员物理触觉回弹**：加号圆钮、内联命令圆钮、发送与停止操作按键全面包裹 `PressableScale`（缩放比 0.90~0.94），提供实体按键级弹性落位反馈。
- **打字意图激活与弹簧律动**：发送按钮动态感应草稿输入，有内容时瞬间流动至饱和主色并外扩主色光晕，发送箭头微放 1.05x（`AnimatedScale`）；
- **发送 ↔ 停止电影级转场**：生成中切换采用 `AnimatedSwitcher`（`ScaleTransition` + `FadeTransition` + `VCurves.springish`），形态平滑形变无闪烁跳动。
- **动态高度平滑伸缩**：技能词与附件气泡接入 `AnimatedSize`（`VCurves.decelerate`），动态高度伸缩丝滑平顺。

## 构建与发布
- 正式证书签名发布 Android 各架构包（arm64-v8a、armeabi-v7a、x86_64）、AAB 与 Linux x64 包。
- 零静态分析警告（`flutter analyze` 2 items clean），全量组件测试通过。
