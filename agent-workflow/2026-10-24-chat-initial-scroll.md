# 智能会话初次加载定位验收

用户在 `lib/features/chat/ai_chat_view.dart` 增加了初始滚动定位，本轮保留其修改意图，验证后发布新版本。

验收范围：已有历史首次进入、异步加载历史、切换会话、快速切换时旧回调隔离、用户上滑阅读时不被流式更新拉回、长短消息混排与列表可见性。使用真实 AiChatView 和本地替身，不向生产 Agent 发送消息。

UI 由原 AgY Valhalla 会话、Gemini 3.8 Flash / high 审查和修复；OpenCode 免费模型负责编写回归与执行验证、构建。主代理负责审查和发布登记。发布沿用本地 Android 三架构 APK/AAB、Linux x64；版本按发布脚本递增，不运行 Actions。

本轮 ADB 无在线设备，因此不把控件测试或构建核验称为设备验收。已发布 `1.0.17+18`，产物与渠道验收记录见 [发布记录](2026-10-24-v1017-release.md)。

## 发布前验收

保留用户的滚动定位实现，未复现需要额外修改产品代码的缺陷。AgY 审查记录见 `2026-10-24-agy-scroll-review.md`；其列举的静态风险不等于已复现故障。

OpenCode 使用免费模型 `opencode/nemotron-3-ultra-free` 完成验证：新增 7 项滚动回归，连同会话隔离、ACP 持久恢复共 20 项测试通过；`flutter analyze --no-pub` 零告警。实际命令、完整输出和退出码保存于忽略的 `build/chat-scroll-validation/final-tests.json`、`final-analyze.json`。

最终回归覆盖 390dp 窄屏、消息实际底部位于视口内、异步首批历史、切换与快速切换、手动离开底部后新输出保持阅读位置，以及 200 行回复。测试修正了夹具把物理像素与逻辑像素混淆的尺寸错误，未为规避失败而修改产品布局；早期 `tee` 管道的退出码不作为最终证据，最终使用 subprocess 实际返回值。
