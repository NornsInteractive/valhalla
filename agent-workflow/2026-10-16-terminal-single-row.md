# 紧凑终端快捷键与方向组

## 用户纠正后的最新契约（覆盖下文旧浮层方案）

- 四方向为直接可用的一体倒T组件：上方中央↑、底部横条←↓→，不是点击展开按钮。
- ARROWS仍为一个可加入／移除／排序的设置项；随常驻键顺序排列，不固定右侧。
- 普通键紧凑两层排列，整体目标88dp（不含SafeArea／Fn提示），视觉约32dp、命中>=44dp；溢出横滚。
- 更多和显式键盘入口上下排列在右侧；未常驻方向组可从更多Nav直接使用，常驻时不重复显示。
- 删除方向浮层、打开／关闭动作及相关生命周期浮层逻辑；保留单次／连续方向发送和后台／隐藏停止重复。
- 保留组合键、Gboard、输入焦点与自定义设置；不修改终端编码、连接或历史。
- UI仍由原AgY会话和指定模型实施；验证仍交OpenCode免费模型。本次不打包、安装、推送或发布。
- 本节变更已完成；下文旧159项结果仅证明上一轮浮层实现，当前验收见下一节。

## 当前倒T组件验收

原Valhalla AgY会话已完成UI：取消弹出入口、Overlay和关闭动作，改为常驻一体倒T背景，
上方两角透明，上键居中，底部左／下／右相连；整个ARROWS组随固定键顺序排列。
主代理复核发现首版矩形外框、43dp挤压、92dp外边距和Nav重复，均由AgY定向修正。
最终常态底栏88dp，普通视觉键32dp，四向触控44×44dp，更多／键盘在物理右侧上下排列。
旧自定义／空列表保持不变；未固定ARROWS时更多Nav可直接使用方向组。
遵循frontend-design既有视觉与surgical-patch小范围原则，没有修改输入编码、终端会话或连接。

OpenCode免费模型完成当前验证（主模型与small_model均显式固定免费）：

- Big Pickle：12个相关测试文件153项通过，0失败，日志`/tmp/valhalla-inline-dpad-nearest-tests.log`。
- Big Pickle／LongCat／MiMo：更新布局和登录终端断言、追加长按后台停止测试；MiMo执行布局专项8项通过，
  日志`/tmp/valhalla-inline-dpad-layout-tests.log`。包含320/360/430dp、2x字号、LTR/RTL，
  常驻／非浮层、倒T几何、44dp触控、键盘右下和inactive停止／resumed不补发。
- 合计13个测试文件161项通过；不是全项目回归，也不是Android真机锁屏验收。
- MiMo执行格式化及`flutter analyze --no-pub`，退出0、No issues found；日志`/tmp/valhalla-inline-dpad-analyze.log`。
- 主代理`git diff --check`通过。未直接运行Flutter测试，未新增生产依赖。

当前证据归档：`build/local-packages/20261016-terminal-inline-dpad/evidence/`。
仍为1.0.8+9，本次没有打包、ADB安装、推送或发布；设备上旧包不会自动出现这次改动。

用户反馈：各键间距太大、整体太高，按钮希望稍小；四方向不再固定，合并为一个可配置按键组。

## 上一轮实施契约（已被顶部用户纠正覆盖，仅保留审计记录）

- 未展开底栏约48dp（不含SafeArea），视觉按钮约32dp，有效触控>=44dp。
- 常驻区单行按键紧凑排列，避免Expanded均分撑出空白；溢出可横滚。
- 新设置标识ARROWS，默认列表在原六项后追加；旧自定义／空列表不改，不迁移远端状态。
- ARROWS像普通快捷键可加入、移除、排序；更多Nav区始终能打开方向盘。
- 一个方向按钮打开就近十字方向盘，四方向触控>=44dp，按住重复，松开／取消／关闭不留计时器；RTL不镜像物理方向。
- 方向盘非正文插入，不为打开／关闭抢终端焦点或自动弹键盘；横屏／键盘／小屏可见。
- 保留所有组合键、按住／锁定、Gboard批量提交、键盘手动开关及会话行为。
- 全部共享终端调用点统一生效；UI/ARB由原AgY会话`ec81a4be-7543-45ee-8658-f68966f57d3b`，`gemini-3.8-flash-high`、effort high。

主代理只负责核心设置白名单、文档及验证协作；OpenCode免费模型优先生成语言／运行检查。
本轮不构建、安装、升版本、推送、发布，也不修改远端终端。

## 上一轮浮层方案验收（不是当前倒T方案验收）

UI已由原AgY会话完成，共享快捷键区由92dp两行改成常态48dp单行（不含系统安全区／Fn提示）；
视觉高度32dp，真实命中>=44dp。没有对整个App重绘或修改输入编码、连接及历史策略。
ARROWS组可以排序／移除，更多Nav区仍可打开；自定义弹窗显示本地化名称而非内部码。
17份ARB新增方向组／方向盘／关闭标签，生成代码由OpenCode执行，不使用dynamic或手写翻译兜底。

最终静态分析`flutter analyze --no-pub`：**No issues found**。
最终13个相关测试文件：**159 passed，0 failed**，原始日志
`/tmp/valhalla-terminal-single-row-final2-tests.log`，执行者为OpenCode免费Big Pickle；
最终命令显式把主模型和small_model都固定为`opencode/big-pickle`。
另以`--machine`定向复跑重复输入停止用例1项、几何／首帧前关闭6个参数变体，
全部具名testDone成功、done.success=true；这些是159项中的子集，不额外相加。
MiMo首批生成及Big Pickle／LongCat的大批widget测试生成多次长时间无返回，已取消这些调用，
未把无返回当作限流证据或测试通过。改为小批次后设置、几何、输入与边界回归均由OpenCode完成，
不再需要主代理接管验证，未发生主代理直接运行Flutter测试。

覆盖：

- 320/360/430dp、2x字号、LTR/RTL：基础键区<=48dp，四方向未打开时不常驻；浮层物理倒T不镜像、四向命中>=44dp，键盘仍在物理右端。
- 方向组弹出／关闭、实际点击上键仅发送一次，关闭后能继续使用更多Edit分类。
- 修饰键单次／按住／锁定、Gboard提交与CJK预编辑、Ctrl+Enter、Shift+Tab回归。
- canRepeat关闭时保留widget不卸载仍停止重复；OverlayEntry插入后首帧前进入inactive安全关闭，避免mounted=false时直接dispose的断言。
- 设置保存／移除／跨容器读回、已有自定义及显式空列表不被默认值覆盖；已有重排与失败保存提示回归。
- 普通SSH／tmux／Mosh入口、共享登录终端、历史抽屉、滚动位置、手动键盘开关与抽屉焦点回归。

复核还修正：浮层离页TickerMode／后台／尺寸变化时收起，按键关闭判定立即阻止重复发送，
不依赖后台下一帧卸载；OverlayEntry按remove后dispose，四向Semantics有真实动作，避免无障碍空回调。
这些为实现及自动化证据，不等于Android后台锁屏真机验收。未重新执行全项目3895项测试。

持久证据：`build/local-packages/20261016-terminal-single-row/evidence/`，含最终159项回归、
静态分析、OpenCode原始输出、格式结果和当前生产源码前后SHA清单，前后相同。
`repeat-proof.jsonl`和`layout-proof.jsonl`保存具名机器事件，避免并发expanded报告仅显示活跃测试名造成误判。

本轮保持1.0.8+9，**未打包、未ADB安装、未推送或发布**。已发布1.0.8附件未被覆盖，
不能把旧包设备操作当作本轮UI验收；新UI实际手感仍需后续新包设备验证。
