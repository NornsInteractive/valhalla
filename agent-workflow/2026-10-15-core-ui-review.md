# AgY UI 收尾复查（修复前历史审计）

以下发现及旧行号保留修复前审计记录，不是当前待修清单；六项实现与修复已完成。
最终测试 3685 通过、30 跳过，静态分析零问题；正式 1.0.6+7 APK 已本地构建
并保留数据 ADB 覆盖安装。设备详细检查仍在进行，不据此宣称全部设备验收通过。
当前证据见[实施记录](2026-10-15-core-experience.md)。

UI 仅由原 Valhalla / Gemini 3.8 Flash high 修改；验证先由 OpenCode 执行，
后经用户本轮明确授权由主代理补齐。下文为当时静态复查，不是设备测试结果。

2026-10-15 08:22 UTC OpenCode 中间分析实际得到50项（含级联警告），完整日志
`/tmp/valhalla-core-experience.ACZJNb/opencode-analyze-interim2.jsonl`。
除下文已列项目，ACP还需修：3866／3887的`chatState`已不在作用域；
`ChatRunSettings`缺import；`AcpCapabilities`应为真实`AgentRuntimeCapabilities`；
5181的`copySuccess`不存在，复用已有复制成功文案。遗留未使用
`_isErrorInlinedInLastAssistantMessage`、`_TransferIdList`应去掉或正确复用。
不要因Agent语法错误的级联unused警告删除现有登录／编辑等真实功能。

1. remote_browser_toolbar：折叠路径和更多菜单 Row 的文字需 Flexible / Expanded
   约束，长目录、德语、2倍字号不溢出；管理模式上传/新建离线保持禁用而非
   消失，选择器仍隐藏；新建 tooltip 不能复用 addServer。
2. terminal_view 新页签角标不能使用 bridge.preferTmux（请求偏好）。当远端
   tmux 不可用或用户选择普通模式继续时，该偏好仍为 true，会谎报持久化。
   请按 bridge.mode 真实状态显示普通／tmux；MoshBridgeAdapter 不应错误
   显示 SSH 字样，复用真实模式。连接建立前未知不能提前声称已使用 tmux。
3. terminal_history_drawer 的“当前打开”不能只按 connected 状态分组，断连
   但页签仍存在的历史应继续在当前打开组，状态单独显示。按 tab/session ID
   判断是否打开，继续最近使用排序，不发起额外远端请求。
4. 历史分组标题 Row 的 Text 也需约束，320dp/2倍字体和长翻译不能溢出。
   历史名称搜索目前误用“搜索文件或目录名”，应补正确终端历史搜索文案。

修复后保留既有 key、输入法规则、默认恢复和手动创建路径，不改核心。

## 设置与 Agent 卡：第二次静态复查（新增）

以下行号以本轮复查时源码为准；没有运行分析、测试、格式或 UI。
先处理 5–7，再进入 OpenCode 验证。不得通过修改核心 API 来迁就不存在的 UI 字段。

5. **设置页当前无法编译：新入口调用了不存在的 API。**
   `lib/features/settings/settings_view.dart:120–184,365–368,400,433,467`：
   - `_getThemeModeName` 未定义。沿用 `_buildThemeModeCard` 现有
     `AppThemeMode` switch 与 themeSystem／themeLight／themeDark／themeAmoled。
   - `_showThemeModeDialog` 未定义。使用已导入的
     `showAppThemeModeDialog(context, settings.themeMode, notifier)`。
   - `ThemeAccentColorDialog.show(context)` 不存在。沿用
     `_buildAccentColorCard` 的 `showDialog` 与 `ThemeAccentColorDialog`
     构造器，传入 settings／notifier，保留当前系统亮暗主题的 initialMode 选择。
   - `_getCurrentLanguageName` 未定义。使用 `localizedLanguageName`，语言标签
     沿用 `_buildLanguageCard` 的 system／`settings.locale.toLanguageTag()` 规则。
   - `_sectionName` 未定义。使用已有 `_getLocalizedSectionName`，摘要传
     `settings.effectiveStartupSection`，避免实验功能关闭后显示不可用启动页。
   - `_showStartupSectionDialog` 未定义。使用已有 `_showStartupPageDialog`。
   - `SettingsState` 没有 customModel／modelName。AI 摘要从现有默认 Agent／
     CLI 历史页数生成，或复用真实设置说明，不能新增虚构模型配置字段。
   - `securitySettingsProvider` 返回 `SecuritySettingsActions`，没有
     requireBiometrics，项目也没有此处所暗示的生物识别开关。安全摘要应展示
     现有可信主机／凭据或终端设置；不能编造 enabled 状态。
   - `AutoConnectSettings` 只有 mode／fixedServerId，没有 enabled。沿用
     `_AutoConnectCard` 的 fixed／lastConnected 摘要和已选服务器名称。

6. **新增文案未写入 ARB，生成不能补出不存在的键。**
   当前这四个文件引用、但 `lib/l10n/app_en.arb` 未定义的键为：
   `agentCollapseDetails`、`agentExpandDetails`、`configMigrationBoundaryNote`、
   `configMigrationSubtitle`、`disabled`、`enabled`、`installAppId`、
   `installArchitecture`、`installPlatform`、`settingsAboutPrivacyDesc`、
   `settingsAccentColorDesc`、`settingsAiOpsDesc`、`settingsAutoConnectDesc`、
   `settingsBiometrics`、`settingsSearchHint`、`settingsSearchNoResults`、
   `settingsSecurityDesc`。修复第5项后，删除不需要的引用；保留的真实新文案须
   按约定补齐17个 ARB，再由 OpenCode 生成。不要添加虚构生物识别文案来掩盖
   不存在的业务功能。关于页安装信息与 Agent 展开按钮也受此问题影响。

7. **预构建详情页使设置不更新，并会覆盖用户刚做的修改。**
   `settings_view.dart:60–106` 接收固定 `Widget child`，调用点
   `:373–376,406–409,472–475` 在打开前构建普通 Card，并捕获 settings。
   详情路由不会因为下面的 SettingsView 重建而替换此 child。
   具体复现：打开导航详情，先取消 Files，再取消 Terminal；两个 Checkbox
   回调都复制打开时的 visibleBottom（`:1590–1616`），第二次保存会把刚取消的
   Files 加回去。快捷入口与拖拽排序同样使用旧列表（`:1460–1528`）。
   AI 历史页数、默认 Agent、字体大小、终端默认会话、可信主机数也会停留旧值，
   再次打开子弹窗还可能传旧选择。
   最小修复：详情接收 builder，在详情路由里的 `Consumer` 使用其自己的
   WidgetRef 重新 watch 对应 provider，再构建原 Card／回调。不要在 onTap
   事件中用外层 ref.watch 构建固定快照。导航回调应使用最新设置，连续多次
   修改必须保留前一次结果。`_AutoConnectCard` 自己有 setState，
   `AboutPrivacyCard` 自己订阅 provider，不能误称它们也完全冻结。

8. **搜索只覆盖分组名，漏掉原有设置标题。**
   `_getSearchItems`（`settings_view.dart:112–228`）没有 Terminal Font Size、
   Known Host Keys、Reset Credentials、CLI History Page Size、默认 ACP／CLI
   Agent、Dashboard Quick Actions、Bottom Navigation Bar、Export／Import
   Configuration 等原设置条目。搜索这些界面上的原始标题会返回无结果；
   即使找到 Navigation 分组，也没有直接定位底栏／快捷入口的操作。
   将现有设置的标题、说明和当前摘要纳入索引，并复用其原操作：
   `_showTerminalFontSizeDialog`、`showStartupSessionDialog`、
   `CustomizePinnedKeysDialog.show`、`TrustedHostsDialog.show`、
   `ClearCredentialsDialog.show`、`_showCliHistoryPageSizeDialog`、
   `DefaultAgentDialog.show`、`ConfigurationMigrationManager`。
   导航子项打开对应详情并定位原设置；CLI／NAS／应用中心仍遵守已有实验门禁。
   搜索中的操作读取最新值，不再捕获已过期的分组快照。

9. **设置详情标题没有宽度约束，窄屏／2倍字体会溢出。**
   `settings_view.dart:82–94` 的 `Row(Text(title), Spacer(), IconButton)` 让
   标题按无限宽度布局。例如 Connection & Security 在320dp、2倍字号时
   与关闭按钮超过可用宽度。用 Expanded/Flexible 包住标题并允许合理换行，
   保留关闭按钮点击区。导航详情 Checkbox 标题 Row（`:1506–1516`、
   `:1593–1603`）的文本也需 Flexible；新详情内边距进一步缩小其可用宽度。

10. **Agent 卡新增展开按钮后，六个固定动作挤出窄屏。**
    `agent_management_view.dart:1243–1338` 对支持 CLI／ACP 登录的 AgY 同时
    放置登录、ACP登录、编辑、检测、删除、展开六个 IconButton，仍是单个 Row。
    320dp 页面扣掉列表左右16、卡片左右14后仅约260dp，而六个常规48dp
    点击区已经需要288dp，时间文本还未计入。保留所有原操作与点击区，
    窄屏改为 Wrap／分行或保留可访问的更多菜单，不能删登录、检测或诊断。

11. **Agent 卡默认目标信息与减少动画契约仍未接齐。**
    `agent_management_view.dart:675–735` 默认保留技术 profile.id，同时 Docker
    只显示通用 Docker 标签；实际 containerReference／containerBinding 被放入
    折叠详情（约`:842–855`），无法从默认卡片分辨同服务器上的不同容器目标。
    将技术 ID 留在详情，默认保留具体 Host／Docker 目标的可读摘要。
    新 `AnimatedCrossFade`（`:797,956`）固定200ms；按既有
    `MediaQuery.disableAnimationsOf(context)` 在减少动画时使用 Duration.zero。

保留情况：Agent 的 CLI／ACP 登录、编辑、刷新检测、删除仍有原回调；诊断日志
按钮已移动到展开详情。关于页继续使用 `appRuntimeIdentity`；DiagnosticsView
改为 `AppDiagnostics.report()` 与核心现有 API 一致，未发现这两个接口的额外
逻辑缺陷。以上仅为源码检查，不替代320dp、2倍字体、RTL或真实保存的验证。

## 恢复顶部入口与详情：第三次静态复查（新增）

12. **当前页面优先级使用了错误的下标集合。**
    `lib/features/shell/main_shell.dart:135–142` 把 `_currentIndex` 用作
    `settings.visibleBottomNavigationSections` 的下标，但 `_currentIndex`
    是 `_buildViews` 的固定视图下标。CLI 固定是8，而默认底栏只有5项，
    所以在 CLI 页面始终得到 null；重排／隐藏底栏项后，ACP 或其他页面也会
    被误判。最小修复：直接用现有 `viewIndexToAppSection(_currentIndex)`
    判断 aiChat／cliChat，其余返回 null；不读取底栏的可见顺序。
    验证必须包含默认底栏、重排底栏、隐藏聊天项后由抽屉打开、底栏为空。

13. **详情保存旧快照，却用当前 notifier 重试，没有目标身份校验。**
    `connection_status_banner.dart:312–329` 只读一次状态，`:379–386` 只在
    dialog builder 构建时读会话名称，`:418–428` 的按钮没有捕获或比较
    server／agent／session 标识。弹窗打开期间 provider 因连接／目标变化更新后，
    旧会话标题的按钮会操作当前新目标；阶段也会继续显示已过期的 failed 或
    syncing。底部通用重试与“确认会话重启”同样使用旧快照（`:480–507`）。
    使用详情内 Consumer 订阅当前恢复状态及目标身份，或捕获每行原始身份并
    在点击前复核。ACP 比较 activeAgentProfile.serverId／id／activeSessionId；
    CLI 比较 serverId／activeAgent.id／activeSession.id；SSH 比较
    activeServer.connectionKey。身份改变应刷新／关闭详情，不执行旧行操作。
    服务器标题只能与匹配的目标绑定，不能把旧服务器标题与新会话内容拼在一起。

14. **通用“重试”会重试错误的恢复对象，且连接可重试门禁不一致。**
    `connection_status_banner.dart:331–336` 只要任一会话 failed／incomplete
    就显示页尾重试；`:502–507` 却无条件操作排序第一项。例：当前 ACP syncing、
    CLI failed 时第一项是 ACP，按钮再次触发 ACP 同步，而 CLI 失败没有重试。
    同一 OR 条件也会让会话失败绕过 SSH 的 retryable 显示门禁，离线点击路径
    仍调用 connect（底层密钥校验仍存在，但 UI 提供了本应禁止的通用重试）。
    最小修复：详情已有每行重试，页尾只保留“当前 SSH 可重试且未连接”的
    连接动作；会话恢复只走对应行。点击时重新核对连接状态、目标和 retryable。
    保留主机密钥变更提示优先，不增加自动发送消息、审批或终端输入的路径。

15. **新增多对象详情未处理受限高度与重试点击区。**
    `connection_status_banner.dart:341–354` 标题 Row 里的服务器 Text 无
    Flexible，长服务器名在320dp／2倍字体会横向溢出；详情 content 仍是无滚动
    Column，同时显示两个长会话名、阶段及上下文丢失提示时可能超过弹窗高度。
    约束标题，并让内容在可用高度内滚动，保留页尾关闭／诊断动作可达。
    新逐行重试（`:410–416`）把 minimumSize 设为 zero 且 shrinkWrap，
    11号文字加上下各2dp的点击高度明显不足约定44dp；保留至少44dp点击区，
    窄屏可换行排列，不通过缩小触控区域容纳长文本。继续按 Directionality
    布局并验证 RTL，不硬编码左右定位。

已保留：投影调用包含全部非 idle 状态；reconnecting 已有展示分支；各行按
mode 选择 ACP／CLI notifier，没有调用 prompt、send 或审批接口。SSH 状态
分支仍位于会话投影之前。此处只记录源代码结论，未执行恢复或连接操作。

## Batch 3 进行中的源码复核：新增明确编译阻塞

以下为批次仍在编辑时的源码快照；不代表已完成批次的验证结论。

16. **设置搜索修复新增了错误的参数签名，且两个圆角 token 不存在。**
    `settings_view.dart:218–222` 调用 `_showCliHistoryPageSizeDialog` 时把
    notifier 与页数传反；函数签名在`:1311–1315`。精确替换为
    `_showCliHistoryPageSizeDialog(context, settings.cliHistoryPageSize, notifier)`。
    `:229–234,241–246` 的 `DefaultAgentDialog.show` 不接受命名 context／ref；
    其真实签名见 `widgets/default_agent_dialog.dart:21–25`。精确替换为
    `DefaultAgentDialog.show(context, server: targetServer, isCli: false)`，
    CLI 处仅将 isCli 改为 true，不传 ref。
    `settings_view.dart:70,431` 使用不存在的 `VRadius.large`／`VRadius.medium`；
    `lib/core/design/tokens.dart:13–33` 只有语义 token，分别改用
    `VRadius.sheet`／`VRadius.input`，不向核心补造新 token。

17. **Agent 减少动画修复放错声明位置，并重复构造参数。**
    `agent_management_view.dart:791–794` 在 `Column.children` 列表中直接放
    `final reduceMotion`／`final animDuration` 声明，不是合法 Dart 集合元素。
    将两条声明移到`:660` 的 `final cardContent` 之前。
    同一个 `AnimatedCrossFade` 同时在`:797–801` 和`:962–965` 传了
    duration／crossFadeState；删除尾部重复的 crossFadeState 与固定200ms
    duration，保留一组状态和使用 animDuration 的 duration／reverseDuration。

18. **终端历史的新状态分支缺少枚举导入。**
    `terminal_history_drawer.dart:968–975` 引用 `TerminalConnectionState`，
    当前导入只含 terminal_provider，后者只导出 terminal_history 模型，
    不转导出该枚举。添加直接导入
    `../../../infrastructure/terminal/terminal_session_bridge.dart`
    （可 `show TerminalConnectionState`）；不改 provider 导出来掩盖 UI 依赖。

19. **新增搜索摘要未订阅终端设置，保存后继续显示旧值。**
    `settings_view.dart:137–138` 用 ref.read 取得字体和默认会话，搜索页 build
    没有 watch 这两个 provider。搜索 Terminal Font Size → 改为另一字号 →
    关闭弹窗后，`:266` 的摘要仍是打开前字号，直到修改搜索词或发生其他重建；
    默认终端会话摘要同样如此。构建搜索索引时改为 watch 所需字段／provider，
    当前默认 Agent 的目标也应订阅 activeServer，而不是长期捕获 read 快照。

本次确认已接上：设置详情的路由内 Consumer、标题和复选框文字约束、Agent
动作 Wrap 与具体 Docker 目标、恢复的固定视图下标映射、详情内 Consumer、
逐行 server／agent／session 校验、仅 SSH 的页尾重试、滚动内容与44dp行重试。
第6项当前仍被引用且 app_en.arb 缺失的键精简为12项：agentCollapseDetails、
agentExpandDetails、configMigrationBoundaryNote、configMigrationSubtitle、
installAppId、installArchitecture、installPlatform、settingsAboutPrivacyDesc、
settingsAccentColorDesc、settingsSearchHint、settingsSearchNoResults、
settingsSecurityDesc。第8项配置导入／导出搜索及导航子项定位仍未完成。
此复核未运行生成、分析、测试、格式、构建或设备操作。
