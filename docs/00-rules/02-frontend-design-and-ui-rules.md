# Valhalla - 前端设计规范与 UI 组件规则

## 2026-10-03 ACP 浏览器登录交互

AgY 管理入口必须区分 CLI 登录与 ACP 登录。ACP 卡片就近显示认证方式、
等待进度、取消与局部错误，避免顶部重复错误；点击登录后立即启动认证，
收到官方授权链接后只打开一次系统浏览器，提供重开、复制及手动回调兜底。
浏览器打不开不能静默失败；不能展示或记录授权码。导航返回后待认证轮次
须保留可操作入口，不能只剩等待标签。授权成功保留原消息及草稿，发送由
用户决定。展示仅由原 AgY Valhalla / Gemini3.8Flash High 修改，验证交由
OpenCode；设计目标与实际验证结果分别记录。

手动回调输入须遮蔽显示，提交/取消清空敏感字段；自持控制器不能在弹窗
`popped` 后立即释放，应由控件在卸载时释放或等待标准 `DialogRoute.completed`。
草稿认证卡片须有高度约束并可滚动，输入工具行的工作目录在窄屏/大字号下
使用正确的外层和内层 Flex 收缩及省略，保留按钮，不通过降低系统字号、
裁掉内容或放宽测试隐藏溢出。320dp/两倍字号作为本轮控件验收条件。

## 2026-10-02 连接状态与消息布局增量

同目标的重连、同步、恢复不完整/失败统一在 Shell 顶部状态区显示，点击
查看详情和重试，不在各页面叠加恢复横幅或用离线页替换缓存数据。
远端执行按钮离线禁用；本地阅读、草稿编辑和复制仍可用。上下文丢失确认
不能随告警迁移而消失，真实操作/对话错误继续留在所属区域。
新助手消息按 `orderedContentBlocks` 交错显示文本与工具；文本 key 使用
messageId+start，不使用随流增长的 end，工具 key 使用稳定 toolId。
保留全文复制、选中文字、附件、计划和审批，不猜测旧历史顺序。
实际展示修改只能由原 AgY Valhalla / Gemini3.8Flash High 完成；本轮契约
见[交接文档](../../agent-workflow/2026-10-02-acp-and-reconnect.md)。

| 文档版本 | 制定日期 | 适用范围 | 效力级别 |
| :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-09-13 | 前端开发 / UI 组件设计 / 国际化实施 | **强制执行 (Mandatory)** |

---

## 1. 核心前端准则总览

Valhalla 前端架构确立以下四大铁律：
1. **UI 组件 100% 依赖标准组件库**：拒绝重复发明基础 UI，全部复用 Flutter Material 3 官方组件与行业权威专用组件。
2. **全界面强制多语言化（Zero Hardcoded String）**：任何呈现在界面上的文字必须经过多语言资源管理（ARB），严禁任何写死文本。
3. **支持全场景主题模式切换**：系统跟随 (System)、明亮 (Light)、深色 (Dark)、纯黑极客模式 (AMOLED Black)。
4. **支持动态主题色（Seed Color）切换**：基于 Material 3 色彩算法，支持全域主色系自适应变换。

---

## 2. 规则一：UI 必须 100% 取自 UI 组件库 (Strict Component Reuse)

### 2.1 官方 Material 3 基础组件强制使用清单
严禁自行实现基础容器、输入框或按钮。全部使用 Flutter Material 3 规范组件：

| 场景 | 强制使用 Material 3 组件 | 严禁行为 |
| :--- | :--- | :--- |
| **页面骨架** | `Scaffold`, `AppBar`, `NavigationRail`, `NavigationBar` | 严禁手写固定宽高的自定义导航条容器 |
| **按钮体系** | `FilledButton`, `OutlinedButton`, `TextButton`, `IconButton` | 严禁使用 `Container` + `GestureDetector` 手捏按钮 |
| **输入与表单**| `TextField`, `TextFormField`, `DropdownMenu`, `Switch`, `Checkbox` | 严禁自定义手写无无障碍支持的输入控件 |
| **弹窗与覆盖**| `AlertDialog`, `showModalBottomSheet`, `showDialog` | 严禁使用全屏 `Stack` 模拟自定义弹层 |
| **列表与容器**| `ListView`, `GridView`, `Card`, `ListTile`, `ExpansionTile` | 严禁重复手写无按压水波纹（InkWell）的列表项 |
| **状态与指示**| `LinearProgressIndicator`, `CircularProgressIndicator`, `Badge`, `Chip` | 严禁自绘无主题自适应的徽标或加载圈 |
| **反馈提示** | `SnackBar`, `Tooltip`, `SimpleDialog` | 严禁手写浮动 Toast 弹窗框架 |

### 2.2 专用领域成熟组件清单
* **SSH 终端视图**：强制使用 `xterm.dart` 官方 `TerminalView`，自带 60fps Canvas 硬件加速。
* **Markdown 富文本**：强制使用 `flutter_markdown_plus`，自带 GFM 表格、代码块高亮与超链接交互。
* **代码编辑器**：强制使用 `syntax_highlight` 或成熟成熟的 TextMate 高亮编辑器。

### 2.3 共享复合业务组件封装规范 (`widgets/`)
如需组合复杂业务卡片，必须且仅能在 `lib/widgets/` 中进行二次组合封装，统一遵循设计系统：
* `ValhallaCard`：基于 M3 `Card` 封装的统一卡片，自带圆角与层级标线；
* `StatusBadge`：基于 M3 `Badge` / `Chip` 封装的在线/离线/运行中指示灯；
* `DangerConfirmDialog`：基于 M3 `AlertDialog` 封装的高危红色警示弹窗；
* `TerminalAccessoryBar`：基于 M3 规范按键封装的移动端辅助键工具栏。

---

## 3. 规则二：全界面强制多语言化 (Strict Localization - i18n & l10n)

### 3.1 零硬编码文本红线 (Zero Hardcoded String Policy)
> **铁律：任何呈现在用户界面（UI）上的文字，严禁在 Dart 代码中出现纯字符串硬编码！**

包括且不限于：
* 页面标题、导航 Tab 标签、操作按钮文案；
* 对话框标题、确认/取消按钮、提示正文；
* 列表空状态文案（如 "暂无运行中的容器"）；
* 输入框的 `hintText`、`labelText`、`errorText`；
* `Tooltip` 悬浮提示文案；
* `SnackBar` 成功、告警、失败弹窗文案；
* 枚举类型的显示名称（如容器状态、连接状态）。

### 3.2 官方 ARB 驱动方案配置
采用 Flutter 官方原生推荐的 `flutter_localizations` + `intl` + `.arb` 方案。

在项目根目录设立 `l10n.yaml`：
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

### 3.3 多语言文件组织与首发支持
在 `lib/l10n/` 目录下维护：
* `app_en.arb`：美式英语（基准模板文件）；
* `app_zh.arb`：简体中文（100% 对齐模板）；
* 后续扩展只需新增 `app_ja.arb`, `app_de.arb` 等。

#### 示例 ARB 规范：
```json
// lib/l10n/app_en.arb
{
  "@@locale": "en",
  "appName": "Valhalla",
  "serverListTitle": "Servers",
  "connect": "Connect",
  "disconnect": "Disconnect",
  "containerCount": "{count, plural, =0{No containers} =1{1 container} other{{count} containers}}",
  "@containerCount": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "permissionRequestedTitle": "Permission Required",
  "confirmDangerousCommand": "This operation is irreversible. Are you sure you want to proceed?"
}
```

```json
// lib/l10n/app_zh.arb
{
  "@@locale": "zh",
  "appName": "Valhalla",
  "serverListTitle": "服务器列表",
  "connect": "连接",
  "disconnect": "断开连接",
  "containerCount": "{count} 个容器",
  "permissionRequestedTitle": "权限审批请求",
  "confirmDangerousCommand": "此操作不可逆，确定继续执行吗？"
}
```

### 3.4 消费调用语法糖扩展
统一在 `core/extensions/context_extensions.dart` 封装 BuildContext 语法糖：
```dart
extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

// 界面调用示例（严格规范）:
Text(context.l10n.serverListTitle)
FilledButton(
  onPressed: () => ...,
  child: Text(context.l10n.connect),
)
```

---

## 4. 规则三：主题模式切换 (Theme Mode Switching)

系统提供 4 种独立的主题模式，由全局 Riverpod `ThemeModeNotifier` 托管，支持实时无重启热切换并持久化：

```text
┌─────────────────────────────────────────────────────────────┐
│                       Theme Mode Matrix                     │
├─────────────────┬─────────────────┬─────────────────────────┤
│ 模式标识         │ 描述            │ 适用特性                │
├─────────────────┼─────────────────┼─────────────────────────┤
│ System          │ 跟随操作系统    │ 自动根据系统白天/黑夜切换│
│ Light           │ 浅色明亮模式    │ 适宜户外高光照环境      │
│ Dark            │ 经典深色模式    │ M3 标配低对比度暗色 (#121316)│
│ AMOLED Black    │ 纯黑极客模式    │ 纯黑底色 (#000000)，OLED 极致省电│
└─────────────────┴─────────────────┴─────────────────────────┘
```

### 4.1 终端与代码区的主题联动
* 当全局切换为浅色主题时，代码高亮与终端视图自动切换为浅色高亮方案（如 Github Light）；
* 当全局切换为深色或 AMOLED 纯黑时，终端自动应用 TrueColor 暗黑终端预设（如 OneDark / Monokai），禁止出现亮暗反差刺眼的不协调。

---

## 5. 规则四：主题色（种子色 Seed Color）切换机制

深度依托 Material 3 的 `ColorScheme.fromSeed()` 算法，保证无论用户选择何种品牌主色，生成的次级色、容器色、表面色均符合 WCAG 2.1 AA 级对比度无障碍标准。

### 5.1 预设主题色系矩阵

```text
┌──────────────────┬──────────────┬───────────────────────────┐
│ 色系名称         │ 十六进制色值 │ 视觉定位                  │
├──────────────────┼──────────────┼───────────────────────────┤
│ 科技深蓝 (Default)│ #2563EB      │ 严谨、专业、开发者友好    │
│ 极客翠绿 (Emerald)│ #10B981      │ 终端感、活力、轻快        │
│ 优雅深紫 (Violet) │ #7C3AED      │ 现代、AI 智能化象征       │
│ 活力绯红 (Crimson)│ #E11D48      │ 热情、高对比度            │
│ 温暖明橙 (Amber)  │ #D97706      │ 醒目、温和                │
│ 自定义色 (Custom) │ 用户任选 Hex │ 满足用户个性化定制        │
└──────────────────┴──────────────┴───────────────────────────┘
```

### 5.2 状态色彩语义一致性
不管 Seed Color 如何切换，语义化状态色保持全工程统一定义：
* `success`: `#10B981` (正常/在线/已完成)
* `info`: `#0EA5E9` (运行中/通知)
* `warning`: `#F59E0B` (警告/待审批/暂停)
* `error`: `#EF4444` (失败/断开/错误/高危)

---

## 6. 规则五：响应式排版与布局防溢出 (Layout Integrity)

1. **绝对禁止黄黑相间的溢出条 (RenderFlex Overflow)**：
   * 所有在 `Row` 中横向展示的不定长文本，必须包裹在 `Expanded` 或 `Flexible` 中；
   * 必须明确指定 `overflow: TextOverflow.ellipsis` 和 `maxLines`，确保在小屏或多语言文本长度膨胀时自动省略或折行。
2. **多语言长度兼容原则**：
   * 德语、俄语等语言往往比英语长 30%~50%，中文通常更短。布局宽度严禁写死绝对像素（如 `width: 80`）。按钮宽度必须自适应文本或采用 M3 规范弹性间距。
3. **断点适配规范**：
   * 移动端（`<600dp`）：底部导航 `NavigationBar`，卡片单列全宽；
   * 平板端（`600~1024dp`）：折叠式 `NavigationRail`；
   * 桌面端（`>1024dp`）：展开式 `NavigationRail`，支持多栏并列与拖拽微调分栏。
