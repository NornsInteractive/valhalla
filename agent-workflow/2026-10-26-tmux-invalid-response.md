# tmux 历史恢复：INVALID_RESPONSE 继续排查

基线 1.0.19+20 / 文档提交 76fbdb7。用户提供：
`Bad state: TERMINAL_HISTORY_UNVERIFIED: SSHConnectionException: TMUX_HISTORY_INVALID_RESPONSE`。

## 已确认

`TERMINAL_HISTORY_UNVERIFIED` 携带的异常取自 `refreshHistory` 的 socket 发现错误；恢复尚未通过历史身份验证，不是已经成功附加后断线，也不能据此认定远端会话已结束。

当前发现命令期望六个 TAB 分隔字段：session_id、session_created、session_attached、pid、socket_path、session_name。此错误码来自列数不符、空/含控制字符的名称或非法 attached 数值等检查。旧实现此时丢弃 stdout/stderr，因此用户提供的错误不足以证明具体原因。输出混杂、特殊名称及 tmux 环境差异均仍是待验证假设，不能写成已确认原因。

## 当前改动

主代理仅补 `terminal_session_bridge.dart` 的五个 INVALID_RESPONSE 抛出点的脱敏响应详情。复用现有 `_queryDetails`，分别脱敏 stdout/stderr 后 JSON 转义，使 TAB/换行可复制辨认；详情总长仍限 4096。不放宽格式、会话身份、socket 或终止权限，不创建替代会话，不改 UI。

免费 OpenCode Beam 未返回执行结果，已停止本轮所启动进程；按现有免费回退授权使用 CodeBuddy hy3 / deepseek-v4.1-flash 补诊断回归、格式和静态分析，实际原始结果：3 文件 114 项常规测试通过（machine done.success=true、无失败/跳过），全项目分析 No issues found，格式与 diff-check 完成。证据为忽略目录中的 tmux-response-test.json、tmux-response-analyze.txt 和 tmux-response-proof.json；CodeBuddy 已自然退出 0，并记录 test_exit=0 / analyze_exit=0；其回执的 117 包含 3 个隐藏 suite-loading 事件，常规测试计为 114。主代理未自行执行应用测试。

ADB 仅只读检查：127.0.0.1:14251 安装的是 1.0.16、无运行的 Valhalla 进程，不能代表用户新包报错现场；没有安装、启动、点击或操作远端终端。

## 需要的现场证据

已请求在出错服务器、同一 SSH 用户执行只读命令并回传：

```bash
tmux -V
tmux -L valhalla list-sessions -F '#{session_id}|#{session_created}|#{session_attached}|#{pid}|#{socket_path}|#{session_name}'
```

服务器自有默认 socket 则使用 `-L default`；自定义 socket 应使用其实际 -L/-S 配置。不要输出密码、Token 或登录文件。

只有取得原始响应或可信复现后才修改对应协议解析。该问题尚未宣称修复，本阶段没有新构建、升号或发布；待恢复修复与门禁完成后按长期规则发布新版本，不能用诊断日志完善冒充恢复问题已解决。
