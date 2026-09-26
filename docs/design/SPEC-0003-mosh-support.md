# SPEC-0003: Mosh 支持 — 实施规格

状态: 待实施 | 分支: durandal | 执行: flash 代理按本规格开发与测试

## 目标

终端模块支持 Mosh 会话: 用现有 SSH 连接引导 `mosh-server`,
随后通过 UDP/SSP 长连接交互 (掉线漫游、IP 切换不断线),
输出渲染进 xterm.dart。

## 选型 (已定,勿改)

**`dart_mosh` ^0.0.4** (Apache-2.0, 依赖 pointycastle)。
理由: 纯 Dart 实现了 Mosh SSP 层 (AES-OCB、分片、压缩、protobuf、
acks、重传、resize、rehoming),且刻意不含 SSH 与终端 UI ——
这两块本项目已有 (dartssh2 / xterm.dart),架构零冲突。
备选 (Blink Shell 移植) 不采用: 移植成本远高于引入包。

## 架构

```
features/terminal/terminal_view.dart        (UI 入口: 新建 SSH / Mosh 会话)
        │
infrastructure/mosh/mosh_terminal_bridge.dart   ← 新增, 对外形状模仿 TerminalSessionBridge
        │                                        (stateListenable: connecting/connected/…)
infrastructure/mosh/mosh_session_service.dart   ← 新增, 唯一允许 import dart_mosh 的地方
        │
dartssh2 (bootstrap 执行 mosh-server new) + dart_mosh (UDP SSP)
```

**硬约束: `dart_mosh` 的类型不得泄漏到 infrastructure/mosh/ 之外**
(provider / UI 层只见我们自己的接口)。库是 0.0.4 实验版,
这层隔离保证将来可无痛替换实现。

### 1. MoshSessionService (`lib/infrastructure/mosh/mosh_session_service.dart`)

- `bootstrap(...)`: 通过现有 SSH client 执行
  `mosh-server new -p <range> [-c <256色>] ...`
  (参考 dart_mosh 的 `MoshSshBootstrap().command()` 生成,locale/UTF-8 环境变量按需注入),
  捕获 stderr/stdout 中的 `MOSH CONNECT <port> <key>` 行,
  用 `MoshServerConfig.parse` 解析。
- 错误分类枚举 `MoshBootstrapError`:
  `notInstalled` (command not found / which mosh-server 为空),
  `startFailed` (有输出但无 CONNECT 行),
  `timeout`, `sshFailed`。
- `connect(config, {required int cols, required int rows})` → 会话句柄:
  包装 `MoshSession.connect`,暴露 `stdout` (Stream<List<int>>)、
  `send(List<int>)`、`resize(cols, rows)`、`dispose()`。
- 通过 infrastructure provider 注入 SSH client (参考
  `lib/core/providers/infrastructure_providers.dart` 既有模式)。

### 2. MoshTerminalBridge (`lib/infrastructure/mosh/mosh_terminal_bridge.dart`)

- 对外接口**形状对齐** `TerminalSessionBridge` (stateListenable +
  connecting/connected/disconnected/error),使 terminal_view 以
  同样的方式消费;先读 `lib/infrastructure/terminal/terminal_session_bridge.dart`
  再动笔。
- 内部: 持有 xterm `Terminal`;
  `session.stdout → terminal.writeBytes`;`terminal.onOutput → session.send`;
  resize 联动 `session.resize`。
- 生命周期 `start()/dispose()`;断线不立即报错 —— Mosh 本身漫游重连,
  仅在会话对象终态 (server 进程退出 / 用户主动断开) 时转 error/disconnected。

### 3. ServerProfile 扩展 (`lib/data/models/server_profile.dart` + 存储)

- 新字段 (全部可缺省, 旧数据兼容):
  - `moshEnabled: bool` 默认 false
  - `moshServerPath: String?` 默认 `mosh-server`
  - `moshPortRange: String?` 默认 `60000:61000`
- 看 `lib/data/storage/local_storage_service.dart` 的既有序列化方式,
  按同样的向后兼容策略迁移 (缺字段 → 默认值, 不丢旧数据)。

### 4. UI

- `server_form_dialog.dart`: 新增 "Mosh" 配置区 (开关 + 可折叠高级项:
  server 路径 / UDP 端口范围),遵循 Norse Steel 设计系统
  (见 docs/design/REDESIGN-2026-09.md)。
- `terminal_view.dart`: 新建会话入口提供 SSH / Mosh 二选;
  Mosh 会话 tab 标识 (如标题后缀 "(mosh)" 或图标);
  bootstrap 报 `notInstalled` 时提示安装命令
  (`apt install mosh` 等),不弹异常。
- 全部 M3 组件、全部文案走 l10n、保留/新增 test key。

### 5. l10n (en + zh 成对新增, 命名 camelCase)

至少: `moshSectionTitle`, `moshEnable`, `moshServerPathLabel`,
`moshPortRangeLabel`, `moshNewSession`, `moshNotInstalled`,
`moshBootstrapFailed`, `moshUdpTimeout`, `moshSessionTag`。
改完跑 `flutter gen-l10n`。

### 6. 测试 (flash 全量执行)

- 单测 (fake SSH, 参考既有 `_FakeOperations` 模式):
  bootstrap 命令拼装 (端口范围/自定义路径)、CONNECT 行解析
  (正常/畸形/混入 ssh banner 噪声)、错误分类映射、
  bridge 状态机 (connecting→connected→dispose;
  bootstrap 失败→error 带分类)、resize 传递。
- widget 测试: server form Mosh 开关持久化;终端新建入口出现 Mosh;
  notInstalled 提示文案。
- 收尾: `flutter analyze` 零告警 + `flutter test` 全绿
  (既有 1112+ 不得回归)。

## 验收清单

- [ ] dart_mosh 类型只出现在 lib/infrastructure/mosh/ 内
- [ ] Mosh 会话完整链路可跑通 (真机验证留给用户, 测试层全绿即可)
- [ ] mosh-server 缺失 → 明确安装引导, 不崩溃
- [ ] 旧 server profile 数据无损加载
- [ ] 既有测试零回归, 新增测试全绿, analyze 干净
- [ ] 铁律: M3 组件 / 零硬编码文案 / l10n 双语 / 4 主题模式
