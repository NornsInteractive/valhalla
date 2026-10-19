# 自由网格快捷栏可用性实施契约

用户已确认保留自由网格、分页、拖动、组合键和宏；方向组自由摆放而非跨页固定。窄屏自动减列，至少44dp触控区，最多8列；默认两行、键面内缩2dp，更多/键盘是不可删除系统键，两行占右侧上下格、单行占右侧最后两格。分页信息整合到更多，滑动及点选页面均可。320dp通常7列，360dp通常8列；大字号以实际标签宽度增加单格最低宽度，不缩字体。

日常与编辑分离：更多→编辑布局；长按方向连发、修饰键组合/锁定，不长按进入编辑。编辑浮层保持终端视口；所有操作仅改草稿，保存/取消/撤销，保存失败保留草稿，离开脏草稿需确认。拖动有落点提示，冲突回弹，同尺寸交换；支持跨页移动。文本字段只有手动点击才唤起输入法。默认新增宏不回车，旧宏行为保留。

所有UI/ARB仅由原AgY Valhalla会话 ec81a4be-7543-45ee-8658-f68966f57d3b / gemini-3.8-flash-high / high修改；主代理负责纯模型、布局算法、存储与文档，OpenCode免费模型负责编写测试/生成/格式/分析。本轮不构建、不安装、不升版、不提交、不推送、不发布；ADB目前无设备，不操作生产终端。

用户在本轮后续回复中明确授权：OpenCode未完成部分由主代理直接补齐测试并运行验证。
该例外只适用于当前轮验证；产品UI/ARB仍全部由原AgY修改，构建／安装／发布限制不变。

## 核心接口（主代理负责）

新增 `lib/data/models/terminal_accessory_layout.dart`，由UI导入并export以保持旧测试/调用方兼容。提供原有AccessoryItem及常量/纯网格函数，但显示名与action分离。

- `TerminalAccessoryAction`：`type`字符串为 key/modifier/paste/keyboard/more/text/unsupported；`key`是规范键名；`modifiers`是CTRL/ALT/SHIFT列表；`text`与`appendEnter`仅用于宏；`supported`表示可发送。`fromLegacy(String send, {String type='k', String kind='key', bool modifier=false})`从实际s而非l推导；`fromJson/toJson`结构化；Meta明确unsupported，不再误作Fn。
- `AccessoryItem`沿用id/t/l/s/w/h/c/r/p/kind/m/arrow字段及构造/copyWith/fromJson/toJson，增加独立`action`。单纯更改l不改变action；修改发送动作显式传新action。
- `TerminalAccessoryLayout({required List<AccessoryItem> items, int rows=2, int pages=2, int columns=8, int? directionSeedColor})`；`fromJson(Map)`支持v1/v2，`toJson()`输出schemaVersion=2；`copy()`深拷贝；`project(int columns)`返回重排副本；`validate()`严格验证；`defaultLayout()`默认8列，更多/键盘由系统预留。`hasSameContent(other)`比较配置内容。
- `accessoryColumnsForWidth(double width,{double minCellWidth=44})`按两边共8dp边距计算，最多8、最少4列；极窄窗口可横向滚动容纳最少4格，不能压缩触控区。三列两行容不下完整方向组加系统键，project(3)对此明确抛错，不能死循环。
- `getEffectivePos(o,rows,{int columns=8})`、`checkCollision(...,rows,{int columns=8})`、`findFreeSpot(...,rows,{int columns=8})`保留旧位置参数，新增加columns命名参数，系统键位置不可占用。
- 显示投影：大组件优先、按原页顺序；优先原坐标附近的合法格，按距离/行/列决定；放不下则在该原页之后插入显示页，组不拆分；不回写存储。保存编辑时明确提交当前投影。空页和显式空自定义键合法。
- 存储`getTerminalGridConfig()`读有效v2，否则有效v1，坏记录保留；新增`getTerminalGridConfigError()`在损坏时返回错误码（无可用记录时UI显示恢复提示，不得自动覆盖）。`setTerminalGridConfig(String)`解析验证后单次写v2，v1不改；失败抛出，UI不吞异常。新key纳入配置备份。旧方向色只作v1缺色时的fallback，独立色与布局同次保存。

## UI接口与输入约束（AgY负责）

保留TerminalAccessoryBar公开参数/ModifierLockState/HoldRepeatKey；新增可选`void Function(String text,{bool appendEnter})? onText`，SharedTerminalCanvas以terminal.paste(text)发送纯文本，附加回车才走_handleKey('ENTER')，不能把宏送入按键编码。
按action统一发送网格/更多快捷键，显示名只显示。Ctrl/Alt/Shift可复合，Fn走原状态链。Meta旧键保留但禁用说明，不新提供伪支持。更多和键盘语义标签、工具提示完整；独立方向颜色复用现有direction_key_color_dialog.dart，跟随Theme，箭头不随RTL镜像。
箭头需要支持按住连发/高亮/生命周期取消，同时横向滑动翻页不可发送箭头：先区分tap/hold/drag，开始拖动即取消键事件。编辑模式任何指针/宏/更多键都不得发送内容。
保持现有Overlay方式，不因更多/编辑开合造成终端resize、跳顶或键盘自动恢复。只在保存行数真实改变时更新基准高度；颜色/页码/编辑状态不能改变基准高度。

## 验收

纯模型/存储：旧v1/v2迁移、空列表、坏记录、重复ID/越界/冲突、稳定动作、复合修饰、宏/Meta、7/8列无碰撞/不丢键/不改原布局、回切可恢复、原子写失败和备份。
组件：320/360/横屏/2x/RTL/深浅主题，44dp完整命中/4dp间距、系统键不可删、分页可达、拖动/交换/撤销/取消/失败保存、编辑零发送、箭头拖动翻页不误发、拆分连发、按下高亮、后台/隐藏取消。
共享画布：Gboard与组合键、宏纯文本、键盘手动单击开合、编辑字段输入、关闭浮层不自动呼出、更多/编辑/翻页不产生PTY resize。
更新旧测试至实际网格结构，不能以删断言掩盖回归。记录实际通过/失败/不可用，本轮无真机验收。

## 实际进度

起始工作区干净，基线dc6adb5／1.0.12+13；AgY模型列表包含gemini-3.8-flash-high，OpenCode MiMo主/辅助免费费用为0。现已完成本轮实现及下述相关验证，版本保持不变；未构建、安装或发布。

### 第一轮UI代码审查：尚未通过，需AgY修正

原会话第一轮已写入UI/17语并返回实施说明，但CLI累计汇总仍带ERROR/上游EOF字段（累计轮数/耗时并非本轮；没有本轮配额错误证据）。不能把其“全部完成”响应当作验证通过。主代理只读审查发现以下未满足项，禁止主代理自行改UI：

1. Padding在GestureDetector/HoldRepeatKey外导致实际命中仍少4dp；把完整cell放在事件/语义层内，2dp只缩键面，系统键/单键/箭头均如此。
2. 重命名修饰键仍用o.l判断isModifier、held/locked、向onModifierDown传label；全部基于action.type/key，显示名只显示。单箭头判定、按压map也用action.key。
3. _saveEdit缺同步_isSaving守卫与await后mounted检查；保存前冻结copy，保存期间禁用编辑/取消/返回，失败保留当前草稿。编辑退出还需PopScope脏确认；无回调的宏禁用，不能fallback到onKey编码。
4. _setRows预检直接修改原bad项且可能留下c=-99，破坏草稿及撤销。核心现提供`layout.project(columns, {int? rows})`，基于原合法source重排到指定rows；先得到合法候选再一次_mutateDraft替换，方向组不足两行明确拒绝。
5. 互换时checkCollision仍把另一个移动项当障碍，无法交换。核心现提供`canSwapAccessoryItems(items,first,second,rows,{columns})`，排除双方后验证，UI用它完成相同尺寸互换。
6. 正常态project每次build重复排序/克隆，按压反馈也触发；缓存投影，只在master/宽度/字号变化时重算。更多页码/chips必须来自投影pages而非_masterLayout.pages；翻页同时支持慢拖距离阈值，不能只看速度。
7. 编辑时保持_draftLayout.columns作为几何基准，屏幕旋转/缩窄不能用新columns挤错格；可有界横滚预览，至少44dp；普通态大字号minCell实际label测量而非简单44*scale，极窄时canvas至少columns*minCellWidth。
8. 编辑/更多页码Row、色彩propertyRow在320dp/2x/长语言会溢出；有界Wrap/滚动、入口始终可达。编辑抽屉高度扣除viewInsets与safearea后允许收缩，不能最小180导致横屏溢出。
9. 大量背景/文字仍写死深色/蓝色，方向单键在无独立seed时没有高亮；统一主题token，方向组与单键都使用默认Theme方案及按下态。v1方向色从旧storage seed fallback；v2显式null不能重新继承旧色。
10. 按键属性还只读显示发送字符串，需要可编辑实际key/combo/text动作（修改后创建新action，不改显示名来推断）；预设增加搜索；更多分类Nav/Edit/Sym及中英文混写需本地化。
11. SharedTerminalCanvas的文本宏附加Enter不能受当前Ctrl/Alt/Fn影响，调用纯发送入口`widget.onKey('ENTER')`（非_handleKey），文本经已有paste回调/terminal.paste；不要改变手动键盘行为。

上述是同一计划的完成条件，不新增功能。UI修正后再由OpenCode生成/格式/分析与新增回归，不把当前未验证文件当完成。

### 第二轮后的具体兼容性检查（继续修正）

- constructor意外将onToggleShift/onToggleFn改为required，须恢复原可选接口；其他公开参数也不得变成必填。
- _ModifierKeyButton的pointer回调不能传永不为null的空闭包，缺onModifierDown时原tap fallback必须生效；传label=action.key再直接传可空回调即可，显示仍用o.l。
- 普通/方向组外层Positioned使用item.id唯一标识，避免同页两个相同Tab/重命名标签产生duplicate key；旧terminal_accessory_key_*可作各自子树标记。组选择/拖动用o.id，不写死'arrows'。
- _computeMinCellWidth不要测量group的虚构'arrows'标签或系统键，不能把默认320/360错误降为6/7列；标签宽度除以item.w，单格总横向余量8dp而非12dp（默认INSERT/DELETE六字宽36dp，36+8刚好44）。缓存按master身份/字号/locale变化更新，按压不能反复序列化布局及TextPainter测量全部键。
- calculateBaseHeight仍28+rows*44，但真实bar为10+rows*44，造成18dp空白；统一真实高度，更多/编辑/翻页不改变TerminalView尺寸。
- _toggleArrows合并时从候选中先排除旧arrow==1的四键再找位，否则原位置也被视为障碍无法合并；先构造合法候选后一次修改，保留四键所在页优先。
- _handleQuickKey仍只解析Ctrl/Alt并直接widget.onKey，要通过同一action/_press处理，行为与网格一致。
- _saveEdit的copy须位于try中，避免草稿校验异常导致永久busy；撤销历史有界（最多50步），大文本不允许无限克隆。

已由OpenCode确认核心72项通过；core3分析14条style info在主代理文件修正，待最终复查。UI尚未运行gen-l10n/分析，不能宣称编译通过。

并行ui0预检已由OpenCode执行：gen-l10n成功；分析13项（8处上述required回调不兼容、2处不存在的context.l10n.more、2个不用的import、一个从未传入的onLongPress可选参数）。源前后hash相同，但这不是最终UI版本。更多文字请复用已有准确key或新增17语词条，不能引用不存在的getter；无用import与参数也由AgY处理。详见本轮ui0-analyze.log。

### 补充验证与实际问题

- OpenCode新增第一批8项网格UI测试通过；较大的编辑回归任务长时间无输出，已停止本轮自己启动的对应进程，保留原始日志。经用户授权，主代理补齐保存失败／草稿取消／撤销／单飞保存与拖动回归。
- 首轮宽回归失败不能归因于生产输入编码：移动IME夹具缺生产Mono字体，Ahem把360dp误投影为4列，将Ctrl等键挤到下一页；补真实字体后，既有Gboard提交／预编辑／CJK／修饰键字节断言全部保留并通过。
- 旧固定／滚动／隐藏方向栏的几何断言已按最新自由网格方案移植，保留真实触控尺寸、颜色、生命周期、TickerMode同State和多指回归。More里与网格同名Fn通过明确作用域定位，编码断言不变。
- 新增测试实际暴露：Container边框多占1dp；更多编辑入口被页码挤出；单行3格宽键缩为4列无法投影；2x长语言操作栏溢出；编辑态外层翻页手势先赢手势竞技场导致水平交换失效。这些UI修正均交AgY，未由主代理改产品文件。
- 布局的单行最低列数需至少`max(4, 最大自定义键宽+2)`，两系统格仍保留；默认多行仍最低4列。不可通过减小触控格或回写存储掩盖。
- 当前测试夹具加载真实Inter／JetBrains Mono，使用生产主题；不能为通过窄屏测试压小系统字体。终端视口／IME字节／失败保存均保留实际行为断言。

上述为分阶段检查记录；最终统一门禁结果如下，不能用旧阶段结果代替。

## 最终验收（2026-10-19 UTC）

本轮实现与相关回归已完成。产品UI／ARB均由AgY原Valhalla会话修改，主代理只做纯模型／存储／文档及经用户授权的测试补齐、生成、格式和验证。

- 自由网格保留分页、拖动、同尺寸交换、自定义动作和宏。窄屏／大字号显示投影不改原记录，方向组可从属性面板整体跨页移动，编辑态外层翻页手势不再抢走水平拖动。
- 底栏默认98dp（10+2×44），完整格44dp、键面内缩2dp，系统键固定保留。更多入口与编辑操作在窄屏／长语言下有界，横屏面板扣除实际底栏高度、IME、安全区和16dp间距。
- 编辑只改草稿，保存单飞，失败保留草稿，取消不落盘，撤销同步键帽与字段，编辑操作不发终端输入。设置页旧入口改为新编辑路径指引，旧关键词仍可搜索，不能继续写无效旧布局。
- 显示名与实际动作分离，结构化Ctrl/Alt/Shift组合；旧Meta不误作Fn；宏走纯文本入口，显式Enter不带已激活修饰键。
- v1保留、有效v2优先、损坏记录不自动覆盖；保存为单条v2并加入备份白名单。深浅主题和17种语言词条已同步。

统一门禁脚本：`build/local-packages/20261017-grid-usability/run-final-checks.sh`。

| 检查 | 实际结果 |
| --- | --- |
| `flutter gen-l10n` | 成功，exit 0 |
| `flutter analyze --no-pub` | No issues found，exit 0 |
| 24个相关测试文件（含设置导航与共享画布） | **313通过／0失败／0跳过**，exit 0 |
| `git diff --check` | 通过 |
| 产品源码验证前后SHA256清单 | 完全相同，compare exit 0 |

最终日志：`final-generate.log`、`final-analyze.log`、`final-tests.jsonl`、各`.exit`及`final-source-{before,after}.sha256`，均位于本轮上述目录；旧失败阶段日志保留，不冒充最终结果。
新增回归包括320/360dp、2x、RTL、深浅主题、德俄阿长语言、横屏、完整触控命中、同名键、重命名修饰键、宏、拖动交换／滑动不误发、方向组跨页、连发取消、同State隐藏恢复、多指、保存／取消／撤销／失败／单飞、IME真实编码和终端视口保持。

验证范围是本地模型／存储／组件与共享画布逻辑，不是整套App全量测试或实机体验结论。
本轮**未打包、未ADB安装、未操作真实SSH进程／历史、未升版本、未提交／推送／发布**；真机Gboard、手感和终端现场仍待后续新包验收。当前版本仍为1.0.12+13。
