# AgY 第一批：工具栏配置与不挤页面的恢复浮层

先读 `2026-10-15-agent-updates-toolbar.md`，仅原Valhalla会话，Gemini3.8Flash/high。
使用frontend-design技能的响应式/交互复核原则，但本任务明确沿用现有Norse Steel
主题和Material组件，不另起视觉设计、不改现有文件行/网格尺寸。

允许修改：lib/widgets/remote_browser_toolbar.dart、remote_browser_view.dart，
lib/features/files/sftp_file_view.dart，lib/features/settings/settings_view.dart、
必要新增settings/widgets工具栏配置弹窗；lib/features/shell/main_shell.dart与
widgets/connection_status_banner.dart；lib/features/dashboard/dashboard_view.dart、
docker/docker_view.dart、system/system_view.dart、terminal/terminal_view.dart；
17个 lib/l10n/*.arb。可更新本交接文档末尾结果，不写其他文档。
禁止改 core/data/infrastructure/tests/platform/pubspec；禁止格式/测试/生成/
构建/ADB/提交/推送/远端操作。生成l10n由OpenCode处理。

## 第一批先做恢复浮层（不依赖新核心）

三套Shell布局把ConnectionStatusBanner从Column挪到内容区域顶部定位，不改变
正文布局。顶栏下8dp，左右12dp，最大宽560；Material不透明surface。
只卡片接收点击，外围透传；保持在Shell树内，drawer/dialog盖住，不能抢焦点。
继续用原聚合/详情/重试/两秒恢复成功逻辑；不是新增全局Toast框架。RTL/2x/
320dp/减少动画要可用，不缩字体、不满屏遮罩、不为倒计时每秒播报读屏。

Files、Dashboard、Docker、System缓存横条不能再条件插入正文；缓存时间仍
须在固定高度状态区域/恢复详情可查看。Terminal tmux恢复成功同样浮层，不挤
终端改变PTY尺寸；缺少tmux/主机密钥变化等安全动作不能因迁移被隐藏。

## 第二批工具栏（待新核心落盘再接，不造API）

core同事将提供 lib/data/models/remote_file_toolbar_action.dart：
RemoteFileToolbarAction enum upload/create/view/transfers/hidden/sort/selection/
bookmarks/refresh；defaultRemoteFileToolbarActions；SettingsState.remoteFileToolbarActions
以及 SettingsNotifier.setRemoteFileToolbarActions(Iterable<RemoteFileToolbarAction>)。
保存Future先持久化成功再改state。更多新增自定义工具栏，设置加入同一弹窗入口；
只勾选固定归属、保存/取消/默认，空选择有效。默认前4固定，其他进更多；更多
固定行尾，固定项多单行横滚。所有操作保留callback及离线/忙态禁用一致；传输
可用callback/count兼容既有Widget插槽；不要把IconButton塞进PopupMenuItem。
isPicker沿用原动作，不应用管理偏好，不泄露管理操作。设置搜索需索引新增入口。

只做上述UI并报告真实落盘文件、接口假设和剩余项；不声称测试通过。
# 当前复核补充（2026-10-15）：不能只移动总横条

三套 Shell 的 ConnectionStatusBanner 已移到 Stack，但 dashboard_view.dart 的
`if (isOfflineCached)` 子树（含12px间隙）、sftp_file_view.dart 的
`if (sftpState.cachedAt != null) _buildCachedBanner(...)`、docker_view.dart 的
`_buildCachedBanner` 仍在正文 Column 中，重连仍会造成位移。请一并移出正文，
统一顶部浮层/详情展示缓存时间；不要仅将 banner 方法返回空而保留动态间隙。
终端恢复提示也确保真正放入 Positioned，原 Column 不留占位。

