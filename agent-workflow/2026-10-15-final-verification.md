# OpenCode 本轮收尾验证要求

后续状态：用户已追加要求实际新包打包／ADB安装测试，旧的未打包状态仅为下列
阶段记录。新包及设备检查请以`2026-10-16-agent-update-apk-adb.md`为准。

## 最终执行结果（2026-10-15 15:29 UTC）

按用户本轮例外授权由主代理及测试子代理补齐验证，生产UI仍全部原AgY修改。
新增测试不代替完整门禁，最终结果如下：

- `flutter gen-l10n`：退出0。
- 全部17个ARB的1740基础key一致，无缺失；无手写生成getter。
- `flutter analyze --no-pub`：退出0，零问题。
- `flutter test --no-pub --concurrency=4 --reporter expanded`：退出0，
  **3849通过／30既有环境项跳过／0失败**。
- 涉及文件格式检查、`git diff --check`：退出0。
- 实际隔离归档脚本9项通过，包含安全失败后保留旧运行时；没有执行真实远端升级。
- 用户确认独占ADB后，仅对旧包保存的krm做授权只读探测，未构建或覆盖安装。
  临时Codex检测配置已删除、原AgY选择恢复；详细路径/版本/模型证据见主工作单。
  新UI不以旧APK操作冒充实机验收。旧ACP0.16.0仍需核实来源并另行确认更新；
  未发送消息验证对话能力。

证据目录`/tmp/valhalla-agent-updates.aOvCbg/`：最终全量
`full-test-final-2.log`，分析`analyze-final-3.log`，生成`l10n-final.log`。
第一轮全量的11个失败均保留在`full-test-final.log`，分别为状态徽标溢出和
旧导航/登录测试的新依赖/当前服务器身份夹具缺失，修复后整套重跑通过。
不改版本、不打包、不安装、不提交、推送、发布或启动Actions。

---

执行补充：OpenCode免费模型未完成完整交付，用户已明确授权本轮主代理补齐
测试／语言生成／静态验证。以下验收要求保持不变；UI仍全部交AgY，不打包、
安装、推送或发布。用户已确认ADB设备可独占，并允许临时只读Codex检测配置；
已完成路径／版本／模型目录检查且删除临时配置。详见主工作单真实证据段。

范围和职责见 `2026-10-15-agent-updates-toolbar.md`。仅测试/格式/l10n生成/分析，
不改业务/UI、不构建、不ADB、不推送。测试修改用apply_patch；禁止占位测试。

## 当前确定需补回归

- 阅读最新 `2026-10-15-codex-runtime-handoff.md`，其中已新增草稿 model A 查询
  pending期间换B / A→B→A的Completer回归；旧Future晚到不能清技能或制造假错。
- agent_registry_provider `_refreshAgent` 异常catch现改用最新runtime：先pending
  inspect，再 beginInteractiveLogin，再让inspect失败，isLoggingIn必须保留true；
  endInteractiveLogin(token)后才false。过期token不能关闭新登录。
- 新factory可选参数 `{String? initialModelId}` 的mock兼容不能漏；临时debug print
  在提交测试前去掉，不留下 /tmp 实验或placeholder进项目。

## UI需要实际widget验证，不只源码字符串匹配

- 文件工具栏全部9固定、0固定、默认4固定；未固定仅在More，More不能横滚出屏。
  320dp、2x字号、RTL，关闭配置不弹键盘；Save/Cancel/Defaults和写入失败保留弹窗。
- 管理页更新入口、计划确认展示host/container/user和CLI/ACP版本；取消没有apply。
  缓存available的command=null也允许prepare；忙碌/未知来源不能假显示成功。
- 实际切入ACP/CLI才触发onChatEntered，IndexedStack挂载不能触发；启动页和
  当前页面切换服务器需要触发，普通重建不能重复调用。
- 重连、缓存、恢复成功/失败各阶段，正文/列表/terminal的Rect与滚动offset不变；
  浮层不抢焦点，drawer和dialog在它上面。测试原inline缓存banner请改为新浮层/
  详情入口，不仅删掉断言。tmux恢复也不改变终端rows/cols。
- 17语言key一致，无Claude CodeX新显示；保留旧数据解析alias。

## 验证输出

先聚焦涉及测试，再全量 `flutter analyze` 和 `flutter test`（跳过依赖真实远端/
设备的已标记手工测试，不新增随意skip）。保存真实命令、通过/失败/skip数和
失败原文到本轮证据，别用代理总结冒充成功。编译错误按所有权反馈；core交root，
UI交AgY。本轮真实宿主机Codex会话与远端升级未获独立目标，不用当前Codex代测。
