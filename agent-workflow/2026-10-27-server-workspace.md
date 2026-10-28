# 服务端工作区实施契约

用户已确认：每服务器/SSH用户独立工作区，个人多设备；凭据仅本机；手机/平板/桌面偏好分开；应用级偏好指定来源（默认首次启用服务器）；草稿按设备存服务器；ACP共同查看、单端操作。新设备仍添加SSH连接。保留本地缓存，禁止清空式迁移、全量启动加载、自动重放远端命令或覆盖历史运行键。正式交付须新版本/GH/Ygg代理/官网，测试构建ADB全部由免费OpenCode或CodeBuddy，UI全部原AgY会话。

## 远端协议（Dart/Python协作固定接口）

assets/runtime/workspace_store.py通过stdin接收一行JSON，stdout仅输出一行JSON；执行 `python3 <script>`，不把正文/凭据放argv。root固定`~/.local/share/valhalla/workspace-v1`，标准库Python>=3.9，sqlite3，目录0700文件0600，拒绝symlink/非属主，WAL+事务。无sudo/公网端口。所有成功`{ok:true,...}`，失败`{ok:false,error:CODE,...}`。

请求`{op,deviceId,...}`，deviceId本机稳定UUID。bootstrap只在用户确认后调用，返回`{workspaceId,schema:1,revision,user}`。discover不创建目录，存在返回同上，不存在`{exists:false}`。changes `{after:0,limit:100}` 返回`{records:[{kind,id,value,version,deleted}],revision,hasMore}`，revision为本批最后一项（没有时当前revision）。snapshot按kind/afterId/limit分页。commit `{operationId,records:[{kind,id,value,baseVersion,deleted:false}]}` 原子幂等；缺省baseVersion=0只允许创建；版本不符整批返回WORKSPACE_CONFLICT和当前records；成功返回变更records及revision。kind/id长度与正文大小受限，未知schema不可写，删除用tombstone。操作ID重复而payload不同拒绝。

通用记录kind：agent、preference、config、draft、chat_session、chat_message、chat_tool、nas_media。ID稳定，serverId在跨设备正文用`@server`替代，仅本机hydrate时映射；禁止保存服务器连接凭据、私钥、hostkey信任/私钥路径。preference id设备类型/key，draft id设备UUID/key。config业务键分类允许清单，不能导出所有SharedPreferences。旧serverId包含在hash的scope需显式映射，不能字符串全局替换。

lease `{sessionId,action:acquire|renew|takeover|release,token?}`返回`{ownerDeviceId,token,expiresAt,generation}`；TTL60秒，续期20秒，服务端时钟；已占用acquire返回WORKSPACE_CONTROL_HELD；读者拿不到他人token。check_control(session,device,token,generation)用于broker每个写请求/审批/取消/模型权限变更前。控制丢失只拒绝旧写者，不能杀Agent。

运行目录acp-runtime-v1继续保留。broker同步启用后配置包含workspaceSessionId/workspaceDeviceId；attach hello包含controlToken/controlGeneration，老无token客户端只读。新服务端store模块可被broker导入（通过其用户目录安装路径），每条日志写runtime_event记录并登记运行索引。提供runtime_events `{runtimeKey,afterSeq,limit}` / runtime_catalog / register_runtime用于新设备发现，不能依赖原设备checkpoint；旧键原样保留，epoch/generation不可重建冒充。对现有busy运行不热替换或终止。

blob操作采用固定目录+校验过的内容哈希，base64分块<=256KiB，临时文件原子完成，路径不可穿越；同Hash复用；消息本体仅引用，按需下载。无用户任意路径删除。

## Dart/UI协作接口（根代理负责实现）

`lib/core/providers/remote_workspace_provider.dart`：`remoteWorkspaceProvider`为NotifierProvider<RemoteWorkspaceNotifier,RemoteWorkspaceState>。
State: `serverId, workspaceId, phase`(enum WorkspacePhase local/discovering/available/syncing/ready/offline/error), `error`(code?), `lastSyncedAt`, `pendingCount`, `conflicts` List<WorkspaceConflict>, `devicesDrafts` List<WorkspaceDraft>, `isPreferenceSource` bool；getter enabled、isBusy；`WorkspaceConflict`字段kind/id/localValue/remoteValue；`WorkspaceDraft`字段id/deviceId/title/value。
Notifier: `discover()`, `enable()`（UI预览确认后）, `syncNow()`, `disable()`（只停止同步保留数据）, `useAsPreferenceSource()`, `resolveConflict(conflict,{required bool keepLocal})`, `loadDeviceDrafts()`, `restoreDraft(draft)`, `clearLocalCache()`（只清同步缓存/状态，绝不删SSH配置或远端）。`migrationPreview()`返回Future<Map<String,int>>各类本地数量。错误按稳定code由ARB映射，UI不渲染原始异常/执行命令。
UI设置入口打开工作区弹窗/页面：归属server/user、同步状态、迁移预览确认、立即同步/冲突解决、偏好来源、设备草稿恢复；无服务器/离线禁用相应操作。不得加入一键远端清空。会话控制状态UI等ACP集成接口提供后再接，不猜假provider。

## 实施范围

覆盖Agent、会话/工具/附件、默认与运行设置、命令收藏、工作台、tmux历史索引、文件书签/视图/目录偏好、应用中心记录和源、NAS规则/媒体索引/播放进度、设备草稿与分类界面偏好。凭据/下载/传输队列/缩略图/窗口/输入状态本地。新增版本在验收后；未实际跑的场景不得报通过。

## 集成补充（2026-10-28）

- 存储 schema 仍为 1，组件版本为 2；安装包同时包含 `workspace_store.py` 与 `workspace_nas.py`。远端分别安装为 `store.py` 与 `workspace_nas.py`，NAS 请求通过固定白名单脚本路由。更高版本或非整数版本在安装前拒绝写入；旧组件可缺省 component 字段。
- 主同步的变更流仅含 config/preference/draft/chat_session，消息/工具正文和 NAS 索引单独按页读取。chat_session 墓碑也必须广播给本机仓库，不能只刷新最近一页后遗漏旧会话删除。
- 提交每批最多 100 条，记录序列化总量最多 512 KiB。批次操作 ID 由原记录操作 ID 的有序列表哈希产生；确认按每条原操作 ID 清理，不能清除网络等待期间产生的新编辑。旧确认不能回退缓存版本。
- 对话草稿恢复先校验作用域，再备份同一个目标草稿；备份的 id/key 必须相符，并通过 restoreKey 记录原目标。文件草稿只在本地加密存储正文，待传队列仅存元数据，文件上传使用内容哈希分块；最多 100 个待处理路径，满额拒绝新增而非丢弃旧项，同一路径更新可替换。
- NAS 源认证信息绑定本机目标指纹（类型、地址、用户、SSH 归属），不参加同步。远端修改同 ID 源的目标时，旧凭据不能自动发送到新目标。元数据热更新保留未变源对象与当前选择，避免重置播放器和连接。
- NAS 旧索引迁移固定初始 rowid 上界；空索引的 0 上界也是有效边界。媒体、播放列表、播放进度分阶段保存游标，任何一阶段未完成都不能宣布迁移完成。应用重启继续未完成阶段。

## 当前交付门槛

本批仍处于集成验收阶段，不能把旧批测试结果算作最终通过。现有历史分项报告保存在 git 忽略的 `build/workspace-sync/`。2026-10-28 的 OpenCode 免费额度与 CodeBuddy DeepSeek 均触发限流，已在 CodeBuddy 终端 `/model` 确认 Hy3 为 x0.00，再以显式 Hy3 执行验证。核心代理不自行运行测试、静态分析、打包或 ADB。界面仍由 AgY 原 Valhalla 会话修改。

最终必须记录：全项目分析、语言生成/键一致性、工作区回归、真实隔离 SSH 传输、NAS 迁移/跨源隔离、运行发现/只读观察/控制权及 ADB 验收的实际结果。禁止对现有真实 Agent 发消息或更改其历史来替代隔离测试。验证通过后才生成新版本并依既有发布脚本同步 GitHub、Ygg 代理包与官网；未运行的项目应明确列出。

### 已获得的本轮分项证据（非最终发布通过）

- CodeBuddy / Hy3：`test/data/workspace_journal_test.dart` 18 项通过（新增 4 项），报告 `build/workspace-sync/ack-journal-report.md`。验证旧确认不删除新编辑、缓存版本不回退、重复确认幂等、冲突中的新编辑保留。
- CodeBuddy / Hy3 的后台原始执行输出：新增会话目录 11 项、存储协议 37 项、NAS Python 辅助组件 6 项、ACP broker 45 项通过；正式分项报告仍在整理，broker 后续仍有运行发现改动，最终需按冻结源码复核。
- 后续 NAS 迁移和凭据绑定回归已通过；设备草稿分页界面由 AgY 完成。完整门禁结果以下文最终登记为准。

### CodeBuddy 任务执行入口补充

免费模型负责测试编写与夹具修复；已编写的门禁也可通过 CodeBuddy 的 --bg --name <本批任务名> --exec <明确命令> 交给其 shell job 执行，不请求模型、不使用付费回退。主代理只读取 CodeBuddy 回执/输出、修正产品代码与登记结果。测试逻辑仍不能由主代理自行编写。长构建仍使用独立 tmux socket，保留本批证据。

本轮已有 CodeBuddy 实际执行证据：真实 SSH 最终 13 项通过；NAS 迁移 8 项及既有 Dart/Python 各 6 项通过；文件草稿和编辑器联动在修复“清空队列返回不可修改列表”后 17 项通过。组合回归的首次执行为 147 通过/10 失败，不能冒充最终通过；其夹具初始化问题和后续新增检查仍待复核。具体 job ID 及原始日志在忽略目录 build/workspace-sync/native-executor-receipts.md。

### 最终集成检查进展（2026-10-28）

- 分项组合回归随后达到 157 项通过。新增真实 AiChatNotifier 冷启动发现、目录重建重开和外国控制租约只读观察测试，与会话同步组合共 33 项通过；观察端协议写入和远端记录写入均为零。
- NAS 凭据绑定 14 项通过，覆盖延迟读取、目标切换、存储失败与重启后的未完成绑定；工作区同步边界及文件草稿 40 项通过。
- 最终服务端检查：存储协议 37、会话目录 11、NAS 辅助组件 6、ACP broker 47，共 101 项通过。日志为 `final-workspace-store.log`、`final-chat-catalog.log`、`final-workspace-nas.log`、`final-acp-broker.log`。
- 首次全项目 Flutter 回归暴露了旧夹具缺失存储依赖，以及工作区状态回调的 Provider 循环依赖和未启用时仍启动轮询的问题。已修正产品回调归属：由工作区 Notifier 接收通知，服务 Provider 不反向读取它；轮询只在启用且前台时存在。修复后的完整回归仍需独立记录，不能沿用第一次失败运行的计数。
- 容器补齐 D-Bus 运行依赖后，Linux 媒体控制的真实本地 D-Bus 检查通过；没有跳过断言来掩盖环境依赖。
- 本轮所有执行均经 CodeBuddy。未向既有生产 Agent 发送消息，未修改生产 tmux；两台真实设备同时连接、真实 Agent 长任务与全量历史迁移仍未验收。
- 修复后的工作区 Provider 生命周期 2 项、同步服务 28 项通过，覆盖真实通知链、释放回调及前台/后台/停用轮询。旧终端的共享与私有存储夹具补齐可空 workspaceGateway；抽屉键盘测试按既有输入契约模拟已连接终端，原断言不变，两套抽屉/已保存命令测试共 20 项通过。
- 第二次完整 Flutter 运行是 4,447 通过、31 跳过、73 失败，不能登记为发布通过。旧夹具及空历史错误展示是剩余原因。复核时拒绝了“补消息避开空状态”和“缩小 finder 范围容忍重复错误”的测试修改，恢复原断言并交 AgY 修复实际界面，等待第三次完整门禁。
- ADB 只读准备确认设备在线、旧包为 1.0.23/4024，但前台是 OmniTune。已暂停界面操作并询问独占状态；未安装本批新包，不能将脚本准备视作验收。
- 用户随后确认“其他测试已停止，可以独占验收”。待新包构建完成后由 CodeBuddy 保留数据覆盖安装；此确认不代表安装或界面检查已经通过。
- 第三次完整门禁：语言生成成功，全项目静态分析零告警，Flutter 测试 4,524 项通过、31 项跳过。AgY 已修复空历史重复错误和内部错误码展示，原测试断言保留；服务端 Python 101 项通过。跳过项与真实生产 Agent、双设备实机验收不能视作通过。
