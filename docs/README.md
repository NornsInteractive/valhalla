# Valhalla - 研发项目全生命周期文档体系

本轮主题、网络速率、关机与快捷入口的实施契约见 [2026-09-19 交接](handoffs/2026-09-19-theme-network-power-shortcuts.md)；自动化门禁与真实服务器验收结论分别记录，不能混为已发布状态。

当前工作（2026-09-19）：[CLI、重启、容器反馈与性能 / 历史隔离设计](handoffs/2026-09-19-cli-reboot-performance.md)，真实环境验收与已验证源码必须区分。

最近接手进度（2026-09-18）：[Agent 共享与下载修复](handoffs/2026-09-18-agent-sharing-downloads.md)。本轮自动服务器归属约定取代此前手动绑定交互；请区分已验证实现、正在实施的原生桥接及后续 Drift 等目标架构。

本项目是一款基于 **Flutter** 开发的跨平台 AI-Native 远程服务器与 AI Agent 一体化管理客户端。

为了确保产品从需求、技术论证、编码开发到测试交付全生命周期具备高度的工程严密性，原单一综合设计文档已完成技术修正，并结构化拆分为以下涵盖规范铁律与四大阶段的工程文档体系：

```text
docs/
├── README.md                                         # [当前文档] 文档体系总览与工程导航
├── 项目设计文档.md                                     # 原版设计总纲（已完成6大技术暗坑修正）
│
├── 00-rules/                                         # 【最高工程规范与设计铁律】
│   ├── 01-project-engineering-rules.md               # 项目规则文档：严禁重复造轮子 / 架构约束 / 安全防线
│   └── 02-frontend-design-and-ui-rules.md            # 前端设计规则文档：100%复用组件库 / 强制多语言 / 主题与色系切换
│
├── 01-requirements/                                  # 【阶段一：需求设计阶段】
│   ├── 01-prd-product-requirements.md                # 完整产品需求规格说明书 (PRD)
│   └── 02-ui-ux-design-spec.md                       # UI/UX 规范与双端（桌面/移动）交互设计
│
├── 02-architecture/                                  # 【阶段二：技术确认阶段】
│   ├── 01-system-architecture.md                     # 系统架构设计说明书 (SAD - 含6大技术暗坑解决方案)
│   ├── 02-protocols-and-interfaces.md                # 标准协议与通信规范 (SSH/SFTP/ACP/Docker/Drift)
│   └── 03-technical-spikes-and-verification.md       # 技术选型评估与 Spike 可行性验证报告
│
├── 03-development/                                   # 【阶段三：开发实施阶段】
│   ├── 01-detailed-design-and-modules.md             # 模块划分与详细设计说明书
│   ├── 02-development-roadmap-and-tasks.md           # 敏捷路线图、里程碑与任务清单 (Tasklist)
│   └── 03-coding-standards-and-guidelines.md         # 代码规范、Riverpod 状态设计与异常处理规范
│
└── 04-testing-and-deployment/                        # 【阶段四：测试与交付阶段】
    ├── 01-testing-strategy-and-testcases.md          # 测试策略与全功能验收用例矩阵
    ├── 02-deployment-and-environment-guide.md        # 客户端跨平台编译打包与服务端环境指南
    └── 03-windows-github-actions.md                 # Windows 自动打包工作流与下载说明

另：`03-development/04-implementation-status.md` 记录当前实现基线、阶段性缺口及 Antigravity UI 协作约束。
```

---

## 各阶段文档快速导航

| 阶段 | 文档名称 | 核心关注点 | 建议读者 |
| :--- | :--- | :--- | :--- |
| **最高铁律** | [01-project-engineering-rules.md](file:///workspace/projects/valhalla/docs/00-rules/01-project-engineering-rules.md) | **严禁重复造轮子**、零服务端侵入、安全隔离、单向依赖架构 | 全体研发、Reviewer |
| **前端铁律** | [02-frontend-design-and-ui-rules.md](file:///workspace/projects/valhalla/docs/00-rules/02-frontend-design-and-ui-rules.md) | **100%使用组件库**、**全界面强制多语言化 (Zero Hardcoded String)**、**4大主题切换**、**动态主题色系切换** | 前端开发、UI/UX |
| **全景总览** | [项目设计文档.md](file:///workspace/projects/valhalla/docs/%E9%A1%B9%E7%9B%AE%E8%AE%BE%E8%AE%A1%E6%96%87%E6%A1%A3.md) | 项目全景总述、设计原则、选型对比（已集成6大修正） | 全员 |
| **需求设计** | [01-prd-product-requirements.md](file:///workspace/projects/valhalla/docs/01-requirements/01-prd-product-requirements.md) | 业务背景、用户故事、9大功能域详细规格 | 产品、开发、QA |
| **需求设计** | [02-ui-ux-design-spec.md](file:///workspace/projects/valhalla/docs/01-requirements/02-ui-ux-design-spec.md) | Material 3 规范、桌面双栏/三栏布局、移动端抽屉与辅助键栏 | UI/UX、前端开发 |
| **技术确认** | [01-system-architecture.md](file:///workspace/projects/valhalla/docs/02-architecture/01-system-architecture.md) | 5 层架构、6 大技术暗坑解决方案（Docker、ACP、PATH、Sudo 等） | 架构师、技术负责人 |
| **技术确认** | [02-protocols-and-interfaces.md](file:///workspace/projects/valhalla/docs/02-architecture/02-protocols-and-interfaces.md) | SSH/SFTP 通道、ACP JSON-RPC 消息体、Docker 解析、Drift Schema | 核心开发、接口联调 |
| **技术确认** | [03-technical-spikes-and-verification.md](file:///workspace/projects/valhalla/docs/02-architecture/03-technical-spikes-and-verification.md) | Flutter/Dart 环境验证、pub 依赖兼容性检验、Web 延迟论证 | 技术选型评估 |
| **开发实施** | [01-detailed-design-and-modules.md](file:///workspace/projects/valhalla/docs/03-development/01-detailed-design-and-modules.md) | `lib/` 源码目录划分、各 Feature / Infrastructure 详细类设计 | 开发工程师 |
| **开发实施** | [02-development-roadmap-and-tasks.md](file:///workspace/projects/valhalla/docs/03-development/02-development-roadmap-and-tasks.md) | MVP 第一期～后续演进里程碑、详细任务清单与验收标准 | 项目经理、敏捷团队 |
| **开发实施** | [03-coding-standards-and-guidelines.md](file:///workspace/projects/valhalla/docs/03-development/03-coding-standards-and-guidelines.md) | Dart 编码风格、Riverpod 不可变状态约束、异常模型 | 开发工程师、Code Reviewer |
| **测试交付** | [01-testing-strategy-and-testcases.md](file:///workspace/projects/valhalla/docs/04-testing-and-deployment/01-testing-strategy-and-testcases.md) | 单元测试、Mock SSH/ACP 联调测试、验收用例矩阵 (TC-01~N) | QA、测试开发 |
| **测试交付** | [02-deployment-and-environment-guide.md](file:///workspace/projects/valhalla/docs/04-testing-and-deployment/02-deployment-and-environment-guide.md) | Android/Windows/Linux 打包流水线、服务端最低权限配置 | 运维、发布工程师 |
| **Windows 构建** | [03-windows-github-actions.md](04-testing-and-deployment/03-windows-github-actions.md) | Actions 自动/手动打包、完整 ZIP 下载与运行 | 开发、发布、用户 |

---

## 核心设计与工程决策总览

1. **绝对严禁重复造轮子**：所有底层协议与通用基础能力（SSH、SFTP、ACP、Docker、SQLite、xterm、Markdown、语法高亮、文件选择器）严格使用选定工业级 SDK，禁止自研私有协议或重写已存在的公共工具。
2. **UI 100% 严格使用组件库**：基础 UI 必须全部使用 Flutter Material 3 官方组件库；终端使用 `xterm.dart`；Markdown 使用 `flutter_markdown_plus`；禁止私下使用 `Container` + `GestureDetector` 手写基础按钮/输入框。
3. **全界面强制多语言化（Zero Hardcoded String）**：任何需要呈现在界面上的文字（标题、正文、按钮、Tooltip、Placeholder、SnackBar、错误提示、枚举文本）一律通过官方 `l10n` / ARB 资源字典管理，严禁在 Dart 代码中硬编码中英文字符串。
4. **支持全场景主题模式与动态主题色切换**：支持跟随系统、明亮、深色、AMOLED 纯黑四大主题模式；深度应用 M3 `ColorScheme.fromSeed`，支持科技蓝、极客绿、优雅紫、活力红、温暖橙及自定义种子色切换。
5. **服务端零专有 Daemon 侵入**：远端 Linux 服务器无需安装专有后台服务或中间件，完全复用既有的 SSH Server 和用户本地安装的 Agent CLI（Claude Code / Codex / OpenCode）。
6. **架构边界清晰解耦**：
   `UI (Material 3) -> State (Riverpod) -> Service/Repository -> Infrastructure (dartssh2 / acpd / xterm / drift)`
   禁止 Widget 越级直连底层网络通道。
