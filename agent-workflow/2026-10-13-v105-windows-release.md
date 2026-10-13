# Windows v1.0.5 补充发布

用户要求拉取最新代码，在本地构建 Windows 并发布到 GitHub 和分发平台；
分发平台仅登记 GitHub Release 外链。保持应用 `1.0.5+6`、MSIX `1.0.5.0`，
原 v1.0.5 标签、Android/Linux 附件及已有 Ygg 分发包保持原样。

## 来源与本地验证

拉取后的 main 为 `fbe62d6`。生产编译源码提交为
`27d182c3b9cec8e32177f0221a33e112e045975f`，打包工作区提交为
`b8b55d193469dc3a1437751d24ff8f7f2750e149`；两者之间只修正测试辅助代码。
Windows 安装器版本和 MSIX 默认版本同步到本次版本，不改变生产功能。

静态检查零问题。Windows 可运行回归 3155 项通过、46 项环境条件跳过，
另有 17 项远端命令结构验证通过，共 3172 项通过，最终回归零失败。
本轮最初广泛测试暴露了测试辅助的 Windows 通道模拟、路径格式和固定事件循环
等待问题；通过模拟运行信息、按宿主选择下载包、规范化播放器路径，以及等待
实际缩略图任务进入/完成修正，未修改生产逻辑。

以下七个依赖 POSIX shell/权限/`pwd` 的测试文件不纳入 Windows 主回归，
其中后两个文件的 17 项跨平台结构断言单独运行：

- `application_cleanup_helper_test.dart`
- `application_worker_stream_test.dart`
- `application_worker_test.dart`
- `nas_native_install_service_test.dart`
- `antigravity_acp_install_test.dart`
- `agent_execution_target_test.dart`
- `antigravity_login_check_command_test.dart`

ZIP CRC、27 个 x64 PE 依赖、73 个安装载荷与生产 bundle 的内容匹配均通过。
EXE 安装、启动和卸载通过；连续启动、最小化恢复和正常/异常退出后重启通过。
MSIX 通过 MakeAppx、商店标识、17 种语言及块哈希验证；使用临时开发身份验证
生产载荷启动及与便携版共享单实例，随后移除临时注册，保留原商店安装。
Windows App Certification Kit 未运行，最终商店认证由微软执行。

## 发布产物与分发方式

- `valhalla-1.0.5-windows-x64-setup.exe`：安装版，暂未代码签名。
- `valhalla-v1.0.5-windows-x64.zip`：便携版，文件名符合应用更新器校验约定。
- `valhalla-1.0.5.0-windows-x64-store.msix`：未签名，供 Partner Center 上传。
- `valhalla-v1.0.5-windows-BUILD-INFO.txt`：实际来源和验证边界。

四个文件分别附带 `.sha256`，在保留原记录的基础上更新 `SHA256SUMS.txt`。
`update.json` 保留 Android/Linux 原记录和来源，补充 Windows ZIP 实际来源。
分发平台现有 `1.0.5+6` 的 Windows/x86_64 目标为空，新增一个 ZIP 外链，
包含准确大小和 SHA-256；不上传 R2，也不重建原 Android/Linux 分发包。

GitHub、分发平台的最终回执待发布后补充。
