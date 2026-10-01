# ACP 可用性第二轮（自动化验收与安装完成，真实ACP待用户验收）

用户批准十项计划；严格只通过 ACP 获取模型/命令/skills/账号/额度。
额度无结构化接口时，仅用户点击后发送已声明的 `/status`，保留会话记录。
不调用 CLI 账号接口、不升级远端、不对真实 Codex 发送测试消息。
旧历史保留，重新导入为副本。默认导航以 ACP 替换 CLI，自定义及空列表保留。

## 分工和禁止事项

- 主 Agent：core/data/infrastructure 与文档。不得修改展示层。
- AgY：仅 `lib/features/chat/**`、`lib/widgets/**`、`lib/l10n/*.arb`。
  必须历史 Valhalla `ec81a4be-7543-45ee-8658-f68966f57d3b`，
  `gemini-3.8-flash-high`、high；保留已有改动，不执行验证/构建。
- OpenCode：原 `opencode/mimo-v2.6-flash-free` 限流，用户已允许切换到经核验免费的
  OpenCode 模型（本轮候选 `opencode/space-bunny-free`，目录 input/output/cache 均0），测试维护、格式化、生成、分析、
  构建及指定 ADB 设备覆盖安装。不得卸载/清数据，不改 UI 语义。
- 不提交、不推送、不接管任何真实 Agent 会话。

## 业务接口（本轮主 Agent 实现，UI 按此接入）

- `AiChatState.account`：`AcpAccountInfo?`，字段 `kind,label,email,plan,updatedAt`。
  `settingsFetchedAt`、`settingsStale`、`agentVersion`。
- `AiChatState.accountStatusText` / `accountStatusFetchedAt`：用户主动 `/status`
  返回的原文及获取时间（只读渲染，不从 token 推算额度）。
- `AiChatNotifier.queryAccountStatus()`：显式点击执行；无已建立会话/忙碌/无声明
  status 命令时抛明确错误，不能偷偷创建会话。
- `AcpSlashCommand.isSkill` / `insertion`：保留 `$skill`，普通命令 `/name`。
- `prepareRunSettings(refresh:true)`：已有会话获取最新配置；草稿仅 initialize，
  不 session/new。空清单显示首次发送后可用。
- `ChatMessage.attachments: List<ChatAttachment>`，附件字段
  `id,name,mimeType,sizeBytes,localPath,uri`，`isImage`；可选字段兼容旧 JSON。
  `AcpPromptAttachment.localPath` 可选（草稿可用 bytes 预览）。
- `resolveWorkspaceDirectory()` 返回真实默认绝对路径；
  `listWorkspaceFiles(String path)` 返回 `List<SftpFileItem>`；
  `attachRemoteFile(String path)` 根据类型有界读取；
  `remoteImagePreview(SftpFileItem item)` 返回 `Future<Uint8List?>`；
  `cancelWorkspaceBrowse()` 取消旧浏览读取。列表由 UI 虚拟化，预览仅可见项加载。
- `openRemoteSession(remote, reimport: true)`：新副本，不覆盖原记录。

## AgY UI 交付范围

1. 输入框空白/短文本单行，hintMaxLines:1，最多4行；不要靠缩小可访问字号。
2. 设置打开自动刷新已有会话，显示获取时间、Agent版本、过期状态；草稿不预建会话。
3. 历史按实际 user/assistant/system 渲染，system 中性；远端列表增加重新导入副本入口。
4. 输入区域增加可搜索命令/技能面板，分类来自 isSkill，选中插入 insertion，不发送。
5. “账号与额度”替换旧标题；账号、订阅、额度、重置时间、最近获取时间；未提供明确提示。
   ACP扩展支持的账号显示结构化字段；额度 /status 原文区说明源/时间，不伪造结构化数字。
   提供显式查询按钮及忙碌禁用；诊断保留折叠区、复制脱敏日志。
6. 默认导航由主 Agent 修改，不在 UI 重写配置。
7. 会话尾部一个更多菜单，含重命名、导出、删除、默认设置；删除保留确认。
8. 工作目录不可把“默认(/)”传作路径。打开自动 resolve，POSIX parent，根目录禁上级。
9. 草稿/已发送附件：图片 contain 完整比例+点击缩放；文件卡片名/类型/大小，不显示内容。
   历史图片使用文件路径惰性解码；缓存失效明确显示缺失，不能崩溃。
10. 远端文件改浏览选择器，列表/卡片/图片网格，独立搜索，多选确认；换目录清筛选；
    只列目录和文件，根目录无..，不列.。工作目录选择复用文件浏览的目录模式。
    预览调用 provider，Widget 禁止 SSH/数据库；dispose/导航调用取消，丢弃迟到响应。

沿用当前主题/token/Material控件，窄屏、大字体、键盘不溢出；英中文案完整。

## 验证清单

多Agent角色/ID分片与同角色不同ID、无ID旧回放、资源/图片、重新导入副本失败；
模型更新/刷新失败/草稿不新建、命令skills前缀/账号推送及手动status；
附件序列化/限额/损坏图片、目标隔离/路径特殊字符/根目录/取消；
默认导航迁移和自定义保留；UI小屏/多语言/单行/三视图/更多菜单；
最终全量测试、分析、release构建、SHA256/时间/签名、ADB install -r与冷启动。

## 当前验证状态

OpenCode（`opencode/space-bunny-free`）最终全量测试：
1305 passed / 17 skipped / 0 failed；新控件36项通过，全量analyze和diff检查通过。
AgY完成全部UI，主Agent未修改展示层。OpenCode已生成并ADB覆盖安装本轮release：
`build/app/outputs/flutter-apk/app-release.apk`，122747763字节，
2026-09-30 11:59:08 UTC，SHA256
`26e21334399485fe948caba51d1ec57a8677a84f8129d2287fbc43fd4110219a`。
目标127.0.0.1:14251，install -r于11:59:57 UTC成功，12:00:08 UTC冷启动、PID23648存活。
未卸载/清数据；沿用Android Debug签名，非商店签名。真实ACP/真机体验待用户验收。
详证见[本轮报告](../../agent-workflow/acp-usability-release.md)。

最后 UI 收尾（AgY 原 Valhalla 会话完成并正常退出，已纳入最终构建）：
- 账号额度标题/查询按钮换行；设置底部动作使用 OverflowBar。
- 图片使用 ResizeImagePolicy.fit 同时约束宽高，草稿走 bytes，历史走私有文件。
- 设置 mode 下拉折叠态 selectedItemBuilder 单行，避免实际主题 2 倍字体 0.4px 溢出；
  展开列表仍保留描述。320/360/411dp、最高2倍字体的正式回归全部通过，
  真实设备系统字体效果待用户复验。最后补测不改生产源码，APK哈希与安装证据不变。
- 临时诊断探针已移除；正式控件测试不忽略 FlutterError，不扩大skip。

### OpenCode 首轮复核后的处置

- 已修复：斜杠命令保持原始前缀且不把未发送的上下文标为已同步；
  设置刷新失败只回退设置字段，不覆盖期间的草稿/会话列表；
  findRemoteSession 等待写队列；取消后的迟到预览丢弃；损坏/超限历史附件保留占位；
  附件 JSON 字段缺失容错；超限 prompt 不预建会话；不重复发送已知不支持的 resume。
- 不采纳启动页自动迁移：启动页是用户独立选择，不应借导航默认变更覆盖。
  新安装默认启动 dashboard，并非 CLI；自定义 cliChat 启动页保留。
- 账号扩展要求 capability 声明是有意限制；不猜测不支持扩展的 Agent。
- 本地附件 addAttachment 已复查聚合字节上限，文件并发增长不会绕过限制。
- 上述修复已纳入本轮回归及新APK，旧首轮缺陷报告保留发现过程，不覆盖最终证据。
- 补充修复：草稿 initialize 成功记录能力获取时间并清除过期标记；
  模型清单仍为空，不伪造、不偷偷 session/new。测试应验证期望行为，
  不把已确认缺陷（如草稿刚刷新仍过期）固化为通过断言。
