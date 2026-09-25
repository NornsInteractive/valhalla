# Valhalla Agent 协作工作流

这里是跨 Agent 的通用工作流资料目录。它是项目协作规则的权威来源；
Codex、Claude、Gemini、Antigravity 等工具的入口文件只负责引导 Agent 读取这里，
不要在多个入口文件中复制整套规则。

## 文档

- [通用规则](agent-development-rules.md)：职责边界、任务分流、交接和冲突处理。
- [UI 交接模板](ui-handoff-template.md)：交给 Antigravity 的任务说明格式。
- [验收清单](acceptance-checklist.md)：代码、UI、测试和真实环境验收门禁。

## 使用顺序

1. 先阅读通用规则，再判断任务属于业务、UI 还是混合任务。
2. 混合任务先由业务 Agent 完成状态、数据和服务契约，再填写 UI 交接单。
3. Antigravity 只修改交接单列出的 UI 文件；完成后报告文件清单和验证结果。
4. 发起任务的 Agent 检查 diff、运行验收清单，并更新对应的 handoff 或实现状态文档。

## Agent 入口适配

各 Agent 的原生入口可以只保留以下指向，不复制规则：

```text
开始任务前阅读 agent-workflow/README.md 和其中与任务相关的文档。
```

固定会话 ID、模型名、工作区路径和外部服务凭证属于项目运行配置，不写入通用规则。
