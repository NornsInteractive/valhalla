# AI Attribution

本仓库的开发全程由人机协作完成,此文件记录 AI 参与情况与一次
多 AI 共同作者署名 (Co-authored-by trailer) 实验。

## 开发分工

- **durandal 之前 (2026-09-13 起)**: 项目由维护者使用市面上的
  多种 AI 编码工具协作开发完成 (Claude Code、Codex、Gemini /
  Antigravity 等,接手文档与 handoffs 中可见多工具接力痕迹)。
  各阶段提交均以维护者 git 身份落盘,未逐工具标注。
- **2026-09-26 (durandal → main)**: ZCode (GLM) 完成 Norse Steel
  全量 UI 重设计、动效系统、切页闪烁修复、Mosh 支持
  (dart_mosh 集成) 与文档;flash 子代理并行执行各视图改造与测试;
  维护者负责需求决策、验收与真机验证方向。

## 共同作者署名实验

提交 trailer 收录主流 AI 编码工具的身份,作为这段多 AI 协作历史的
名单,同时观察 GitHub 对各邮箱的识别效果 (头像 / 贡献者列表):

- 第一批 (12): Claude、Codex、ChatGPT Codex、Copilot、Gemini、
  Gemini CLI、Cursor、Devin、Cline、Amazon Q、Continue、CodeRabbit
- 第二批 (4): DeepSeek、GLM (智谱)、MiMo (小米)、Grok (xAI)
- 第三批 (3): Codex (codex@openai.com, 与 noreply bot 并列的
  第二身份)、DeepSeek (service@ 邮箱)、Antigravity (google.com)

第二、三批用厂商域名邮箱而非 GitHub noreply bot 地址,
预计多数不会被识别为账号头像;最新提交共 19 个 trailer。

协议与决策背景见 [ADR-0002](docs/design/ADR-0002-a2a-wrapper-decision.md)
与 [接手文档](docs/handoffs/2026-09-26-durandal-norse-steel-redesign-and-mosh.md)。
