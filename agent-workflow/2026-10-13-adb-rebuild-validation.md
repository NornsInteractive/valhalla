# 本轮直接构建、ADB 安装与真实操作验收

用户明确授权主代理负责本轮 UI、测试、打包和 ADB 安装。沿用1.0.4+5、原兼容
测试签名，保留手机配置与会话数据。生产服务器未用于写操作，无推送或发布。

## 构建与安装

证据目录：`/tmp/valhalla-adb-verification.YIewE5`。

首次重新构建成功（3.4秒，复用缓存），2026-10-13 18:56:15+08 覆盖安装；源码
未变，哈希与上一包一致。设备发现时间显示问题并修复后，再次构建成功（58.8秒）。

- 最终 APK：`build/app/outputs/flutter-apk/app-x86_64-release.apk`，另存
  `/tmp/valhalla-adb-verification.YIewE5/valhalla-1.0.4-adb-final-x86_64.apk`。
- 构建时间：2026-10-13 19:07:09+08，52,669,128字节；release模式，x86_64。
- 包名：`com.antigravity.valhalla.valhalla`；版本1.0.4/native4005。
- APK SHA256：`e0f7ccf3579ba2f222d5c20cb8d73a9d8b77f778b76b20b49e2304b3a091dad8`。
- 原测试证书 SHA256：`2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`。
- `adb install -r`成功；设备更新时间2026-10-13 **19:08:24+08**，首次安装时间
  仍2026-09-23 03:26:04。实际拉取已安装base.apk，哈希与最终APK一致。
- 原服务器、来源、菜单设置及本轮测试部署记录在覆盖安装后保留；最终进程PID27151。

构建命令沿用项目Gradle缓存，取消正式签名环境变量，只使用原测试签名：

```sh
env -u VALHALLA_ANDROID_KEYSTORE -u VALHALLA_ANDROID_KEY_ALIAS \
  -u VALHALLA_ANDROID_STORE_PASSWORD -u VALHALLA_ANDROID_KEY_PASSWORD \
  -u VALHALLA_CI_UNSIGNED GRADLE_USER_HOME=/tmp/valhalla-app-center-gradle.mgpUTM \
  /opt/flutter/bin/flutter build apk --release --split-per-abi \
  --target-platform android-x64
```

## 自动化与设备发现的修复

- 统一浏览、文件页、NAS选择、应用商店／命名／路径／卸载相关185项回归全部通过，
  静态分析零问题。此前3237项全量记录保留，不把它写成本轮重新运行的数字。
- 实际安装任务发现服务器时钟领先时“最后输出:-1s”。安装向导和任务详情两个
  已有格式化函数均将负时长显示为0s，不改服务端时间或任务状态。
- 在两个已有测试中注入未来输出时间，修复前2项失败，修复后应用相关77项通过，
  静态分析再次零问题。它们与185项有重叠，不合计成262项。
- 新包卸载任务同步过程中“最后输出:0s”实际显示正常，未出现负数。
- `git diff --check`通过；记录构建前及修复后的源码哈希清单。
- 默认集成测试安装器可能卸载应用并清数据，本轮未使用它；实际操作使用ADB
  保留数据安装、界面点击、XML、截图及固定身份VM核验。

## ADB 完整应用中心闭环

ADB设备`127.0.0.1:14251`是Android x86_64模拟器（逻辑宽360dp）。操作前逐次
核对前台属于Valhalla；唯一进入Chrome是本轮明确点击打开测试应用Web页面。

先运行只读身份门：SSH127.0.0.1:22023／valhalla，固定machine-id
`3579bace85be432fa7cde6da46ad839b`、hostkey
`SHA256:j0JCpHOOGNJlL2UDKj5nQnFSJlePw63tPE8Yo4MINtM`及fixture-ready。
全部远端变更只发生在此隔离VM；私有SSH密码没有打印、复制到报告或更改。

真实流程通过：

1. 从官方商店选择BentoPDF，进入环境检查与配置；输入独立实例名
   `adb-acceptance-7cd183e2`，名称预览同步显示相同名称。
2. 点击默认尚未创建的数据路径，统一选择器自动定位到存在的父目录，支持
   搜索／隐藏／视图／排序；取消后原实例名和路径保留，输入法不自动弹出。
3. 明确选择仅本机访问，预览`127.0.0.1:3000->8080/tcp`后执行安装。
4. 任务显示真实`docker compose ... pull`命令及持续更新的镜像层下载日志；
   选择后台运行并进入文件页，任务继续。已安装页随后显示running／健康。
5. 独立SSH只读核验Docker容器名精确等于输入名称，标签绑定本轮部署ID；
   点击打开Web界面，经SSH隧道在Chrome实际显示BentoPDF工具首页。
6. 安装最终修复包后，上述部署记录仍在。打开卸载预览：默认0/1未勾选；完整
   数据根目录可勾选为1/1；继续后需确认用途并输入完整实例名，才允许删除。
7. 仅对本轮测试根目录确认删除。任务显示执行成功／退出0／目录已删除。
   独立SSH断言容器不存在、数据目录不存在；应用已安装页恢复为空。
8. 原Jellyfin容器仍在运行，共同apps父目录仍存在。未删除镜像缓存、审计或其他
   fixture目录；没有操作生产服务器或用户媒体。

本轮精确对象：

- 部署ID：`1b8319ad2f9cc28ac7c04aec6ecb3fae`。
- 已移除容器：`adb-acceptance-7cd183e2`。
- 已删除目录：`/home/valhalla/.local/share/valhalla/apps/1b8319ad2f9cc28ac7c04aec6ecb3fae`。
- 安装任务：`4af67a6aa049e8ce9cfd9e39144e412d`；卸载任务：`ed17ed88397d11b81f8f87f5091751bf`。
- 上述目录仅为本轮新建测试数据，删除不可恢复；任务与控制审计有意保留以复核。

证据：`07-named-config`、`08-wizard-picker`、`13/14-install-progress`、
`20-installed`、`22-web-result.png`、`29-uninstall-preview`、
`30-uninstall-selected`、`32-uninstall-authorized`、`35-cleanup-finished`、
`36-installed-after-cleanup`；服务器断言见`vm-cleanup-verified.log`。

远程文件页也实际切换卡片／列表，隐藏目录显示淡化；应用商店实际切换手机
单列／双列。日志未见Flutter异常、崩溃、布局溢出或Valhalla ANR。

## 未覆盖

本轮未在实体手机、Windows、iOS测试；无真实独立ACP Docker Agent。实际安装
闭环使用一个官方应用，其他模板、多挂载、保护目录及副容器依赖原有回归和隔离
VM证据，不能推断所有商店应用均已实际安装。无GitHub推送／Release发布。
