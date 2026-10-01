# CLI模型目录与手动模型（实现、验证与覆盖安装完成）

用户明确放弃之前额外OAuth授权的目录方式，改为复用已有CLI；同时要求手动
输入模型名。Codex默认查询切换至所选host/container/user的短生命周期
`codex app-server`，只initialize/initialized/model/list（分页后关闭）。
不读取/恢复/创建聊天、不发送推理，不复制或替换登录，未删除既有授权数据。
官方接口说明：https://learn.chatgpt.com/docs/app-server#list-models-modellist。
CLI列表受版本和缓存限制，并非保证实时的云端账户权限目录；支持手动刷新。

ChatRunSettings新增可选customModel bool，旧JSON默认为false，无破坏性迁移。
明确的手动输入允许不在目录中的modelId，但必须非空、<=256且无空白/控制字符。
仅向ACP已经声明的model配置发送，响应必须确认同一个currentValue；未确认、
拒绝、没有模型配置接口时明确失败，不能乐观保存/自动换模型。推理/权限校验不
放宽；CLI仍使用既有结构化模型设置路径。列表选择仍保留原有成员校验。

UI仅由原AgY Valhalla / gemini-3.8-flash-high / high完成：共享运行设置中
模型列表/手动输入切换，空列表亦可输入，刷新/重开保留手动名；ACP页移除额外
授权回调/按钮。可选共享弹窗授权参数保留兼容，但实际ACP页不再使用。
主Agent没有编辑UI；未新增依赖、独立页面或授权替代机制。

OpenCode main/small `opencode/mimo-v2.6-flash-free`完成默认CLI通道、容器用户、
分页/关闭、旧JSON、持久化、手动RPC确认/拒绝、首发意图保留及校验隔离验证。
共享弹窗控件28通过，专项145通过，全量1598通过、17既有环境跳过、0失败；
多语言生成、格式检查及静态分析通过。未修改真实凭据、远端历史或发送真实推理。

新release APK：`build/app/outputs/flutter-apk/app-release.apk`，123190191字节，
mtime 2026-10-01 11:41:48 UTC（19:41:48 +0800），SHA-256
`32c3478d689fefe7173586e1f9a4ce1bed16b3b105a56c338383d068d91514a3`。
版本1.0.0+1，沿用Android Debug签名，不是商店签名。18:51旧包已保存于
`build/apk-backup/*20261001T114030Z.stage4`，可恢复，未删除。
19:42:13 +0800覆盖安装至现有ADB模拟器 `127.0.0.1:14251`成功，无卸载或清数据；
首次安装时间保持不变，启动后PID24879且MainActivity前台；有限观察窗口无
fatal/ANR，模拟器JDWP/图形警告及其他进程日志不等于应用崩溃。
真实远端模型是否可用仍由用户验收，模拟不等于真实推理成功；CLI目录受版本与
缓存限制，手动输入不能赋予账户权限。证据见
../../agent-workflow/cli-model-catalog-verification.md。未commit/push。
