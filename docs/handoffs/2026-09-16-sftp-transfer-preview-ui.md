# Valhalla UI Handoff — 已拆分为三个切片（本文件是索引）

原先「三块合一」的 brief 已按「brief 要拆小」的经验拆成三个可独立分发的文件，
避免单次范围过大导致 agy 在大范围里打转甚至一行没写。

**按顺序派发，一次一个。** 每个切片的 Allowed files 互相排斥，不要串。

| 切片 | 文件 | 范围 | 状态 |
|---|---|---|---|
| A | `2026-09-16-sftp-file-open-download-ui.md` | `lib/features/files/` — 下载入口 + 打开前格式判断（修 bug） | ✅ 已完成 |
| B | `2026-09-16-auto-connect-settings-ui.md` | `lib/features/settings/` — 启动自动连接二选一 | ✅ 已完成 |
| C | `2026-09-16-top-layout-drawer-ui.md` | `lib/features/shell/` — 顶部布局重排 | ✅ 已完成 |

## 后端已就绪（三个切片共用的契约，均由后端侧实现并测试完毕）

- **A**：`SftpNotifier.canPreview / uploadFrom / downloadTo / clearError`、
  `SftpState.transfer`、`SftpState.isAtRoot`；
  reason code `SFTP_UPLOAD_FAILED` / `SFTP_DOWNLOAD_FAILED` /
  `SFTP_PREVIEW_UNSUPPORTED` / `SFTP_READ_FAILED`。
- **B**：`autoConnectSettingsProvider`（`AutoConnectMode.fixed / lastConnected`，
  默认 `lastConnected`）+ `setMode` / `setFixedServerId`。
  启动钩子已在 `lib/main.dart` 接好，失败静默、服务器不存在则不连。
- **C**：无新增后端契约（纯布局）。

## 派发后必做

1. `find lib/features lib/widgets -newermt "-30 minutes" -type f` 核对磁盘。
2. grep 具体标识符（ARB key / provider 名）确认真的写进去了。
3. 自己跑 `flutter analyze` + `flutter test -j 1`。

`--print` 超时（`print timeout after Nm ... returning partial output`）
**不代表做了或没做**，必须回磁盘核对。

---

## 第二批：传输列表 / 排序 / 主题快切（2026-09-16 新增）

用户的第二批需求，同样按「拆小」原则分两个批次。**本文件只记索引**，
实际 brief 见：

| 批次 | brief | 范围 | 状态 |
|---|---|---|---|
| 1 | `2026-09-16-file-sort-theme-quick-switch-ui.md` | 文件排序按钮 + 顶栏主题弹窗 | 待派发 |
| 2 | `2026-09-16-transfer-list-ui.md` | 传输列表（取消/暂停/继续/删除）+ 完成通知 | 依赖批次 1 与后端改造，稍后出 |

### 批次 1 后端契约（已实现并通过变异验证）

- **文件排序**：`SftpState.sortKey`（`SftpSortKey.name / size / date`）+
  `SftpState.sortAscending`（默认 true）。
  **排序后的列表就是既有的 `SftpState.filteredFiles`**——UI 不需要自己排，
  直接渲染它即可（它同时处理搜索过滤、目录优先、同名兜底）。
  改排序用 `SftpNotifier.setSort({required SftpSortKey key, required bool ascending})`，
  它会落盘，重启和重连都保留。
- **`SftpFileItem.modifiedEpoch`**（Unix 秒）已补上，供按时间排序。
  展示用的 `modified` 字符串保持不变，**不要拿它排序**。
- **主题持久化已修好**：`SettingsNotifier` 之前**完全不落盘**（重启即失效），
  现在 `build()` 会读存储，`setThemeMode` / `setAccentColor` / `setLocale`
  都改成 `Future<void>` 并落盘。
  **注意：这三个 setter 的签名从 `void` 变成了 `Future<void>`**，
  既有调用点如果忽略了返回值不会报错，但不要 `await` 在不该 await 的地方。
- ARB 需要新增的键见批次 1 brief。
