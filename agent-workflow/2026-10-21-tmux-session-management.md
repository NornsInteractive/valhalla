# 多socket SSH历史与tmux管理：实施契约

用户批准计划：发现默认、App专用及用户手动配置的-L具名/-S绝对路径socket；隐藏与终止分开。
仅当前SSH账号权限，不提权、不扫描其他用户；不操作生产任务。UI归原AgY Valhalla会话/Gemini3.8Flash high。
核心逻辑主代理实施；验证/构建OpenCode已核验免费模型。完成后调用tool/release.py自动新增版本和两端发布，预计1.0.15+16。

## UI接线契约

- TerminalHistoryRecord增加socket（id/kind/value）、identity（远端稳定身份）、isExternal、attachedClients。
- TerminalHistoryStatus增加unavailable，表示来源未配置；ended优先于本地页签状态，必须显示“已结束·无法恢复”。
- SshTerminalState.socketSources为额外配置，内置app/standard不包含其中；hiddenRecordIds与socketErrors均可读。
- notifier.setHistoryVisible(bool)：打开立刻刷新、15秒轮询，关闭停止；在terminal_view Scaffold onDrawerChanged接线并处理页面隐藏/销毁。
- notifier.addSocketSource(TmuxSocketSource.named(value)/.path(value))、removeSocketSource(source.id)。会话来源弹窗管理内置和额外来源。
- notifier.unhideHistory(id)：恢复隐藏记录；deleteHistory(id, terminateRemote:false, expectedTargetKey:target)只隐藏本机记录且清除默认。
- addSocketSource/removeSocketSource/unhideHistory也接受可选expectedTargetKey，弹窗确认必须传入打开时的target，避免服务器切换后误改新服务器。
- 终止为单独菜单动作，确认后deleteHistory(id, terminateRemote:true, expectedTargetKey:target)，保留历史及终端输出并标记ended。
- 沿用restoreHistory、setDefaultHistory、renameHistory；不可恢复/设默认：ended、unavailable。unknown允许发起连接并由核心再次验证，不允许设置默认或终止。
- UI显示默认、来源/socket、其他客户端连接数量；列表按可连接/已结束分组，未确认/来源失效单独恰当展示不丢失；搜索标题/远端名/socket。
- 菜单“已隐藏会话”可查看并取消隐藏；列表自身隐藏hiddenRecordIds。隐藏项不自动重现。
- 终止确认明确服务器、socket、会话和客户端数，告知停止进程并影响其他客户端；禁止kill-server。
- 小屏紧凑、标题空间优先、菜单统一，复用已有主题/组件；不改变终端输入/手势、快捷栏、自动键盘行为。多语言17语键齐全。

## 数据和操作边界

v2新key保留v1原始数据；旧记录默认为app socket，旧标题/default保留，成功探测绑定identity。
identity含session ID/created time/server pid/socket path，同名重建不恢复旧进程；所有操作使用同一socket及identity，不按名称扩大查询。
外部发现先为临时记录，使用/重命名/default/隐藏后才持久化元数据，绝不保存输出/凭据。
来源局部查询失败不使其历史ended；不存在socket明确判空；其他来源不受影响。查询合并、最多两路并发、过期服务器响应丢弃。
无默认仍普通终端；有效默认可恢复，明确失效清除default并普通终端，未知保留default供重试；手动新建仍按tmux开关。
用户明确移除自定义来源时，如默认引用该来源，一并清除本机默认设置（不终止进程），避免下次启动卡在未配置来源；历史元数据保留。
设置新默认需实时验证：验证尚未完成即切换服务器则明确取消该次选择，不清除任何旧默认、不把选择应用到新服务器；此正常取消不记系统异常事件。

## 完成条件

单元/假SSH/组件回归和隔离真实tmux闭环；所有原安全拒绝用例保留，不以放宽断言过关。
更新发布脚本相关测试覆盖新模型/Bridge及history provider，产物签名和代理下载闭环通过后才宣称发布。
## 实施与回归记录

核心实现、原AgY历史抽屉及17语文案已完成，正在最终统一验证；尚未构建或发布。
v2历史与来源配置保存沿用串行队列，隐藏和来源变换在队列内读取最新状态，避免快速连续操作覆盖。
真实tmux回归仅在测试私有socket创建临时会话，覆盖同名重建身份不匹配和精确终止，不访问生产会话。

验证过程保留在`build/local-packages/20261021-tmux/`：
- 初次全量回归597项，594通过；修复多语言元数据/德语克隆及懒加载测试屏幕外定位。
- 小屏测试不吞异常，保留320dp、2倍字体、RTL、输入法和实际滚动断言；单文件25项通过。
- 新增连续隐藏保存回归；修复测试辅助代码弃用Finder接口后重新执行统一门禁。
- 最终结果以`final-verification.json`和后续发布记录为准，不以中途模型文字报告替代实际退出码。

### 最终统一门禁通过

OpenCode已核验免费`opencode/minimax-m3.1-flash-free`执行`verify.sh`：36文件598项全部通过，零失败/跳过。
全项目静态分析零问题、语言生成/格式/差异检查成功；发布脚本6项与更新清单27项通过，源码SHA256前后相同。
覆盖两项隔离真实tmux闭环、v1原始记录保留、串行隐藏保存、跨服务器取消、来源故障与别名恢复及小屏UI。
UI/ARB始终由原AgY Valhalla会话交付；机械格式、生成与验证由OpenCode执行，没有实体设备或生产SSH验收。
实现阶段完成，转入自动新增1.0.15+16本地构建及两端发布；最终公开状态另记发布记录。

### 发布完成

1.0.15+16已正式本地构建并公开至GitHub及原分发项目，四包代理整包/八项Range与历史不变校验通过。
详见[本轮发布记录](2026-10-21-v1015-release.md)；无ADB或生产服务器验收。
