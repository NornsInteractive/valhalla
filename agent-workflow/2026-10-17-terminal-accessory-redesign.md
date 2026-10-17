# SSH 快捷键栏：固定方向区与独立配色

## 最终状态：已完成，未打包/安装/发布

UI/ARB由原Valhalla AgY、Gemini3.8Flash high实施；测试由OpenCode免费MiMo/Big Pickle编写，
最终生成、格式、静态分析与18文件回归由OpenCode免费MiMo执行。主代理只实现非UI持久化、
复核及机械应用OpenCode提供的测试补丁，没有接管UI或直接运行Flutter验证。
最终243项通过、0失败、0跳过；全项目静态分析零问题，源码前后哈希一致。详见文末最终验收。

## 本轮契约

用户已确认实施：常用键两行横滚，更多/键盘固定一列，其右侧为默认固定的132×88dp一体倒T方向区。
普通字号底栏88dp；44dp不重叠触控槽内放40dp键面，槽内2dp内缩，不另加外边距，视觉键距4dp。
方向区固定/随常用键滚动/隐藏可选。默认跟随主题，可独立选色（预设、HSV选择器、HEX、预览、恢复跟随主题）。
保留单次/按住/锁定修饰键、Gboard输入、连发与后台停止、手动键盘入口，禁止改变连接/会话/历史/输入编码。
原AgY Valhalla会话 ec81a4be-7543-45ee-8658-f68966f57d3b，gemini-3.8-flash-high、effort high负责所有UI/ARB。
验证/格式/语言生成由OpenCode已核验免费模型负责；过去主代理单轮验证例外不延续。
本轮不打包、不安装、不升版本、不推送或发布，不操作生产终端。

## 核心接口与兼容

- `TerminalDirectionPadMode { fixed, flow, hidden }`；`TerminalSettings.directionPadMode`与`int? directionKeySeedColorValue`。
- `TerminalSettingsNotifier.setAccessorySettings(pinnedKeys:, directionPadMode:, directionKeySeedColorValue:)`原子保存整个弹窗。
- `copyWith`清除颜色使用`clearDirectionKeySeedColor: true`。
- 新记录`valhalla_terminal_accessory_v2`保存三项，旧v1列表不改，读取新记录失败回退旧列表。
- 无新记录时：默认列表含ARROWS则fixed，旧自定义无ARROWS（包括空）则hidden；旧顺序及单个箭头保留。
- 新界面方向模式是组合ARROWS的唯一显示来源：fixed从滚动区过滤ARROWS；flow按原ARROWS位置，无标记时追加末尾；hidden不显示组合区。
- 自定义弹窗可保留ARROWS排序标记，但不能提供与方向模式矛盾的独立增删入口；移除标记应同步hidden，重新添加应同步fixed。
- `setPinnedKeys`为旧调用保留：移除ARROWS转hidden、重新加入转fixed，已有ARROWS保留选择的模式；旧v1数据一直保留可回退。
- 新记录已加入配置导入/导出白名单。写盘失败不得部分更新对话框三项或内存。

## 验收目标

320/360/390dp与2x字号、RTL和深浅/纯黑主题；44dp触控与4dp间距；横滚时固定区坐标不变。
组合区不重复；按下/连发高亮与pointer cancel/后台/隐藏复原；空角不发送输入不弹键盘。
Ctrl+C、Shift+Tab、Gboard、锁定与按住组合；保存失败、跨重启、旧配置、空列表与备份恢复。
按键局部反馈不得重建终端。自动化证据不代替真机验收；完成后填写实际结果。

## 阶段状态（历史快照，最终结果见文末）

实施中；原AgY正在修改UI/ARB，OpenCode免费MiMo（主/辅助模型均固定免费）已完成核心首批回归。

- 新增`test/core/terminal_accessory_settings_test.dart`21项，连同原设置18项与存储30项，合计69项通过。
- 覆盖三态、颜色清除与跨重启、旧列表/单箭头/显式空值、失败不改内存、坏记录回退、备份导入与v1保留。
- 原始日志`build/local-packages/20261017-terminal-accessory/evidence/focused-tests.log`，真实测试exit0。
- UI布局与输入回归、最终静态分析尚未完成，不把首批核心结果当作UI完成证据。
- 第二批新增8项方向几何/固定/滚动/隐藏/2x/RTL通过；原共享画布重排用例因未滚动到可用键而失败，夹具调整中。
- 并行编辑期间首次UI编译遇到新ARB未生成，OpenCode重新生成后已排除；失败现场保留，不作为最终门禁。
- 复核追加普通键Material默认48dp触控留白、修饰键边缘命中和无计时器推进的后台/前台切换，修正仍交AgY。
- 未构建、安装、升版本、推送或发布。

## 主体完成与阶段门禁

原AgY已完成全部展示：40dp键面/44dp独立触控（显式去掉Material默认48dp留白），默认右侧固定132×88一体倒T，
更多/键盘在其左侧同列；修饰键边缘命中完整、锁角标不撑宽；三态设置、独立HSV/HEX配色与17语文案齐全。
HoldRepeatKey自身监听生命周期，非resumed立即取消；高亮为按键局部状态，安全异步回调不在构建/释放中更新祖先。
配置保存同步防重入，隐藏方向区不丢ARROWS排序标记；单记录写盘失败不更新内存。

- OpenCode MiMo完成`stage5-nearest.log`：14个文件189项通过，含17语占位元数据、Gboard组合、焦点、滚动及历史回归。
- OpenCode生成旧夹具修正补丁，主代理仅通过自带apply_patch机械应用（其CLI无此命令）；测试逻辑仍由OpenCode编写、执行。
- `stage6-ui.log`：共享画布、旧布局、新8项布局三个文件45项通过；实际拖拽排序与保存失败均通过，旧几何按新相对位置更新。
- `stage6-analyze.log`：全项目静态分析exit0、No issues found；格式/语言生成exit0。
- 上述两套文件互不重复，阶段合计234项通过。额外精确按压/取消和选色弹窗回归正在补充，不把阶段门禁当作全部验收。
- 失败现场`stage2-tests.log`、`stage2-feature-tests.log`、`stage4-analyze.log`和`stage4-nearest.log`保留，后续成功记录另存，不覆盖。

## 精确补验与最后布局修正

- MiMo编写/执行13项布局与反馈测试（原8+新5）全部通过，见`stage8-feedback.log`。
  使用生产JetBrains Mono字体测得320dp六个普通键全部位于滚动视口、列中心距44；深浅/独立seed按压配色、
  连发/取消、inactive后无计时器推进立即resumed、同State的TickerMode隐藏/恢复和双指均通过。
- Big Pickle编写/执行选色弹窗3项全部通过，见`stage8-color.log`：320dp/2x/es、真实Inter字体、SV拖动、HEX确认、取消返回null及恢复主题。
- `stage7-*`中曾有测试夹具缺context、颜色场景复用provider、异步反馈少一帧等失败，已修夹具后通过；未修改生产配色或降低断言。
- 追加默认fixed的父配置弹窗用例D，发现此前隐藏模式夹具漏掉配色行：320dp/2x/es实际向右溢出110px。
  证据`stage9-color.log`保留，正在由原AgY修正该行响应式布局，不缩字体或隐藏文案；最终全套门禁待此项通过后记录。

## 最终验收（全部通过）

AgY已将默认fixed配色行改为有界LayoutBuilder/Wrap，标题、色块、完整文字按钮可自动换行；
320dp/2x/es的父配置弹窗和实际进入选色器用例D由失败转为通过，没有修改字体、语言或断言。
最后一处use_null_aware_elements提示也由AgY作语法等价修正为`?swatch`。

OpenCode MiMo执行最终`final2`门禁：

- `final2-format.log`、`final2-gen-l10n.log`：真实exit0。
- `final2-analyze.log`：`flutter analyze --no-pub`真实exit0，No issues found。
- `final2-tests.jsonl`：`flutter test --no-pub --machine`覆盖18个文件，suite=18，非hidden testDone成功243、失败0、跳过0；
  最终done.success=true，真实进程退出0见`final2-exit.txt`，stderr为空。框架内部20个hidden事件不计入243。
- 格式/生成完成后才记录`final2-source-before.sha256`，测试后`final2-source-after.sha256`的286项lib Dart/ARB及pubspec完全一致，
  `final2-source-diff.txt`为空。不要用expanded并发输出中重复的活动标题推算单文件通过数。
- 先前`final-source-before/after`包含格式化前后差异，`final-analyze.log`保留旧info；不覆盖这些现场，最终判定以上述final2为准。
- 主代理最终`git diff --check`通过；未新增依赖，未修改终端连接、编码、会话或历史逻辑。

证据目录：`build/local-packages/20261017-terminal-accessory/evidence/`（本地忽略产物）。
规则、模块设计和实施状态已同步。本轮仍为1.0.9+10，未构建APK、未ADB安装、未推送或发布；
自动化测试不等于真机手感、系统输入法动画或读屏实机验收，设备旧包不会自动得到本次UI。

## 后续打包发布

上述未打包状态为实现轮次结束时的事实。用户随后明确要求打包发布，已新增1.0.10+11，本地正式签名Android三架构APK／AAB与Linux x64构建通过，
并公开GitHub新Release和原分发平台新版本；相关验证由OpenCode免费MiMo执行。仍未ADB安装或实机手感验收。
详见[1.0.10发布记录](2026-10-17-v1010-release.md)，不覆盖原实现证据或旧公开版本。
