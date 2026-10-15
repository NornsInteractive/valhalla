# Agent 更新与工具栏：新包 ADB 验收

用户明确要求“你打新包测试啊”，本轮执行新正式包本地构建、保留数据覆盖安装与
设备操作检查；不升版本、不推送、不发布。旧的“不打包／不安装”阶段边界已被
本次要求替代。OpenCode MiMo 已核验所有计价为0，但本次调用持续无事件、没有
启动任何构建；终止本次进程后，由主代理按用户当前要求接手。没有替换收费模型。
生产UI修复仍仅交原AgY Valhalla/Gemini3.8Flash high；本轮没有内部子代理。

## 首包的真实构建和安装

- `flutter build apk --release --target lib/main.dart`，原正式证书，1.0.6+7。
- 实际构建UTC：2026-10-15T16:05:13Z至16:07:02Z，退出0。
- 首包`build/local-packages/agent-updates.SWFykp/Valhalla-1.0.6+7-agent-updates-signed.apk`。
- 首包SHA256：`7890b0d680284c78a35c4123276b6b21f81377f578f2330ca7cf55030e7f8a7d`。
- APK包名／版本／ABI、ZIP CRC、原证书、源码构建前后校验通过。
- `adb -s 127.0.0.1:14251 install -r`成功，拉回设备base.apk，SHA256与首包一致。
- 设备lastUpdateTime为2026-10-16 00:07:25（设备本地时间），firstInstallTime仍为
  2026-10-15 02:24:07。新旧包名独立，未卸载／清数据或迁移旧包凭据。
- 设备为x86_64 Android模拟器；本节是新包设备操作，不是物理手机性能结论。

## 已执行设备操作（首包）

- 工具栏默认4项、取消全部保存、应用冷启动后仍全部取消；未固定项在More可达。
- 固定全部9项，横滚可达最后刷新项，More始终在右侧；More此时只含配置入口。
- 全选状态点恢复默认后Cancel，仍保留全选；再恢复默认并Save，最终恢复原4项。
- 搜索框确实打开键盘后，打开并关闭More，`mInputShown`从true变false，没有重弹。
- 添加Agent表单默认名称及模板为Claude Code；未保存Claude配置或执行安装。
- 仅在已有隔离服务器SFTP-Perf-Fixture内添加临时只读Codex／OpenCode检测配置，
  不在用户生产宿主机新增程序、登录或发送消息。手动检查可显示CLI/ACP缺失。
- 主动重连和HOME／返回后，远程文件路径、现有文件及首屏位置保持不变。
- 原安装的服务器、文件列表及传输记录均仍在；没有清除原用户数据。

## 设备发现及修复

首包不是最终交付包。设备发现360dp宽的Agent管理页因新增右侧动作导致标题只剩
32.5dp。AgY使用既有600dp紧凑断点，手机使用带Tooltip的添加图标，保留桌面文本。
补充360/400/412dp标题宽度和动作可达、桌面文本保留回归，管理页相关36项通过。

手动重连完成仍出现旧底部连接结果SnackBar；正文虽未移动，提示位置仍不符合
顶部浮层约定。已交AgY仅在MainShell／ConnectionStatusBanner完成统一提示，
保留目标身份检查、错误展示、定时清理及现有恢复优先级。另修正局部函数的
catch作用域，并用原“主动断开优先于会话恢复”回归防止优先级变化。没有改动
连接／重试核心，也没有放宽原测试断言。最终五文件重点回归82项全部通过。

## 最终包：已安装并完成设备复测

- 产物：`build/local-packages/agent-updates-final.c9MFza/Valhalla-1.0.6+7-agent-updates-signed.apk`。
- 大小143476080字节；SHA256：
  `c826a352a45e7bab4af045d7dda74a5e1af79c2049ec722966df354b05767d48`。
- 原正式证书／com.norns.valhalla／1.0.6+7；ABI为arm64-v8a、armeabi-v7a、x86_64。
- `flutter build apk --release --target lib/main.dart`，UTC2026-10-15T16:33:49Z
  开始，16:35:47Z结束，退出0。包内身份、签名、ZIP CRC、源码前后哈希通过。
- 再次`adb install -r`退出0；设备base.apk拉回SHA256与最终产物相同。
  设备lastUpdateTime为2026-10-16 00:36:24，firstInstallTime保持原值不变。
- 最终全量`flutter test --no-pub --concurrency=4 --reporter expanded`：
  **3856通过／30既有环境项跳过／0失败**，退出0；全项目静态分析零问题。
  这次结果包含新增7项回归，不能与此前3849相加。

最终APK另执行11项真实设备断言（与首包13项有重叠，不相加为独立功能数量）：

1. 安装时间改变、首次安装时间保留；包哈希与签名匹配。
2. 手动重连成功提示实际位于顶部，XML范围`[48,352][1392,712]`，不再位于底部。
3. 提示出现期间远程文件首屏各文件bounds不变，正文没有下移。
4. Agent管理页标题可用宽度从130px增加至480px（360dp设备），三个操作图标可达。
5. 覆盖安装后本轮临时Codex与OpenCode配置仍在，未清除原数据。
6. 逐条核对确认后删除这两条临时配置，管理页恢复原“No Agents Configured”。
7. 最终新包添加表单仍默认Claude Code，检查后Cancel，没有新增Claude配置。
8. 原工具栏4项恢复，搜索、路径和列表内容保留。
9. 最终新包搜索框打开键盘后关闭More，`mInputShown`从true变false。
10. 最终新包HOME／返回后，文件路径及各首屏文件bounds仍一致。
11. 最终进程PID24341未见未捕获异常；安装后系统本包am_crash／am_anr事件为0。

自动检测额外证据：新增OpenCode后并未手动点击更新检查，离开再进入ACP页，
其更新区记录00:22:24，与环境检测00:22:14区分；同日既有Codex更新记录继续
复用。仅在隔离VM探测缺失程序，未点击Auto Install、登录或更新执行。

设备当前前台为最终`com.norns.valhalla`，停留远程文件页，没有弹窗、键盘或
本轮待运行任务。旧`com.antigravity.valhalla.valhalla`安装及其krm配置保持不变。
源文件仅新增这次三个AgY UI补丁和两个测试文件，未更改版本或发布远端资产。

## 证据与边界

本轮证据目录：`/tmp/valhalla-agent-adb.Gc6Nah/`。构建命令、UTC、签名、拉回包
哈希、设备XML／截图／操作轨迹均保留。最初自动化测试3849通过的结果是上一轮
源码回归；本轮另有真实新包与设备证据，不混成物理手机或远端真实对话验收。

宿主机Codex旧ACP0.16.0仍须单独确认来源／升级；本轮未升级、登录、发消息或
改动用户生产账号和会话。真实远端升级及ACP生成能力不能用缺失程序的隔离检测
冒充已验证。测试临时配置已清理，工具栏偏好恢复原4项，没有更改实验性、
主题、语言、终端或默认Agent偏好。最终产物目录附BUILD-INFO与验收证据归档。
