# Agent 更新、Codex 运行环境与可配置工具栏

用户确认实施五项计划；每日检查当前服务器全部已添加 Agent。宿主机 Codex
警告后不能正常对话，不能当作仅文案问题。保留既有脏工作区；本轮不升版本、
不打包、不安装、不推送发布。UI/ARB只由原 AgY Valhalla 会话
`ec81a4be-7543-45ee-8658-f68966f57d3b` / `gemini-3.8-flash-high` / high 修改。
验证、测试编写、格式、生成与分析交 OpenCode 明确免费模型，优先
`opencode/mimo-v2.6-flash-free`，历史单轮主代理接管例外不沿用。

本轮追加授权：用户已明确允许主代理补齐回归、语言生成与静态验证（免费模型
无法完整交付）；UI仍全部AgY。本轮可通过已有ADB安装和已配置的
`server.krm.cc.cd`做宿主机问题只读排查，先确认设备独占；不升级远端CLI、不
修改凭据/历史，不向当前正在运行的Codex会话发送消息。没有新打包/安装授权。

## 批准契约

1. 文件工具栏：全应用固定动作偏好，9项 upload/create/view/transfers/hidden/
   sort/selection/bookmarks/refresh；默认前4，空集合合法。未固定动作进更多，
   更多始终在右边可达，固定区单行横滚。更多及设置都有配置入口，保存/取消/
   默认。不加拖拽排序；不改变搜索、文件行/网格、选择器及权限语义。
2. 名称：新预设与旧枚举显示 Claude Code，旧标识兼容；不覆盖已有用户命名。
3. Codex：统一检测/模型目录/标准ACP的实际CLI、用户环境；只影响Agent启动，
   不修改全局SSH执行。保留CODEX_PATH，日志只含目标/白名单路径/版本/阶段，
   不读写认证/历史正文。已验证标准适配器用CODEX_CONFIG进程级合并初始model，
   不改provider/权限/配置文件；无效JSON报错，不清空。草稿重建仅无session的
   adapter，既有会话仍走官方设置接口。model/list独立进程，无new/load/resume。
   具体远端失败阶段未实测，不以升级或隐藏warning声称已经恢复真实对话。
4. 更新：CLI/ACP分别真实版本/来源/时间/状态。两个会话页每日首次进入触发，
   当前服务器全部已添加Agent、最大2并发；同日成功缓存、失败15分钟退避，
   手动强制检查。发现更新顶部提示，确认目标/组件/当前→目标版本/命令后运行。
   仅识别可靠的官方安装来源，未知自定义程序手动处理，不照搬installCommand。
   新旧Claude ACP包迁移需明确确认且安装验证后才改标准配置；OpenCode合并
   CLI/ACP；AgY CLI用更新机制，受管理ACP按官方元数据验证切换保留旧版本。
   更新绑定服务器连接身份、实际容器、用户/二进制；目标变化计划失效。生成/
   审批/登录/交互终端中禁止更新，新操作不能撞入更新。保留退出码与流式脱敏
   日志并复探版本，不凭流结束判断成功。断线核对、不自动重复更新，不sudo。
   成功失效对应能力缓存，不清认证/历史，不自动发送/审批/杀第三方进程。
5. 恢复提示：Shell顶部栏下方浮层，不改变正文几何尺寸/滚动/PTY/焦点；沿用
   已有聚合和重试目标校验。所有页面动态缓存横条与tmux恢复通知一并移出流。
   抽屉/弹窗盖住提示，外围透传；安全操作确认仍可达。不重写重连算法。

## 所有权

- Codex核心：agent_execution_target、codex_native_client、ai_chat_provider、必要ACP适配层。
- 更新核心：新增update模型/service/provider/lock、builtin_agent_preset。
- 偏好核心：新增toolbar动作模型、settings_provider、local_storage_service。
- 主代理：集成非展示门禁、兼容名称、文档、外部协作与结果复核。
- AgY：指定features/widgets和17个ARB；不得修改核心/测试/平台/依赖。
- OpenCode：测试、格式、l10n生成、静态/全量验证；不得改业务或UI补丁。

## 验收与状态

验收范围：偏好全空/未知重复/重启/备份/写失败；来源识别/每日去重/退避/目标变化/
忙碌/非零退出/断线；Codex不同PATH/HOME/初始模型/配置保留/历史不重建；浮层
各恢复阶段页面Rect/滚动/焦点/终端rows-cols不变，320dp/2x字号/RTL/桌面。
生产服务器只读；真实升级必须隔离测试目标，当前Codex会话不能用来发消息验证。
首批偏好与检查记录新增19项测试由OpenCode MiMo执行通过。后续MiMo与Big
Pickle限流，Step 5不可用；免费Cat Jam补充的测试覆盖不足，已按用户本轮
明确授权补齐并执行真实断言。最终完整`flutter test --no-pub --concurrency=4
--reporter expanded`：**3849通过、30既有环境项跳过、0失败**，退出码0；全项目
`flutter analyze --no-pub`零问题。语言生成、17个ARB/1740基础键一致性、格式和
差异检查通过。完整门禁先发现并修复UI溢出及缺失的新provider测试夹具，再重跑
全量通过；未删除／放宽原行为断言。日志位于`/tmp/valhalla-agent-updates.aOvCbg/`，
最终记录`full-test-final-2.log`、`analyze-final-3.log`、`l10n-final.log`。
UI焦点恢复、320dp/2x字号/RTL溢出、更新组件取消全选、失败后只读重新准备且
重新确认等问题均由AgY修复。更新管理专项39、Dashboard/compact专项8、主壳层
几何专项10、恶意归档实际执行专项9均通过，已包含在全量，不能重复相加。
宿主机旧ACP与真实远端升级的未验收边界见下；不以测试通过冒充远端对话恢复。
本轮未打包、未安装、未推送发布。用户随后明确设备可独占：ADB检查已有两个
包，新包`com.norns.valhalla`（1.0.6+7）仅有SFTP-Perf-Fixture；旧包
`com.antigravity.valhalla.valhalla`（1.0.6+4007）保存krm/server.krm.cc.cd:31415。
旧包连接已恢复，其Agent管理只列AgY、状态已就绪／已登录，没有Codex配置。
用户允许后，仅在旧包添加`OpenAI Codex-ReadOnly-20261015`临时配置，检查路径、
登录状态、版本和独立模型目录；检查结束已删除该临时配置，管理列表恢复仅有AgY，
会话页恢复选择AgY。未安装／升级远端程序、登录、发消息或修改凭据／历史。
旧包导航与连接检查不代表本轮新UI或宿主机Codex对话已验收。

### 真实宿主机只读证据与边界

- CLI路径`/usr/local/bin/codex`，实际版本`codex-cli 0.162.1`；原登录检查
  `codex login status`成功，报告ChatGPT登录。
- ACP路径`/usr/local/bin/codex-acp`；ACP初始化报告`0.16.0`，实际执行
  `codex-acp --version`返回不支持该参数。不得将其写成成功的版本命令结果。
- 旧包独立CLI目录查询已返回`GPT-6.1-Sol`等模型，没有发送新消息；查询成功不
  等于旧ACP运行时能够使用这些模型，也不等于账户额度或权限已验证。
- 临时复合版本探测因ACP不支持参数而失败，旧包将该失败映射成“未登录”；这不
  代表凭据真的失效。临时配置已删除，未执行任何登录操作。
- 本轮新更新服务对ACP读取路径和npm包元数据，不依赖其支持`--version`。
  来源未知时显示不支持自动更新，不冒充未安装，不自动替换。
- 本轮对已验证`@agentclientprotocol/codex-acp 2.0.0`统一CLI路径和初始模型；
  官方旧`0.16.0`源码内嵌`rust-v0.137.0` Codex库，并不使用新适配器的外部CLI
  运行链路；宿主机版本行为与其相符，但还没有核实二进制来源，不能宣称故障已修复。
  需要确认旧适配器安装来源，并经用户确认后更新／安装兼容适配器再验证真实对话。
  当前授权只读，未擅自进行这一步。
- 证据在本轮临时目录：`adb-codex-diagnostics.xml`、
  `adb-codex-runtime-settings.xml`、`adb-codex-models.xml`、
  `adb-codex-versions.xml`及`adb-cleanup.xml`。原有历史错误不是本次发消息结果。

## 兼容迁移与回退

- 工具栏偏好是新增可选key：旧安装缺值使用4项默认；显式空列表不能迁移成默认。
  新版本读取并保存稳定枚举名，旧版本忽略新key。失败写入不提交内存新状态。
- 更新检查记录使用独立schema=1与目标哈希；不包含可执行计划、凭据或授权。
  未知schema按缺失记录只读重查；不删除旧记录，不回放更新命令。
- Claude旧版读者保留原adapter和旧installCommand，新建预设使用当前官方包。
  只有原标准旧配置才提供迁移确认；先装新包并验证版本，后保存两个新字段。
  不卸载旧包、不改会话/认证；配置保存失败显示中断，不冒充已迁移。
  需要回退时可在Agent编辑中恢复原`claude-code-acp`与旧安装命令，旧包仍在。
- npm/官方CLI更新本身不承诺自动降级；出现部分成功/断线后只读检查实际版本，
  用户重新确认后才再更新，不自动重复或删除文件。受管理AgY ACP保留旧版本
  目录；旧launcher可按旧版本重新指向，不能以清理目录代替回退。
