# 2026-10-13 应用数据清理与容器命名回归结果

## 执行边界

OpenCode 三个测试 writer 停止后，按用户本轮允许主代理/团队直接验证的授权接手。
本次只修改域内测试和本记录；未修改 UI、ARB 或其他团队文件，未执行格式、分析、
全量测试、生成、打包、ADB 或生产服务器命令。

## 最终命令与结果

```bash
flutter test --reporter expanded --concurrency=2 \
  test/core/application_cleanup_helper_test.dart \
  test/core/application_container_naming_test.dart \
  test/core/application_compose_test.dart \
  test/core/application_worker_test.dart \
  test/core/application_paths_test.dart \
  test/core/application_preflight_health_test.dart
```

结果：退出码 **0**，**194 tests passed**，无跳过、无失败。
本次新增 58 个回归：清理 helper 24、容器命名 17、prepare/execute 15、本地真实 Bash restore 2。

初始未补 mock 的五文件基线为 128 通过、8 失败。8 个失败均因安装预检新增加
`docker ps -a --no-trunc --format`，原严格 mock 未声明该只读应答；补充空 inventory 后
保留原端口占用、磁盘空间和禁止写操作断言，没有放宽为任意命令成功。

## 已证明的行为

### 数据目录清理

- 从当前嵌入式 Python 脚本提取模块，真实运行 `owned_files`、`inspect`、`selected_snapshot`、
  `guard_target`、`guard_retry`、`cleanup`、fd 只读遍历及实际目录删除。
- 所有配置、所有权标记、Compose 文件、数据和任务状态均在每例独立临时目录内。
  仅替代外部 Docker 应答、host machine-id 读取及 mountinfo；没有创建系统 machine-id，
  没有调用真实 Docker daemon 或创建真实 bind mount。
- 根目录候选包括未挂载文件；只选子目录保留同级数据；父子同时选只清理一个顶级树；
  dataRoot 与同路径挂载合并为一个候选，命名卷仍不可选。
- 未挂载的 `.ssh` / `.gnupg` 文件、目录、链接均阻止预览和直接清理；
  删除前只读遍历结束后再插入保护子项，实际递归仍拒绝且保护内容和外围 sentinel 存活。
- 预览后目标、配置、inode、共享引用变化不会执行删除；配置挂载变成符号链接时不能通过父目录绕过。
- 外部 bind 别名 backing 等于、包含或位于 dataRoot 内时拒绝；普通祖先挂载、不同设备、
  不相交的同设备 backing 不误拒绝；其他受管实例共享和嵌套挂载继续保护。
- 空选择和缺风险确认不能形成有效授权；根目录失败重试不能扩展为原未单独授权的子目录，
  也不能再次清理已经完成的目标。

### 容器命名与部署

- 新 defaults 使用合法 catalog ID 作初始实例名；单服务主容器精确匹配实例名。
- 多服务主/辅助名称、有效模板 main 自动选择、缺失/无效 main 必须显式选择。
  已选主服务驱动管理 Web 端口，项目名、部署标签、模板网络别名及端口绑定仍保留。
- 新字段跨 JSON、copyWith、目录标准化、mergeDefaults、变量更新保留；旧 JSON 仍使用 legacy，
  不因为新 defaults 或调用方误传新模式而自动重命名旧部署。
- 非法用户名称不被静默清洗；显式命名拒绝多副本/scale/global 模板；单副本和 legacy 兼容。
- prepare 使用无运行状态筛选的 `docker ps -a` inventory；畸形行、别实例/项目/服务占名拒绝，
  原部署同服务容器允许。新模式改名进入差异预览，previous compose 保留原名称。
- execute 再检查占名后才开始写配置和持久化；预览后被占名时没有文件写入或 worker launch。
  成功路径保存显式命名字段，任务意图持久化在唯一 launch 之前。
- 实际本地 Bash restore worker 在隔离目录执行两遍（legacy / explicit）。Docker 命令用
  shell fixture 替代，确认调用 up 前已恢复原 Compose，配置/部署/template 原样恢复，
  固定项目名、`--pull never` 及任务成功终态保留。

## 未覆盖及后续验收

- **未运行真实 Docker**：Go template 对实际 daemon 的格式、真实 running/stopped 容器冲突、
  Compose 重建及服务网络访问需在已固定身份的隔离 VM 补验；手写 inventory 不是该证明。
- 外部 bind 保护使用受控 mountinfo 坐标，未在本机或生产机实际 mount。
- 未做大目录百万文件性能、ACL/不同系统权限矩阵或长任务中断压力测试；预算超限仍必须安全保留。
- 未验 UI 勾选/风险确认、安装向导主服务选择、手机视图和真实设备交互；由对应 UI/ADB 验收覆盖。
- 本次清理边界仅删除各测试自行创建的临时文件树；没有触碰用户数据、容器或远端服务。
