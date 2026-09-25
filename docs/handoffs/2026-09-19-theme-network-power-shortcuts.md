# 2026-09-19 主题、网络、关机与快捷入口交接

## 产品决策

- 终端画布不再拦截长按/拖动，交还给 xterm 原生交互；辅助键栏保持。
- 设置页的单选项（主题模式、语言、自动连接模式、启动页）改为摘要行与弹窗；主题色单独按浅色、深色、极客黑暗配置。跟随系统按当前系统亮度读取前两者。主题色支持预设、可视化选色和 `#RRGGBB`；旧单色偏好保留为三个新槽位的缺省回退值。
- 仪表盘运行时间移至服务器信息卡；重启、关机、断开连接靠近服务器名称。关机与重启共用目标校验、临时 sudo 密码和危险确认，但关机不做 boot_id 重启验证。服务器断开后命令执行结果未知，不得自动重试。
- 网络主卡仅显示默认路由网卡上下行，不合计 Docker/VPN 等可能重复计数的接口；弹窗可查看各网卡详情。Linux procfs 计数器以两次采样的差值/实际秒数换算，首采样或计数器回退不提供速率。
- 快捷入口选择和顺序独立于底栏导航，默认保持旧六项，可全部隐藏；候选为除仪表盘外的其他页面，持久化 AppSection 名称而非 tab 下标。

## 状态与持久化契约

- `SettingsState.lightAccentColor`、`darkAccentColor`、`amoledAccentColor` 是不透明的 `Color`；`colorForTheme(mode)` 供 UI 读取。`setThemeAccentColor(mode, color)` 只写目标模式。`system` 模式没有独立写入口。
- 新颜色键为 `valhalla_accent_color_v2::<mode>`，格式 `#RRGGBB`。键不存在或非法时读取旧 `valhalla_accent_color_v1` 对应预设；旧键不删除，以支持回退。重置默认同时覆盖三个新键。
- `SettingsState.dashboardQuickSections` 和 `setDashboardQuickSections` 以稳定 AppSection 保存排序；存储键 `valhalla_dashboard_quick_sections_v1`。缺键返回旧六项，空列表表示用户明确隐藏，未知项/重复项/仪表盘项被过滤。
- `SystemMetricsSnapshot.primaryNetworkInterface` 指向默认路由网卡或首个非回环回退网卡，`networkRates` 提供各网卡每秒接收/发送字节数。无上一次计数器、零时间间隔或回退计数器时对应速率缺失。
- `ServerPowerState.action` 区分 `reboot`/`shutdown`；`ServerPowerNotifier.shutdown` 复用相同的身份与权限防线。关机 `accepted` 仅表示命令通道返回成功，`unknown` 表示发出后通道丢失，均非物理关机验证。

## 验收边界

- 自动化：旧偏好兼容、三模式互不覆盖、快捷入口空值和排序、默认网卡速率与回退、计数器重置、关机权限/切服/断线保护、共享终端长按和设置/仪表盘 Widget 交互。
- 真实 Linux SSH 与 Android/桌面 UI 行为仍需可控测试服务器和目标设备验收；不得在生产服务器自动关机测试。
- 展示层只由指定 `agy` Valhalla 历史会话、`gemini-3.8-flash-high` / high 修改。此文档不将未通过验收的行为标记为已发布。

## 自动化结果

- `flutter test --no-pub --reporter expanded`：815 项通过，包括关机结果未知横幅与单次 sudo 密码挑战测试。
- `flutter analyze --no-pub`：No issues found。
- `dart format --output=none --set-exit-if-changed lib test`：191 个文件无格式改动；`git diff --check`：通过。
- `flutter build apk --debug --no-pub`：成功生成 Android debug APK。真实 Linux SSH 关机、网卡采样和设备端长按手势尚未实测。
