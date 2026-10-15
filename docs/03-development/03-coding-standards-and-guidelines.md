# Valhalla - 编码规范与工程开发指南

| 文档版本 | 发布日期 | 适用语言 | 质量基准 |
| :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-09-13 | Dart 3.x / Flutter 3.x | flutter_lints (Strict) / Clean Code |

---

## 1. Dart & Flutter 核心编码风格

### 核心体验增量约束（2026-10-15）

- 暂停原因是显式持久化枚举，不能由 UI 根据错误字符串猜测；手动暂停与
  进程重启暂停不参加网络自动重试。批量操作捕获当前目标与任务集合。
- 重连与历史读取不得自动重发消息、审批或终端命令。恢复详情动作必须绑定
  当前真实目标；旧请求完成不能修改新目标状态。
- ACP 错误元数据独立于正文并脱敏，历史回放不能伪造成功；稳定消息对象
  必须保留，不能在 selector 内复制/反序列化整段会话来规避重建。
- 终端模式标签显示实际模式而非请求偏好。共享文件工具栏在选择模式不能
  暴露管理操作，离线管理动作保留位置并禁用。弹窗需验证窄屏、RTL和大字号。
- 本轮 UI 仍由 AgY，验证、格式、生成和构建优先由 OpenCode。本轮另获用户
  明确授权：OpenCode 多次超时／工具错误后，由主代理补齐测试、验证、打包
  和保留数据 ADB 安装；仅限本轮，不延伸至未来轮次。安装包、源码测试、
  ADB 操作结果分别留证，不以旧包代验。

### 本轮新增传输与终端约束（2026-10-14）

- 展示由原 AgY Valhalla 会话修改，模型 Gemini 3.8 Flash／high；账号变化需
  只重启本项目进程，不操作其他项目进程或将凭据写入仓库。本轮主代理验证
  例外仅对本轮生效，后续测试／打包仍遵循 OpenCode 委派规则。
- 文件传输优化不得抽样替代完整续传校验、取消文件／证书验证或无界预读。
  使用单调计时、实际字节速度、节流及强制终态；通道故障只清理本任务资源。
- 2026-10-15：批量文件传输的 SSH／SFTP、校验与写盘须在独立 isolate；
  主线程不接收文件字节。独立连接须固定已验证主机钥匙及认证快照，凭据仅
  内存、断开即清除，禁止自动信任新钥匙或静默回退主线程。验收区分 mock、
  真实隔离 VM、ADB 模拟设备和真机，不用 UI CPU 帧耗时冒充显示帧率。
- 新建普通终端默认不记可恢复历史；设置不重建已有终端。历史远端终止需要
  用户明确确认、固定目标／名称／专用 socket，未知结果不自动重试。
- 2026-10-15：自动新建一律普通 SSH，仅手动新建可读取 tmux 开关；保留
  已设默认历史的精确恢复。测试需要 tmux 种子时显式手动新建，不依赖冷启动。
- 新建普通 SSH／tmux 模式入口位于 SSH 终端页。普通 shell 网络恢复后可自动
  重开 PTY，保留本地输出但不宣称恢复旧进程；CLI／登录／exec 启动命令不可
  因重连自动重放。tmux 历史缺失仍须明确处理，不悄悄替换成新 shell。
- 包名变化按独立应用迁移处理，不卸载旧安装、不篡改已发布身份／标签证据。
  回归／模拟性能、编译检查与实机验收要分开记录，不用旧包或旧结果冒充。

### 1.1 命名规范
* **文件与目录**：全小写蛇形命名（`snake_case`），例如 `ssh_client_manager.dart`、`server_card.dart`。
* **类名、枚举、扩展**：大驼峰命名（`UpperCamelCase`），例如 `ServerEntity`, `SshAuthType`。
* **变量、方法、参数**：小驼峰命名（`lowerCamelCase`），例如 `connectTimeout`, `fetchContainerLogs()`。
* **常量**：小驼峰命名（`lowerCamelCase`），禁止全大写下划线。

### 1.2 Widget 构建与性能优化
* **优先使用 `const` 构造函数**：所有无动态状态依赖的 Widget 必须声明为 `const`，减少不必要的 Element 树重绘。
* **拆分微型组件**：单个 Widget 的 `build()` 方法长度严禁超过 100 行。过长布局必须拆分为带有明确语义的独立子组件或私有方法。
* **禁止在 `build()` 中直接发起副作用**：严禁在 Widget 的 `build()` 方法中调用异步请求、建立 Socket 或触发持久化写入。

---

## 2. Riverpod 状态管理规范

### 2.1 状态不可变性原则 (Immutability)
所有作为 State 传递的模型类必须是不可变对象（Immutable）：

```dart
// 规范示例
@immutable
class ServerState {
  final bool isLoading;
  final List<ServerEntity> servers;
  final String? errorMessage;

  const ServerState({
    this.isLoading = false,
    this.servers = const [],
    this.errorMessage,
  });

  ServerState copyWith({
    bool? isLoading,
    List<ServerEntity>? servers,
    String? errorMessage,
  }) {
    return ServerState(
      isLoading: isLoading ?? this.isLoading,
      servers: servers ?? this.servers,
      errorMessage: errorMessage,
    );
  }
}
```

### 2.2 Provider 作用域与清理规范
* 页面级状态与瞬时会话必须显式声明 `.autoDispose`，在离开页面后由 Riverpod 自动回收资源、关闭监听管道，杜绝内存泄漏：
  ```dart
  final terminalSessionProvider = AutoDisposeAsyncNotifierProviderFamily<...>(...);
  ```

---

## 3. 全局异常处理与脱敏日志规范

### 3.1 领域异常体系 (Domain Exceptions)
严禁底层异常直接抛至 UI 产生红屏崩溃。业务层统一捕获并转化为明确的领域异常：

```dart
abstract class AppException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AppException(this.message, [this.originalError, this.stackTrace]);
}

class SSHConnectionException extends AppException {
  const SSHConnectionException(super.message, [super.originalError, super.stackTrace]);
}

class SSHAuthenticationException extends AppException {
  const SSHAuthenticationException(super.message, [super.originalError, super.stackTrace]);
}

class ACPException extends AppException {
  final int? rpcCode;
  const ACPException(super.message, {this.rpcCode, super.originalError, super.stackTrace});
}

class DockerExecutionException extends AppException {
  final int exitCode;
  const DockerExecutionException(super.message, {required this.exitCode});
}
```

### 3.2 日志脱敏过滤器 (Log Sanitizer)
在向控制台或文件写入日志前，必须经由 `LogSanitizer` 过滤特征敏感词：
* 匹配 `BEGIN [A-Z]+ PRIVATE KEY` 的私钥内容；
* 匹配常见密码或 Token 模式（如 `password: "..."`, `Bearer ey...`）；
* 将脱敏内容替换为 `***REDACTED***`。

---

## 4. Git 协作与提交规范 (Conventional Commits)

提交说明格式：`<type>(<scope>): <subject>`

| Type | 适用说明 | 示例 |
| :--- | :--- | :--- |
| `feat` | 引入新功能特性 | `feat(acp): support session resume command` |
| `fix` | 修复缺陷或 Bug | `fix(terminal): resolve mobile IME composition issue` |
| `docs` | 文档编写与更新 | `docs(arch): clarify docker mobile remote execution` |
| `refactor`| 代码重构（不改变外部行为） | `refactor(ssh): decouple ssh channel factory from manager` |
| `perf` | 性能调优 | `perf(dashboard): throttle system metrics stream to 3s` |
| `test` | 增加或修改测试用例 | `test(acp): add unit tests for json-rpc dispatcher` |
