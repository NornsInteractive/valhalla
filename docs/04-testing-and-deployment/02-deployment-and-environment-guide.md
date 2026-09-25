# Valhalla - 客户端打包发布与服务端运行环境指南

## 2026-09-19 性能与原生 CLI 验收

键盘动画使用 `flutter build apk --profile` 或 `flutter run --profile` 在物理 Android 设备测量，debug 包仅用于功能排错。当前环境只连接 Linux 桌面，没有 Android 设备，不能给出真机帧率通过结论。生成包与门禁结果见 [本轮记录](../handoffs/2026-09-19-cli-reboot-performance.md)。原生接口取决于服务器 CLI 版本；缺全局历史 / 原生删除能力保留真实终端或禁用相应动作，不自动升级。Claude 历史 SDK 要求 Node.js/npm，安装须确认；agy 交互登录在真实终端完成。真实重启 / 删除只在用户指定测试服务器确认后验收。

| 文档版本 | 发布日期 | 适用系统 |
| :--- | :--- | :--- |
| v1.0.0 | 2026-09-13 | 客户端: Android, Windows, Linux, macOS, iOS / 服务端: Linux (所有主流发行版) |

---

## 1. 客户端跨平台编译与打包指南

Valhalla 客户端基于 Flutter 构建，支持全平台独立二进制分发。

原生功能是否已通过当前构建与真机验收以 [实施状态](../03-development/04-implementation-status.md) 为准，平台目录存在不等于全部原生桥接已验收。

### 下载与登录补充（2026-09-18）

- Android 下载保存在应用持久支持目录 `files/downloads`，与 FileProvider 的受限目录一致；桌面使用 `Downloads/Valhalla`，无法取得 Downloads 时回退应用文档目录。卸载应用可能清除应用内文件；这不是公共共享下载目录。
- 下载写入 `.part` 后成功改名，同名自动编号。失败/取消的临时文件不是已完成文件，不自动覆盖现有文件。
- Android 13+ 通知需 `POST_NOTIFICATIONS` 用户授权；拒绝通知只降低展示能力，不阻止传输。应用被系统杀死不保证下载继续。
- Claude 默认登录 `claude auth login`，状态 `claude auth status --json`；Codex 使用 `codex login status` 检查。AGY 登录为交互运行 `agy`，版本检测不证明登录成功。
- 安装与登录须经用户确认，应用不能自动升级远端 CLI/ACP 或暴露凭证。新 Codex Adapter 使用 `@agentclientprotocol/codex-acp`，保留用户自定义命令。

### 1.1 Android 端打包
* **最低系统要求**：Android 6.0 (API Level 23) 及以上（满足 `flutter_secure_storage` 硬件 Keystore 最低要求）。
* **权限清单 (`AndroidManifest.xml`)**：
  ```xml
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
  <uses-permission android:name="android.permission.VIBRATE" />
  ```
* **打包指令**：
  ```bash
  # 生成通用 Release APK
  flutter build apk --release --split-per-abi

  # 生成 Google Play App Bundle
  flutter build appbundle --release
  ```

### 1.2 Windows 桌面端打包
* **系统要求**：Windows 10 / 11 64位。
* **依赖运行库**：目标机器需安装 Visual C++ 2015-2022 Redistributable。
* **打包指令**：
  ```bash
  flutter build windows --release
  # 产物位于: build/windows/x64/runner/Release/
  ```

### 1.3 Linux 桌面端打包
* **系统要求**：glibc >= 2.31（Ubuntu 20.04+, Debian 11+ 等）。
* **打包指令**：
  ```bash
  flutter build linux --release
  ```

---

## 2. 服务端最低运行要求（零专有 Daemon 侵入）

服务端**严禁且无需安装 Valhalla 专有服务端程序**，仅依赖 Linux 既有标准环境：

### 2.1 基础系统环境
* **操作系统**：Debian, Ubuntu, CentOS, RHEL, Rocky Linux, Arch Linux, Alpine Linux 等主流 Linux。
* **SSH 服务**：`OpenSSH Server` 7.6+ (保持默认端口 22 或自定义端口开放)。
* **认证推荐**：推荐配置 Ed25519 或 RSA (>= 3072位) SSH 密钥免密登录。

### 2.2 Docker 管理前置配置（可选）
为了免 Sudo 密码平滑管理 Docker，建议将登录用户加入宿主机的 `docker` 用户组：
```bash
sudo usermod -aG docker $USER
# 注销重新登录或执行 newgrp docker 生效
```

### 2.3 AI Agent 环境配置（可选）
若需使用 AI Agent 能力，在服务器端全局或用户主目录下安装官方 Agent CLI 及 ACP Adapter 即可：

* **Claude Code 安装**：
  ```bash
  npm install -g @anthropic-ai/claude-code
  # 启动一次完成认证
  claude
  ```

### 2.4 Docker 容器内 Agent（可选）

容器 Agent 不需要暴露新端口；SSH 登录用户仍需要调用 `docker exec` 和 `docker inspect` 的权限。CLI、ACP Adapter 与认证状态均安装在目标容器内。OpenCode 原生会话要求 SSH 宿主机能路由容器地址（常见 bridge/host 网络）；rootless 或隔离网络无法转发时，客户端会显示限制，不能通过自动修改 Docker 网络绕过。
* **Codex ACP Adapter 安装**：
  ```bash
  npm install -g @agentclientprotocol/codex-acp
  ```

---

## 3. 常见排错与 FAQ

### Q1: 客户端连接报 `command not found: claude` 或找不到 Node？
* **原因**：Node.js 是通过 `nvm`、`fnm`、`asdf` 或 `pnpm` 安装在用户个人主目录，默认非登录 SSH Exec 不加载 `~/.bashrc`。
* **解决**：Valhalla 客户端内置了“Login Shell Wrapper (`bash -l -c`)”，会自动加载 `~/.profile`；如仍未找到，可在 App【Agent 设置】中手动填写 Agent 的绝对安装路径（如 `/home/dev/.nvm/versions/node/v22.0.0/bin/claude`）。

### Q2: 执行快捷命令或重启服务时提示 `sudo: a terminal is required`？
* **原因**：非交互式会话执行需要密码的 `sudo` 命令时，系统因无 TTY 拒绝输入。
* **解决**：
  1. 在快捷命令属性中勾选【需要 Sudo 提权】，App 将自动以 `sudo -S` 模式从本地安全凭据库安全管道推送密码；
  2. 或在服务器 `/etc/sudoers.d/` 中为该指定命令配置 `NOPASSWD` 免密规则。

### Q3: 首次连接提示 Host Key 改变？
* **原因**：目标服务器重装了操作系统，或网络中存在潜在的 DNS 劫持/中间人拦截（MITM）。
* **解决**：如确认服务器重装，进入【服务器设置】->【重置已知主机密钥】，接受新指纹；若未知情，切勿点击信任，避免密码或私钥凭据泄露。
