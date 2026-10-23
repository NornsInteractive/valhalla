# ACP 后台持续运行实施状态

当前 pubspec 仍为 1.0.15+16，修改未提交；独立验证入口已由 OpenCode
构建为 1.0.16 / code 4017，正式证书核对通过并已保留数据安装到 ADB。
隔离测试已完成，已重新构建并安装正常 `lib/main.dart` 入口，仍保留用户数据。
尚未公开发布；正式发布需执行仓库发布脚本。
已快进合入远端 Windows 打包更新 `6accd8c`，未改其打包文件。

## 已实现

- 用户确认部署的 Python 3.9+ 用户级代理，私有 Unix socket/SQLite，SSH 附着与任务分离。
- runtime/turn 身份与游标，发送前绑定持久化、断线补传、审批保留、显式取消、完成输出七天清理。
- 恢复提示关闭而保留诊断；每日本地日期检查与新版本弹窗、前台/模态/输入法延后。
- UI 与 17 份 ARB 由原 AgY Valhalla / Gemini 3.8 Flash high 修改。

## 已验证

- Python 代理 12 项，两次连续通过；补充终态审批清理后再次 12 项通过。
- 新增传输/适配器 8 项；每日提醒 11 项及原更新 provider 11 项通过。
- provider 完整补传/实时完成回归及同文件七项通过；组合 174 项通过时有一项窄屏 UI 溢出。
- AgY 修复溢出后，恢复与 banner 相关 38 项通过。
- 最后一条 UI 异步 context 告警已修正，随后又由 AgY 修复授权弹窗双重 pop；这些最终 UI 修改仍待补回归与静态检查。
- 真实模拟 SSH 服务小响应和二进制输入通过；这不是 Android 设备端 ACP 验收。

详细证据见同目录本日各 `acp-*tests`、`acp-closeout-check` 和 `update-prompt-tests` 文档。

## 交付进度

1. 最终语言生成成功、分析零问题；180 项 Flutter 回归、12 项代理回归通过，含授权弹窗 5 项。
2. `tool/acp_runtime_device_probe.dart` 已成功构建；它不读取生产配置，仅写独立 probe 目录。
3. ADB 验收通过：5 个 chunk 后强制关闭，远端继续至 10 个，重开后恰好 30 个有序 chunk、远端仅一个 prompt。
4. 正常 `lib/main.dart` 安装包已恢复并验收启动；原正式签名、1.0.16 / code 4017；模拟服务与 Agent 已按记录 PID 清理。
5. 待发布：新版本 1.0.16+17 的正式构建、GitHub Release 与 Ygg 代理分发，依照 `tool/RELEASE.md`。

## 当前执行限制

OpenCode MiMo、Beam、GLM 免费模型已返回 Free usage limit reached；DeepSeek 免费模型此前中断，未完成设备构建。
用户随后明确“现在交给 opencode 实现”，因此继续由 OpenCode 负责剩余实现、验证和构建/ADB，不采用主代理直接执行的例外。
已重启 CLI 并重新核验免费目录；MiMo/Big Pickle 仍返回额度限制。
`opencode/nemotron-3.5-lightning-free` 已真实执行 `pwd`、exit 0、记录 cost=0；
后续主/辅助模型均固定此免费模型，已重新交付剩余回归、构建与 ADB 验收任务。
不把历史轮次例外当成本轮授权，不以等待时间视为同意。

后续改用同样已核验免费且实际可调用的 Nemotron Ultra 执行构建/ADB。
OpenCode 曾越界修改 Android 仓库配置，已恢复 HEAD 原配置；无此项产品改动。
它也曾将签名密码展开到工具命令日志中：已停止该进程、清理本地输出副本，
未改签名文件/证书，也未将该值写入 Git 或发布文件。工具服务历史可能仍保留原调用；
不得宣称已从历史彻底抹除。后续仅调用 `tool/acp_device_build.py`，由进程内环境
读取签名值，禁止模型读取凭据或展开到参数。实际公开发布前仍须检查所有材料。

模拟 SSH 服务 PID、短路径 HOME、端口与准备结果见忽略目录
`build/acp-device-validation/fixture-state.json`。仅处理该 fixture 自有 PID/文件；不操作真实开发 Agent。
完成后关闭 fixture 和本次 ADB reverse，并保留验收证据。宣传素材仍在忽略的 `promo/`，不得进入发布。
