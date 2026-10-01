# 独立模型查询（业务自动化验收完成，UI/新APK未交付）

## 本轮用户约束

模型列表必须通过 Agent 提供的独立接口获取，不得通过已有会话获取。
因此本轮覆盖 2026-09-30 ACP 可用性文档中的模型来源约定：
允许 Codex 官方 app-server `model/list` 用于只读模型发现，对话仍使用 ACP。
不更改账号、命令、skills、额度来源；不导出凭证、不升级远端。

## 当前实现

- 复用 `CodexNativeClient` 与 acpd Connection，不引入新依赖或自研协议。
- 在所选 Agent 的宿主机/Docker 容器和用户环境启动短生命周期 app-server，
  `initialize` → `initialized` → `model/list`（分页）→ 关闭。
- 不调用 `thread/start/read/resume/list`，不发送 prompt，不读写会话历史。
- ACP 设置打开和刷新仅 initialize，模型从独立查询获得；不因为查询模型
  重建正在使用的 ACP 连接。真正修改设置/发送时才按需建立原会话。
- `config_option_update` 仅提供当前选择、推理/模式/其他配置及应用结果，
  不作为模型清单来源。接口模型可通过 Agent 声明的 model 配置项尝试切换，
  ACP 报错不能当作成功，不构造不存在的配置项。
- 查询失败保留上次列表并标为过期；切换服务器、Agent、执行用户、CLI 命令
  或会话时隔离迟到响应。未知 Agent 不读取历史补全，明确不支持独立查询。
- 分页显式排除 hidden 模型、去重、识别循环 cursor/格式错误，最多100页；
  SSH 开通15秒、初始化30秒、目录查询整体30秒上限，退出时关闭查询进程。

## 数据新鲜度边界（尚未解决）

`model/list` 是独立接口，但官方明确在部分 provider 配置下可能返回内置或缓存
目录，不能保证云端当前账号权限，也不能把接口调用时间冒充云端目录更新时间。
本轮解决「不依赖历史会话」，不宣称解决所有旧目录/账号权限问题。

OpenAI 官方 Sign in with ChatGPT 文档提供使用对应授权 access token 请求
`GET https://api.openai.com/v1/models` 的账号目录方案；这属于特定授权流程，
不能假定现有远端 Codex 登录 token 兼容，也不能把 token 传回手机或记录日志。
接入云端目录前必须确认该 Agent 的 provider、登录方式与兼容的官方授权接口。
当前不读取远端认证文件，不添加未经确认的 endpoint 或私有 backend-api 调用。

来源：
- [Codex App Server：Models](https://learn.chatgpt.com/docs/app-server#models)
- [官方账号目录与缓存说明](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)

## 验收

测试维护、格式/分析、全量测试、APK 和 ADB 由 OpenCode 执行。
主/辅助模型 `opencode/space-bunny-free`（用户已授权的免费替代模型）。
UI/ARB 未由主 Agent 修改。不提交、不推送、不操作真实 Codex 会话。
执行要求见 `agent-workflow/independent-model-query-tests.md`。
OpenCode 最终专项104项通过；全量1447通过、17既有环境跳过、0失败，
flutter analyze 零问题。包含SSH开通超时后迟到通道关闭的虚拟时钟回归。
没有操作真实远端Agent会话；真实目录新鲜度与模型实际可用性仍待用户验证。

AgY 登录/模型已确认，但指定原会话的CLI订阅反复中断，交接中的模型下拉
兼容/空态文案未实现，主 Agent 未代改UI。本轮不能视为完整交付。
首个OpenCode执行器在读取新增UI门禁前启动了构建，主Agent中断了该构建，
未执行ADB安装。被清理的上一轮生成APK已由OpenCode从完整备份恢复并核验：
SHA256 `1af486e7dec5c32ea1cc6ba487d2a4f1a1e3b60a3208d97fe381ca571610bdb3`，
123108211字节、恢复后mtime2026-09-30 16:12:32 UTC（保留备份时间），签名一致。
上一轮原始构建输出时间是16:12:14 UTC；恢复不改变构建来源，不冒充新包。
这是上一轮稳定包，不包含本轮改动；不得标为新APK。用户设备数据未清理。
