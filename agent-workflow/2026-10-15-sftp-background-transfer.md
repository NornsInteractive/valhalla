# SFTP 下载主线程卡顿：后台传输

## 诊断与范围

用户反馈正式包传输期间整个应用仍卡顿，SFTP 下载最明显。既有 Widget
订阅已隔离，但 SSH 的 AES-GCM 解密仍在 UI isolate；4ms 让步发生在完整包
处理之后，无法中断单个包的同步解密。
本机实际 PointyCastle 算法诊断：32KiB 最大包 33.788ms；模拟原 4ms 让步，
2MiB 解密耗时 2098ms、主事件循环最差间隔 35.256ms；相同计算在 worker
耗时 2108ms、主事件循环最差间隔 9.701ms。不是手机帧率／吞吐结论。
原始探针与输出在 `/tmp/valhalla-sftp-isolate.ASMBrs`。

## 实现契约

- 已验证的主 SSH 连接保存仅内存的认证／主机指纹快照，断开时丢弃；worker
  连接必须校验相同指纹和类型，不自动接受新主机钥匙，不修改用户登录资料。
- 浏览、终端和 ACP 沿用主客户端；文件下载／上传各自 worker 负责独立连接、
  解密、SFTP 解析、前缀校验和写盘，主线程不接收文件字节，仅接收节流进度。
- 复用 SftpClientService 原有实现，保留源身份、完整续传校验、不覆盖上传
  目标、暂停／取消／提交保护与最终字节精度。切服／连接替换／dispose 必须
  关闭对应 worker，不能关闭浏览或终端客户端，不允许静默退回主线程传输。
- 测试接缝仅 workerConnector（顶层纯函数），用于本地替身连接；生产必须
  使用真实 SSHSocket、密码／私钥认证和已验证指纹。不得读取生产凭据或向
  用户已有 Agent／终端发送命令，不操作生产文件。

## 验证与交付

测试编写／运行、格式和静态检查按规则优先交 OpenCode。至少覆盖：实际
isolate 下的下载字节／哈希、上传、源身份、异常分类、进度有界、暂停继续／
取消、启动取消／连接替换、提交保护、浏览与传输隔离；主事件循环在 worker
执行 CPU 负载期间仍可运行。已有 SFTP／SSH／UI 回归需要保持。
OpenCode 的 MiMo／Big Pickle 本轮无返回，免费备用只完成早期分析，未完成
测试；用户授权主代理直接完成验证，并追加要求连接 ADB。本轮主代理完成
相关 12 文件 **120 通过／0 失败**（已包含新增 worker／指纹的 13 项），
独立 VM 的真实密码／私钥上传下载／错误指纹验收另 **1 项通过**，合计 121。
真实 2MiB 下载 SHA256 一致，主事件循环最差间隔 9.061ms，传输期间共享主
客户端仍可执行检查命令。全项目 `flutter analyze --no-pub` 零问题，差异检查通过。

ADB `127.0.0.1:14251` 为 x86_64 模拟设备。安装包含本轮源码的 production
入口 profile 包（非测试页面），包名 `com.norns.valhalla`、1.0.6+7、原正式
证书；旧包名应用未卸载／改动，未读取其生产凭据。使用独立 VM 的明确测试
服务器及 120 个样本条目，真实下载 **141,935,500 字节** APK 两次均完成，
SHA256 均为 `aaea88e199be207d0d444471ab2dc3484f80ebc6d4339addd6ac1315269256e0`。
这是旧 APK 作为测试数据的哈希，不是本轮新安装包哈希。

下载活动期间 VM 显示 `main`／`sftp-transfer` 两个 isolate；滚动目录、切换
Dashboard 后返回文件页仍正常响应。活动滚动／切页采集 718 个 Flutter UI
`Frame`：p95 **2.131ms**、最大 **11.178ms**、超过 16.667ms 为 0；不是 GPU
呈现帧率或所有设备结论。仅进度更新样本 1247 帧 p95 1.729ms、最大 2.319ms。
第三次下载在约 40% 暂停，继续后字节增至约 68%，取消后显示 Canceled，
worker isolate 退出，只剩 main；主连接仍正常、未出现本进程异常日志。
传输动画导致 `uiautomator dump` 等待空闲超时，改用有前台包检查的截图坐标
及暂停后的语义树验收，不将该自动化等待误报为 ANR。

证据位于 `/tmp/valhalla-sftp-isolate.ASMBrs`（分析／回归／真实 VM 日志、
活动时间线和截图），本地测试包位于 `build/local-packages/sftp-profile.KnY8XO`。
不改变 UI／语言／版本，不推送发布；真机 ARM 性能和生产服务器未验证。

## 正式包 ADB 交付

本地 `flutter build apk --release --target lib/main.dart` 于
2026-10-14 18:59:59 UTC 完成（构建机本地为 2026-10-15），退出码 0。
使用隔离 Gradle user home 复用依赖缓存，避免全局 init 配置冲突，没有修改
全局配置。原证书签名／包名 `com.norns.valhalla`／1.0.6+7／三架构／ZIP／
构建前后源码哈希通过；不是 profile 或旧包重命名。

正式 APK：`build/local-packages/sftp-worker-release.Hq0zmt/Valhalla-1.0.6+7-android-universal-signed.apk`，
141,984,652 字节，SHA256
`b82f16ee919043a0450b5f9bfb3c3656984d59cc96a1e8db5e85e0a1ad8d63c8`。
ADB `install -r` 成功，保留新包名测试应用数据；安装后 `base.apk` 的 SHA256
一致，release 无 DEBUGGABLE 标记。启动自动连接到独立测试服务器，浏览
仍正常；正式包再完成同一 141,935,500 字节下载（第四条任务 Completed／
100%），下载期间滚动、切 Dashboard 后返回及打开传输列表正常；进程保持
15205，没有本进程异常日志，exit-info 仅记录 profile 被覆盖安装的正常退出。
正式 release 不用 `run-as` 读取私有文件；内容哈希来自前述 profile 两次
下载，release 本轮确认真实完成与响应，不冒充 release 文件内容哈希校验。
旧包名应用始终未卸载或改动。隔离 VM 样本及新应用的明确测试服务器保留
便于复验；仅移除本轮 VM 调试端口 forward，不清除其他设备映射或用户数据。
