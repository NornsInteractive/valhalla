# 前后台连接与会话恢复（2026-09-30）

状态：功能、全量回归、最终格式门禁、release构建与ADB覆盖安装完成。

## 验证证据与边界

OpenCode 全量1421通过、17既有环境跳过、0失败；最新静态分析零问题。
最终86个修改/新增Dart文件格式检查零改动；格式收尾后重新构建并覆盖安装。
连接/恢复专项115项通过，包含真实心跳定时器的后台暂停、恢复和并发探活合并。
AgY 在指定原会话完成界面保留、恢复横幅、同目标硬件缓存和离线文件列表。
新 release 已构建并通过签名一致的 ADB `install -r`；没有卸载或清数据。
最终包UTC时间2026-09-30 16:12:14，安装成功时间16:12:26；沿用既有调试签名。
模拟器启动、Home/恢复、锁屏/唤醒观察窗口保持同一进程，无应用 fatal/ANR；
未强制 Doze、未向真实 Agent 发送消息，不能等同真实服务器恢复验收。
最终产物大小、UTC时间、SHA-256、签名与设备证据统一以
[发布报告](../../agent-workflow/background-recovery-release.md)为准，
[冻结门禁](../../agent-workflow/background-recovery-final-gates.md)记录最终检查。

本轮回归还修正了 CLI 恢复失败错误码被后续状态更新清掉、无服务器时 Agent
默认选择空值异常与窄屏仪表盘溢出。测试辅助的异步清理死锁已排除；没有删除、
跳过失败用例来通过门禁。首轮旧测试失败与中断的运行不计为通过。

## 本轮业务实现

- manager 单一心跳（替代 SDK 与 manager 双重 ping）；探活 single-flight，
  同一 ping 首次 8 秒超时再等 8 秒；后台/旧生命周期超时不销毁当前连接。
  明确 transport done 仍立即报告。短后台 <10秒且最近30秒探活成功直接复用。
- ReconnectController 同代次在途握手不重复排期；读取凭据后重新校验用户意图。
  FGS 同步串行，重连期间保留登记，原生启动失败记录异常类型并停止失败服务。
- ACP registry 状态改 listener，不以 ready 列表变化重建 provider；真实断线保留
  内容并中断本地接收，不发送 cancelPrompt；恢复原 ID，不发 prompt。
  adapter 空闲超时在后台暂停，恢复前台重新计时，避免锁屏时间触发 cancel。
- `ChatRepository.mergeReplayBatch` 复用现有 DB isolate/事务，50条一批解析与合并。
  保留本地消息 ID 与较长本地内容；任何较短回放/身份或顺序歧义降级 incomplete。
  共享会话只按可靠远端 ID 更新，不按跨 Agent 顺序猜测追加。
- 单次恢复最多加载当前窗口后500条，超出仍保持原窗口并标记 incomplete，可再次补齐；
  不把全部远端历史一次装入 UI。CLI 最多20页寻找重叠锚点，找不到明确标记 incomplete。
- ACP checkpoint 保存已收到消息、草稿文字/目录及内容寻址附件（JSON不嵌入图片字节）；
  同一进程保留全部内存草稿。CLI 原生历史仍以远端官方接口为准。
- 文件列表同连接目标保留目录/搜索/条目/编辑器，真实失效的传输标失败，不伪装继续成功。
  指标与进程轮询在后台暂停；现有终端 rebind 已保留缓冲，无须重写。

验证模型：OpenCode 主/辅助 `opencode/space-bunny-free`，2026-09-30本机目录
input/output/cache均0，官方 https://opencode.ai/docs/zen/ Pricing亦为Free。
OpenCode session `ses_f0d290b7affems3h5Vk83o3uIZ`；无真实远端测试授权。

测试接缝：`debugRegisterClient(..., startKeepAlive: true)` 才启动心跳；
原有默认 false 保持原测试注册语义，不能把纯注册当作真实定时器已启动。

## 用户确认

后台允许暂停；回来先显示原内容，顶部可提示重连，不能清空对话。
不新增远端服务，不自动重发消息、创建替代会话或重放审批。
所有现有未提交改动保留。

## 分工与接口

- Codex：连接、provider、协议、存储、原生服务与文档。
- AgY：仅原 Valhalla `ec81a4be-7543-45ee-8658-f68966f57d3b`，
  `gemini-3.8-flash-high` / high，负责全部 UI（含 main.dart）、ARB。
- OpenCode：全部测试维护/运行、格式、生成、分析、打包、ADB；
  使用经核验免费模型，主/辅助均固定，不能改业务/UI源码（格式/生成除外）。

业务层已提供 `SessionRecoveryStatus { idle, reconnecting, syncing, incomplete, failed }`
（`lib/data/models/session_recovery_status.dart`），ACP `AiChatState.recoveryStatus`、
CLI `CliChatState.recoveryStatus`；两 notifier 提供 `recoverConnection()` 重试，
ACP 提供 `checkpoint()`，后台只保存，不取消 prompt。
`appVisibilityProvider`（core/providers/app_visibility_provider.dart）为 bool，true 前台；
由现有 ConnectionLifecycleCoordinator 更新，不需要 UI 再发一次连接动作。

## AgY 界面要求

1. 不因服务器 disconnected / reconnecting 替换聊天内容树；保留历史列表、选择、
   草稿控制器、附件、阅读位置；恢复只更新顶部轻量状态。
2. recoveryStatus 显示统一本地化状态：重连中、同步输出、部分输出无法恢复、
   恢复失败（可重试）。不堆叠与既有 connection banner 重复的重连提示。
3. 未连接或 reconnecting/syncing 时禁发送/审批/远端操作，允许阅读复制与草稿编辑。
4. 消息补齐时，仅用户原本在底部才跟随；阅读旧消息时保留滚动锚点；不重置 key。
5. main.dart 生命周期 hidden/paused 保存 ACP checkpoint（现有 provider 已初始化时），
   不因生命周期初始化尚未使用的聊天 provider。业务 coordinator 处理幂等/合并。
6. 仪表盘旧数据、文件目录、终端缓冲在同服务器恢复时保留，不显示空白替代。
7. 不运行测试/格式/分析/构建，交 OpenCode；不编辑 core/infrastructure/data/android。

## 验收

合并探活/重连，超时宽限和旧代次隔离；后台不主动断线/取消任务；
同服务器连接状态变化不清选择/草稿/消息；真实断线恢复原 ID 并去重同步，
无回放能力诚实降级；长历史分批；手动断开/换服务器旧响应无效。
OpenCode 模拟协议及 ADB 验证，不触碰当前真实 Codex 会话。
需记录新 APK UTC 时间、hash、签名、目标设备、覆盖安装及有限观察窗口。
Android Doze/进程回收不是永久在线保证；真实远端对话由用户验收。
