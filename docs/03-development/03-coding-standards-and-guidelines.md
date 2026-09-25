# Valhalla - 编码规范与工程开发指南

| 文档版本 | 发布日期 | 适用语言 | 质量基准 |
| :--- | :--- | :--- | :--- |
| v1.0.0 | 2026-09-13 | Dart 3.x / Flutter 3.x | flutter_lints (Strict) / Clean Code |

---

## 1. Dart & Flutter 核心编码风格

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
