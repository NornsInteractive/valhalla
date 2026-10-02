# 2026-09-26 接手文档: Norse Steel 全量 UI 重设计 + Mosh 支持

状态: 已完成并合入 `main` (重设计前的原始代码存档于 `OldBranch` 分支)。
本文档面向后续接手的开发者/Agent,记录本轮全部变更、决策依据、
契约与未验证事项。

---

## 1. 变更总览

| 工作流 | 提交 | 内容 |
|---|---|---|
| UI 全量重设计 | (已并入 main 历史) | 设计系统 + 主题重建 + 全部视图改造 |
| 切标签闪烁修复 | `f184ecd` | AnimatedIndexedStack 常驻转场链 |
| a2a-wrapper 决策 | `250bb86` | ADR-0002: 不引入、不替代 |
| Mosh Phase 1 | `250bb86` | SSP 基础设施 (dart_mosh) + 27 单测 |
| Mosh Phase 2 | `f11ddce` | Profile 字段 + 表单/终端 UI + l10n + 14 测试 |

质量基线: `flutter analyze` 零告警;`flutter test` **1153 通过 / 18 跳过 / 0 失败**
(基线 1112)。工具链升级到 Flutter 3.47.5 (Dart 3.10),`intl` 0.20.3。

---

## 2. 设计系统 "Norse Steel" (`lib/core/design/`)

新代码必须使用这套系统,禁止回退到裸样式:

- `tokens.dart` — 圆角体系锁定 (`VRadius`: 输入/按钮 12、卡片 16、
  大卡/弹窗 20、底部弹层 24、胶囊 999;装饰性小方块可用 8);
  间距 `VSpace`;语义状态色 `context.vSuccess/vInfo/vWarning/vDanger`
  (亮度自适应,不随种子色漂移);`monoTextStyle()` (数字/主机/路径/命令);
  `vElevation()` 冷调阴影。
- `motion.dart` — 时间/曲线/弹簧令牌 (`VTiming/VCurves/VSpring`);
  `vStaggerDelay(index)` 交错步长 42ms、上限 12 档。
- `motion_widgets.dart` — 全部内置"减少动态效果"与测试环境闸门:
  - `Entrance` 一次性入场 (fade+slide+微缩放),列表项 >12 个不要包;
  - `AnimatedIndexedStack` 保活页面转场 (见 §3);
  - `PressableScale` 按压反馈 (ValhallaCard 传 onTap 时自动带);
  - `PulseDot` 语义状态点 (只用于真实状态);
  - `CountUp` / `AnimatedProgressBar` / `AnimatedRingProgress` 指标动效;
  - `Shimmer`/`SkeletonBox`/`SkeletonListTile`/`SkeletonMetricGrid` 骨架屏
    (loading 一律骨架,不再转圈)。
- `lib/app/theme.dart` — 全组件 M3 主题 (按钮/输入/弹窗/弹层/芯片/
  导航/SnackBar/Tooltip),钢灰表面阶梯 + 单一种子色强调。
  表面阶梯在 `AppTheme` 常量区,改色先读注释。
- 字体: **Inter + JetBrains Mono 已打包** (`assets/fonts/`,
  pubspec 注册)。JetBrains Mono 用于数字/主机/路径/代码。

完整规则与验收清单: `docs/design/REDESIGN-2026-09.md`。

### 硬约束 (违反即返工)

1. 状态色禁止硬编码 (`0xFF10B981`/`Colors.red` 等) → 语义色扩展。
2. 圆角禁止游离值 (4/6 出现在容器层级) → `VRadius`。
3. 界面文字零硬编码 → `context.l10n.*`, en/zh ARB 成对新增后
   `flutter gen-l10n`。
4. 测试 Key 是契约,重构原样搬运。
5. 无限循环动画 (PulseDot/Shimmer) 已内置测试环境闸门
   (`_loopingAnimationsSuspended`), 新增循环动画必须走同样模式,
   否则 `pumpAndSettle` 测试会挂。

---

## 3. 关键修复: AnimatedIndexedStack 常驻转场链

壳层切页用 `AnimatedIndexedStack` (保活 + 转场)。曾有缺陷:
转场包装与裸子页之间 widget 类型切换导致 Flutter 每次切页拆掉重建
页面 Element → 状态丢失 + 入场动画重放 (切标签闪烁)。

现行实现: 每页永远经历同一串
`Offstage > TickerMode > FadeTransition > SlideTransition > ExcludeSemantics`,
切页只翻转属性值。**修改壳层或新增页面宿主时必须维持这个不变量**;
回归测试: `test/core/animated_indexed_stack_test.dart`
(三页来回切换 build 计数恒为 1)。

---

## 4. a2a-wrapper 评估结论 (ADR-0002)

[shashikanth-gs/a2a-wrapper](https://github.com/shashikanth-gs/a2a-wrapper)
(TS/Node, 把 Claude Code/Codex/OpenCode 包装成 A2A HTTP 服务)
**不引入、不替代** CLI 智能会话。核心论据:

1. 要求服务器部署常驻 Node 服务并开 HTTP 端口,违背 PRD
   "零服务端改造" 铁律 (现有方案: Codex 走 SSH stdio JSON-RPC,
   OpenCode 走 SSH 本地端口转发,零暴露);
2. 不读写官方 CLI 原生历史,验收契约无法满足;
3. 丢失手机端真实终端审批交互;
4. 协议栈重复 (已有 ACP + CLI 原生接口)。

详见 `docs/design/ADR-0002-a2a-wrapper-decision.md`,内含两个 ACP
协议的术语澄清 (IBM/BeeAI 的 Agent Communication Protocol 已于
2025-08 并入 A2A;本项目用的是 Zed 的 Agent Client Protocol,仍在
活跃开发,暴露面被隔离在 `acp_client_adapter.dart`)。

---

## 5. Mosh 支持 (已完成, 待真机验收)

用户开启 Mosh 后,终端经 UDP/SSP 连接 mosh-server
(掉线漫游、IP 切换不断线)。选型 `dart_mosh ^0.0.4` (Apache-2.0,
纯 Dart SSP 层: AES-OCB/分片/压缩/重传/rehoming),刻意不含 SSH 与
终端 UI —— 与本项目的 dartssh2 + xterm.dart 零冲突。

### 分层与隔离

```
terminal_view ── terminal_provider (addMoshTab)
      └─ MoshBridgeAdapter (extends TerminalSessionBridge, 复用全部终端管线)
            └─ MoshTerminalBridge (stateListenable 状态机 + xterm 接线)
                  └─ MoshSessionService (bootstrap + connect, 唯一 import dart_mosh 处)
```

**`dart_mosh` 类型不得泄漏出 `lib/infrastructure/mosh/`** —— 库是
0.0.4 实验版,这层隔离保证可无痛替换实现。

### 关键实现事实 (改动前必读)

- bootstrap 用裸 `SSHClient.execute` 通道流式读取,收到
  `MOSH CONNECT` 行后**立即销毁通道** —— mosh-server 前台驻留,
  缓冲式读取会死锁;mosh 忽略 SIGHUP 继续服务 UDP。
- dartssh2 的 `SSHChannel.done` 不会以错误完成 (4.1.0 源码验证),
  通道死亡表现为 `exitCode == null` → 分类 sshFailed。
- `session.done` 必须在 exec 后立即接管监听,否则裸 Future 未处理
  异常会崩 (单测已覆盖此坑)。
- `MoshBridgeAdapter.rebind` 是 no-op: mosh 漫游独立于 SSH,
  SSH 重连不应 rebind mosh 会话。

### 用户可见行为

- `ServerProfile` 新字段: `moshEnabled` (默认 false)、
  `moshServerPath` (默认 `mosh-server`)、`moshPortRange`
  (默认 `60000:61000`);旧 JSON 无损加载;
  `hasSameConnectionSettings` 不含 mosh 字段 (切换不强制重连 SSH)。
- 服务器表单: "Mosh" 分区 (开关 + 可折叠高级项),
  测试键 `server_mosh_switch` / `server_mosh_path_field` /
  `server_mosh_port_range_field`。
- 终端页: 服务器开启 Mosh 后出现新建 Mosh 会话按钮
  (键 `terminal_new_mosh_tab`,标题带 l10n `moshSessionTag` 后缀);
  bootstrap 失败显示分级提示条 (键 `terminalMoshErrorNotice`),
  `notInstalled` 附安装命令 (apt/dnf)。
- l10n: `mosh*` 9 键 (en/zh),`@moshBootstrapFailed` 占位符元数据
  两个 ARB 都要有 (l10n parity 测试强制)。

### 未验证事项 (接手者注意)

- ~~真实服务器 UDP 数据面~~ **已于 2026-09-26 在真实 mosh-server 1.4.0
  (WSL Ubuntu) 上验证通过**: bootstrap → locale 自动回退 (C.utf8) →
  UDP SSP 握手 → AES-OCB → 终端回显, 全链路 OK。真机 e2e 测试:
  `test/infrastructure/mosh/mosh_e2e_manual_test.dart`
  (`VALHALLA_MOSH_E2E=1` 开启, 默认跳过)。
- **locale 协商已修复** (commit 42c01e2): bootstrap 不再写死
  en_US.UTF-8; 服务器拒绝时经 `locale -a` 探测并按优先级回退
  (C.UTF-8 优先)。此前这是 "mosh 失效" 的实锤根因 (mosh-server 在
  无该 locale 的服务器上拒绝启动, Debian 精简镜像/Docker/WSL 命中)。
- 剩余待真机验收: 弱网下 dart_mosh 0.0.4 的 rehoming/resize 表现;
  断网重连漫游 (设计上由 mosh 自身保证)。
- iOS/macOS 构建未验证 (本轮只出了 Android APK + 全量测试)。

---

## 6. 分支结构变更

- `main` = 重设计后全部代码 (快进合并, 历史完整);
- `OldBranch` = 重设计前快照 (`551277a`);
- `durandal` 分支已删除 (内容并入 main)。

---

## 7. 已知遗留与建议后续

1. 服务器表单等少数界面仍有**预存在的硬编码中英文案**
   (早于本轮, 违反零硬编码铁律, 本轮未清);建议后续专项清理。
2. Settings 里个别条目 l10n 回退显示中文 (同上, 属既有债务)。
3. `dart_mosh` 升级跟踪: 作者若发 0.1.x, 关注 rehoming API 变化。
4. 桌面端 (Windows) 的 rail 布局视觉只过了组件主题与测试,
   未截图走查;有需要可按 docs/design/REDESIGN-2026-09.md 验收清单补。
5. 发布签名: release APK 目前用 debug keystore 签名, 上架前需配正式签名。
