# Valhalla 1.0.31+32

## 智能会话 Agent 切换弹窗滚动修复
- 修复智能会话（AI Chat）界面切换 Agent 弹窗（Agent Switcher Modal）无法上下滑动的问题：
  - 弹窗底部抽屉启用 `isScrollControlled: true` 与安全区适配，并添加平滑圆角卡片外观。
  - 将固定的 Agent 列表重构为弹性滚动的 `ListView.separated`，列表高度自适应内容并在超出屏幕时（最大 85% 屏高）支持流畅上下滑动与惯性滚动。
  - 智能体名称添加横向溢出截断保护（`Expanded` + `TextOverflow.ellipsis`），防止长名称导致渲染溢出。
  - 保留顶部固定操作标题与底部“管理 Agent”快捷入口。
- 新增组件级滑动与切换测试，验证移动端窄屏下多 Agent 列表流畅上下滑动、目标 Agent 滚动可见及切换触发。

## 移动端构建与发布
- 发布手机端 ARM 架构（arm64-v8a、armeabi-v7a）签名发布包。
