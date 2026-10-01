# 实时账号模型目录与 ACP 草稿能力（自动化验收与 release 安装完成）

## 最终交付（2026-10-01）

原 AgY Valhalla / Gemini3.8Flash High 完成UI及复核；OpenCode主/辅助均为
`opencode/mimo-v2.6-flash-free`，完成新增22项控件测试、相关70项、全量
1564通过/17既有环境跳过/0失败，静态分析零问题、多语言生成成功及12个相关
源码/测试格式检查零改动。
发布验证详见 [最终报告](../../agent-workflow/live-models-draft-release-verification.md)。

release APK：`build/app/outputs/flutter-apk/app-release.apk`，123304927字节，
2026-10-01 10:51:48 UTC生成，SHA-256
`1dfe9ab4e59b93e3234300ece10ec2cffcb2390ae584cda0732cbb728d4b0f35`。
版本1.0.0+1，沿用Android Debug证书，尚非商店签名；旧包可从
`build/apk-backup/`恢复。ADB设备127.0.0.1:14251于18:52:10 +0800
install -r成功，未卸载/清数据，启动PID26523和前台Activity稳定，有限日志
窗口未发现fatal/ANR。没有执行真实授权、推理或修改远端会话。

最终格式补查发现的3个UI文件已由OpenCode机械格式化，无展示或语义修改；
随后重新全量验收、构建和安装。上方为最终包，18:39的中间包已备份。

用户验收：在实际服务器/容器目标确认独立授权，刷新实时目录；草稿打开命令/技能；
选择模型时确认适配器支持，不支持的模型应明确提示，不能承诺云端目录中的每个
模型均可由当前ACP适配器设置。实际目录403原因及Docker -32603根因尚未真实验证。

以下为实施过程和历史快照，旧“尚未打包/阻碍”记录不代表当前交付状态。

## 用户批准与边界

采用独立账号模型接口，禁止为发现模型新建/恢复/读取会话。用户明确允许新增
独立“授权模型目录”入口；必须由用户确认登录，不替换 Codex 原有认证。
本轮同时修复 Docker ACP 草稿没有命令/技能入口、切换模型出现 -32603 的问题。
主 Agent 只改业务；UI 仅原 AgY Valhalla 会话、Gemini3.8Flash/high；测试、
格式、分析、打包、ADB 均交给 OpenCode，不提交/推送，不操作真实 Codex 会话。

## 已写入业务代码（尚待本轮验收）

- Codex ACP 模型发现改为所选宿主机/容器/用户的 HTTPS
  `GET https://api.openai.com/v1/models`，不再用 app-server/model/list 当实时来源。
  解析账号目录 models[] / visibility=list / slug / display_name，保留顺序去重。
  Node 仅返回模型元数据或固定错误码，令牌/原始 HTTP 错误留在远端。
- 独立授权使用手机 127.0.0.1 随机端口回调，授权码通过 SSH 发给原执行环境；
  远端 Node 原生 HTTPS/crypto 执行 OAuth state/nonce/PKCE、JWKS RS256 验证、
  issuer/audience/azp/expiry/subject/授予 scope 校验。每服务器+Agent 独立目录：
  `~/.config/valhalla/model-auth/<hash>/`，0600 原子保存，绝不写 Codex auth.json。
  和现有 Codex 账号绑定，错误账号拒绝；按需刷新串行锁，不自动注册/登录。
  用户显式重新授权可更新绑定；账号变化时先移除旧授权令牌，再交换新授权，
  避免交换失败把旧账号令牌重新标记为新账号。刷新锁内再次检查账号和 scope。
  用户取消或切换目标关闭回调和 SSH，最长五分钟。Node 不存在时明确失败，
  不自动安装；没有自动真实推理验收。
- prepareRunSettings 的 ACP 握手成功后，即使模型目录请求失败仍可打开设置，
  modelCatalogError 单独呈现；缓存和上次成功查询时间保留并标为 stale。
  既有已保存模型仍可用 ACP 真实声明的选项验证，不让 HTTP 失败阻断普通对话。
- prepareComposerCatalog 独立使用 Codex skills/list，不创建聊天或发送 prompt；
  修正实际 data[].skills[] 嵌套结构，支持 forceReload、禁用项过滤与去重。
  合并真实 $skills 和已宣告 ACP /commands，不臆造 CLI TUI 命令。
  通用 ACP 没有已接入的会话外命令清单，不能承诺未建会话就有所有远端命令；
  UI 交接要求草稿入口常显，并提供本地设置/目录操作及诚实空态说明。
- 云端模型目录与 ACP 可设置项不是同一能力。未被 ACP 声明的模型明确
  ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER，不再盲目发送设置 RPC。
  -32603 区分 session/new/load/resume 和 set_config_option 的诊断阶段；
  无法恢复历史时不新建替代会话。其他协议错误保留类型与认证流程。

## 已获得证据与未解决条件

当前环境 codex-cli 0.159.3、codex-acp 2.0.0。只读检查现有登录方式为 ChatGPT，
不含 direct-plan grant；使用现有访问令牌请求公开模型目录返回 HTTP403。
只打印状态、类型和固定诊断，不输出令牌、账号身份或原始错误正文。
403 原因尚未确定，不能归因于 Docker 或承诺重新授权必能解决网络拒绝。
实际新目录、浏览器授权、用户 Docker -32603 的真实根因均尚未远端验收。

官方示例 SDK @siwc/local 来自 devkit，npm registry 查询 E404；没有安装虚构
依赖，本轮用 Node 标准 OAuth/crypto 原语，必须由 OpenCode 做针对性安全测试。
刷新锁遭 SIGKILL 可能保留；失败关闭、不擅自抢锁，后续需明确恢复流程。
只做最小目录缓存（当前目标内存缓存），不做后台轮询或远端常驻服务。

## UI/交付阻碍

最新状态：已证明原会话交互式控制台可正常响应，历史也有 print 失败探测的
READY；不能把那些 EOF 认定为服务不可用。原会话 Gemini3.8Flash High 已完成
UI 白名单交接及审查修正（草稿入口、动态/重试菜单、独立授权/取消、模型目录
错误/空态、目标和存活检查、await保存）。主 Agent 新增 Android 原生官方授权
浏览器桥接，OpenCode 模拟10项通过；新增 Widget20项、相关68项通过，静态分析
零问题；当前最终补验/全量/构建门禁进行中，尚无新包/ADB。
CLI --conversation 与 --prompt-interactive 组合曾意外创建另一会话，已立即退出，
未删除历史；三处窄修正已交回原 Valhalla 阅读复核并接收。后续只使用先启动原
交互会话再手动发送任务的方式；退出恢复 ID 已确认仍为原 ec81a4be。
详见 agent-workflow/live-models-draft-ui-status.md 和 live-models-draft-release.md。

以下 print 路径阻碍为历史记录，已被交互路径的实际响应/改动证据取代：

最新重试（用户要求继续、仍只用原会话）：交互 CLI 日志/退出恢复命令及 print
JSON 均确认原 ec81a4be-7543-45ee-8658-f68966f57d3b，模型 Gemini3.8Flash High。
会话身份已恢复，但交互工具无返回、同 ID 非交互退出1：订阅落后10秒，
上游 streamGenerateContent EOF。UI/ARB 修改时间未变，仍没有新包或 ADB。
不再将旧 ID 不符当作最新阻碍，不切换新会话/清空历史绕过；后台缺失验收交给
OpenCode，见 agent-workflow/live-models-draft-remaining-tests.md。

以下是前次记录：

AgY print 调用订阅中断；交互调用虽显式 --conversation 原 ID，却报告当前
9d585a49-698f-4f62-a087-caa707a7791e，与允许的
ec81a4be-7543-45ee-8658-f68966f57d3b 不同，模型 Gemini3.8Flash High 已核对。
AgY 已停止，没有本轮 UI/ARB 修改。主 Agent 不绕过限制修改界面。
因此授权按钮、草稿菜单入口、模型错误/空态及下拉兼容尚未交付。
OpenCode 只能进行业务验证，UI READY 前禁止构建/删除旧 APK/ADB 安装。

交接：agent-workflow/live-models-draft-ui.md、live-models-draft-ui-status.md、
live-models-draft-tests.md。最终验证以本轮实际报告为准，不复用前轮通过数。

## 本轮自动化结果与剩余门禁

最新继续补验：Provider 通知合并用例复现失败（只剩 $deploy，没有后来公布的
new_plan）。prepareComposerCatalog 缺事件订阅，主 Agent 仅在 _acpSub 为空时
附加控制订阅，保留已有对话监听；未改 UI。OpenCode 相关47项全部通过：
Provider32、诊断6、恢复9；格式和静态分析通过。新增证明包括草稿 Docker/cwd、
通知合并、并发准备共享传输、切换后迟到结果丢弃、技能失败不阻断发送、草稿
配置不发RPC、模型先于推理并按新选项过滤，以及 -32603 的失败阶段。
独立 Node 模拟安全执行已补充21项，执行实际生产脚本并模拟 SSH/HTTP/文件系统：
覆盖签名/JWKS、state/nonce、账号重绑失败清旧令牌、锁后身份/权限复查、刷新
原子写入和不安全存储拒绝，不读取真实账号、不连接真实服务。主 Agent 另修复
手机授权监听吞掉本地非法端点/缺失状态错误码的问题，仅保留两个受控固定码。
OpenCode 最终授权专项40通过，静态分析零问题，全量1532通过、17跳过、0失败。
日志 /tmp/opencode/lmd2-authfocused.log、lmd2-analyze.log、lmd2-fulltests.log；
详见 agent-workflow/live-models-draft-remaining-verification.md。
模拟未证明跨进程锁竞争、信号清理或真实服务；不安全目录刷新可能先消耗一次
远端令牌刷新再拒绝落盘，可能需要重新授权，不能声称所有安全路径已完整验收。
原 AgY 无工具重试仍因订阅落后8秒/上游EOF退出1；授权入口和草稿 UI 未交付，
没有本轮新 APK/ADB。以下为前次快照结果，不是最新缺失项。

OpenCode 主/辅助模型配置均为 `opencode/mimo-v2.6-flash-free`。前次专项194通过；
全量1495通过、17既有环境跳过、0失败；静态分析零问题，6个业务文件格式检查零改动。
验证涵盖账号目录解析、通道关闭、嵌套技能解析、模型不支持时不发 RPC、
目录失败时设置仍可用、账号缓存失效以及手机授权取消/回调单次使用等。
不能把这些通过数视为新功能全部验收：远端 Node OAuth/JWKS/刷新逻辑目前
只有静态断言，缺执行模拟验证，账号重新绑定失败不复用旧令牌仍需执行回归。
prepareComposerCatalog 的 Provider 集成、与设置并发打开同一传输、迟到结果
及后续 ACP 命令通知合并也仍需专项验证；已有 adapter initialize 合并测试
不能代替这些 Provider 测试。真实授权、真实目录读取和用户 Docker -32603 均未验证。
AgY 会话限制未解决前不做 UI；剩余门禁完成前不打包、不 ADB 安装。

## 官方依据

- [账号模型目录与缓存限制](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [注册、OAuth 验证和凭据存储](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)
- [账号隔离、刷新与凭据保护](https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions)
- [Codex skills/list 格式](https://learn.chatgpt.com/docs/app-server#skills)
