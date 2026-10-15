# AgY：真实 widget 回归缺陷（由主代理验证，UI仍只AgY修改）

最终状态（2026-10-15 15:29 UTC）：下列UI缺陷均由原AgY修复并通过回归。
另补组件取消全选不能被重建全选、apply失败后日志和重新prepare仍可见，以及
StatusBadge自身文字宽度约束。更新管理39项、Dashboard/compact8项、Shell
几何10项通过；最终全量3849通过／30跳过／0失败，静态分析零问题。
本轮未构建安装，不将旧APK只读检查当成本轮UI实机验收。
以下保留首次失败证据，不能把旧状态误读为当前尚未修复。

2026-10-15，新增工具栏/弹窗/恢复测试组合74通过3失败，日志
`/tmp/valhalla-agent-updates.aOvCbg/ui-final.log`。

1. `test/features/remote_file_toolbar_dialog_test.dart` 的320dp/2倍字号，德语和
   阿拉伯语 AlertDialog 底部 RenderFlex overflow（阿语56px）。请让标题/内容/
   actions在有限高度下可滚动/合理换行，保留字号与所有保存/取消/默认按钮可达。
   不缩小字体、不删按钮、不改测试、不提高测试viewport掩盖问题。
2. 同文件 Android 已聚焦搜索→打开配置→Cancel，focus又变true，键盘恢复。
   入口打开前清焦点scope和原输入节点，不能仅autofocus:false；关闭不主动恢复。
   更新：工具栏配置入口已修且通过，但connection_status_banner_test.dart新增
   `closing recovery details...`仍复现同一焦点恢复；请修_showDetailsDialog入口。
   `remote_browser_toolbar_test.dart` 的 `closing More never restores mobile
   search keyboard`也已失败：PopupMenuButton More打开/取消/选择后需清理
   移动端原搜索焦点；不能只修配置弹窗。其他42个工具栏用例已通过。
3. 静态复核：终端自动恢复失败error/notice仍在Column插行，移至Stack定位浮层。
   其他手动删除/改名/缺tmux安装错误继续可操作，不更改provider恢复算法。
4. MainShell activeServer监听目前只比较id，但同id主机/端口/用户配置变化会使
   agentUpdatesProvider按connectionKey重建并清空chatEntered。应比较connectionKey，
   当前确在ACP/CLI页面时重新onChatEntered；postFrame回调再检查当前页面，
   防快速离开后仍当作正在进入。原来的未进入页面不自动检测规则保持。

按UI白名单修，完成后主代理重新跑测试和生成。若当前主批已修请指出准确位置，
不要重复实现；任何生产UI改动不能由主代理代做。

## 新增更新弹窗／编译复核

5. `AgentUpdateDialog` 的core interrupted标记在执行开始即持久化，以便崩溃恢复；
   UI不能在isBusy时显示“已中断”。只有不在执行且确有中断时显示。
6. apply失败后_plan已一次性消耗，不能重新启用确认按钮重放同计划；提供只读
   重新检测／prepare，再展示新计划供再次确认。不能自动重试远端更新。
7. 版本Row中source目前无宽度约束，长npm包名320dp/2x会溢出；用可换行独立
   行或有界Flexible，版本、来源、确认动作全部保留。请同样自检管理卡片。
8. 首次编译发现不存在的 `VRadius.small`、`l10n.retry`、`l10n.closeButtonTooltip`，
   请使用现有tokens/本地化键；新增agentUpdate键请齐全补17ARB后再交付。
   core测试1702通过/1跳过，两文件加载仅被这些进行中UI编译问题阻挡。
9. 管理页更新状态不能直出 `comp.status.name`（unsupported/missing）或errorCode；
   用户看到本地化未安装／需手动更新／失败摘要，技术码放诊断详情。管理卡片
   同样不能在updateEntry.isUpdating时显示持久化interrupted的中断文案。
10. 当前入口直接 `AgentUpdateDialog.show(profile: profile)` 准备全部组件，没有
    用户选择CLI/ACP的入口。批准计划要求选择待更新组件；请在只读检测后提供
    可操作组件勾选（缓存available允许prepare复核），选定后prepare生成精确计划，
    展示后再确认。OpenCode单组件不重复。不能勾选unsupported/error后猜命令。
11. 从管理页直接查看更新详情时也应调用dismissUpdateNotice（只记录已读，不执行
    更新），不能只在顶部通知入口ack，否则看过详情后仍重复提示。
12. 新登录锁两个入口的finally都在await交互登录后 `ref.read(...)`，路由已被
    销毁时会抛 disposed WidgetRef，且可能漏释放登录标记。请await之前捕获
    `final registry = ref.read(agentRegistryProvider.notifier)`，begin与finally/end
    均调用同一捕获notifier（core的end自带ref.mounted/token校验），不要把finally
    简单套mounted后放弃清理。管理页和ACP fallback入口都要修。
13. 差异检查：app_hi/id/th/tr/vi.arb 新增多余EOF空行，请只去掉多余空行（保留
    正常文件末尾换行）；17语言生成已经通过，无缺失翻译，不重写其他文案。

后续复核：不要手改生成文件`lib/l10n/app_localizations.dart`添加`retry`等alias！
本轮已观察到`String get retry => stateRetry;`被手写进去，下一次gen-l10n必然
删除它。必须修改UI调用者为已有stateRetry/MaterialLocalizations的close tooltip，
无需新getter。生成代码最终会由主代理重新生成，不能以手改生成文件绕过编译。
