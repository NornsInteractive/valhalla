# Valhalla - 模块详细设计与分层架构说明书

## 2026-10-15 Agent 更新与执行环境（本轮验证中）

更新检查经独立 `AgentUpdateService` 读取版本和官方目录，不复用安装命令执行
升级。`agentUpdatesProvider` 只在实际进入 ACP／CLI 页面后启用每日检查，检查
范围为当前服务器已添加的 Agent，并发上限为 2；失败退避 15 分钟，手动检查
可绕过缓存。持久化报告不保存可执行命令、凭据或确认计划；中断只重查不重放。

升级分 prepare／确认／apply：计划绑定连接身份、Docker 实际 ID、执行用户、
HOME、程序来源和版本，执行前再次核对。服务器级互斥锁覆盖安装、登录、生成、
审批和交互终端；释放锁前先使同服务器 CLI／ACP 能力失效，成功后再刷新，不
删除现有消息、认证或历史。未知来源保留手动处理，禁止猜安装方式或隐式 sudo。
旧 Claude 标准配置保留原适配器，只有确认安装并验证新适配器后才更新两项
配置，旧程序不卸载；新添加预设使用当前适配器。

Codex 检测、模型目录与运行统一真实可执行路径、选定用户及 HOME。标准适配器
已核验版本的初始模型使用进程级配置合并，不改磁盘配置；未知自定义适配器不
注入猜测参数。已有会话继续走设置接口，独立模型目录查询不创建／恢复会话。
快速切换草稿以代次隔离旧异步请求，未初始化的旧连接同样必须关闭。

文件工具栏偏好新增稳定枚举列表：缺值使用四项默认，空列表合法，未知值忽略、
重复值去重，写失败不更新内存。恢复通知属于 Shell 的定位浮层，不占正文空间。
详细协议、来源与回退限制见[本轮实施契约](../../agent-workflow/2026-10-15-agent-updates-toolbar.md)
和[更新 API](../../agent-workflow/2026-10-15-agent-updates-api.md)。本节不代表真实
服务器升级、宿主机对话或新包设备验收已经通过。

## 2026-10-15 核心体验补充（已实现，设备详细验收进行中）

六项实现已完成；最终测试 3685 通过、30 跳过，静态分析零问题。正式
1.0.6+7 APK 已完成本地构建及保留数据 ADB 覆盖安装；设备详细检查仍在进行，
不代表全部设备场景已验收。最终证据统一记录于下方实施记录。

传输记录新增可选 `pauseReason`（user/network/appRestart）；旧暂停记录按手动
处理，旧活动记录恢复为应用重启暂停，不由重连自动运行。批量暂停先关闭调度
闸门，批量继续只将捕获的暂停任务排回既有串行队列；启动和暂停确认期间仍
占用调度保护。同 ID 自动重试必须等上一执行器 finally 清理完成后再启动。

恢复排序是既有 ACP/CLI 状态的纯投影，不新建会话仓库；SSH 状态优先，当前
可见页面优先，其余失败、不完整、恢复中。生命周期探活只对相同 connectionKey
合并，换服务器或同 ID 改端点不能复用旧 Future，也不能被旧完成清除新请求。

ACP `ChatMessage.failureCode` 是可选脱敏 JSON 元数据，不进入模型上下文。
旧消息正文保留；新失败不再把原始错误追加为 Markdown。只有收到明确终态才
能证明成功，单纯历史内容回放不能抹掉已保存的失败。流式更新保持其他消息
对象身份，UI 按消息与所需元数据局部订阅，仍使用原 50 条分页和 50ms 合并。

诊断报告与关于界面复用运行应用 ABI，不读取设备支持架构列表；更新服务保留
原架构映射接口。导入导出仍不迁移凭据，不读取旧包私有目录。精确契约与当前
验证状态见[实施记录](../../agent-workflow/2026-10-15-core-experience.md)。

## 2026-10-15 SFTP 大文件后台传输

批量上传／下载经 `IsolatedSftpClientService` 在独立 isolate 内建立自身 SSH
连接，复用原 SFTP 实现；解密、协议解析、前缀完整校验与写盘均不进入 UI
isolate。主线程只传递控制和节流元数据，浏览／终端仍保持原主连接。以下
“共享 SSH TCP”仅描述此前实现，不再适用于生产文件传输。每个 worker 精确
验证主连接已接受的主机类型／指纹；认证快照仅内存保存，断开时清除，禁止
未知钥匙自动接受或失败后回退主线程。取消只影响本任务，上传提交保留保护。
相关验证与 ADB 边界见[本轮契约](../../agent-workflow/2026-10-15-sftp-background-transfer.md)。

## 2026-10-14 传输窗口与新建终端模式

SFTP 已知长度下载使用单个持续 `read`，64KiB 请求／最多 32 个待响应请求，
按序落盘并背压；未知大小保持顺序读取。续传前缀仍完整比对，上传使用独立
SFTP 子通道但共享 SSH TCP，浏览超时只关闭浏览通道。完整 SHA256 校验在
isolate 读取文件路径，界面进度约 150ms 节流，最终字节数强制精确同步。
更新保留平台／应用架构路由、Range 重定向与大小／哈希／证书检查；短流或
瞬态失败最多重试两次，2MiB 写盘缓冲有界，原生 APK 解析使用后台任务队列。
下载源仍是原分发平台到 GitHub 的链路，未部署或宣称 CDN 缓存。

2026-10-15 收紧新建策略：自动新建始终普通 PTY，仅手动点击新建读取持久化
`useTmux`（缺键为 false），只有实际 tmux 会话进入可恢复历史。设置不影响
已有终端；显式选择的启动历史仍优先恢复，确认缺失后回退普通 PTY。普通模式
关闭标签释放 SSH channel，不承诺杀死用户主动脱离终端的后台任务。
历史删除默认仅本地，保存远端名称抑制重新发现；显式终止须连接目标一致、
精确名称与专用 `-L valhalla` socket，未知结果不自动重试。旧快照兼容，
旧版应用若重写快照会丢弃新增抑制字段，回滚前应保留备份。

xterm 的输出／控制器变更显式使 repaint boundary 失效，不靠键盘或焦点变化
刷新；PTY 分配期间完成的首次布局在接通后补发尺寸。验证记录见
[本轮契约](../../agent-workflow/2026-10-14-transfer-performance.md)。

## 2026-10-13 统一远程浏览与应用实例数据（实现／验证中）

`RemoteBrowserSource` 是单次只读浏览租约：捕获服务器客户端、执行用户／容器、
来源与草稿身份，分批返回条目，取消和关闭只释放自身资源，不关闭共享 SSH。
UI 复用主文件页面抽出的浏览展示组件；选择模式不暴露下载、删除等管理操作。
本地文件选择继续使用系统选择器；Docker Agent 工作目录不回退到宿主机。
具体接口见[浏览契约](../../agent-workflow/2026-10-13-browser-core-api.md)。

卸载候选增加配置中保存的整个 `dataRoot`，包括未挂载文件；父子选项按顶层目标
归并，仍保留保护目录、其他实例引用、符号链接和挂载检查。预览、删除前只读遍历
及真正删除重复检查 `.ssh`／`.gnupg` 和目录身份。外部 bind 别名按 mountinfo
底层文件系统坐标核对，不能通过选父目录绕过保护；超时、超深、超量时安全保留。
命令仍只接受确认计划中的不透明目标键，不接受 UI 自由输入删除路径。

新安装配置 `instanceContainerNames=true`：主容器等于实例名，其他容器为
`实例名-服务名`；多服务没有有效 main 元数据时要求显式选择主服务。预览和执行
都检查含已停止容器的命名冲突；Compose project／实例 ID／标签保持稳定，原固定
容器名转为网络别名。旧配置缺字段保持旧命名，不自动重建。此约定覆盖下方早期
“统一移除固定容器名”的新安装规则，不修改旧实例。

应用目录加载按服务器代次、来源 ID+URL、语言合并同一进行中请求；各来源只合并
自己的结果，不用旧快照覆盖其他来源。系统语言变化触发新代次，晚到结果失效。
本轮代码未通过完整门禁前，不沿用上一轮构建／ADB 结果作为验收。

## 选择性卸载与原生 Jellyfin（2026-10-12 新迭代）

`ApplicationCleanupHelper` 负责只读预检和显式选择后的安全清理；选择只传不可编辑
的预览键，不传任意路径。`ApplicationTask` 增量持久化卸载完成标记和逐项目结果，
旧记录缺字段仍兼容。目录身份、共享引用与目标身份在执行前重新检查，缺能力拒绝
清理。失败清理须新预检与确认，不能再次执行 compose down。

`NasNativeInstallService` 提供 prepare／execute／reconcile 与阶段流，独立保存按
SSH连接身份绑定的任务；不是旧 Docker 安装服务的新枚举分支。新增原生功能和清理
尚待 OpenCode 回归与隔离 VM 验证，不把代码落盘当成安全验收通过。

## 应用中心易用性增量

复用现有 Provider／独立 worker。目录刷新只替换成功源，空磁盘缓存不清空
内存；来源以 ID+URL 匹配保留，服务器错误与来源错误分离。前台恢复复用
refreshServer singleflight，不启动新任务。UI 用局部回调在现有三页签跳转，
任务详情读取已限长 logTail；不引入流程框架或全局事件总线。设计及目标检查
要求见[AgY 交接](../../agent-workflow/2026-10-12-app-center-polish-ui.md)。

## 2026-10-12 稳定性与媒体增量

dartssh2 4.1.0 本地依赖窄补丁见 `packages/dartssh2/PATCHES.md`，不改共享包缓存。
SFTP/subsystem 请求等待 acceptance，发送失败仅完成同一 Future；终端延迟输入／
resize／流回调验证会话代际，ACP 文件关闭观察异步失败。NAS 分页、离线任务与
校验细节见[媒体架构](../02-architecture/04-nas-streaming-architecture.md)。
文件最近目录按服务器持久化，失败重试重新验证来源类型/大小/mtime及服务器。
应用状态读取 Docker inspect 结构字段；安装检查现有父目录文件系统剩余空间，
更新比较仅暴露发生变化的分类，不显示环境变量秘密。UI 契约见本轮 AgY 交接文档。

## 2026-10-12 实验性应用中心

`application_center.dart` 为目录、实例、配置、单次确认计划和任务契约。
`ApplicationCatalogService` 解析官方 v2 envelope，处理商店前缀下 `/apps`
资源；官方本地化索引可能只有 ID 与翻译，必须合并完整 v2 index.json，仅覆盖
title／tagline，不替换安装地址或架构。完整本地化索引继续使用 ETag；翻译片段
的 ETag 不能证明基础目录未变，不用于跳过基础目录获取。解析仍在 isolate。
HTTPS、重定向、大小、结构受限，模板及图片磁盘
缓存有界。`content_hash` 仅变更标记，不伪装为 SHA256 完整性验证。
`ApplicationComposeService` 转换有界 YAML，拒绝特权／设备／宿主命名空间／
外部共享卷及相对宿主目录；移除固定容器名，为实例增加隔离项目名与标签。
端口、数据和挂载、变量／环境由向导确认，用户值中的 `$` 转为 Compose 字面值。

`ApplicationDeploymentService` 绑定 SSH 客户端、机器身份及 Docker daemon；
确认计划五分钟过期且仅可执行一次。秘密不存本地 Preferences，私有远端配置
使用原始受限 SSH 读取，避免诊断脱敏改变配置。应用数据独立于私有控制目录。
先落盘本地任务意图，再以 `setsid` 运行受控 worker，服务器 `flock` 串行操作；
状态原子写入、日志 256KiB 上限、读取尾部 64KiB。记录 PID／启动令牌／boot ID，
禁止把退出或重启后的旧进程误认为仍运行。取消只在安全检查点，不杀应用过程。
更新前保存旧实际镜像 ID 与配置，可手动恢复；不回滚数据库或自动删卷。

`ApplicationCenterNotifier` 保留每台服务器的列表和任务，连接代次隔离异步
返回、合并刷新期间新提交的任务；只在前台／已连接／有进行中任务时轮询。
默认复用 `NasSshTunnelService` 的本地 HTTP 转发，HTTPS 直连不降级 TLS。
导航 `appCenter` 固定索引 10，实验关闭时沿用既有过滤与禁用占位机制。
验证边界及外部代理分工见[实施台账](../../agent-workflow/2026-10-12-app-center.md)。

## 2026-10-11 核心稳定性增量契约

`SftpState.filteredFiles` 复用现有不可变 `files` 列表的投影，以弱引用键
保存一组搜索／隐藏／排序／根目录参数对应的只读结果。收到新目录列表或
过滤参数变化时重算；进度、错误、加载状态和视图切换不会重复排序。调用方
必须替换原列表，不能原地修改；不增加目录持久化缓存或网络请求。UI 的滚动
存储按连接身份、目录和视图隔离，同路径刷新保留位置，换目标／目录清除选择。

ACP 继续使用已有 50ms 流式刷新与有界历史分页；同会话的 `messageOffset`
下降表示向前翻页，不扫描完整消息列表。首次空摘要加载出消息后定位最新，
阅读旧内容时不强制跟随流。延迟滚动复验组件存活、会话、Agent 及连接身份。
模型、审批、取消、恢复仍复用已有协议；不重发用户提示或审批。

更新文件的打开操作合并为一个进行中任务。异步大小／SHA256 校验后，原生
打开前再次核对 Provider 存活、发布与下载代次、路径及包身份；过期操作不
启动安装器。沿用原 ABI／签名校验和分发平台架构标识，不新增下载器。

`AppDiagnostics.recordTiming` 复用现有本地有界日志，记录
`timing.connection.resume`、`timing.acp.initialize/history/recovery`、
`timing.sftp.directory`、`timing.updates.check/download`。字段仅固定结果、
毫秒时长和可选数量（下载时为字节数），不记录服务器、路径、账号、正文或
凭据；队列上限 32，沿用脱敏和文件轮转，不自动上传。
实测与未验证边界见[本轮台账](../../agent-workflow/2026-10-11-core-stability.md)。

## 历史交付：2026-10-11 编辑器与系统操作身份契约

远程编辑器捕获连接身份、路径和 `editorToken`；启动打开操作后立即捕获
token，再等待读取。保存必须显式传入 token，并在远端响应后复验，旧弹窗
不能清理同一路径后来产生的草稿。`editorOriginalContent` 提供远端修订的
基线，恢复草稿不等同于已保存文件。安全存储写入与删除串行；保留草稿必须
等待 `flushEditorDraft` 成功，失败保持文本可复制并可重试，不能宣告已保留。
关闭／丢弃携带原 token，修订冲突不能覆盖远端。草稿仍按连接身份与路径
隔离并加密，不引入新存储或服务。

进程操作携带 PID 和启动时间，服务操作与日志携带确认前捕获的
`expectedConnectionKey`。断线、换目标或异步完成后身份不一致时拒绝操作／
结果回写；用户确认不自动重试。服务目录采用真实的运行和开机启用状态，
日志每次最多请求 200 条，界面保留有界窗口。非 systemd 环境、权限不足、
查询失败和目标变化区分为稳定错误码，不能把失败当作空目录。
旧日志翻页因 cursor 包含边界记录而请求 201 条原始记录，去重后最多返回
200 条，首次仍请求 200 条；cursor 含义见
[systemd 官方 journalctl 文档](https://github.com/systemd/systemd/blob/main/man/journalctl.xml)。

具体消费者与新增测试进度见[六组契约](../../agent-workflow/2026-10-11-six-workstreams.md)，
以上接口已修改但尚不代表全量验收通过。

## 2026-10-05 远程文件浏览增量

SftpFileItem 新增兼容默认的 isSymbolicLink 和 linkTargetErrorCode；
SftpOperations 接口不变，listFiles 仅为链接调用原生 stat，最多四个并发。
isDirectory 表示目标类型，path 仍是链接入口；权限字符串以 l 表示链接。
SFTP 状态错误单条隔离，运输错误仍交由既有超时和过期结果保护处理。
SftpState.showHiddenFiles 与 copyWith 保留本地过滤状态，偏好在保存成功后
更新，失败使用稳定错误码。下载和预览拒绝已知失效链接，目录链接删除走
deleteFile/remove。详情及验证进度见[本轮契约](../../agent-workflow/2026-10-05-remote-files.md)。

## 2026-10-01 模型发现（覆盖下方旧的会话配置发现约定）

`agentModelQueryProvider` 是可注入的独立API查询入口，Codex复用
`CodexNativeClient.queryCapabilities`，与对话所用ACP session解耦。
模型刷新只进行ACP initialize + 独立模型查询，不恢复/加载/创建会话；
保留已有工作连接。模式、当前选项、用户主动应用设置仍使用ACP配置接口。
未知独立接口不猜测，不从历史配置回退。云端实时账号目录尚未接入，接口目录
与账号权限验证不得混淆。见[交接与来源](../handoffs/2026-10-01-independent-model-discovery.md)。

## 2026-09-30 前后台连接与会话恢复

复用现有 SSH manager、生命周期协调器和重连控制器：单一心跳、探活与握手合并，
后台超时不主动销毁连接；前台探活有一次宽限，用户断开/换目标使旧异步结果失效。
聊天 provider 仅随连接目标变化重建，不随连接布尔值或 Agent 检测状态重建。
`SessionRecoveryStatus` 独立于已有会话内容；断线停止本地接收而非发送取消指令。
ACP 复用 load/resume 和导入解析器，在 DB isolate 中50条一批事务合并，保留本地 ID；
单次可见窗口补齐有界，歧义或不支持回放标 incomplete，绝不 fallback 到 session/new。
CLI 复用官方历史分页；草稿/消息在进程内保留。ACP 生命周期检查点另持久化消息、
文字草稿和附件描述，图片存私有文件。无新增依赖、远端 Daemon 或强制 WakeLock。
详细限制、分工及门禁见[本轮交接](../handoffs/2026-09-30-background-session-recovery.md)。

## 2026-09-30 ACP 可用性第二轮（优先于下方旧契约）

沿用 acpd v1 的消息 ID 与通知分发，事件保留角色/ID/资源块；账号通过已声明
authStatus 扩展接收。草稿只 initialize，首次发送才 new；已有会话优先 resume
获取最新配置，必要时 load，失败保留工作连接并标记旧配置。
ChatMessage 扩展可选 remoteMessageId/attachments，旧 JSON 不变；图片不入消息 JSON，
通过 AcpAttachmentStore 在后台保存内容寻址私有文件。导入仍50条批写和背压，
重新导入新本地副本，原记录和远端不改。
AcpWorkspaceFiles 按 Agent 执行目标复用 SFTP/已有 docker exec 封装，读取有界、
可取消，预览串行且8MiB缓存，单个预览源最多2MiB；大图浏览显示占位，选中附件
仍遵守20MiB图片/1MiB文本总量。目录超过10000项明确报错，不静默截断。
默认导航采用读时兼容映射旧默认值，显式保存记录迁移标识，自定义和空列表不变。
图片渲染使用 Flutter 原生 ResizeImagePolicy.fit 同时限定宽高（不拉伸、不访问远端URL），
草稿按已限额bytes预览，历史按私有文件加载；损坏/缺失图片显示占位。
目录浏览用请求代次丢弃迟到结果，目录失败禁确认；选择多个文件时逐项核验当前目标。
自动化及APK/安装结果以[实施状态](04-implementation-status.md)和
[本轮交接](../handoffs/2026-09-30-acp-usability.md)为准，不能代替真实ACP验收。

## 2026-09-30 ACP 增量架构

- 协议仍使用acpd v1类型化ClientRole/ClientContext，避免Session高层封装重复缓存整轮流事件；不自研RPC。
- 权限结果保持原始optionId或取消，wire为 `result.outcome = {outcome, optionId?}`；旧扁平断言无效。
- 工具按ID合并可选更新，配置按远端确认值联动，普通设置打开不重建进程。
- ChatRepository使用独立SQLite，所有SQL固定且参数绑定，在后台isolate执行；摘要与消息分开，messageOffset为绝对序号。
- 旧JSON保留、幂等事务导入并核验归属/数量；失败可回读旧记录且不把损坏JSON视为空历史。新数据通过exportAll导出。
- 每2秒保存生成中检查点，终态立即保存；重启后streaming转interrupted，不自动重发。
- 远端session/list只初始化连接；导入session/load分批50条落盘，待写批次达到2时暂停SSH输入，下降后恢复。
- 附件仅显式发送，按promptCapabilities启用；本地文件限长读取，Docker文本文件在目标容器用户环境读取。
- stderr通过共享LogSanitizer按流脱敏并保留8KiB尾部；生成采用无进展超时，审批等待不计时。

详见[接口与验收交接](../handoffs/2026-09-30-acp-client-completion.md)。本节是本轮实现契约，不替代测试结果。

| 文档版本 | 发布日期 | 适用阶段 | 核心架构 |
| :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-09-13 | 开发实施阶段 | Clean Architecture + Riverpod Provider Pattern |

---

## 1. 源码目录工程结构规范

工程遵循高内聚、低耦合的特性导向模块化划分（Feature-First）：

```text
lib/
├── app/                                # 应用层全局入口
│   ├── app.dart                        # MaterialApp 根组件 (Theme, Locale)
│   ├── router.dart                     # go_router 路由定义与导航守卫
│   └── theme.dart                      # Material 3 主题配色与字体定义
│
├── core/                               # 核心跨模块基础库
│   ├── constants/                      # 系统常量与预设枚举
│   ├── errors/                         # 全局异常体系 (AppException, SSHError 等)
│   ├── extensions/                     # Dart/Flutter 语法糖扩展
│   ├── logging/                        # 脱敏日志输出器 (LogSanitizer)
│   └── utils/                          # 工具函数 (格式化, 校验器等)
│
├── data/                               # 数据访问与持久化层
│   ├── database/                       # Drift SQLite 表定义与 Database 实例
│   │   ├── app_database.dart           # Drift 数据库主类
│   │   ├── daos/                       # 数据访问对象 (ServerDao, CommandDao)
│   │   └── tables/                     # 表结构定义 (servers.dart, commands.dart)
│   ├── secure_storage/                 # flutter_secure_storage 凭证封装
│   └── repositories/                   # Repository 实现 (聚合 DB 与 Storage)
│
├── infrastructure/                     # 底层 SDK 封装与远程通信实现 (防污染业务层)
│   ├── ssh/                            # SSH 连接池与会话管理
│   │   ├── ssh_client_manager.dart     # 核心 SSHClient 管理器
│   │   ├── ssh_command_executor.dart   # 带 Login Shell & PATH 包装的命令执行器
│   │   └── ssh_host_key_verifier.dart  # Host Key SHA256 验签器
│   ├── sftp/                           # SFTP 文件操作封装
│   │   ├── sftp_file_manager.dart      # 文件上传、下载、CRUD 操作流
│   │   └── sftp_transfer_tracker.dart  # 传输进度与速率监听
│   ├── acp/                            # ACP 协议交互层
│   │   ├── acp_client_adapter.dart     # stdio over SSH Channel 桥接器
│   │   ├── acp_event_dispatcher.dart   # JSON-RPC 事件分发器
│   │   └── acp_permission_handler.dart # 权限审批拦截与回调
│   ├── docker/                         # Docker 远程操作封装
│   │   ├── docker_cli_executor.dart    # 结构化参数调用与 JSON 反序列化
│   │   └── docker_log_streamer.dart    # 容器实时日志流
│   ├── terminal/                       # 终端仿真核心
│   │   └── terminal_session_bridge.dart# xterm.dart 与 SSH PTY 双向字节流绑定
│   └── system/                         # 系统监控流
│       └── system_metrics_sampler.dart # 资源占用自适应流式采样器
│
├── features/                           # 业务功能特性模块 (按业务垂直切片)
│   ├── dashboard/                      # 首页状态概览 (CPU/内存/卡片聚合)
│   ├── servers/                        # 服务器管理 (添加/编辑/测试连接/列表)
│   ├── agents/                         # Agent 首页与管理 (Claude/Codex/OpenCode)
│   ├── sessions/                       # ACP 聊天会话 (Markdown流/Tool Call/审批)
│   ├── files/                          # 文件管理器 (浏览/多选/编辑器)
│   ├── terminal/                       # SSH 终端视图 (Tab管理/辅助键栏)
│   ├── docker/                         # Docker 管理 (容器/镜像/日志/Exec)
│   ├── processes/                      # 进程管理器 (列表/搜索/杀死进程)
│   ├── commands/                       # 快捷命令 (参数模版/危险操作拦截)
│   ├── services/                       # Systemd 服务管理
│   └── settings/                       # 应用设置 (主题/字体/安全选项)
│
└── widgets/                            # 跨业务通用 UI 组件
    ├── cards/                          # 统一卡片样式
    ├── dialogs/                        # 危险操作确认框, 密码输入框
    ├── markdown/                       # 增强富文本 Markdown 渲染器
    ├── terminal/                       # 移动端 Accessory Keyboard Bar
    └── status_badge.dart               # 状态徽标 (Online/Offline/Running)
```

---

## 2. 核心服务设计与数据流转

### 2.1 SSHManager：物理连接池管理
```dart
class SSHManager {
  // 单台服务器复用单条物理 SSH 连接，按需建立 Channel
  final Map<String, SSHClient> _activeClients = {};

  Future<SSHClient> getOrCreateClient(ServerEntity server) async {
    if (_activeClients.containsKey(server.id)) {
      return _activeClients[server.id]!;
    }
    final client = await _connect(server);
    _activeClients[server.id] = client;
    return client;
  }

  Future<void> disconnect(String serverId) async {
    _activeClients.remove(serverId)?.close();
  }
}
```

### 2.2 ACPClientAdapter：stdio over SSH Channel
```dart
class ACPClientAdapter {
  final SSHClient sshClient;
  final String agentCommand; // 如 "bash -l -c 'claude-code-acp'"
  SSHSession? _session;
  StreamChannel<String>? _acpChannel;

  Future<StreamChannel<String>> start() async {
    _session = await sshClient.execute(agentCommand);
    
    // 将 SSHSession 的字节流包装为行分隔的 UTF-8 字符串管道
    final inStream = _session!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final outSink = StreamController<String>();
    outSink.stream.listen((line) {
      _session!.stdin.add(utf8.encode('$line\n'));
    });

    return StreamChannel<String>(inStream, outSink.sink);
  }
}
```

### 2.3 TerminalSessionBridge：xterm.dart 与 SSH PTY 桥接
```dart
class TerminalSessionBridge {
  final SSHClient sshClient;
  final Terminal terminal;
  SSHSession? _shellSession;

  Future<void> attach() async {
    _shellSession = await sshClient.shell(
      pty: SSHPtyConfig(
        terminalType: 'xterm-256color',
        width: terminal.viewWidth,
        height: terminal.viewHeight,
      ),
    );

    // 远端输出 -> xterm 终端屏幕
    _shellSession!.stdout.listen((data) {
      terminal.write(utf8.decode(data, allowMalformed: true));
    });

    // 用户键盘输入 -> SSH 管道
    terminal.onOutput = (input) {
      _shellSession!.stdin.add(utf8.encode(input));
    };

    // 监听视图 Resize 事件
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _shellSession!.resizeTerminal(width, height);
    };
  }
}
```

---

## 3. Riverpod 状态流向规范

在任一 Feature 内部，严格遵循单向数据流动：

```text
┌─────────────────────────┐
│     UI Widget (View)    │
└────────────┬────────────┘
             │ 1. ref.watch(provider) / ref.read(provider.notifier).action()
             ▼
┌─────────────────────────┐
│ StateNotifier / Provider │  (管理纯内存状态，不持具体 Widget)
└────────────┬────────────┘
             │ 2. 调用业务 Service 或 Repository
             ▼
┌─────────────────────────┐
│ Repository / Service    │  (聚合数据库持久化与 Infrastructure 通信)
└────────────┬────────────┘
             │ 3. 操作底层 SDK (dartssh2 / acpd / drift)
             ▼
┌─────────────────────────┐
│ Infrastructure SDKs     │
└─────────────────────────┘
```
# 2026-10-09 五模块增量设计（已实现）

- 安全：复用本地主机指纹与安全存储，设置动作集中处理断连、删除和失败传播。
- ACP：草稿保存成功后发布状态；显式运行设置部分失败尝试回滚，失败保留真实诊断。
- 文件：SFTP 继续承担目录/删除/传输；同服务器复制/移动走现有 SSH 执行器，
  复制使用目标目录内临时副本再无覆盖移动，链接保留，不经手机中转文件内容。
- Docker：列表解析 Compose 标签，项目动作逐个执行确认过的 ID，沿用日志与终端。
- 迁移：版本 1 JSON 保存白名单配置；新增对象重新分配 ID，按服务器+Agent 联合
  身份重映射默认选择。偏好写入逐项检查结果，失败恢复受影响键，不导出凭据。

UI 与接口责任边界见[实施契约](../../agent-workflow/2026-10-09-completion.md)，
测试结果及真实环境待验收项见[本轮交接](../handoffs/2026-10-09-five-module-completion.md)。
复制/移动要求 GNU coreutils；导入回滚不保证进程被杀时多键原子性，不能将
本地模拟测试当作各平台或真实账号已可用。
