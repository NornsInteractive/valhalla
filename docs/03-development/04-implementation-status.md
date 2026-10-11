# Valhalla - 实施状态与工程基线

## 当前：2026-10-11 九项完善与追加修复（开发中，尚未打包安装）

按[本轮完成契约](../../agent-workflow/2026-10-11-completion.md)继续实施。
新增远程文件隐藏项的图标与文本弱化、列表／卡片视图切换与偏好保存，
AgY 已完成展示层，OpenCode 专项 29 项通过；选择控件和操作菜单不弱化。
随后文件视图、传输完整性及草稿恢复联合复测 **102 项通过、0 失败**。
隐藏项的小字元数据／链接警告徽标对比度已由原 AgY 修正，尚未做新包
实机检查；专项通过不代表整应用已可打包。
终端按实例保留历史阅读位置／跟随末尾意图，显式键盘意图避免弹窗关闭后
自动唤起输入法，相关 14 项通过。快捷栏与安全粘贴仍在收尾。

业务实现包括有界、按连接身份隔离的冷启动缓存，文件修订检测及安全替换、
加密编辑草稿，持久化显式续传与来源／本地完整性验证，真实服务状态与
日志／PID 身份校验，NAS 缩略图队列和缓存 API，GitHub 稳定版更新与原生
Android 安装前身份验证。上述业务测试已有分组通过证据，但消费者 UI
和新增竞态保护仍待完成，不等同于本轮全量通过。

GitHub 更新入口及更新弹窗已由 AgY 实现，17 种文案已生成，多语言一致性
检查通过，更新界面专项验证仍待完成。此前 AgY 配额耗尽；用户要求继续后已重新启动 CLI，原 Valhalla
会话和指定模型／high 确认正常处理 UI 修复。终端弹窗／全局输入法及编辑器、
服务和 NAS 消费者尚未验收；没有改用其他 UI 作者或让主 Agent 越界修改。
业务修复与免费 OpenCode 测试继续。

原 AgY 已修复终端编译导入、tmux 非空引用及固定键弹窗布局，并落实根路由／
Shell 的移动端焦点清理。OpenCode 首轮新增 SSH 回归后的九文件联合门禁为
**128 通过、4 失败**；其后窄屏与桌面收尾夹具、各语言资源问题已修正并分组
通过。最新九文件联合复测为 **131 通过、1 失败**：固定键排序持久化断言仍
未通过，尚不能确认仅为夹具问题，不能标记为全绿。新增用户要求“SSH 终端
点击不弹键盘，右下角按钮主动唤起”已交原 AgY，见
[专项交接](../../agent-workflow/2026-10-11-ssh-explicit-keyboard-ui-handoff.md)；
CLI／容器／登录终端保持默认交互。原 AgY 已完成 SSH 点击不唤起键盘及
右下角固定按钮，17 种按钮提示及粘贴占位元数据已补齐。OpenCode 多语言
生成、限定文件格式化和终端／根焦点专项静态检查均退出 0、零问题；
实际 SSH 专项 **17 项通过**（Android／iOS 显式键盘、320dp 大字号及 Windows
普通／中文／物理键输入），多语言一致性 **9 项通过**，测试风格提示已由 OpenCode
修正，更新后的终端／根焦点／两份终端测试六目标静态检查零问题，相关终端
身份守卫测试 **1 项通过**。见[专项验证](../../agent-workflow/2026-10-11-ssh-keyboard-validation.md)。
尚无新包或设备验证；其他消费者 UI 与整应用验收仍待完成。

本轮没有构建、ADB 安装、推送或发布。下方通过数字、安装包、设备检查
均为此前版本的历史记录，不能用来证明当前工作树已验收。

## 2026-10-10 移动端五项回归修复（历史：全量检查通过，ADB 已覆盖安装）

- 路径段改为文字自适应宽度，保留 44px 点击高度、完整路径提示和原导航；实测短目录段宽 24px，相邻文字间距约 22px。
- SSH 终端所有平台统一独立关闭按钮和本地 ANSI 清屏刷新；保留最后页签，不发送远端清屏命令。
- Android 新增原生自适应及圆形图标资源，保留旧系统兼容和原品牌素材。
- Docker 列表命令补齐缺失的 JSON 结束括号；拒绝把损坏响应当空列表。刷新错误保留缓存并可重试，筛选栏单独位于容器/Compose 选择器下方，选择器在窄屏内可点击。
- 抽屉开关释放内容焦点，隐藏及转场中的非当前页面不能获取焦点；页面、连接和输入草稿不重建。

展示层由原 AgY Valhalla 会话（Gemini 3.8 Flash / high）修改；OpenCode 使用已核验免费模型 `opencode/step-5-preview-free` 完成检查、构建及安装。
最终全量 **2195 通过、18 环境跳过、0 失败**；`flutter analyze --no-pub` 和 `git diff --check` 均退出 0。
版本仍为 **1.0.3+4**。三个 ABI 正式签名 APK 单独保存，未覆盖已发布产物；经用户许可，ADB 设备 `127.0.0.1:14251` 使用原调试证书签名的 release 模式 x86_64 测试包执行 `install -r` 成功（code 4004），首次安装时间不变，没有卸载或清数据，启动成功。
本轮未推送、未发布 Release、未触发云端构建；自动化通过不代表所有真实服务器操作、OEM 桌面图标或物理手机输入法均已验收。
ADB 只读检查：保留的 racknerd 配置自动连接成功，远程根目录文件可见；容器列表与 Compose 项目均显示真实数据，筛选栏位于选择器下方。搜索输入法状态按“点搜索/开菜单/关菜单/再点搜索”依次为显示/隐藏/隐藏/显示；搜索词仍为空。未执行容器生命周期、终端命令或真实 Agent prompt。
见[修复契约](../../agent-workflow/2026-10-10-mobile-regressions.md)、[最终检查](../../agent-workflow/2026-10-10-mobile-final-gates.md)及[构建安装记录](../../agent-workflow/2026-10-10-mobile-build.md)。

## 2026-10-03 后台恢复 / AgY / 下载修复（历史检查与安装记录）

业务代码已完成同目标数据保留和健康探活去重、连接后的自动 Agent 检测、
AgY 已保存凭据官方复验、OAuth 回调返回、独立 CLI 模型目录与下载隔离/
错误分类/单次网络重试。AgY 原 Valhalla 会话已完成展示层改动；新增认证
探针测试复现同步事件回调内关闭 controller 的错误，业务层窄层补修后
5 项探针回归通过。连接自动检测又暴露真实注册表与连接层的循环依赖，
已调整命令式启动入口，真实注册表参与的 7 项连接回归通过。
需求与专项实现不能等同于完整验收。

原 ADB `127.0.0.1:14251` 已恢复。OpenCode 最新全量
**1881 通过、18 跳过、0 失败**（`fullsuite_final2.log`），多语言生成、
格式化及静态分析零告警通过。旧包已保留为
`app-release.apk.bak-20261003-224443`。本轮 release 构建退出码 0，新包
**123916842 字节**，mtime **2026-10-03 14:47:01 UTC / 北京时间 22:47:01**，
SHA-256 `8a0bdd0de0897605623aae9f2745ed49c30d2ff56ebc649079a1905a056cd47f`。
新旧签名一致，仍是 Android Debug 签名，不是商店签名。OpenCode 对原设备
`install -r` 返回退出码 0 / Success，设备取回的已安装 APK 与上述 SHA-256
完全一致，新包/设备包独立签名校验均退出码 0。未卸载或清数据；启动自动连接 racknerd、
短时 Home/锁屏恢复检查可见原内容及更新后的指标，但新包运行期间记录了
**14:49:27 UTC 的 `dart.unhandled / SSH connection closed`**，具体触发和
未处理 Future 来源未知。不能宣称设备零异常或所有恢复问题已排除，
有界补查确认，智能会话后台 25 秒后返回首帧和 12 秒后的画面均保留原 Agent/
已有消息，PID 始终 12893；不能代替长时间后台/进程回收验收。
实际模型下拉框可见独立 CLI 候选 Gemini 3.8/3.7/3.6 Flash（各 High/
Medium/Low）、Gemini 3.1 Pro（High/Low）；仅打开查看并取消，未应用设置，
不据此证明账号对候选模型的调用权限。实际 Agent 管理页未手动刷新即显示
CLI 已安装、ACP 已就绪、Auth 已登录，最近检测 23:03:37 +08:00。
本轮没有进行 Google 同意、真实 prompt/历史修改或真实文件下载。
下方旧 APK 和通过数字均是历史记录。
MiMo 和 Big Pickle 遇到上游 429 后，按用户免费模型例外，
核验零价格及官方 Free 说明，改由同会话主/辅助 `opencode/space-bunny-free`
继续验证。Google 授权、真实远端模型应用和 Docker 端到端仍不能宣称通过。
见[当前验收契约](../../agent-workflow/2026-10-03-recovery-auth-final-gates.md)
及[工作记录](../../agent-workflow/2026-10-03-recovery-auth-download.md)和
[本轮验证报告](../../agent-workflow/2026-10-03-recovery-auth-verification.md)。

## 2026-10-03 授权转发断线补修（验证/构建完成，ADB 离线待安装）

继续检查上轮 SSH 断开诊断，新增已认证真实 SSHClient / 模拟 socket 掉线
测试正常返回 false、清理连接并广播掉线，未复现历史 `dart.unhandled`；
真实 racknerd 连接为什么断开仍未知，不改心跳/重连策略，不声称根因已修复。
另复现授权回调转发的 stderr 流错误不进入调用方，并在同一流程确认
done 错误观察过晚的代码风险；done 初期夹具的 zone 错误不能当作严格的
修复前产品断言证据，最终四条失败路径均已覆盖。首次补修以 Future.any
竞争仍可能让成功先于 stderr
处理；最终改为发送前接管输出及结束事件，两路输出都处理完毕才判断
成功，任一路异常立即失败，通道打开后的写入/读取/完成等待共享 20 秒
期限，关闭抛错仍取消监听。仅修改业务基础设施，无 UI 或依赖变更；
不复制 CLI 凭据、不自动重发，认证成功仍由官方 RPC 确认。

OpenCode 主/辅助均为 `opencode/mimo-v2.6-flash-free`。11 项回调与 19 项
SSH 传输专项 **30/30 通过**；全量 **1808 通过、18 跳过、0 失败**，静态
分析零告警，本轮明确授权的 3 个文件格式检查通过。初始测试夹具的 void /
错误 zone 跨界等待导致编译失败/超时，已修正；模拟正常 exec 也补齐 stderr
结束事件，所有原有断言和 4 个新失败路径断言保留，没有新增跳过。

新 `build/app/outputs/flutter-apk/app-release.apk` 构建退出码 0，大小
**123736478 字节**，mtime **2026-10-03 08:17:03 UTC**（北京时间 16:17:03），
SHA-256 `5f0f3bae6d07ed83be1c3e2b6c234ce2e9008c1be43dd462d32eb6095aa7c4db`。
14:44 包已保留为 `app-release.apk.bak-20261003-161602`，保留原 mtime 与
SHA-256 `6ff2244ea5cf00db417c3b956b5aa7f2d5332610f1da5bc7315c40e8aa13035e`。
新包与备份签名核验一致，仍为 release 构建 / Android Debug 签名，不是
商店签名包；相同大小不表示相同内容，本轮 hash 与旧包不同。

**当前尚未覆盖安装或启动新包**：OpenCode 检查 ADB 列表为空，原目标
`127.0.0.1:14251` 连接被拒绝。没有新建模拟器、卸载、清数据或读取账号
信息；需用户恢复同一设备或提供新地址，由 OpenCode 继续安装和有限启动
检查。下方 14:45 的安装及 13:40 的浏览器实测均是历史版本，不能代替
16:17 包的设备验收。Google 授权、真实回调及 Docker 端到端仍待用户。
见[本轮验证/安装契约](../../agent-workflow/2026-10-03-ssh-auth-disconnect-final-gates.md)
及[最终结果](../../agent-workflow/2026-10-03-ssh-auth-disconnect-investigation-result.md)。

## 2026-10-03 AgY ACP 浏览器登录（补修完成，新 release 已覆盖安装）

**最终代码验收**：原 AgY 修复手动回调弹窗取消时
`TextEditingController was used after being disposed`，控制器等路由退场完成
后再释放；取消/提交立即清空输入。草稿认证卡片增加滚动约束，输入工具栏
用外层及目录内层弹性约束修复 320dp / 两倍字体的 53px 横向溢出。
OpenCode 新增 8 项严格控件测试，覆盖打开一次、打开失败、手动回调校验、
取消、真实 RPC 成功语义及窄屏，全部通过并重复验证三次；没有吞掉异常
或放宽溢出断言。新滚动布局下四个既有测试夹具增加 ensureVisible，保留
原认证行为断言。最终全量 **1803 通过、18 跳过、0 失败**，静态分析零告警，
多语言生成及明确授权的本轮路径格式检查通过。

OpenCode 初查旧版本时在现有 ADB / `racknerd` 只读核实：AgY CLI 与 ACP 二进制就绪，
登录检查字段为空，检测日志为 authentication: not configured；当时点击登录
无浏览器跳转。官方 1.2.1 源码确认 CLI/ACP 独立凭据，旧应用仅缓存认证
方式，下一次发送才认证，授权 stderr 仅进诊断日志。

业务层已补 immediate authenticate、官方授权请求提取、手机回环与 SSH 原
目标回调、配置只读检查及旧配置回填；不读取 token、不新建会话、不自动
重发。AgY 原会话完成浏览器/回调/管理入口展示并退出，OpenCode 主/辅助均为
`opencode/mimo-v2.6-flash-free`。13:40 阶段全量测试为
**1795 通过、18 跳过、0 失败**，不能代替上面的最终 1803 项验收。首轮两个旧夹具仍期待空登录检查和仅选择
认证方式就提示成功，已按实际登录检查及 RPC 成功语义更新，相关 34 项
与全量重新通过；没有改回产品错误行为。全仓格式只读检查发现 34 个
未格式化文件（尚未确认是否全部属于既有基线），没有为本轮修改无关 UI；
随后由 OpenCode 对明确授权的本轮产品/测试/生成路径机械格式化并检查通过，
没有改变 UI 语义或为本轮重写无关页面。

新 `build/app/outputs/flutter-apk/app-release.apk` 为 **123736478 字节**，
mtime **2026-10-03 06:44:39 UTC**（北京时间 14:44:39），SHA-256
`6ff2244ea5cf00db417c3b956b5aa7f2d5332610f1da5bc7315c40e8aa13035e`。
13:40 阶段包保留在
`build/app/outputs/flutter-apk/app-release.apk.bak-20261003-144316`，SHA-256
`3e748162ab1dc2a29649073d581d73b91d529f6e614251dc078bb64f304b424a`；
11:30 旧包另保留在 `build/app/outputs/flutter-apk/app-release.apk.bak-20261003-133900`。
仍为 release 构建、Android Debug 签名，不是商店签名包；新旧签名一致。
OpenCode 已对现有 `127.0.0.1:14251` 执行 `install -r`，退出码 0 / Success，
原配置和数据保留；从设备取回的已安装 APK 与新构建 SHA-256 一致。
设备更新记录为北京时间 **14:45:52**，启动退出码 0，MainActivity 前台、
进程存活；45 秒有限日志观察未见 Android fatal / ANR，不代表所有功能
或长时间后台恢复均已完成真机验收。

OpenCode 在 **13:40 阶段包**的 racknerd 已通过实际 initialize 获取四种官方认证方式，选择
Google 后点击“去登录”，设备前台切换到 Chrome，授权目标为
`https://accounts.google.com/o/oauth2/v2/auth`（证据不含授权查询参数）。
返回应用仍保留原对话、显示等待浏览器授权；取消仅结束本次认证，恢复
“请求认证”入口，无自动发送。**Google 账号授权未完成**，由用户确认；
真实授权回调后的对话及 Docker 端到端登录尚未验收，不能据此宣称登录成功。
最终新包的安装/启动检查与上述阶段包浏览器实测分开记录，不假称在最终包
再次完成了 Google 登录或真实回调。
设备期间另记录一次 SSH 断开后的 `dart.unhandled / SSHStateError`，登录按钮
操作前已发生，来源尚未定位；不能宣称设备检查零异常。**下面此前 APK
和测试记录均为历史版本证据，不可代替本轮验收**。
详见[本轮契约](../../agent-workflow/2026-10-03-agy-login-flow.md)和
[只读设备证据](../../agent-workflow/2026-10-03-agy-login-device.md)和
[最终验证报告](../../agent-workflow/2026-10-03-agy-login-verification.md)。

## 2026-10-03 合并远程 mosh 修复与 AgY 认证提示（release 已构建并覆盖安装）

已 fetch 并快进至 `de37ed6`，保留远程 mosh locale 协商、僵尸 SSH 清理、
终端字号设置、仪表盘 neofetch，同时恢复本地 ACP/缓存/重连修改；没有文本
冲突，合并前工作区完整备份仍在 `valhalla-before-origin-update-20261003` stash。
不自动提交或推送。OpenCode 合并与认证专项 447 项通过，mosh 真机用例默认
跳过，未读取真实 SSH 密钥或运行真实远端推理。

AgY 原 Valhalla / Gemini3.8Flash High 修复无条件登录催促和长安装命令弹窗
滚动。业务层区分实际 ACP 认证请求与用户取消，新增
`awaitingAuthentication` 状态；真实会话/请求成功才清除匹配目标的旧认证
提示，明确重试复用占位消息并恢复 streaming→completed，不自动重发。
initialize/安装成功不算登录，认证失败仍显示真实挑战。AgY 补充 UI 已
FINAL READY 并退出，挑战在待认证消息附近单处显示，草稿仍有入口；安装
弹窗支持滚动/复制及窄屏换行。OpenCode 主/辅助仍为
`opencode/mimo-v2.6-flash-free`：专项 120 项、修正终端字号设置测试夹具后
相关 65 项通过；最终全量 **1713 通过、18 跳过、0 失败**，格式/多语言/
静态分析通过且零告警。首轮 24 个缺少设置依赖的测试失败已通过夹具注入
修复，未修改产品初始化、放宽断言或增加跳过；320dp/两倍字体弹窗测试
发现的溢出已由 AgY 修复并严格复测。

新 `build/app/outputs/flutter-apk/app-release.apk` 为 **123419671 字节**，
mtime **2026-10-03 03:30:19 UTC**（北京时间 11:30:19），SHA-256
`23cc6e9175643e5c4b17e6c9fc1e9bb9fec8990566f6556f505d103ceef594a8`。
版本 1.0.0+1；release 构建仍用 Android Debug 签名，不是商店签名包。
旧包已备份到 `build/apk-backup/app-release-prev-20261003-20261003T032851Z.apk`。

现有 ADB 目标 `127.0.0.1:14251` 单次重连成功，OpenCode `install -r`
实际退出码 0 / Success，启动成功、进程存活且前台显示；有限启动日志检查
未发现 FATAL EXCEPTION、am_crash、am_anr。没有卸载、清应用数据或新建
模拟器。**启动检查不等于远端验收**：用户实际宿主机（及 Docker）认证、
登录共享和真实 ACP 对话尚未端到端验证，也未激活真实 mosh e2e。
见[本轮交接](../../agent-workflow/2026-10-03-merge-mosh-agy-auth.md)。
最终证据见[OpenCode 验证报告](../../agent-workflow/2026-10-03-merge-agy-verification.md)。

## 2026-10-02 官方 Antigravity ACP、消息顺序与重连（release 已构建，ADB 待连接）

官方入口与用户确认安装、按首次事件交错输出、未知结果状态、单 adapter
恢复及同目标列表/仪表盘缓存保留已写入业务层；AgY 原 Valhalla / 指定 High
模型已完成展示复核并退出。OpenCode 主/辅助均使用
`opencode/mimo-v2.6-flash-free`，核心目录 615 项及后台生命周期专项 32 项
通过；统一顶部状态、ACP/CLI 内容与草稿保留的四个控件文件 72 项通过。
最终全量 1664 项通过、17 项既有环境跳过、无失败；多语言生成和静态分析
零告警通过。首轮编译/旧语义失败已修正，不作为最终验收结果。

`flutter build apk --release` 实际退出码 0；新包为
`build/app/outputs/flutter-apk/app-release.apk`，123304935 字节，mtime
**2026-10-02 10:55:18 UTC**（北京时间 18:55:18），SHA-256
`6dfed53b4e8f14241a9c200e2c841c54aadc5a56f3b81b8e43c7ea8f1b3dd4b9`。
版本仍为 1.0.0+1，release 构建但沿用 Android Debug 签名，不是商店签名包。
旧包已备份到 `build/apk-backup/app-release-prev-20261002-105359.apk`，
保留原 SHA-256 `e7efc0ce52f1466a92c31e79c05e8d716c2a8c2c8c1263203d2491be140dd34b`。

**本轮尚未 ADB 安装或设备启动验收**：设备列表为空，原目标
`127.0.0.1:14251` 连接被拒绝，`get-state` 退出码 1。`adb connect`
虽返回退出码 0，其文本明确失败，不能据此宣称连接成功。没有卸载或清数据；
待用户恢复设备后由 OpenCode 继续覆盖安装与有限启动/崩溃/ANR 检查。
真实官方登录/对话、用户远端后台恢复尚未验收；没有读取当前运行 Agent
的凭据或发送真实 prompt。完成证据更新至
[本轮契约](../../agent-workflow/2026-10-02-acp-and-reconnect.md)、
[UI 报告](../../agent-workflow/2026-10-02-acp-reconnect-ui-status.md)和
[验证报告](../../agent-workflow/2026-10-02-acp-reconnect-verification.md)。

## 2026-10-01 ACP运行时对齐与首轮前命令：回归、打包与覆盖安装完成

已确认当前环境PATH Codex 0.159.3、codex-acp 2.0.0内置Codex 0.158.0，
实际用户远端的版本/登录差异尚未验收。标准Codex ACP启动改为在所选宿主机或
容器用户环境解析配置的CLI可执行路径（绕过Bash别名），显式设置CODEX_PATH，
stderr诊断记录路径与版本；找不到CLI明确失败，不退回内置副本。自定义启动
脚本保持原语义，不改登录或配置文件，不替换用户指定模型。
草稿initialize后提供已核实的codex-acp 2.0.0兼容命令预览，实时skills独立查询；
未知适配器/版本不伪造清单，真实available_commands_update含空列表均优先。
选择只插入草稿，Send才按现有流程建会话并直接执行命令，无垫底普通对话。
打开/刷新菜单不建本地或远端会话，不读/恢复历史。技能查询失败保留命令；
成功重试仅清除目录错误，不清除其他错误。UI由原AgY/指定模型修改，OpenCode
MiMo免费模型负责回归及最终APK/ADB。专项160项、控件15项、恢复/历史23项通过；
全量1631通过、17既有环境跳过、0失败，静态分析零问题，多语言生成成功。
CLI命令纳入运行时身份；两处旧测试夹具按实际CLI更新，未放宽跨目标检查。
另修复ACP传输在initialize之前关闭、无流监听时等待不结束的问题，并覆盖回归。
新APK为123288495字节，mtime **2026-10-01 14:57:42 UTC**（22:57:42 +0800），
SHA-256 `e7efc0ce52f1466a92c31e79c05e8d716c2a8c2c8c1263203d2491be140dd34b`。
版本1.0.0+1，release构建但仍沿用Android Debug签名，不是商店签名包。
旧包备份为 `build/apk-backup/app-release-prev-20261001-225532.apk`。
OpenCode向现有ADB模拟器 `127.0.0.1:14251` 覆盖安装成功，设备更新时间
22:58:46 +0800；未卸载、未清数据。冷启动成功、PID16448存活、MainActivity
前台，有限观察及崩溃/事件/进程日志检查未见fatal/ANR。
真实远端账号对模型的接受情况仍须用户验收；模拟协议和启动检查不代表真实对话成功。
见[本轮契约](../../agent-workflow/acp-runtime-draft-commands-ui.md)及
[验证报告](../../agent-workflow/acp-runtime-draft-commands-verification.md)。

## 2026-10-01 CLI模型目录与手动模型：实现、验证与覆盖安装完成

用户最新要求覆盖下方HTTP/OAuth模型目录方案：默认通过所选服务器/容器/用户的
既有Codex CLI app-server `model/list`查询，无额外授权，不读/恢复聊天。
复用分页、隐藏过滤、去重、超时和关闭逻辑，手动刷新重新查询。
目录可能受CLI版本/缓存影响，不声明保证云端实时或订阅可用性。
新增 `ChatRunSettings.customModel`（旧JSON默认false）；手动名可越过目录成员
校验，但仅向已声明model配置发送，远端必须确认精确值；普通列表/推理/权限
校验不放宽。AgY原Valhalla / Gemini3.8Flash High 已完成共享弹窗与授权入口移除，
OpenCode `opencode/mimo-v2.6-flash-free` 完成验证、生成、格式、打包与ADB：
专项145通过（共享弹窗控件28通过），全量1598通过、17既有环境跳过、0失败，
静态分析零问题。新增首发回归覆盖初始会话配置通知不丢失手动模型意图。
新APK为123190191字节，mtime **2026-10-01 11:41:48 UTC**（19:41:48 +0800），
SHA-256 `32c3478d689fefe7173586e1f9a4ce1bed16b3b105a56c338383d068d91514a3`。
版本1.0.0+1，release构建但沿用Android Debug签名，不是商店签名包；旧包已备份。
OpenCode于19:42:13 +0800向现有ADB模拟器 `127.0.0.1:14251` 覆盖安装成功，
未卸载或清数据；启动后PID24879、MainActivity在前台，有限观察窗口无fatal/ANR。
真实远端模型是否接受
手动名称仍须用户验收，不把模拟协议测试或启动检查等同于真实对话验收。交接见
[CLI模型/UI契约](../../agent-workflow/cli-model-catalog-ui.md)。

## 2026-10-01 实时目录与草稿能力：自动化验收与 release 安装完成

OpenCode 主/辅助均使用 `opencode/mimo-v2.6-flash-free` 完成最终验证、打包和ADB。
最终全量 **1564通过、17既有环境跳过、0失败**，相关控件70项通过（含新增22项），
静态分析零问题，多语言生成成功，12个相关源码/测试格式检查零改动。
原 AgY Valhalla / Gemini3.8Flash High 已完成
UI及复核，主Agent未接管展示修改。详细阶段证据见
[发布验证报告](../../agent-workflow/live-models-draft-release-verification.md)。

新包 `build/app/outputs/flutter-apk/app-release.apk`，123304927字节，mtime
**2026-10-01 10:51:48 UTC**（18:51:48 +0800），SHA-256
`1dfe9ab4e59b93e3234300ece10ec2cffcb2390ae584cda0732cbb728d4b0f35`。
版本1.0.0+1，沿用Android Debug签名；是release构建，不是商店签名包。
旧APK已保存于 `build/apk-backup/`，没有删除。设备 `127.0.0.1:14251`
于18:52:10 +0800覆盖安装成功，未卸载、未清数据；启动后PID26523保持存活，
MainActivity在前台，有限观察窗口未发现fatal/ANR。真实授权、最新账号目录与
用户Docker对话仍须用户验收，不把模拟与启动检查宣称为真实远端验收。

最终格式补查发现的3个UI文件已由OpenCode机械格式化，不涉及展示或语义修改；
上方为重新全量验收、构建及安装后的最终APK，18:39的中间包已备份。
以下为实施过程与先前快照：

独立 HTTP 账号模型查询、远端隔离 OAuth 业务、草稿 skills/list 嵌套解析、
ACP 模型支持校验和 -32603 分阶段诊断已写入。
OpenCode `opencode/mimo-v2.6-flash-free` 前次快照验证：专项194通过，全量1495通过、
17既有环境跳过、0失败；flutter analyze零问题，6个业务文件格式检查零改动。
以上为前次快照，不代表功能完整交付。
最新补验已发现并修正草稿未订阅 ACP 后续控制通知的问题；草稿/模型设置/错误诊断
相关47项通过（Provider32、诊断6、恢复9）。远端 OAuth/JWKS/刷新脚本已通过
21项真实 Node 执行的隔离模拟，不读取真实凭据、不连接服务、不发送推理。
另修复手机授权监听吞掉非法端点/缺失状态固定错误码的问题；授权专项40项通过，
业务快照静态分析零问题，全量1532通过、17既有环境跳过、0失败（UI接入前）。
真实授权、最新模型目录与 Docker 诊断仍待验证；模拟不证明真实服务兼容。
详见 [补充验证报告](../../agent-workflow/live-models-draft-remaining-verification.md)。
已纠正 print 路径 EOF 的可用性误判：原 Valhalla 交互会话实际可响应，并已由
Gemini3.8Flash High 完成授权入口、草稿命令/技能菜单、模型警告/空态与兼容下拉，
以及目标切换、等待保存和弹窗销毁保护。主 Agent 只补 Android 官方授权浏览器
桥接，OpenCode 浏览器模拟10项通过；新增 UI Widget20项、相关68项通过，
静态分析零问题。原 Valhalla 已复核并接收 CLI 参数误开会话产生的三处窄修正，
事故及恢复方式记录于 UI 报告；不得再次组合 --conversation/--prompt-interactive。
最终弹窗销毁/动态命令补验、全量测试、release构建及安装正在执行。
本轮尚无新 APK/ADB，不得把旧包作为本轮结果。
现有登录只读目录请求返回403，原因未定，未拿到真实最新目录/未真实授权。
详见 [本轮交接](../handoffs/2026-10-01-live-models-and-draft-composer.md)。

## 2026-10-01 独立模型发现（业务验收完成，UI与新APK未交付）

已将模型发现从历史 session/resume/load 改为独立接口：Codex 官方 app-server
`model/list`；分页/隐藏/重复目录处理，短生命周期查询关闭，执行目标/用户隔离。
设置刷新不重建 ACP 会话，旧 configOptions 不覆盖独立模型目录。失败保留旧列表
并标记过期；不支持独立查询的 Agent 不再用历史清单冒充结果。
仅解决不依赖历史会话，Codex 接口自身缓存和账号 entitlement 不宣称已解决。
OpenCode `opencode/space-bunny-free` 最终专项104通过，全量1447通过、17既有
环境跳过、0失败；flutter analyze零问题。AgY 原 Valhalla会话
已按指定模型发起UI交接，但资格检查/订阅连接失败；主 Agent 不代改UI。
中断了先前执行器在UI门禁生效前启动的构建；未ADB安装。上一轮已发布APK
已由OpenCode从完整备份恢复并核验哈希/签名，仍是下方的旧包，不含本轮改动。
详细方案、边界与待验项见[本轮交接](../handoffs/2026-10-01-independent-model-discovery.md)。

## 2026-09-30 前后台无损恢复（自动化验收、release覆盖安装完成）

单一 SSH 心跳、探活/重连合并、后台暂停、原会话恢复和有界历史合并已实现。
同目标断线不清聊天/草稿，后台不因空闲超时自动取消 prompt；健康连接复用，
真实断线恢复原 ID，不自动重发、审批或创建替代会话。不支持回放或身份歧义时
保留本地内容并提示未完整恢复。AgY 原 Valhalla / Gemini 3.8 Flash high 完成
全部界面修改：内容保留、顶部恢复提示、离线动作限制和同目标仪表盘/文件缓存。

OpenCode 主/辅助均为获准的免费 `opencode/space-bunny-free`，执行全部测试、
格式/生成/分析、构建及ADB。最终全量 **1421通过、17既有环境跳过、0失败**；
静态分析零问题，86个修改/新增Dart文件格式检查零改动，连接恢复专项115项通过。
测试清理死锁及旧fixture依赖问题已修正，没有删除或跳过失败用例来通过检查。

最新APK：`build/app/outputs/flutter-apk/app-release.apk`，123108211字节，
mtime **2026-09-30 16:12:14 UTC**（2026-10-01 00:12:14 +0800），SHA-256
`1af486e7dec5c32ea1cc6ba487d2a4f1a1e3b60a3208d97fe381ca571610bdb3`。
版本仍1.0.0+1，沿用Android Debug签名；是release构建，不是商店签名包。
设备 `127.0.0.1:14251` 签名匹配后 `adb install -r` 于16:12:26 UTC成功；
未卸载、未清数据。16:12:39–16:13:12 UTC启动/Home/恢复/锁屏唤醒检查保持
PID19075，观察窗口未发现应用fatal/ANR。未强制Doze，也未向真实Agent发送消息。

真实服务器后台长时恢复、系统杀进程后远端任务状态仍未验证，由用户验收。
不把有限模拟器窗口等同永久在线保证。详见
[前后台恢复交接](../handoffs/2026-09-30-background-session-recovery.md)、
[最终发布报告](../../agent-workflow/background-recovery-release.md)。

## 2026-09-30 ACP 可用性第二轮（自动化验收、release安装完成）

业务层完成消息ID/角色分片、附件私有文件持久化、账号扩展、草稿只初始化、
配置实时刷新及失败保留、目标感知远端文件浏览、重新导入副本与默认导航兼容迁移。
斜杠命令不包裹历史上下文；损坏历史图片保留占位，不阻断其他消息。
AgY在原Valhalla会话 `ec81a4be-7543-45ee-8658-f68966f57d3b`、
Gemini 3.8 Flash / high完成全部UI：单行输入、命令技能面板、账号额度页、
紧凑会话菜单、目录/文件三视图选择、图片预览放大及文件卡片。新组件有中英文案，
图片按宽高同时限额解码，设置按钮支持窄屏换行。主Agent未接管UI编辑。

MiMo免费模型限流后，按用户授权改用已核验免费的 `opencode/space-bunny-free`；
主模型与small_model均指定免费模型，调用记录cost=0。OpenCode执行全部测试维护、
格式化、生成、分析、打包与ADB安装。最终全量 **1305通过、17环境跳过、0失败**，
新增控件专项36项通过（包含320/360/411dp的2倍字体回归），`flutter analyze`零问题，
`git diff --check`通过。最后3项仅补测试与修正文档，未改生产源码，APK与安装证据不变。

APK：`build/app/outputs/flutter-apk/app-release.apk`，122747763字节，
mtime **2026-09-30 11:59:08 UTC**；SHA-256
`26e21334399485fe948caba51d1ec57a8677a84f8129d2287fbc43fd4110219a`。
版本1.0.0+1，沿用既有Android Debug签名；是release构建，不是商店签名包。
新旧证书核对一致后，设备 `127.0.0.1:14251` 的 `adb install -r` 于
11:59:57 UTC完成（Success/exit0）。未卸载、未清数据，首次安装时间保留。
12:00:08 UTC冷启动成功，PID23648存活且MainActivity位于前台；观察窗口无应用fatal。

真实ACP会话、远端Agent实际模型/skills/账号支持及真机性能仍由用户验收，
本轮未向真实Codex/ACP发送测试消息。Agent未声明的字段明确未提供，额度仅手动
调用已声明 `/status`；不会用CLI数据伪装实时ACP结果。
详见[交接](../handoffs/2026-09-30-acp-usability.md)、
[验证与安装报告](../../agent-workflow/acp-usability-release.md)。

## 2026-09-30 ACP 客户端补全（逻辑验收与release安装完成）

审批原始选项/嵌套回包、首次发送目录、工具增量、连接复用与推理分类已修改。
AgY已修改Docker登录、审批/刷新、消息分页、目录/附件/命令、用量诊断、历史搜索/重命名/导出/导入及工具输出UI。
异步SQLite历史、检查点和长工具输出独立存储已进入源码；旧JSON保留作迁移源。
OpenCode最终冻结版全量1192通过、17环境跳过、0失败；`flutter analyze --no-pub`零问题，`git diff --check`通过。专项为provider33、adapter20、framing3、repository18，全部通过；新增features与adapter/resume组合33项通过。
AgY连接恢复后完成剩余14项静态问题和重命名异常反馈，所有UI收尾均由原Valhalla会话、Gemini 3.8 Flash / high执行；根代理未接管UI编辑。
历史章节中“扁平权限回包已修复”的说法与官方v1不符，以本轮嵌套结构及新回归为准。
OpenCode构建`build/app/outputs/flutter-apk/app-release.apk`成功：122288727字节，修改时间2026-09-30 10:01:13 UTC（18:01:13 +0800），SHA-256 `4e4c4adc294e740cc85f0dee67e38d3e0aa599f25e1e596c15accb328fc342e9`。版本仍为1.0.0+1，沿用既有Android Debug签名；这是release构建，不是商店签名包。
ADB设备`127.0.0.1:14251`执行`install -r`成功，安装更新时间由11:16:12变为18:01:26 +0800，首次安装时间保留；未卸载、未清数据。18:02:22 +0800冷启动，10秒后PID11636存活，启动窗口无AndroidRuntime fatal；存在模拟器CPU/JDWP/图形等环境日志，不等于所有系统日志完全无警告。
用户确认没有独立ACP测试目标：真实对话与界面体验由用户自行验证，本轮未向真实ACP/Codex会话发送消息。构建/安装详证见[最终验收报告](../../agent-workflow/acp-final-release.md)。

细节：[本轮交接](../handoffs/2026-09-30-acp-client-completion.md)。

## 2026-09-30 Docker Agent 默认名称绑定与回归门禁

- 新建 Agent 的模型与表单默认按名称绑定；编辑时保留原绑定，旧 JSON 缺字段仍按 ID 解释。名称/完整 ID/唯一短十六进制 ID 切换跟随同一容器，空或未知引用不再误选首个容器。
- 容器引用/执行位置/绑定变化立即失效旧用户查询并取消待触发防抖，成功/错误结果仅回写对应当前目标；手动用户输入保留。表单 17 项、模型 15 项、Docker 服务 9 项专项测试通过；尚无真实服务器 ID 报错复测。
- 指定 AgY Valhalla 历史会话（`gemini-3.8-flash-high` / high）完成全部表单与 UI 修改，并修复全量回归发现的 600px 顶栏实际溢出。OpenCode `opencode/mimo-v2.6-flash-free` 更新顶部主题入口移除后的旧测试，未恢复按钮或跳过断言。
- 最终 `flutter test --no-pub --reporter expanded`：**1158 通过、17 环境跳过、0 失败**；`flutter analyze --no-pub` 零问题，`git diff --check` 通过。正式 APK 重建为 **121714899 字节**，更新时间 **2026-09-30 11:16:06 +0800**，SHA-256 `7c6b3fc1d9316ee4976e220adc39edc367cd44d4c0264d4461f32450efa67943`。
- OpenCode 通过 ADB `127.0.0.1:14251` 执行 `install -r` 成功，冷启动 `Status: ok`，PID **22115**，最近 200 行 AndroidRuntime 错误查询为空。未卸载或清空数据；release 沿用既有项目签名配置，不表示真实 SSH/Docker/ACP 全部端到端验收通过。详细记录见 [容器绑定交接](../handoffs/2026-09-30-agent-container-binding.md)。

## 2026-09-29 服务器切换/删除与 ACP 会话增强（自动化验收通过）

- 服务器切换串行化并持久化目标 ID 后断开旧连接；连接、自动重连及弹窗回调都核验目标服务器，避免旧请求覆盖新选择。删除前确认，配置持久化失败不再先断开当前连接；删除时清除最近连接、自动连接和 sudo 凭据引用。失败时保留弹窗并显示错误。
- ACP 设置从远端 `session/new`/恢复结果读取模型、推理、模式和扩展选项；设置变更使用协议 RPC 并回显远端确认值。旧配置不再阻断发消息：不可用的已保存选项回退到 Agent 当前选项，用户主动选择不可用值仍报错。打开空白草稿的设置只建立远端会话，首条消息才建立本地历史。
- ACP 内容、思考和工具事件在请求进行中写入界面；文本按 50 ms 合并刷新，停止、错误和完成时立即冲刷。权限请求排队、未知工具默认为需确认；认证重试不重复插入用户消息，远端历史回放不重复显示为新回复。
- 展示层由 Valhalla 历史 AgY 会话修改；测试、静态检查、APK 和 ADB 验收由显式指定 `opencode/mimo-v2.6-flash-free` 的 OpenCode CLI 执行。专项测试 63 项通过；全量 `flutter test --no-pub` 为 **1154 项通过、17 项环境跳过**；`flutter analyze --no-pub` 零问题，修改的测试文件格式化零改动，`git diff --check` 通过。旧测试已按认证后继续同一远端会话及设置弹窗预加载的新契约更新。
- `flutter build apk --release` 生成 **121616811 字节** APK，ADB `127.0.0.1:14251` 覆盖安装成功、启动 PID **26195**，未清理既有数据。此 release 仍使用项目既有 debug 签名，不是商店签名包。先前 `--no-pub` 构建因陈旧的 `integration_test` 自动注册文件失败，正常构建重新生成后成功。真实 SSH/ACP Agent 端到端验收尚未完成，模拟器安装不等于所有服务器配置和 Agent 实测通过。

## 2026-09-29 仓库同步、OpenCode 验证与模拟器安装

- 已快进同步 GitHub `main` 至 `916082f`。本轮验证由 OpenCode CLI 显式选用 `opencode/mimo-v2.6-flash-free` 执行，未把其他模型的结果计入本轮门禁。
- 本机 Flutter SDK 对 `intl` 固定为 `0.20.2`；上游的 `0.20.3` 导致 `flutter pub get` 无法解析，故将依赖与锁文件调整到本机 SDK 可用版本。
- `flutter test --no-pub`：1154 项通过、17 项隔离 VM/设备前置条件用例跳过；`flutter analyze --no-pub` 无问题；`flutter build apk --debug --no-pub` 成功。APK 为 `build/app/outputs/flutter-apk/app-debug.apk`，232201539 字节，SHA-256 `8b9655e65b95f4fb851787954460573d03ee8a92654c9ddc5ad1e0c07678b3ac`。
- OpenCode 对模拟器 `127.0.0.1:14251` 执行 `adb install -r` 返回 `Success`，触发应用启动后 `pidof com.antigravity.valhalla.valhalla` 返回 `23762`。前台截图显示容器管理的服务器离线状态已正常渲染，原有服务器记录仍在。覆盖安装保留原应用数据；这不代表 SSH/NAS/Agent 的端到端验收。
- 格式检查发现上游 31 个 Dart 文件不符合当前格式器输出；本轮没有批量格式化展示层文件。物理 Android 设备性能和真实服务器功能仍未验证。

## 2026-09-23 本轮稳定性修复与已列范围验收完成

本节记录本轮稳定性修复与已列范围的完成结果，保留未实现功能和外部未验边界，不代表全功能发布就绪。下文 NAS 媒体库及更早记录保留为历史证据，不能代替本轮验收。

- 已修复 SSH 超时/取消/连接身份与指纹兼容、SFTP 预览大小及句柄清理、Docker 日志取消、systemd 状态解析、终端分包中文与关闭后进程释放；NAS 部署增加持久任务、阶段时限、脱敏进度、取消/回滚和恢复核验。WebDAV 使用 canonical `repository@digest`，并修复 gzip 压缩 XML 扫描失败；快捷命令补齐凭据/SSH 异常、目标身份检查、双流输出和 loading 收尾。
- NAS 冷启动时元数据服务先于自动 SSH 连接初始化，适配器缓存首次连接错误，重连后也可能保留旧隧道；已改为按媒体源自身 `sshServerId` 的客户端身份失效重建。新增 4 项回归，与关联用例合计 13 项通过，覆盖源不等于活动服务器、断线/重连、同 ID 客户端替换与无关连接不重建。Emby 安装/恢复健康检查改用 `/System/Info/Public`，防止首页 302 时 API 仍为 503 就提前报告成功，2 分钟预算不变。
- 最新源码自动检查：**1111 项测试通过、17 项隔离环境测试默认跳过**；`flutter analyze` 无问题，277 个 Dart 文件格式检查零改动。最新 release APK 为 **120,047,520 字节**，SHA-256 `4d28eab39248ef1a3e5248709f19ab0fd5103878509422d0d17163c1a1222da3`，构建、签名及 `adb install -r` 覆盖安装通过，既有配置保留；08:59:24 UTC 启动 PID 22840。日志为 `test-nas-lifecycle-final.log`、`analyze-nas-lifecycle-final.log`、`format-nas-lifecycle-final.log`，APK 记录为 `apk-release-nas-lifecycle-final.json`。
- 真实一次性 VM：SSH/SFTP 综合回归通过，Docker/系统/PTY/tmux **7/7** 通过，普通终端 dispose 修复前后有对照；实际重启 **1/1** 通过，仅派发一次并验证 boot ID 改变。NAS 原五项通过结果保留；Emby 原健康超时经隔离 VM 内核/模拟 CPU 条件诊断、环境调整及产品 API 就绪修复后，正式 VM 用例 **1/1 通过**，08:52 UTC 完成、耗时 **4 分 37 秒**，日志 `emby-health-api-vm-final.log`。不把分轮结果说成一次六项全量重跑，也不替代 Emby Android 媒体源验收。
- [NAS 各用例最新汇总](../../build/app-stability-validation/nas-vm-final-summary.json) 包含跨多次运行的原六项通过及新增中断拉取只读核验，历史失败记录保留。[09:03:31 UTC 只读资源核验](../../build/app-stability-validation/vm-final-readonly-state.json) 确认三个测试媒体哈希未变、同一 WebDAV 容器运行、boot ID 未变，另保留两个 fixture BusyBox 容器；不等于环境已全部清理。
- 历史 `946aa467…86014a` APK 的设备回归已通过：NAS 真实拉取关闭重开/取消后只读核验正确归为 cancelled、端口错误固定可见、恢复成功任务无回滚误标；WebDAV 扫描 3 项并打开真实图片；快捷命令断线 -1 错误立即可关闭，重连后 stdout/stderr 与退出码 7 同时显示。这些证据不冒充最新包回归；原 `fc8dbf95…` 包手工运行约 65 分钟无新增 FATAL/Unhandled/ANR，也不替代新版自动 soak。
- 最新 `4d28eab…` 包已在 Android 14 x86_64 模拟器验证：已保存 WebDAV 源冷启动自动连接后，未经编辑/保存直接扫描 3 项并显示真实图片；主动断线扫描立即明确报错，重连后无需保存源直接重新扫描 3 项。最终自动 soak 于 **09:01:34 UTC** 启动，完成 **25 轮、10 个路由共 250 次入口检查、1817 秒（30 分 17 秒）**，PID 22840 始终未变；crash buffer 为空、实时日志无 FATAL/Unhandled、无新增退出或 ANR，已复核为 [passed_observed_scope](../../build/app-stability-validation/soak-final/reviewed-summary.json)。25 次 PSS 为 128101–140244 KiB，末次 132282 KiB，本窗口无持续增长，不等于证明无长期泄漏。旧 `946aa467…` 包 soak 的 **4 轮/308 秒** 是发现 Emby 就绪问题后的主动 SIGINT 中断，不能记为崩溃或最终通过。
- Soak 后再次扫描 WebDAV 3 项成功，PID 仍为 22840；09:33:24 UTC 仅停止自有 ADB 日志采集，应用保持运行，截止时无 FATAL/Unhandled。见 [末次扫描](../../build/app-stability-validation/device/nas-lifecycle-final-after-soak-scan.xml) 和 [结束记录](../../build/app-stability-validation/device/nas-lifecycle-final-release-end.json)。
- 真实 Agent 登录/模型调用、DLNA 实体接收和物理手机性能仍未验，设置空入口等功能缺口保留在验收报告中。仅在隔离 VM 写入，现有服务器配置只做只读检查。

结果、各版本 APK 哈希、实际日志、未验范围和复跑入口见 [App 稳定性验收（2026-09-23）](../04-testing-and-deployment/04-app-stability-acceptance-2026-09-23.md)。

## 2026-09-23 NAS 多来源媒体库（实现与阶段验证）

本节记录本轮 NAS 当前源码和已确认的验证结果，覆盖下文早期 NAS 设计中的待接入方案。非 NAS 历史记录保持原样；本轮尚未宣称整个应用发布就绪。

- 媒体源以独立 ID 管理，选择不依附仪表盘的活动 SSH 服务器。已接入 SFTP、WebDAV / HTTP(S) 原文件、成熟 `libsmb2` 原生封装、Jellyfin 和 Emby；密码 / token 存在安全存储，列表、收藏、播放和下载捕获各自来源。
- 本地 SQLite 索引采用后台 isolate、WAL 与串行事务写入。扫描按代次分批 upsert，只有成功结束才清理未见条目；取消不会误删旧库。浏览按修改时间 / 路径游标分页，分类 / 目录 / 歌手 / 专辑及总量从数据库查询，FTS5 使用 token 前缀搜索。本地与远程播放列表均展示真实成员并支持增删改排。
- 文件型媒体库的未播放音频由暂停、静音 libmpv 后台任务提取标签，每批最多 32 首、每文件最多 3 MiB 上游读取；失败记次、变更后重探测、断线保留待处理队列。生命周期进入后台时取消探测，已保存标签保留；Jellyfin / Emby 使用服务端元数据。
- 普通资源经受限 Range 代理播放，HLS master / variant / 分片通过同源安全中继；媒体凭据不放进交给播放器或电视的明文 URL。用户播放由一套 `media_kit` 播放器与有界队列管理，系统控制桥接同一队列；支持进度、重复、窗口内随机、倍速、音轨 / 字幕及服务端画质。
- DLNA 复用 `upnp_client`，显式投屏时才建立可撤销的局域网中继。下载复用统一来源读取器、两路并发和 `.part` 成功重命名，支持取消、重试与本地文件系统打开；当前不承诺跨进程断点续传。
- 可选部署向导提供固定镜像 / digest、路径 / 端口 / 挂载 / Compose 预览和一次性确认，默认远端 loopback、媒体只读挂载。缺 Docker / Compose 时提供指导，不自动装系统依赖、不改防火墙；失败只回滚向导创建并标识的资源。HTTP 来源可显式选用 SSH 转发；隧道不以禁用 TLS 校验来支持 HTTPS。

已确认的证据：

| 验证项 | 本轮结果与适用边界 |
| --- | --- |
| 最终分析与测试 | `flutter analyze --no-pub` 无问题；全量 **1009 项 Flutter 测试通过**，日志为 `/tmp/valhalla-nas-final-analyze.log`、`/tmp/valhalla-nas-final-tests.log` |
| Android 最终构建 / 安装 | 默认 `lib/main.dart` 的 debug APK 构建成功，`adb install -r` 返回 Success，来源与媒体索引保留；窄屏列表、应用内彩色视频和横屏全屏视频已目视复验，见下方截图链接 |
| Linux | 最后 UI / 许可证改动后的最终 debug 构建通过，产物 `build/linux/x64/debug/bundle/valhalla` 包含 SMB 原生库且 `ldd` 无缺失；此前 Xvfb + session D-Bus 启动和真实隔离 D-Bus 控制回归通过。容器没有 PipeWire 音频输出，未验证实际听音 |
| Android 后台系统控制 | 模拟器在应用后台响应系统 MediaSession 后退 / 播放 / 暂停 / 停止，位置与状态同步；曲目元数据为 `NAS test track / Valhalla / Fixture`，停止后 `active=false`、状态 `NONE`、位置归零。证据 [`android-media-controls.txt`](../../build/nas-validation/android-media-controls.txt)；不代表物理手机、耳机 / 音频焦点或进程被杀后的行为 |
| 模拟器视频黑屏 | 捆绑 libmpv 的 `EGL_CONTEXT_FLAGS_KHR=0` 在当前 Android 14 x86_64 模拟器 EGL 1.4 上返回 `0x3004`，NDK 对照探针去掉属性后成功；仅模拟器采用 `mediacodec_embed` / `mediacodec`，实机及其他平台维持默认配置。共享 controller / UI 整合后的最终 APK 已安装，应用内和横屏全屏彩色视频画面复验通过 |
| 最终许可证产物 | Android APK 与 Linux bundle 的 `NOTICES.Z` 均核验包含完整 `valhalla_smb/NOTICE`、libsmb2 `COPYING` 和 `LICENCE-LGPL-2.1.txt`；[Android 全文 / 哈希证明](../../build/nas-validation/android-lgpl-license-proof.json)、[Linux 全文 / 哈希证明](../../build/nas-validation/linux-lgpl-license-proof.json) 均记录三项 `complete_text_present: true` |
| 签名 SMB2 | Linux 实际 `libvalhalla_smb.so` 与 Android 14 `sdk_gphone64_x86_64` 模拟器通过 2502 文件 / 5 页、Unicode、超过 4 GiB 偏移、取消及重连；不代表真实 SMB3 NAS / 加密服务验收 |
| Jellyfin 12.1 | 真实服务认证、三类扫描、收藏、列表增删改排、12 秒续播、原始 Range、缩略图、4 Mbps PlaybackInfo、HLS master / variant 和实际 MPEG-TS 分片通过；Emby 兼容修复后再次回归通过。重复媒体项返回歧义成员 ID 时拒绝不确定删除 / 排序 |
| Emby 4.10.0.40 | 真实服务认证、三类扫描、收藏、重复列表项独立成员 ID 的移动 / 删除、列表改名 / 删除、12 秒续播、三类原始 Range、缩略图、4 Mbps PlaybackInfo 与 HLS / MPEG-TS 分片通过；实测修复 JSON 显式 Content-Length 和原始播放独立 PlaySessionId / DirectPlay 报告，相关 network / HLS / cast / source-review **30 项通过**，静态分析无问题 |
| 百万条合成索引 | 当前最终 schema（含元数据队列索引）重跑通过：Linux x64 / Dart 3.10.0 / 16 逻辑处理器，100 万条、每批 5000、各查询 20 次：首页 P95 **2.352 ms**，95% 深页 **1.662 ms**，稀有 / 常见 token 前缀 **111.497 / 143.518 ms**，总量 **107.055 ms**；写入 90.905 秒，数据库 1,345,769,472 字节，采样 RSS 峰值 278,683,648 字节。不代表真实 NAS 扫描、冷缓存或手机帧率 |
| 自动化边界 | 索引迁移 / 取消、元数据预算、代理 / HLS / 投屏 / 下载、SSH 隧道及安装预览 / 确认 / 冲突 / 回滚已有回归；向导未在用户目标服务器真实执行部署 |

Android 已连接的设备是宿主机端口 14251 对应的 **Android 模拟器，不是物理手机**。完整 NAS integration 测试已通过，日志 `/tmp/valhalla-nas-device-test.log` 包含 `NAS_DEVICE_PASS` 和 `All tests passed!`：覆盖原图 / 512 缩略图、视频跳转与 `Media.start` 续播、1.5 倍速、MP3 标签、收藏 / 播放列表 CRUD、切换媒体源后保留原播放身份及原文件下载大小。删除测试来源曾触发的 Riverpod `CircularDependencyError` 已修复，4 项专项回归及修复后完整设备流程均通过。后台系统控制实测范围见上表；最终 APK 另已取得 [窄屏列表](../../build/nas-validation/09-final-library.png)、[应用内彩色视频](../../build/nas-validation/10-final-video.png) 和 [横屏全屏视频](../../build/nas-validation/11-final-video-fullscreen.png) 的实际画面证明。上述结果不等于物理手机或所有平台验收。

最终 APK 人工复验已完成：原图实际显示；从媒体库设置进入并保存 WebDAV 扫描范围无需 SSH；歌手 Valhalla、专辑 Fixture 下钻显示对应曲目，目录下钻显示三类媒体；播放器全屏、收起后重新打开及从后台返回后均正常出画。截图 `12-final-video-resumed.png` 至 `17-final-folder.png` 保存在本轮 `build/nas-validation/`。最终应用进程日志未发现未处理异常、RenderFlex 溢出或 EGL / 视频输出初始化失败；不据此声称全部设备与编码兼容。

验收结束已从应用移除本轮 `NASFixture` 测试来源，停止临时媒体服务并清理已确认属于本轮的调试转发；正常 APK 保留安装。设备截图后仅对扫描服务执行纯格式整理，无行为改动；格式检查通过（261 文件零差异），Android / Linux 重新构建并再次覆盖安装成功。最终分析、1009 项测试、格式检查、双平台构建、安装、设备集成和百万条基准日志已复制到本环境 `build/nas-validation/`，这些构建产物不作为源码提交。

视频兼容实现位于 [`nasVideoConfiguration()`](../../lib/core/services/nas_media_player_service.dart) 与 [`nasVideoControllerProvider`](../../lib/core/providers/nas_provider.dart)：复用 `Utils.IsEmulator`，共享播放器生命周期内的同一视频 controller，fatal / 视频输出错误转为 `NAS_PLAYBACK_FAILED`。本轮 [EGL 探针](../../build/nas-validation/android-egl-flags-proof.txt)、[原生失败日志](../../build/nas-validation/android-video-black-screen-proof.txt) 与 [同 APK 彩色画面证明](../../build/nas-validation/video-native-output-proof.png) 支持上述模拟器处理；最后一项只证明输出路径，不代表最终布局。模拟器原生 codec 的格式支持有限，未改变实机默认配置，也未验证实机或 Apple / Windows 视频。上游同类现象可查 [media-kit issue #1343](https://github.com/media-kit/media-kit/issues/1343)，具体 EGL 属性根因来自本轮独立探针。`build/nas-validation` 证据是本地构建产物，不是永久附件。

Flutter integration runner 的 `kill()` 清理路径会卸载应用包，测试来源不会持久到随后正常安装的应用；本轮设备初始没有本应用，没有用户数据丢失。**只能在无用户数据的专用测试模拟器运行集成测试，禁止在有用户数据的设备执行 `flutter test integration_test/...`。** 正常安装应重新构建应用入口并用 `adb install -r`；可重放的 fixture、地址与命令见架构文档中的“Android 集成测试重放与数据边界”。

Apple / Windows 没有本机工具链，未做原生构建与实机验收；未连接真实 DLNA 电视，不能声称物理投屏兼容性已通过。

详细数据流、可复现基准入口和限制见 [NAS 媒体库与流播放架构](../02-architecture/04-nas-streaming-architecture.md)。本轮原始记录包括最终基准 `/tmp/valhalla-nas-index-benchmark-final.json` 及同名 `.log`、保留的旧报告 `/tmp/valhalla-nas-index-benchmark.json`、`/tmp/valhalla-nas-device-test.log`、最终分析 / 测试日志 `/tmp/valhalla-nas-final-analyze.log` 与 `/tmp/valhalla-nas-final-tests.log`、最终构建 / 安装日志 `/tmp/valhalla-nas-final-android-build.log`、`/tmp/valhalla-nas-final-install.log`、`/tmp/valhalla-nas-linux-build.log`，以及 `/tmp/valhalla-nas-media-servers` 中的真实媒体服务烟测脚本。最终 APK SHA-256 为 `a8a7ddd3d7d00b34c6b38fdb08834db799a49a83417aa38e51f5e04ea57b0c19`，与 Android 许可证产物证明一致；这些日志、证明及截图均为当前环境产物，不是可跨机器访问的永久仓库附件。

## 2026-09-22 全量审计与稳定性修复

- 修复 ACP `session/request_permission` 回包形状：`result` 直接包含
  `outcome` / `optionId`，不再错误嵌套为 `result.outcome.outcome`；Codex
  审批允许后的 JSON-RPC Parse error 已有 wire 回归测试覆盖。
- Docker Agent 执行目标统一通过容器内 `/bin/sh -lc` 启动，并在容器存在 Bash
  时优先使用 `/bin/bash -ic`，Bash 不存在时回退到 sh；诊断日志同时保留目标、
  脱敏后的 transport command、退出码和输出尾部。
- NAS repository 在 provider 与媒体播放器之间复用同一初始化入口，SQLite WAL
  写入继续串行化；新增服务器隔离的播放列表 CRUD、播放列表条目和播放进度节流。
- NAS 扫描在 GNU `find -printf` 不可用时尝试 GNU/BSD `stat` 格式，并返回稳定的
  `NAS_SCAN_UNSUPPORTED_FIND_FORMAT` 错误分类。
- 日志脱敏补充 JSON 字段、Bearer、cookie 和 `--token=value` 等常见凭据形式。
- 指定 Valhalla `agy` 会话完成 UI 文案恢复、仪表盘参数顺序修复、CLI/ACP 消息
  文本选择复制；相关 70 项 Widget 测试通过。
- 门禁结果：全量 Flutter 测试 0 errors，`flutter analyze --no-pub` 通过，格式与
  `git diff --check` 通过；release APK 已构建成功。真实 SSH/Codex/Docker/NAS
  设备验收仍需在目标服务器执行。

## 2026-09-21 会话启动偏好与 NAS 流媒体基础

- 会话启动偏好已新增为服务器、会话模式（ACP/CLI）及 Agent 三元组的持久化数据：支持记住最后会话、固定会话和空白草稿；会话失效或删除时安全回退到草稿，绝不为打开页面而创建远端会话。
- NAS 索引以兼容迁移扩展播放进度、收藏、媒体元数据与播放列表表；SFTP loopback 媒体代理只绑定 `127.0.0.1`、使用随机临时令牌并支持单 Range/HEAD，使播放器可拖动和在完整下载前开始读取远端文件。
- 引入统一的 `media_kit` 音视频播放基础和 Android/iOS 后台媒体平台声明；外部打开仍复用已有下载队列和系统 chooser。音乐通知/锁屏状态桥接以及真实设备兼容性仍需本迭代最终验证。
- Codex CLI Composer 使用官方 app-server `skills/list` 获取真实 Skill，不把仅能被 Codex TUI 解释的斜杠命令伪装为可执行项；Catalog 失败不得阻断聊天发送。

## 2026-09-20 CLI 会话长历史修复

- 历史消息从“全量传回后本地截取”改为远端分页：Codex 使用官方 items 游标，OpenCode 使用消息 limit/before，Claude Code 使用远端 SDK 窗口投影。旧版不支持分页时不回退全量读取；Claude Code 的远端扫描耗时仍需实测。
- 修复 Codex 原始 item 页被工具记录占据时只显示一条且无法触发滚动的问题：连续读取小页直到取得目标数量的可见消息。会话目录首屏从 30 条降到 15 条，并在切回 Agent 时复用已取得的目录缓存。
- 当前主机仅执行只读 `thread/list` 验证（未读取正文、未启动 / 发送 / 删除会话）：10 / 20 / 30 条首页约 1.4–3.1 秒且均有下一页，证明主要耗时来自 Codex 历史扫描。相关 14 项协议 / 状态测试与静态分析通过，debug 和 release APK 均重新构建成功。
- Agent 切换保持移动端会话抽屉打开；展示层由指定 Valhalla `agy` 会话负责。专项 49 项测试通过、相关静态分析无问题、`flutter build apk --debug --no-pub` 成功；Android 真机长历史流畅度仍待 profile 实测。全量测试另有 1 项与本功能无关的既有失败：`multi_column_lists_test.dart` 的紧凑 Agent 管理列表测试在未滚动时查找尚未构建的 `Agent 2`，单独复跑同样失败，本轮未扩展范围修改该测试。

## 2026-09-19 主题、终端与仪表盘体验完善

- 共享终端画布已移除长按方向键微滑，保留 xterm 原生长按及辅助键栏；设置页单选项改为弹窗，浅色/深色/极客黑暗各自保存预设或自选主题色。跟随系统使用系统明暗对应槽位，旧单色设置保留回退。
- 仪表盘运行时间已移入服务器信息卡，重启/关机/断开连接集中在服务器名称旁；关机复用捕获服务器与临时 sudo 密码的安全流程，但不伪装成重启验证。第四指标卡与明细弹窗展示默认路由网卡及各网卡当前收发速率，首采样、计数器回退和无网卡有明确状态。
- 快捷入口已支持独立勾选与拖动排序，空列表隐藏整个区域；升级用户缺键时保持旧六项。展示层、ARB 与 Widget 测试均由指定 Valhalla `agy` 历史会话以 `gemini-3.8-flash-high` / high 完成，后端与文档由 Codex 完成。
- 关机 `unknown` 与 `accepted` 分别显示非断言性文案；离线时 `unknown` 保留警告横幅，sudo 密码提示按关机/重启区分。最终门禁：`flutter test --no-pub --reporter expanded` 全量 **815 项通过**；`flutter analyze --no-pub` 无问题；`dart format --output=none --set-exit-if-changed lib test` 检查 191 个文件无改动；`git diff --check` 通过；`flutter build apk --debug --no-pub` 成功。未在真实服务器执行关机或验证 Android 实机颜色/终端手势，不能把自动化门禁等同于现场验收。
- 详细迁移键与失败状态见 [本轮交接](../handoffs/2026-09-19-theme-network-power-shortcuts.md)。

## 2026-09-19 本轮实施

独立 CLI 原生会话、安全重启、Docker 逐容器等待与切服守卫、真实连接数统计、安全确认、PTY resize 合并 / 生命周期清理与并行 SSH 退出码已完成实现。在此基础上，前端展示层完成以下 7 项关键能力交付：
1. **Docker 容器终端（进入容器）**：在运行中容器操作行提供“进入容器”按钮，通过 `dockerCliServiceProvider.openTerminal` 创建桥接并调用 `bridge.start()`，展示支持自适应（移动端全屏 / 桌面端 900x600 模态）的 `SharedTerminalCanvas`，接入按键直通与剪贴板粘贴；退出时通过 `finally { bridge?.dispose(); }` 安全释放终端 PTY 资源，且不停止容器；非运行容器严格禁用。
2. **CLI / ACP 设为默认 Agent**：在 CLI Agent 选择行与 ACP Agent 切换弹窗中增加“设为默认”星标切换按钮；读取 `localStorageServiceProvider.getDefaultAgentId(serverId, cli: true/false)` 标识默认状态，点击调用对应 `setDefaultAgent(id)`；切换默认不自动跳转或强制改变用户当前活动的 Agent 与会话。
3. **AgentFormDialog 响应式表单重构**：移动端采用全屏对话框 `Dialog.fullscreen` + `Scaffold` + 吸底操作栏；桌面端采用居中模态框（maxWidth: 680, maxHeight: 750）；清晰组织 4 大信息分区（预设模板 ChoiceChips、基本信息、等宽多行命令 1~4 行、等宽多行安装与登录命令 1~3 行），支持预设即时填入与自定义清空校验。
4. **Dashboard 当前资源占用看板**：将旧有趋势折线图全面替换为“当前资源占用”面板；CPU 面板呈现使用率/空闲率/负载与按 CPU 占用降序的实时进程列表；内存面板呈现使用率/空闲率/总量与按 RSS KiB 降序的实时进程列表；磁盘面板呈现已用/可用/总量、扫描未完成黄色警告横幅、一级子目录占用排行与刷新按钮；弹窗随 `autoDispose` 自动卸载，断线展示停止告警。
5. **Settings 底栏导航拖拽排序**：保留 9 个 AppSection 独立勾选能力，下方提供 `ReorderableListView` 拖拽手柄自由排序，勾选自动追加末尾，取消勾选剔除且保留其余顺序；移动端底栏严格依照配置顺序渲染。
6. **语言“跟随系统”（System Default）**：`SettingsState.locale` 缺省设为 `Locale('system')`，`main.dart` 中为 system 时向 `MaterialApp` 传递 `null`，无缝联动宿主系统语言。
7. **L10n 全量覆盖与自动化测试**：完善 `app_en.arb` 和 `app_zh.arb`，通过 `l10n_key_parity_test.dart`，针对 7 项能力编写高覆盖 Widget 测试套件（`dashboard_metric_trends_test.dart`、`docker_terminal_button_test.dart`、`agent_default_selection_test.dart`、`agent_form_dialog_redesign_test.dart`）。

全工程 `flutter analyze` 零告警、代码格式与 `git diff --check` 严格通过。详细设计与测试清单见 [前端交接记录](../handoffs/2026-09-19-resource-usage-and-docker-terminal.md)。

## 当前基线

本项目以 Android/Windows Native MVP 为第一交付目标，远端服务端零专有 Daemon 侵入。展示层由 Valhalla Antigravity 历史会话维护，业务实现遵循：

```text
Material 3 UI -> Riverpod State -> Service/Repository -> Infrastructure SDK -> SSH/SFTP/ACP/Docker
```

## 已实现能力

- `dartssh2` SSH 连接池、Host Key 校验、KeepAlive、Login Shell 执行。
- SFTP 目录浏览、文件读取/写入、创建、删除和重命名。
- `xterm` SSH PTY、多标签终端和移动端辅助按键。
- ACP 事件模型、流式消息、Tool Call、Plan 和权限请求基础链路。
- `acpd` 1.0.0 标准 JSON-RPC 核心及 SSH 行传输适配器。
- 快捷命令模板参数替换、终端直通和后台 SSH 执行。
- 中英文 ARB、本地主题模式和种子色设置。
- Docker CLI 结构化容器解析、容器生命周期命令和日志流基础服务。
- `ps` 进程解析、systemd 服务解析与受限操作接口。
- 命令风险识别（Safe/Warning/Danger）和系统指标快照解析。
- SSH 服务器管理修复：首次安装不再注入 `prod-cluster-us-east`，旧版
  `demo-debian-12` 数据会一次性迁移清理；服务器支持确认删除（含最后一项），
  切换时等待活动服务器持久化后再连接，新增服务器保存后自动设为活动项。

## 下一步必须完成

### 2026-09-18 接手核对与修复进度

接手基线静态分析通过，624 项自动化测试通过。当前工作树还包含其他协作者的未提交实现，不能用 Git 提交历史推断全部功能状态。

已存在的能力还包括服务器隔离 Agent 管理、CLI/ACP 安装向导、交互登录与 ACP 认证挑战、标准 ACP 流式会话与 load/resume、SSH 自动重连与应用生命周期复验、Android 前台保活、可选 tmux、SFTP 上传下载队列及暂停/继续/取消、文件预览排序，以及 Dashboard/Docker/系统展示层。下列旧任务清单中的部分内容已实现，不能重复从零开发。

本次后端修复：

- CLI-only 配置不进入 ACP 聊天可切换列表，列表同时核验服务器归属。
- 本地 ChatSession 保存 serverId、workingDirectory、remoteSessionId；旧会话归属方案已由本页下述七项修复更新为首次服务器一次性迁移，不再要求用户手动绑定。
- Adapter 按服务器、Agent、本地会话隔离；远端会话 ID 从对应本地会话读取，不把一个 Agent 的 ID 用于所有会话。
- 恢复仅在 JSON-RPC method-not-found 时尝试下一种恢复方式；全部不支持时返回 ACP_SESSION_RESTART_REQUIRED，不静默新建。
- 版本命令不作为登录状态检查；停止生成清理权限/认证等待并保存部分消息，过期请求不再更新状态。
- 认证状态已独立为 unknown/authenticated/unauthenticated；旧 Codex 版本检测使用 login status，其他版本检测不能证明认证。
- ACP 通道创建异常与 SSH 断线均退出生成状态并保存部分消息；生成期间不能新建会话或删除活跃会话，删除其他会话不改变当前选择。

仍未完成整套交付：其他 Agent 的真实登录探测、停止请求的完整协议验收、远端会话列表和动态配置、工作目录选择、Drift 迁移、传输重试/覆盖/临时文件策略，以及真实设备/服务器验收。数据库迁移前必须验证 SDK 依赖兼容，不能删掉原始 JSON 数据。后台服务不代表进程被系统杀死后 SSH 仍存活。

前端绑定确认、停止按钮和中英文身份错误提示已由指定 Antigravity 会话实现，5 项专项 UI 测试通过；全量 637 项测试通过，静态分析无问题，Android debug APK 构建和 diff 格式检查通过。整套功能尚不能标记为发布就绪；未交付功能见 [接手交接记录](../handoffs/2026-09-18-chat-identity-and-cancellation.md)。

1. 将 SharedPreferences JSON 持久化迁移到 Drift/SQLite，并提供一次性导入。
2. 将现有聊天 Provider 完整迁移到标准 `acpd` Session 生命周期。
3. 补充 SFTP 上传/下载、批量操作、权限修改和成熟代码高亮编辑器。
4. 接入 Docker、Dashboard、进程和 systemd 的展示层与 Provider 状态。
5. 完成 Agent Context 协同、断线恢复、统一危险确认和 Sudo PTY 回退。
6. 将所有展示文案迁移到 ARB，消除 UI 硬编码字符串。
7. 按测试矩阵补齐 SSH、ACP、Terminal、Docker、Command、Monitor 验收用例。

### 兼容性记录

在 Flutter 3.44.2 / Dart 3.10.0 环境下，当前可用的 `drift_dev`、`build_runner`、`drift_flutter` 版本组合与 Flutter SDK 固定的 `meta`/`test_api` 约束无法同时解析。Drift 迁移必须先完成依赖矩阵升级或锁定一组兼容版本，禁止提交会导致 `flutter pub get` 失败的临时依赖组合。

## Antigravity UI 协作约束

### 2026-09-18 七项修复（已实施，待实机与桌面原生验收）

完整契约见 [Agent 共享与下载交接](../handoffs/2026-09-18-agent-sharing-downloads.md)。本节覆盖之前手动绑定界面的方案，旧验收结果仅代表旧里程碑。

- 已修复 `acpd` 1.0.0 权限回包扁平序列化问题；标准回包为 `result.outcome = {outcome: selected, optionId: 原始选项ID}`。允许、拒绝、取消均有严格 JSON 回归检查。真实 Codex 远端复测尚未完成，不能据此声称其他 Agent 已通过验收。
- Agent 切换只切换选择；新建按钮进入未持久化草稿，首次发送才创建会话。
- 跨 Agent 会话共享默认关闭、按服务器持久化；共享仅传递历史文本，各 Agent 使用独立远端会话及同步游标，不共享审批或登录凭证。
- 未归属旧数据只迁移到首次确定的服务器，保留原始 JSON 备份；新增 Agent 必须属于当前服务器，异步检测结果不得跨服务器回写。
- Claude 使用结构化 `auth status --json` 判断登录，Codex 使用 `login status`，AGY 保持交互登录且不以版本命令证明已登录。
- 下载持久路径、重名避让、`.part` 成功后重命名、通知及系统打开的平台通道已接入；连续下载、动画及减少动态高亮、完成记录点击打开、Android FileProvider 和逐文件进度通知已由指定 AGY 会话实施。桌面使用系统 chooser 和通知接口，原生代码尚无本机构建/桌面会话验收。
- 删除确认和会话共享展示已由 AGY 修改；通知点击有页面接收及销毁清理，Windows 通知完成点击走系统 chooser，其余进入传输列表。Windows/Linux 原生行为仍待各自平台构建和验收。

最新 Flutter/Android 门禁：`flutter analyze` 无问题，`flutter test --reporter expanded` 全量 658 项通过，`flutter build apk --debug` 通过，`dart format --output=none --set-exit-if-changed lib test` 检查 152 个文件无变化。Linux 缺 GTK 开发库，实际构建停在 CMake；Windows 无本机构建环境；没有连接的 Android 真机，系统通知/应用选择器及真实 Codex 审批仍待实机验收。不据此宣称整套应用发布就绪。

展示层任务只能交给以下历史会话：

```text
conversation: ec81a4be-7543-45ee-8658-f68966f57d3b
workspace: /workspace/projects/valhalla
model: gemini-3.8-flash-high
```

Codex 侧只提供稳定的 Model、Provider、Service 和 Repository 契约，不直接修改页面布局、组件、主题视觉或展示文案。

## 2026-09-19 当前迭代：容器终端、资源拆解与默认设置

- 运行中容器可通过独立 SSH PTY 执行 `docker exec -it <id> sh`；关闭终端只释放通道，不停止容器。非运行中容器与断开的 SSH 连接在启动前拒绝。
- CLI 与 ACP 分别保存每台服务器的默认 Agent ID；仅在没有有效当前选择时使用默认值，已保存的手动选择不被覆盖。旧设置没有默认 Agent 时回退到可用列表首项。
- 仪表盘资源拆解使用 `ps` 的 RSS 和 CPU 当前采样差值，根分区容量来自 `df -kP /`，一级目录占用来自只跨当前文件系统的 `du -x -k -d1 /`；目录扫描最多等待 30 秒，失败时容量仍可展示并标记部分结果。
- tmux 会话启动命令改为 SSH 独立 `exec` 通道发送，不再写入交互 Shell 的历史记录；已有历史记录不清理。普通交互终端及 CLI 命令保持原有语义。
- 新用户默认底栏顺序为仪表盘、CLI 智能会话、容器管理、远程文件；语言与主题默认跟随系统，旧用户持久化选择保留。
- 真实 Docker 容器、服务器进程、目录扫描耗时、SSH 历史行为及 Android/桌面交互仍需连接目标设备实测；自动化测试不代替真实远端验收。
- 本轮最终门禁：`flutter test --no-pub` 全量通过、`flutter analyze --no-pub` 无问题、`dart format --output=none --set-exit-if-changed lib test` 与 `git diff --check` 通过，Android debug APK 构建成功。

## 2026-09-19 后续六项体验改进

- 容器终端按服务器 ID 与容器名称保存 Bash/Sh 偏好，默认 Bash；Bash 预检失败时尝试 Sh，显式 Sh 不探测 Bash。两种 Shell 都失败时不启动交互终端，原有容器生命周期不受影响。
- SFTP 的可见条目在状态层过滤 `.`，根目录额外过滤 `..`；非根目录的 `..` 仍可返回上级。搜索和排序使用相同的过滤结果。
- CLI 草稿工作目录与历史会话目录筛选已分离；首次发送使用草稿目录，创建下一草稿重置为默认目录，已有会话保留其原工作目录。
- 服务器硬件快照通过当前 SSH 连接按需查询 CPU、内存、根分区、发行版和内核；缺失字段保持未知，连接或服务器变化时重新读取。
- 服务器表单、容器 Shell 选择、CLI 目录选择、会话图标与硬件卡片的展示层由指定 Antigravity Valhalla 历史会话维护。真实服务器 Shell 回退和硬件兼容性仍需远端验收。

## 2026-09-20 当前迭代：Agent 编辑、容器执行与终端操作

- Agent 配置可编辑，保持 ID、服务器归属和创建时间；保存后清空旧运行态并重新探测，启动命令或执行目标变化会在下次请求重建 CLI/ACP 传输，不删除历史会话。
- Agent 可运行在宿主机或 Docker 容器内，并允许用户选择容器 ID 固定或名称跟随，以及可选容器用户（例如 `dev`）。旧 JSON 自动保持宿主机执行、容器用户为空则遵循镜像默认用户；容器停止、消失、用户不可用或不可路由时显示错误，不自动换绑或改网络。
- Docker 容器内检测、安装、登录、ACP、CLI 交互终端、Codex 与 OpenCode 原生会话已经接入统一执行目标；OpenCode 仅在主机能路由容器地址时可用，真实 Docker 网络仍需端到端验收。
- Codex 删除原生会话使用明确的本地确认和远端 `--force`，失败不再折叠为泛化错误；终端选中内容提供复制操作。仪表盘卡片、强调色编辑器、容器 Shell 选择器的展示层均由指定 Valhalla `agy` 会话完成。
- 本轮门禁：全量 `flutter test --no-pub` 789 项通过，`flutter analyze --no-pub` 无问题，`dart format --output=none --set-exit-if-changed lib test` 与 `git diff --check` 通过，Android debug APK 构建成功。格式化仅在全量测试后改变代码排版，未改变行为。

## 2026-09-20 当前迭代：会话运行设置与 NAS 媒体库

- ACP 与 CLI 智能会话已增加模型、推理等级和三档操作权限设置；配置按会话、Agent、服务器隔离并记住新会话默认值。ACP 使用动态配置项，Codex/OpenCode 使用原生协议能力，普通交互 CLI 保持由其自身管理。
- 智能会话移动端会话列表已统一为 Material Drawer，桌面会话栏统一为 320dp；全部可见 UI、ARB 与 Widget 测试由指定 Valhalla AGY 历史会话完成。
- NAS 媒体库已接入可配置导航，支持扫描/排除目录、只读 SSH 扫描、本地 SQLite 索引、搜索分类、分页、图片缓存预览，以及复用下载队列后系统打开。
- 自动化已覆盖设置序列化、NAS 路径规范化与 NUL 记录解析、索引事务与服务器隔离、抽屉/设置弹窗、NAS 空状态、配置、筛选和导航。真实大目录性能、非 GNU find NAS、Android 系统打开及远端协议参数仍需设备验收。
- 最终门禁：`flutter analyze --no-pub` 无问题，`flutter test --no-pub` 全量 884 项通过，Codex 运行参数线协议专项测试通过，`git diff --check` 通过；`app-release.apk` 构建成功。当前 Gradle release 仍使用 debug signing，仅适合安装验收，不作为应用商店正式签名包。

## 2026-09-22 NAS 流播放稳定性

- `NasMediaProxyService` 的单个 HTTP Range 请求现在复用一个 SFTP 文件句柄，并使用 dartssh2 流水线读取；视频不再按 1 MiB 分块写磁盘缓存。
- SFTP 子系统在响应结束时关闭，缓存写入使用临时文件替换，缓存清理延迟合并；HTTP 服务只启动一次并清理过期 token。
- MIME 回退改为具体扩展类型，避免 `media_kit` 因 `video/*` / `audio/*` 通配类型无法探测格式。
- 新增 [NAS 媒体流播放架构](../02-architecture/04-nas-streaming-architecture.md)：默认保持任意 SSH 服务器可用的 SFTP 回退，可选接入 Jellyfin/Emby/Caddy 的 SSH loopback 隧道；本轮未修改展示层。

## 质量门禁

### 2026-09-29 ACP Codex 回归处理中

- ACP `session/prompt` 的远端 JSON-RPC 错误现在单独标为 `ACP_REMOTE_ERROR`，附请求阶段与远端 `data`，不再误报成 SSH 传输故障；这只是明确诊断，不把 `-32603` 猜测为某一种具体故障。
- 已恢复的 ACP 会话不再在每次发送或打开设置时重放本地保存的旧模型配置；新建远端会话仍按 Agent 宣告的可用选项应用默认值。主动打开设置时重新建立 ACP 连接并恢复相同会话 ID 获取新的模型选项，若恢复失败则保留原连接。
- Codex ACP 官方包会自带一份 Codex CLI；其模型清单由远端包/账号返回，不由 App 内置。[上游已报告过期登录返回 `-32603` 而非认证错误](https://github.com/agentclientprotocol/codex-acp/issues/495)。尚未取得用户远端 `codex` / `codex-acp` 版本、登录状态与 `error.data`，因此不能宣称远端错误根因已排除，也不自动升级远端或改动认证。
- 固定的 OpenCode `opencode/mimo-v2.6-flash-free` 会话已执行格式化（2 文件无改动）、ACP 专项测试（41 项通过）、`flutter analyze --no-pub`（无问题）、全量 `flutter test --no-pub`（1154 项通过、17 项跳过）；构建 `app-release.apk` 成功（121616811 字节，SHA-256 `ed4daf080c4cb0111fe8431749c8a764c5d1a19f7c54a82d9950e5a0e465d634`）。本轮新的针对性测试未成功由该模型写入，真实远端 Codex ACP 发送和最新模型清单仍待设备验收。
- OpenCode 同一模型随后指定 ADB 序列号 `127.0.0.1:14251`，以 `adb install -r` 覆盖安装上述 APK（`Success`，未卸载/清空数据）；`am start -W` 冷启动返回 `Status: ok`，应用进程在前台，最近 200 行 `AndroidRuntime:E` 无崩溃。此结果只证明安装和启动，未对真实远端 Codex ACP 发消息。

每个里程碑必须通过：

```text
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

不得提交敏感凭证明文、假造远端数据、空异常捕获或绕过高危操作确认的执行路径。
# 2026-10-03 连接/AgY/下载修复（进行中）

本轮业务与 AgY 原 Valhalla 会话 UI 修改已完成。OpenCode 原会话负责新增回归、格式化、检查、构建与安装；MiMo/Big Pickle 上游限流后，按用户确认的免费模型例外切换主/辅助 `opencode/space-bunny-free`。本轮全量 1881 通过、18 跳过、0 失败，分析零告警，多语言/格式化通过；新 release 已在原 ADB 设备覆盖安装并核验设备包哈希。有限设备检查已记录；SSH 未处理异常来源仍未知，Google 回调/真实对话/下载仍待验收，不宣称全部完成。最新进展以上方“当前”节及本轮工作记录为准。

初次 ADB 检查无设备且 127.0.0.1:14251 不可用；用户恢复后 OpenCode 已复查连接成功，检查全绿后 `install -r` 返回 Success。Google OAuth 账号同意由用户本人完成，不以模拟测试代替真实授权成功。详见本轮工作记录。
