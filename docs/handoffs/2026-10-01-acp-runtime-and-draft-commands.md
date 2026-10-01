# ACP运行时与草稿命令交接（2026-10-01）

## 实现边界

标准Codex ACP在所选服务器/容器用户内解析配置的CLI，并通过CODEX_PATH使用
同一可执行文件；诊断记录路径和版本，缺失明确失败，自定义启动脚本不改。
这修复已证实的CLI与适配器内置Codex版本不一致，不保证账号支持任意手动模型名。

initialize确认codex-acp 2.0.0后，草稿可显示该版本已核实的兼容命令预览；
未知版本不伪造目录，真实命令通知（含空列表）优先。技能独立查询，失败保留命令。
菜单不创建会话，选项只插入输入框，发送时才创建并直接执行，无普通对话垫底。
预览并非实时无会话ACP命令接口。UI由原AgY Valhalla/Gemini3.8Flash High完成。

## 交付证据

OpenCode主/辅助模型均为 `opencode/mimo-v2.6-flash-free`：专项160、控件15、
恢复/历史23项通过；全量1631通过、17既有环境跳过、0失败；静态分析零问题。
旧夹具只补实际CLI启动身份，未跳过或放宽断言。

- APK：`build/app/outputs/flutter-apk/app-release.apk`，123288495字节。
- mtime：2026-10-01 14:57:42 UTC（22:57:42 +0800）。
- SHA-256：`e7efc0ce52f1466a92c31e79c05e8d716c2a8c2c8c1263203d2491be140dd34b`。
- 版本1.0.0+1，release构建、现有Android Debug签名，非商店签名。
- 旧包备份：`build/apk-backup/app-release-prev-20261001-225532.apk`。
- ADB设备：127.0.0.1:14251，覆盖安装成功；无卸载/清数据。
- 冷启动成功、PID16448存活、MainActivity前台；有限日志检查无fatal/ANR。

## 用户验收

在用户宿主机/Docker所选用户上确认检测日志的Codex路径/版本，并测试原失败
模型和草稿首发斜杠命令。自动化使用隔离模拟，未发送真实推理、未读写登录凭据、
未修改真实Codex历史；不可将这些检查表述为真实远端会话已通过。没有提交或推送。
详细命令及阶段失败/修正记录见
[验证报告](../../agent-workflow/acp-runtime-draft-commands-verification.md)。
