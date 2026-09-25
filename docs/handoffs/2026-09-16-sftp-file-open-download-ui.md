# Valhalla UI Handoff — 远程文件：下载入口 + 打开前格式判断（切片 A of 3）

后端契约与业务逻辑**已经实现并测试完毕**。本切片只包含**界面层**工作。
**不要改 `lib/core/`**。

> 本轮共三个切片，本文件是 **A**：
> - **A（本文件）** 远程文件页：下载入口 + 打开前格式判断 ← 本轮重点，修 bug
> - B 设置页「启动自动连接」二选一 → `2026-09-16-auto-connect-settings-ui.md`
> - C 顶部布局重排 → `2026-09-16-top-layout-drawer-ui.md`
>
> **只做 A**。B / C 会在后续单独派发。

## Antigravity session

```text
conversation: ec81a4be-7543-45ee-8658-f68966f57d3b
title: valhalla
workspace: /workspace/projects/valhalla
model: gemini-3.8-flash-high
```

## Allowed files

- `lib/features/files/sftp_file_view.dart`（主要）
- `lib/widgets/**`、`lib/app/**`
- `lib/l10n/**`（只需新增本文件第 5 节列出的 key）
- `test/features/**`

**不要修改** `lib/core/`、`lib/data/`、`lib/infrastructure/`、`pubspec.yaml`，
**也不要动 `lib/features/settings/` 和 `lib/features/shell/`**（那是 B / C 的范围）。

所有用户可见字符串必须同时写入 `app_en.arb` 与 `app_zh.arb`，不得只写一侧，
不得在 Dart 里硬编码文案。

> **ARB 是雷区**：`app_zh.arb` 里有大量未提交译文。**绝不要 `git checkout` 这两个文件**，
> 只做增量编辑。改完立刻跑 `flutter test -j 1 test/core/l10n_key_parity_test.dart`
> （当前 en/zh 都是 345 个 key，你新增多少就要两边各加多少，保持数量一致）。

---

## 1. 已经做好的后端（直接用，别重写）

### 1.1 传输状态

```dart
// lib/core/providers/sftp_provider.dart

enum SftpTransferKind { upload, download }

class SftpTransfer {
  final SftpTransferKind kind;
  final String remotePath;      // 上传是目标、下载是来源
  final String localPath;
  final int transferredBytes;   // 已传输字节
  final int totalBytes;         // 总字节；未知时为 0
  double? get progress;         // 0.0~1.0；总大小未知时返回 null（别显示假进度）
}

class SftpState {
  final SftpTransfer? transfer; // null = 当前没有传输
}
```

**同一时刻只允许一个传输**：`transfer != null` 时再调上传/下载会被直接忽略，
不会有任何异常。所以 UI 应当在 `transfer != null` 时把上传/下载入口置灰或隐藏。

### 1.2 新方法

```dart
// 读：该条目能不能打开（目录恒为 false；只有文本类型为 true）
bool canPreview(SftpFileItem item);

// 上传本地文件到「当前目录」；remoteName 默认取本地文件名
Future<void> uploadFrom(String localPath, {String? remoteName});

// 下载远端文件到本地路径
Future<void> downloadTo(SftpFileItem item, String localPath);

// 清除当前错误
void clearError();
```

### 1.3 行为要点

- **上传成功后会自动刷新目录**，你不需要手动调 `refresh()`。
- **上传/下载失败不抛异常**，只在 `state.errorMessage` 写入 reason code（见 1.4）。
- `openFileForEditing(item)` 会**先判断 `canPreview`**：
  不支持的类型**不会去读远端文件**，直接写 `errorMessage = SFTP_PREVIEW_UNSUPPORTED`。
  也就是说，对不支持的文件调用它，`editingFilePath` / `editingFileContent` 保持为空。

> **「打开」的语义 = 全屏文本编辑器（带保存）**，不是只读预览。
> `openFileForEditing` 只是这个动作的入口名，UI 上按「打开」呈现即可。
> 支持的范围**只有文本**，图片**不在本轮范围内**（`FilePreview` 里根本没有图片扩展名，
> 所以 `canPreview` 对 `.png` / `.jpg` 一律返回 false）。用户明确要求：
> 压缩包等非文本格式**必须给提示**，不能打开。

### 1.4 reason code（**必须由你映射成 ARB 文案**）

后端只产出稳定 code，不产出本地化文案：

| code | 语义 | 建议文案方向 |
|---|---|---|
| `SftpNotifier.uploadFailedCode` = `SFTP_UPLOAD_FAILED` | 上传失败 | 上传失败，请检查权限或网络后重试 |
| `SftpNotifier.downloadFailedCode` = `SFTP_DOWNLOAD_FAILED` | 下载失败 | 下载失败，请检查权限或本地空间后重试 |
| `SftpNotifier.previewUnsupportedCode` = `SFTP_PREVIEW_UNSUPPORTED` | 该类型不支持打开 | 暂不支持打开该格式 |
| `SftpNotifier.readFailedCode` = `SFTP_READ_FAILED` | 读取远端文件内容失败 | 读取文件失败，请检查权限后重试 |

现在 `sftp_file_view.dart` 里**没有任何地方消费 `errorMessage`**，所以这四种失败目前
**对用户完全不可见**。请补上展示（SnackBar / 内联错误条均可）。

> `state.errorMessage` 里还可能出现**历史遗留的英文拼接串**（如
> `Failed to load directory: <异常>`），那是 `lib/core` 里既有的实现，本轮不改。
> 你的映射逻辑遇到**不认识的 code 时**，请给一个通用兜底文案，不要原样透出英文。

---

## 2. 上传 / 下载入口

### 2.1 上传

- `file_picker: ^12.3.0` **已经在 `pubspec.yaml` 里**，直接用，不要加新依赖。
  用 `FilePicker.platform.pickFiles()` 选本地文件，拿到 `path` 后调
  `uploadFrom(path)`。
- 入口建议放在 `_buildActionBar` 里已有的那排 IconButton 旁边（目前是
  新建文件夹 / 新建文件 / 刷新）。`sftpUpload` 这个 key **已存在且当前无人使用**，
  正好用在悬浮提示上。
- 用户取消选择（返回 null）时什么都不做，不要报错。

### 2.2 下载

- 放在列表每行的 `PopupMenuButton` 里（目前有 edit / rename / delete），
  仅**非目录**项显示，标签用 `sftpDownload`。
- 目标本地路径：本轮**不做目录选择器**，直接用 `Directory.systemTemp`
  （**不要引入 `path_provider`** —— 它不是本仓库的直接依赖，
  只是别人的传递依赖，不安全可导入）。用文件名拼出本地路径即可。
- 完成后给出提示（成功用 SnackBar，失败走 1.4 的 code 映射）。
- `transfer != null` 时下载入口同样应当禁用（同一时刻只能有一个传输）。

---

## 3. 打开文件前的格式判断（**本切片的 bug 修复重点**）

现状：`sftp_file_view.dart` 菜单项判断只有 `if (!item.isDirectory)`，
而 `_openFileEditor` **从不检查 `canPreview`**，直接调
`openFileForEditing` 然后拿 `editingFileContent ?? ''` 弹全屏编辑器。
结果就是**压缩包等二进制文件照样被打开成一个空编辑器**——用户明确反馈的问题。

必须改的三点：

1. **菜单项门禁**：只有 `canPreview(item)` 为 true 时才显示/启用「打开」项。
   判断条件是 `canPreview` 而**不是** `!item.isDirectory`。
   （`SftpState` 本身没有这个 getter，用
   `ref.read(sftpProvider.notifier).canPreview(item)`。）
2. **不支持的类型要给出提示**，文案用 `sftpOpenUnsupported`
   （`暂不支持打开该格式`），**不要进入任何编辑界面**。
   不要指望后端写 `SFTP_PREVIEW_UNSUPPORTED` —— 做了门禁后这个 code
   正常情况下根本不会被写入，它只是后端的兜底。
3. **弹窗前必须校验**：`editingFilePath == item.path`。
   不相等就说明读取失败（此时 `errorMessage == SFTP_READ_FAILED`）
   或类型不支持，**不要弹空编辑器**，改为展示错误文案。
   `_openFileEditor` 里那个 `editingFileContent ?? ''` 就是空编辑器 bug 的直接来源。

- 支持的类型：点「打开」→ 走 `openFileForEditing` → 全屏 `Dialog.fullscreen`
  文本编辑器，**保留现有的保存按钮**（复用 `saveFileContent`，不用改）。

---

## 4. 系统返回键：回上级目录（**已做好，只需对齐判据**）

**后端已经完成**（`lib/features/shell/main_shell.dart` 包了 `PopScope`），交互语义：

- 只有当 **Files 标签页处于激活状态**、且 `state.isAtRoot == false` 时，
  系统返回键才「回到上级目录」。
- 已经在根目录（`currentPath == '/'` 或 `''`）时，返回键才**退出 app**。
- 在其它标签页时，返回键行为不变（退出 app）。

`state.isAtRoot` 是唯一判据，**不要在 UI 里再内联比较 `currentPath == '/'`**。

现有的面包屑 `IconButton`（向上箭头）在根目录时已被禁用，条件来自
`state.currentPath == '/'`——请改成用 `state.isAtRoot`，保持两处判据一致。

---

## 5. 需要你新增的 ARB key

**只新增这些**（en / zh 各加同样数量）。名字可微调，但**必须 en/zh 成对**。

| key | en | zh |
|---|---|---|
| `sftpDownload` | `Download` | `下载` |
| `sftpOpen` | `Open` | `打开` |
| `sftpUploadFailed` | `Upload failed. Check permissions and try again.` | `上传失败，请检查权限后重试。` |
| `sftpDownloadFailed` | `Download failed. Check permissions and local storage.` | `下载失败，请检查权限或本地空间。` |
| `sftpOpenUnsupported` | `This file format cannot be opened.` | `暂不支持打开该格式` |
| `sftpReadFailed` | `Failed to read the file. Check permissions and try again.` | `读取文件失败，请检查权限后重试。` |
| `sftpTransferFailed` | `File operation failed. Please try again.` | `文件操作失败，请重试。` |

如果上传/下载过程中你想显示进度，再自行补 `sftpUploading` / `sftpDownloading`
一类的 key（同样成对）。

**已存在、直接复用（不要改名、不要重复添加）**：

`sftpUpload`, `sftpRefresh`, `sftpNewFile`, `sftpNewFolder`, `sftpSearchHint`,
`sftpEmpty`, `sftpCurrentPath`, `sftpFileName`, `sftpFileSize`, `sftpFilePerm`,
`sftpFileModified`, `fileEditor`, `fileEditorSave`, `fileSavedSuccess`, `cancel`,
`delete`, `confirm`。

---

## 6. Constraints

1. Material 3。紧凑 `<600` NavigationBar，中等 `600–1024` 折叠 rail，宽屏 `>1024` rail + inspector。
2. 不加新依赖；不改 `lib/core/`、`lib/features/settings/`、`lib/features/shell/`；不伪造远端数据。
3. 必须补/改的 widget 测试：
   - 对不支持打开的类型（如 `.zip` / `.png`），打开入口是禁用/隐藏的，
     且**不会**触发读文件，也**不会**弹出编辑器；
   - 对支持的类型（如 `.txt` / `.md`），点打开后出现全屏编辑器且能保存；
   - `errorMessage == SFTP_READ_FAILED` / `SFTP_UPLOAD_FAILED` /
     `SFTP_DOWNLOAD_FAILED` 时，界面出现对应文案（不是英文 code、不是空白）；
   - `transfer != null` 时上传入口不可再次点击；
   - 根目录时向上箭头禁用，非根目录时可用（用 `isAtRoot`）。
4. 跑 `dart format`、`flutter analyze`、`flutter test -j 1`。
   本仓库的测试**必须**带 `-j 1`。
5. **断言要有牙**：写完后把被测的那行逻辑临时改掉（比如把门禁条件从
   `canPreview` 换回 `!isDirectory`），确认测试**真的会红**，再改回来。
   只断言「渲染出来了」而不区分「该显示的东西有没有显示」是无效测试。

## After you finish

列出改动过的文件。**只做 A**，不要顺手改 B / C 涉及的文件。
