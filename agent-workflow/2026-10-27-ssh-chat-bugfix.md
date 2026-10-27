# SSH 与智能会话缺陷修复

基线1.0.22+23 / d73009c，用户批准先复现再修复及“回归+ADB界面验收”。UI只由原AgY Valhalla会话ec81a4be-7543-45ee-8658-f68966f57d3b，gemini-3.8-flash-high/high；核心与文档主代理，验证优先免费OpenCode、不可用时已核验免费CodeBuddy。无真实Agent消息、生产tmux创建/终止，已有服务器仅只读诊断。

## 发现与修复契约

1. P1：SharedTerminalCanvas._handleTextInput在无修饰键时返回false，物理键处理返回ignored，xterm继续发字节；inputEnabled只覆盖部分快捷入口。共享输入层离线消费远端输入，保留本地搜索/复制。
2. P1：粘贴只在入口检查inputEnabled，异步确认后只比terminal身份，快速重连同terminal仍可能发送。新增兼容inputEpoch=0，父层传已有连接事件代际，剪贴板/确认后核对代际、terminal、mounted与inputEnabled；后台/目标变化使旧操作失效。
3. P1：updateRunSettings在_adoptFinishedRun之前未捕获来源，等待后读取新状态。主代理已加workspaceSelectionKey/requestEpoch来源守卫，过期成功/失败均不再作用新目标；尚待回归验证。
4. P2：运行设置UI加载失败先显示新状态错误再检查目标，需先验证完整工作区再反馈。
5. P2：技能删除用\s+可吞换行，光标只是clamp。仅移除令牌与必要横向空白，按实际删除区间更新selection/composing。
6. P2：收藏保存未防并发，旧失败可回滚新点击。每条目保存期间禁用重复操作，失败仅回滚该操作，保持其他条目可用。
7. P2：命令弹窗目标失效后重复postFrame pop只检查ctx.mounted，关闭动画中仍可能弹出后续页面。单次安排且只关闭原当前route。

## 验收与发布

补失败用例后改正，保留Gboard/物理键/退格回车/连接变化/多行确认、模型权限目标隔离、换行光标、收藏回滚和路由断言；冷历史/流式顺序/链接/恢复既有回归继续跑。语言生成、格式、分析和重点集合绿色后打同签名保留数据测试包进行ADB验收，正式包保持原发布证书。设备恢复前不得宣称实机已通过，不公开发布。

真实TMUX_HISTORY_INVALID_RESPONSE仅有用户历史错误，缺少原始响应，不能降低identity校验或用新建代替恢复来掩盖。实服无法复现则明确记录未验证。

每批新增patch/build，本次若基线未改变为1.0.23+24；本地Android3APK/AAB+Linuxx64，GH/Ygg代理/官网及文档同步，无Actions/Windows/Apple。当前ADB10.0.2.15:5555 offline，已请求恢复；修复与模拟继续，未安装或发布。

## 实施过程证据（保留历史状态）

原AgY已将改动写入live绝对路径（先前误用旧镜像已停止并纠正，未以镜像改动作为新包）。补充修复运行设置保存后误pop后续页，以及禁用星标点击穿透到ListTile导致误选命令；实际二次点击测试必须保留，不能用只检查onPressed==null代替。

核心9项来源/持久化反例及中文预编辑、修饰键代际、离线键盘等已补。初始core5项在移除守卫后4失败/1正常控制通过，加守卫5通过。首轮完整64文件门禁分析/9项发布脚本测试通过，运行设置旧集合有26失败；其基线与当前均失败，正在保留断言定位fixture初始化时序，不计为最终绿灯。

发布脚本新增--build-only并有3项专门回归（发布脚本共9项通过）：冻结后先ADB验收，再同目录resume，不提前公开。已有无网络terminal_ime_probe复用并由AgY增加启用/代际控制，构建助手支持terminal入口；探针APK不进入正式发布，验收后恢复冻结main正式APK。

用户已启动设备，已发现在线入口127.0.0.1:14251（x86_64模拟器，Gboard，桌面launcher）；10.0.2.15离线不可用。预检设备版本1.0.16/native4017，正式证书一致，允许保留数据覆盖升级。预检仅包信息/签名和状态读取，尚未安装新包或实机验收。

最终源码门禁stage3-gates-20261027T072230Z：64文件854项常规测试、9项脚本测试、generate/format/analyze零问题/diff-check全部0，零失败跳过。旧两组模型/回滚测试在初始化完成前调用接口；fixture显式启动provider并等待本地历史初始化后通过，全部RPC/回滚断言保留。星标真实二次点击已恢复并通过，禁用点击穿透属产品缺陷，已修复，不接受仅onPressed==null作为替代。准备1.0.23+24 build-only，装机未通过前不推送或发布。

1.0.23首次build-only停在扩展终端集合6项失败，尚未产出/冻结正式main包。失败来源为旧测试Bridge的state getter与stateListenable不一致、键盘用例使用断开连接状态；OpenCode只修正3个fixture，59项全部通过，未修改产品保护或断言。保留prebuild-terminal-failure.raw和原source f94d6b6回执，提交测试修正后在同批恢复构建，不额外升号。

## 正式构建与原生输入验收（2026-10-27）

最终构建源码1ca02e5073d41733335bcb6827da52b6c419f195；OpenCode完成正式Android三架构APK/AAB与Linux x64，17个产物冻结，扩展发布集合608项通过。版本1.0.23+24，x86_64 split原生versionCode4024。

CodeBuddy免费deepseek-v4.1-flash执行ADB验收，根代理不执行测试或设备命令。复用本地无SSH探针，18/18通过：触摸输出不弹键盘、显式开键盘、Gboard Ctrl+A输出[1]、普通c空格[99,32]、Shift+Tab[27,91,90]、连接代际清状态、离线拒绝输入、重连不自动弹键盘、HOME返回同进程无自动输入法。报告build/ssh-chat-bugfix/device/native-probe-report.json。验收后已保留数据恢复冻结正式MAIN 1.0.23/native4024，安装APK SHA256=d4f80a7133a7f3bbcf54debe1c076c95a56b3879bdeb6d5317283414789a849f，与发布产物一致。探针不进入发布。

早期自动化错误（标题空格、坐标、将editing日志误判为output）已修正后重跑，失败回执不计通过；最终严格断言只解析output字节且无or True。中文Gboard原生输入未验证（当前设备英文键盘），相关预编辑widget回归通过。正式MAIN只读页面验收仍在进行，完成前不公开发布。

CodeBuddy正式MAIN只读验收完成：冷启动、菜单导航、已存服务器配置、HOME返回仪表盘缓存与输入法状态、安装版本和哈希通过，本次进程无FATAL/ANR。报告build/ssh-chat-bugfix/device/main-smoke/report.json，截图同目录。当前选中SFTP-Perf-Fixture无可用Agent且没有缓存会话，因此真实ACP历史、运行设置/命令弹窗不可达，明确未验证；不创建Agent或发送真实消息补齐。当前仪表盘服务器错误为已有离线缓存状态，未执行连接或修改。原生输入探针通过与此限制分别记录。

本批已交付1.0.23+24：GitHub/Ygg代理整包及Range/官网公开回读全部通过，最终渠道、产物及验收边界见[发布记录](2026-10-27-v1023-release.md)。前述未安装/未发布为当时过程状态，以最终回执为准。
