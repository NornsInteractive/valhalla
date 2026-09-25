# 2026-09-18：Agent 会话及下载修复

本记录取代上一轮“旧会话手动绑定服务器”的产品约定。所有展示层及原生通知展示由 Valhalla 历史 agy 会话维护，模型 Gemini 3.8 Flash、推理 high；后端开发者不直接修改 UI。

## 产品约定与接口

- 切换 Agent 不创建历史记录；`createNewSession()` 只清空当前选择，进入未保存草稿。`activeSessionId == null` 不再回退到第一条记录。首次合法发送才保存会话；历史列表保留。
- `AiChatState.shareAgentSessions` 默认 false；`setShareAgentSessions(bool)` 按服务器保存。`state.sessions` 已过滤服务器，关闭共享时再过滤参与 Agent；开启时切换 Agent 可在同一本地对话继续。
- `ChatSession.agentContexts` 按 Agent 保存远端会话 ID 与已同步消息数量；共享不迁移权限、工具执行或认证。接手及再次切回时，仅同步尚未接收的用户/助手文本。
- `participantAgentIds` 保留历史参与者；`ChatMessage.agentId` 标识实际响应者。关闭共享不删除记录或拆分会话。
- 每条会话均需删除确认，最后一条也可以删除；正在生成的活跃会话禁止删除。
- 添加 Agent 自动归属当前服务器。旧数据只迁入第一次选中的服务器，备份键为原键加 `_before_owner_v2`，归属标记 `valhalla_legacy_owner_v2`；不可在其他服务器重复迁移。
- 认证方式选择使用 `serverId::agentId` 键，不能跨服务器复用。
- `SftpNotifier.downloadFile(item) -> Future<String?>` 返回入队任务 ID，不代表完成；`openCompletedTransfer(id)` 仅打开完成的下载。
- 下载默认持久目录，文件名跨平台清洗、同名编号及并发预留；新增下载写 `.part`，成功后改名，失败/取消不能打开为完成文件。
- 平台通道 `valhalla/downloads`：`openFile({path})`；`reportProgress({id,name,path,bytes,total,status}) -> bool`。进度限频 500ms，终态强制报告。`SftpState.downloadNotificationsUnavailable` 用于提示系统通知不可用，不能影响传输。
- 展示层删除“入队即下载成功”的 Snackbar，允许连续加入任务，约 300ms 图标飞入传输入口；减少动态模式使用高亮。Android FileProvider 限定应用下载目录，系统 chooser 只授予临时读权限；桌面使用系统打开方式。

## ACP 审批根因与兼容修复

本地回归发现 `acpd 1.0.0` 的 `RequestPermissionResponse.toJson()` 输出扁平 outcome。ACP v1 需要 `result: {outcome: {outcome: selected, optionId: ...}}`，旧允许审批测试只搜索字符串，未检验层次，遗漏了该问题。SDK 边界使用窄范围 response 子类补上外层 outcome，仍复用 SDK 编解码、请求相关性与原始 optionId。未来 SDK 修复后可移除该兼容类，但必须保留线格式断言。

规范：[ACP v1 工具审批](https://agentclientprotocol.com/protocol/v1/tool-calls)。UTF-8 接收另改为流式解码及逐行分帧，覆盖中文分包、CRLF、尾帧及错误帧，stderr 不进入 JSON-RPC。

## 内置预设

Claude 检测 `claude auth status --json`，解析 `loggedIn`；登录 `claude auth login`。命令不支持或响应格式无效保持认证 unknown，不把它当已登录或未登录。AGY 登录使用交互启动 `agy`，没有机器可读状态命令，检测不得伪装为已认证。

Codex 旧 ACP 上游已归档，新安装使用 `@agentclientprotocol/codex-acp`。仅修复旧默认安装配置，保留自定义命令，不自动安装或升级服务器组件。参考：[旧上游迁移公告](https://github.com/zed-industries/codex-acp)、[Claude CLI](https://code.claude.com/docs/en/cli-reference)、[AGY 认证流程](https://www.antigravity.google/docs/cli/install)。

## 验证状态

接手本轮基线 637 项测试通过。后端分享接续、文件名并发与 UTF-8 分帧已通过专项测试；审批线格式断言曾明确失败并据此修复。七项对应代码已实施；真实 Codex 审批、设备通知及 Windows/Linux 原生构建验收未完成，不宣称跨平台正式交付或发布就绪。

恢复开发验证：`flutter test test/core test/data test/infrastructure` 共 484 项通过，包括允许/拒绝/取消的嵌套回包、共享上下文 JSON 往返以及下载 `.part`→正式文件→系统打开调用的链路。服务器切换后异步保存/删除/共享设置不会回写其他服务器状态。期间全量 648 项通过，但后续新增测试和 AGY 下载展示仍在修改，该数字不是最终门禁。

构建环境：Flutter 3.44.2、Dart 3.10.0、Android SDK 36 工具链可用；`flutter doctor -v` 提示缺少 GTK 3 开发库，Linux 构建门禁不可用，本机亦不能替代 Windows 构建。无连接的 Android 真机；通知权限、进度展示及选择应用仍需设备验收。

下载界面及 Android 原生桥接落地后，最终 Flutter 全量 **658 项测试通过**（含新增通知跳转两项），静态分析无问题，Android debug APK 构建通过；格式只读检查 152 个文件无变化。Linux 实际 `flutter build linux --debug` 因缺 GTK 包停在 CMake 配置阶段，不属于编译通过。Windows chooser/通知原生代码由指定 AGY 会话修改，但本机未编译，不能用 Flutter 测试替代原生桌面验收。

APK：`build/app/outputs/flutter-apk/app-debug.apk`。真机验收须覆盖首次通知授权/拒绝、单独禁用下载渠道、中文及同名文件、连续下载、减少动态模式、完成文件系统选择器，及 Codex 真实允许/拒绝审批。本轮未安装、升级任何远端 Agent，未修改自定义命令或提交 Git。

AGY 已完成 UI 格式化及 Windows 通知点击/销毁清理并退出，退出提示仍指向 `ec81a4be-7543-45ee-8658-f68966f57d3b`；本轮保持 `gemini-3.8-flash-high`、effort high、accept-edits。Codex 未直接修改 Flutter 展示文件。保留全部协作者未提交修改。
