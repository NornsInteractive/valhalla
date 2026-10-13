# 应用中心安装目录错误修复

## 用户反馈与证据

选择安装目录返回 SFTP noSuchFile(code2)；Nginx 代理管理器填写变量后
下一步返回 APP_CENTER_PATH_INVALID。用户未提供具体目录值。

选择器调用链：安装向导 _pickDataDirectory 使用未创建数据目录的父目录；
_pickMountDirectory 使用预计挂载目录。共享选择器直接 listFiles，缺少首次
打开时的父目录回退，而且失败后仍可确认。这里不应提前创建远端目录。

路径校验链：配置 -> prepare JSON快照 -> Compose build -> validatePath。
原 validatePath 要求路径和 POSIX normalize 完全相同，因此 /data/app/ 等
合法目录后缀也被拒绝；无字段标识导致无法判断数据目录或哪类挂载有问题。
Nginx Proxy Manager 官方模板的两个原始路径本身规范：
`/DATA/AppData/$AppID/data -> /data`、
`/DATA/AppData/$AppID/etc/letsencrypt -> /etc/letsencrypt`。
尚不能证明用户当时的输入就是尾斜杠，不将这一分支当作完整现场复现。

## 最小修复范围

- 共享目录选择器仅首次打开、仅 typed noSuchFile 时逐级找现存父目录。
  权限／连接失败不回退，普通导航失败不自动换目标；失败禁用确认。
  每次异步往返检查原连接、在线状态与存活，不创建目录、不改取消后的表单。
- Compose 配置与 prepare 快照统一去除目录末尾斜杠，模板挂载键／输出一致。
  不使用 normalize 消除 .. 等路径段，严格校验仍拒绝根、相对、穿越、控制符。
  标准化必须在控制目录／敏感挂载判断前执行，避免 /etc/ 等旁路。
- PATH_INVALID 提供 dataRoot/mountSource/mountTarget 字段标识，不记录路径、
  变量或密码。UI 由原 AgY 映射本地化字段及解释，不显示内部标识。

## 归属与当前验证状态

UI/ARB：仅原 Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b，
gemini-3.8-flash-high/high；主代理只改业务与文档。
OpenCode MiMo 在08:44UTC限流；明确免费的 Nemotron3.5Lightning 测试草稿
审查发现未覆盖所称行为并破坏原测试，已停止，仅把该文件恢复至本次执行前
快照8f7c4a41f7ea02dd7fb3dba196a2b2d468d44aba，保留原22个测试。
Big Pickle 在08:50UTC同样限流。没有把未执行的回归标记通过。
已询问仅本轮由主代理直接验证的例外；尚未取得前不运行新测试或构建。
模型免费价目复核：https://opencode.ai/docs/zen/，本机目录对应cost均为0。
AgY首次调用重复调查无编辑，停止该单次CLI后续接相同会话继续，未切换模型。

不升版本、不推送、不发布；不在用户服务器安装／重启应用或创建目录。
本轮尚未重新打包或安装。证据目录 /tmp/valhalla-app-paths.HS4wpP。

## 审查补充

AgY已完成选择器与字段错误17语言文案；其CLI结尾上游EOF不代表编辑未完成，
已按磁盘源码核对。移除新增的重复手写翻译，统一调用生成的ARB方法。
备用模型的两次缩小范围测试草稿仍存在错误导入、语法错误和不符合实际API的
断言，不保留为有效测试：相关新文件移至scratch的rejected-*文件供复核；
没有删除用户测试。原application_compose_test.dart与委派前快照一致。
已改为让OpenCode只执行既有相关套件、生成与分析，禁止再编辑产品或测试。
本轮新增回归仍待可用验证路径，既有套件通过也不等同于新增场景已覆盖。

## 既有门禁结果

OpenCode opencode/nemotron-3.5-lightning-free 主/辅助模型，执行only调用日志
opencode-validation.jsonl保留完整命令输出与显式EXIT_CODE：gen-l10n=0；
指定4文件格式化=0（仅picker格式变化）；Compose/preflight/worker/l10n/
AppCenter UI/SFTP UI六个既有套件合计123通过，EXIT_CODE=0；flutter analyze
--no-pub无问题，EXIT_CODE=0。代理未按要求另存三份简短日志，真实证据以
JSONL内bash结果为准，不杜撰日志文件或新增回归成功。

阶段结论：已落地公共目录浏览回退、目录尾斜杠兼容和本地化字段提示；尚缺
新场景专项回归、用户当时路径现场复现、重新构建和设备验证。没有APK更新。

## 用户要求先完成验证（后续状态覆盖上文）

在主代理询问是否可直接补齐专项回归后，用户回复“你要测试好，再给我测试”。
本轮据此由主代理补齐专项验证，不继续把不合格模型草稿交给用户验收；UI
仍只归原AgY。新增fixture来自本轮已核对的官方Nginx Proxy Manager相关字段。
23项专项已通过：14项Compose路径／安全检查、9项真实Widget交互（不是只
调用假prepare）。包含首次缺失目录回退、权限／连接失败不回退、普通导航
不误选父目录、根终止／限制目录、换服务器／断线迟到结果、取消保留配置、
实际选目录后填写变量进入预览、完全默认配置进入预览。Wizard测试的prepare
内部执行真实Compose build，不能绕过路径校验。

测试初稿仅有finder定位两个Cancel的歧义及确认按钮文字假设，已修正测试
选择器，产品代码未因此调整。专项证据：
/tmp/valhalla-path-verification.vKv9vC/focused.log，23通过。
当前继续执行隔离VM真实Nginx预览（不安装Nginx代理管理器、不创建其目录）
及既有fixture完整部署周期、全套回归和静态分析。

## 现场定位与专项验收已完成

ADB当前前台确认为Valhalla，仅读取安装表单目录字段：dataRoot=/data/temp/，
两处source=/data/temp/data/temp、/data/temp/data/temp/test。此前缺少用户输入
这一证据现已补齐：旧build直接把带尾斜杠的dataRoot交给strict validatePath，
确实抛PATH_INVALID。新增测试原样保留这两处手工挂载，证明旧校验抛错，而
新build规范化数据根目录后通过，不擅自替换用户的挂载。未读取变量／密码。

- focused.log：24通过（15核心、9Widget）。
- full.log：2687通过／20环境跳过／0失败；该次全套开始后增加了上述现场值
  1条回归，后续focused已单独覆盖它，因此不把全套虚报成2688。
- vm.log：3m56s，1通过。先校验固定主机密钥、machine-id、hostname和marker；
  真实prepare Nginx模板，确认data与letsencrypt两处源正确、预览前后目录仍
  不存在（没有预先创建）；随后nginx:alpine唯一fixture安装/HTTP/重连/启停/
  配置/重启/更新/恢复/卸载，哨兵数据保留。未安装Nginx代理管理器产品镜像。
- analyze.log：零问题。产品没有因测试而增加额外修改。

测试产物安装仍按职责交给OpenCode明确免费模型执行，使用原模拟器兼容证书，
新目录build/app-center-paths-validation/compatible，不覆盖旧正式包，不发布。
构建与设备验证已完成，详见下方最终结果。

## 构建、覆盖安装及设备实际流程（完成）

OpenCode主/辅助模型均为opencode/nemotron-3.5-lightning-free，执行本地
android-x64 release构建、签名核验及adb install -r，返回Success。首次调用
受OpenCode外部目录权限限制未执行构建，第二次仅放行验证临时目录及隔离
Gradle目录后完成；执行证据opencode-install-retry.jsonl。不升版本、不发布。

测试APK：build/app-center-paths-validation/compatible/app-x86_64-release.apk，
51,685,644字节；SHA256：
28c1d991257770fb32f01fdb76e0ba22789d67d07727ee5b738e2c2929295927。
沿用原模拟器调试证书，release运行模式；不是新的正式签名发布包。主代理
独立拉取设备base.apk确认哈希一致，versionName=1.0.4，versionCode=4005，
lastUpdateTime=2026-10-12 17:17:44（设备时区），原firstInstallTime未变。

主代理在ADB实际操作Nginx代理管理器安装向导（每次输入前确认Valhalla前台）：
- 默认新目录尚不存在，浏览成功回退到/root/.local/share并展示子目录，
  没有SftpStatusError；选择目录后正常返回向导。
- 数据目录填/data/temp/，挂载自动重定位为/data/temp/data及
  /data/temp/etc/letsencrypt；时区变量修改为Asia/Shanghai。
- 下一步正确提示服务器80端口已占用，不再报PATH_INVALID。仅在未提交
  表单把端口改为18141/18142/18143，再次下一步进入真实Compose预览。
- 截图可见jc21/nginx-proxy-manager:2.13.5、正确测试端口及/data挂载；
  底部已到“执行部署方案”。点击取消退出，未执行方案、未改变用户服务器。
- 本次启动后设备日志未匹配E/flutter、FATAL EXCEPTION、Unhandled Exception、
  RenderFlex、APP_CENTER_PATH_INVALID或SftpStatusError。

设备截图、层级、日志及全部验证证据位于
/tmp/valhalla-path-verification.vKv9vC/。隔离VM完成真实fixture部署闭环；
用户服务器仅到预览，没有安装Nginx代理管理器产品镜像或进行破坏性测试。
