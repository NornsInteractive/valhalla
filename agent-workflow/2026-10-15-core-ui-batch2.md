# AgY 第二批：接入已完成核心接口

延续原 Valhalla 会话与 Gemini 3.8 Flash / high。先完成第一批独立 UI，
然后实现本文件。仅 UI / ARB；不要修改 core、data、infrastructure、test，
不要自行运行格式、生成、分析、测试、构建或 ADB，OpenCode 负责这些。
读取主契约 `2026-10-15-core-experience.md`，不要扩大功能范围。

必须逐个完整阅读并按真实接口接入：

- `2026-10-15-transfer-core-api.md`
- `2026-10-15-recovery-core-api.md`
- `2026-10-15-acp-core-api.md`
- `2026-10-15-runtime-identity-api.md`

## 界面任务

第一批文件工具栏静态复查发现三项，请在第二批一起修复：
`remote_browser_toolbar.dart` 折叠路径菜单与“更多”菜单的 Row 文本缺少
Flexible/Expanded，长目录、德语和 2 倍字号会溢出；需要约束并允许换行或
截断配 Tooltip。管理模式上传/新建不能因离线回调为 null 而消失，保持固定
位置并禁用，选择器模式仍隐藏管理按钮。新建按钮 tooltip 误用了 addServer，
应使用正确的本地化“新建”，不能提示“添加服务器”。

1. `features/files/sftp_file_view.dart` 的 SftpTransferListSheet / ListItem：
   筛选全部、进行中、失败、已完成，默认全部且活动任务靠前、组内稳定。
   暂停算进行中；取消仅全部可见。显示当前筛选计数。紧凑条目显示名称、
   阶段、进度、速度、ETA 与必要动作，路径、校验、错误等折叠详情。
   接入 pauseAllTransfers / resumePausedTransfers，调用有忙碌反馈，避免
   连点；暂停原因用新 enum 本地化，不猜错误字符串。可见动作保留原异常
   处理、完成后打开、失败重试、清理已结束等功能，不能静默吞异常。
   当前任务每秒进度不能让无关文件列表重建，继续保留既有 select 边界。
2. `features/shell/widgets/connection_status_banner.dart`：使用纯排序工具，
   SSH 优先，当前可见 ACP / CLI 页面优先，其余按失败、不完整、同步。
   当前模式来源于可见路由，必要由 MainShell 传可选 mode，默认 null
   保持已有构造和测试兼容。详情实时显示全部非 idle 恢复对象与各自
   服务器/会话/阶段，独立重试；切换目标不能让旧按钮操作新对象。
   恢复不重发消息或审批。处理 SessionRecoveryStatus.reconnecting。
3. `features/chat/ai_chat_view.dart`：按照 ACP 文档拆头栏、历史、输入、消息
   订阅。不要只把整个 state 移入 Consumer；选择实际所需稳定字段。
   稳定消息按 sessionId/messageId 局部 select 原始消息对象；已完成消息
   的 Markdown 和历史标题不能每个 token 重建。沿用现有分页、选择复制、
   多媒体、工具时间顺序、滚动、草稿、权限审批和登录实现。
   新错误使用每条 message.failureCode，显示本地化分类摘要、适用动作、
   可复制脱敏详情。仅真正已显示的同一错误抑制顶部重复；历史加载等
   独立错误仍显示。旧正文内 Error 兼容继续保留，不改写存储。
   空正文失败也必须可见；历史错误动作校验当前目标，不能误操作别的
   Agent。登录与重连均不得隐式重新发送。
4. `features/settings/widgets/about_privacy_card.dart` 复用现有 PackageInfo
   加紧凑安装详情：应用标识、版本/构建号、平台、运行应用架构。
   `diagnostics_view.dart` 从 diagnostics.read 改成 report；保留注入测试。
   配置迁移提示复用现有导入/导出，解释不同包名数据隔离，凭据需重填；
   不新增迁移向导、不读旧包私有数据、不把密钥导出。

## 验收与汇报

沿用当前视觉系统，不加新依赖、不重新设计整页。320dp、2倍字号、RTL
布局要可滚动不溢出；按钮热区保留，文本必要截断但详情可查看。
新增文案补齐现有17语言 ARB，生成交给 OpenCode。
现有 widget key 尽量保留；布局变化确实需要改变测试时说明新路径。
完成后精确列出文件、API接入、遗留事项，不宣称未执行的测试通过。
