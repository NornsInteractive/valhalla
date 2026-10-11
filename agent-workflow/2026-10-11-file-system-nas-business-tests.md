# 2026-10-11 文件 / 系统 / NAS 业务测试

范围：只做只读验证与新增测试。**没有任何生产代码被修改**（`git diff --stat -- lib/` 与开工前一致）。
未执行构建、未执行 ADB、未触碰 `terminal_keys_test.dart` 与 `app_update_service_test.dart`。

## 1. flutter analyze --no-pub 基线

开工时的 21 条问题，**全部**落在另一个人正在写的两个文件里：

| 文件 | 数量 |
| --- | --- |
| `test/core/app_update_service_test.dart` | 7 error + 1 warning + 2 info |
| `test/core/terminal_keys_test.dart` | 2 error |
| `test/core/zz_scratch_probe_test.dart` | 3 warning + 4 info |
| `lib/core/providers/app_update_provider.dart` | 1 info（`curly_braces_in_flow_control_structures`，生产但只是风格） |

生产代码（`lib/`）**零 error、零 warning**。这是我接手时的状态，如实记录。

收尾时 `lib/features/terminal/widgets/`（`shared_terminal_canvas.dart`、
`customize_pinned_keys_dialog.dart`）新增了 5 个 error——那是并行会话在我工作期间
落下的改动，不在本任务范围内，我没有触碰。

## 2. 新增测试

### 2.1 `test/infrastructure/system_service_safety_test.dart`（20 项，全绿）

用 `_RecordingSsh extends SSHClientManager` 只覆写 `executeWithLoginShell`：
命令进数组、结果按子串回放。**不会建连、不会碰任何真实主机。**

- **目录合并**：`list-units` 的实时状态 + `list-unit-files` 的开机状态合成一份 catalog；
  只出现在 unit-files 里的单元补成 `not-loaded`；结果按名字排序。
- **状态如实呈现**：`failed` 绝不被 `isRunning` 读成 true；
  `activating` / `inactive` 既不是 running 也不是 failed；
  unit-files 缺行时 startup 为 `unknown`，`isEnabled` 为 false（不猜「大概是开的」）。
- **失败分类**：exit 127 → `SERVICE_UNSUPPORTED`，stderr 含 access denied/permission →
  `SERVICE_PERMISSION_DENIED`，其余 → `SERVICE_QUERY_FAILED`；unit-files 这一步失败会让整次列举失败。
- **注入面**：`validateService` 拒绝 `nginx.service; reboot`、`$(id)`、反引号、换行、
  超长名、非 `.service`（`.slice` / `.mount` / `.target` 一律拒绝，因为目录只列 service）；
  `action` 白名单外的 `halt` / `enable --now` / `start; reboot` 在**触达 SSH 之前**就被拒
  （断言 `ssh.commands` 为空）；放行时命令形如 `systemctl restart -- 'docker@printer.service'`。
- **日志翻页**：首页不带 `--cursor=`；后续页的游标经 `cliShellQuote` 转义；
  `__CURSOR` 等于请求游标的那一行被丢掉（否则翻页会重复一条）；
  空行不进结果。
- **PID / 启动身份**：断言 journald 的 `_PID` 与 `_SYSTEMD_INVOCATION_ID` 被原样透传，
  所以 `Started`(inv-1) 与 `Started`(inv-2) 能被调用层区分开——重启才画得出来。

### 2.2 `test/core/sftp_transfer_records_test.dart`（16 项，全绿）

替身 `_FakeService` 同时实现 `SftpOperations` / `SftpEditorOperations` / `SftpResumableOperations`，
全部能力由字段驱动；**只做内存记账，不发任何真实传输**。草稿走内存版 `SecureStorageService`。

- **源身份持久化**：`onSource` 回调的身份落进 state 并写进 `saveTransferRecords`，
  读回一致；第二个任务不会继承第一个的身份。
- **恢复语义**：`fromJson` 把 `running`/`queued` 一律降级为 `paused`，
  终态 `failed` 保持不变——恢复出来不会自己跑起来。
- **目标隔离**：同 id 不同 host 的两个 profile 各读各的记录，不串。
- **显式续传**：只有 `resumeTransfer` 才推进；续传时把持久化的身份作为 `expectedSource` 传下去。
- **partial 清理**：取消上传 → `discardUploadPartial(remotePath, id)`；
  取消受管下载 → 删本地 `${localPath}.part`，且**不**产生远端清理调用。
- **安全编辑器**：保存走快照接口；只实现 `SftpOperations` 的旧服务以
  `SFTP_ATOMIC_SAVE_UNSUPPORTED` fail-closed 且**一个字节都没写**；
  目标路径不符 / 编辑器已关闭 → `SFTP_EDITOR_EXPIRED`；
  草稿生命周期覆盖「失败保留」「成功清草稿」「超过上限不落盘」。

### 2.3 `test/core/services/nas_thumbnail_scheduler_test.dart`（11 项，全绿）

`path_provider` 的 MethodChannel 在每个用例里被 mock 到本次测试的**临时目录**，
缓存读写全部发生在那儿；适配器的 `thumbnail()` 恒返回 null，
于是测试不需要 dart:ui 解码，**不碰任何 NAS 或服务器**。

- **取消**：释放最后一个 owner 不影响仍在办的任务；`dispose` 后全部以 null 收尾且不再起新任务；
  预算为 0 时在调适配器之前就短路。
- **优先级**：队列后进先出，新出现的瓦片先跑；同一格子重复请求共用一份结果，不重复取；
  在办任务数有上界（64），滑得快的列表不会把内存吃光。
- **缓存**：命中缓存不再调适配器；缓存键在 server/path/mtime/size 任一维度变化时都不同；
  用量统计只算已提交的 `.png`，中断留下的 `.part` 不计入。

## 3. 修掉一个既有失败

`test/core/sftp_provider_test.dart` 的 `write completing after a source switch does not
refresh the new server` 在我开工前就是**红的**：

```
SFTPException: SFTP_EDITOR_EXPIRED   sftp_provider.dart:1659   test/core/sftp_provider_test.dart:484
```

原因：该用例让假替身走 `saveFileContent` 并期待它成功，但 `_FakeOps` 没有实现
`SftpEditorOperations`，而生产代码对这类实现是 fail-closed 的——这条断言本来就过不了。

修法：新增 `_FakeEditorOps extends _FakeOps implements SftpEditorOperations`
（**只给这一个用例用**，不顺手把 `_FakeOps` 整体改成实现编辑接口，否则会连带改变
其它用例里 `openFileForEditing` 的读法、把它们断点一起挪走）。
用例改为先打开编辑器再保存，并断言切源后以 `SFTP_EDITOR_EXPIRED` 收场、
且没有触发新服务器的目录刷新。

**没有削弱任何原子性断言**：fail-closed 那条分支现在由
`sftp_transfer_records_test.dart` 的 `a service without SftpEditorOperations fails closed`
单独守着，且断言了「写入列表为空」+「编辑器仍开着」。

## 4. 复核中发现、但按要求**未改**源码的疑点

以下是读 `sftp_client_service.dart` / `sftp_provider.dart` 时发现的**正确性问题**，
按任务要求只报告、不实现。都不影响现有测试通过。

1. **续传身份比较用 `jsonEncode`，对 map 键序敏感**（`sftp_client_service.dart:607` 与 `:693`）。
   `expectedSource` 是上一次 `jsonEncode` 存进 SharedPreferences 的字符串，
   读回来键序一致时没问题；但身份一旦被别处构造（例如未来加字段、换平台），
   仅仅键序不同就会误判成 `SFTP_TRANSFER_SOURCE_CHANGED`，把一次合法续传判死。
   建议改成逐字段比较或比较规范化后的结构。

2. **上传目标存在性检查与 `.part` 续传之间有 TOCTOU 窗口**（`:696-701` → `:721`）。
   `stat(remotePath)` 通过后再去开 `.part`，两步之间远端若被别处创建了目标文件，
   `ln` 会失败；好在失败被转成 `SFTP_UPLOAD_COMMIT_FAILED` 且 `.part` 保留（不丢数据），
   所以不是数据安全问题，但用户会看到一次莫名其妙的失败。

3. **上传 commit 依赖宿主有 `ln`**（`:732-735`，注释已自陈这是 shortcut）。
   精简容器 / 禁用 `ln` 的环境会一路失败到底，且错误码统一成
   `SFTP_UPLOAD_COMMIT_FAILED`，与「磁盘满」「权限不足」无法区分。

4. **`_failTransfer` 把上传侧所有错误压成 `SFTP_UPLOAD_FAILED`**（`sftp_provider.dart:1132`）。
   「源文件变了」和「网络断了」在 UI 上是同一条文案，只有下载侧才有细分码。
   `SFTP_TRANSFER_SOURCE_CHANGED` / `SFTP_TRANSFER_PARTIAL_INVALID` 是可恢复性差异很大的两类，
   值得单独成码。我的用例按现状断言，没有反过来把这个行为「写死成期望」——
   注释里写明了它是当前实现而非设计意图。

5. **`clearCache` 会等在办任务收尾**（`nas_image_cache_service.dart:197`）。
   `adapter.thumbnail()` 拿不到 `NasCancellation`，所以 `clearCache` 期间
   一个慢 NAS 请求能把清空操作一直挂住。缩略图测试里如实记下了这个边界。

## 5. 验证命令

```
flutter analyze --no-pub                      # 本任务的 4 个文件 0 问题
flutter test test/infrastructure/system_service_safety_test.dart \
           test/core/sftp_transfer_records_test.dart \
           test/core/services/nas_thumbnail_scheduler_test.dart \
           test/core/sftp_provider_test.dart \
           test/infrastructure/service_manager_test.dart \
           test/infrastructure/sftp_client_service_test.dart \
           test/features/sftp_file_view_test.dart
# → All tests passed! (128)
```

新增 47 项；`sftp_provider_test.dart` 45/45（含原先失败的那一项）。