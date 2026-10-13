# 2026-10-13 应用数据与容器命名：隔离 VM 集成结果

## 边界及身份

按用户本轮直接验证授权，完成两个现有 opt-in VM 测试文件的补充及实际执行。
本轮未编辑业务代码、UI、ARB，未执行全量测试、构建、ADB、推送或发布。
未使用 racknerd、krm 或任何生产服务器。测试目录均为本轮新随机实例，创建前检查不存在。

先单独运行只读身份门，之后每个集成测试仍重新验证：

- SSH：`127.0.0.1:22023`，用户 `valhalla`，hostname `valhalla-test-vm`。
- machine-id：`3579bace85be432fa7cde6da46ad839b`。
- 实际 SSH hostkey：`SHA256:j0JCpHOOGNJlL2UDKj5nQnFSJlePw63tPE8Yo4MINtM`。
- `/home/valhalla/fixture-ready` 存在。
- 私有凭据只从既有 `/tmp/valhalla-test-vm/credentials.json` 读取，没有打印、复制、提交或更改其内容。
- 身份不符会在远端写入前失败；不再仅信任凭据文件任意填写的 hostkey。

## 实际命令和结果

```bash
VALHALLA_APP_CENTER_VM_CREDENTIALS=/tmp/valhalla-test-vm/credentials.json \
flutter test --reporter expanded --concurrency=1 \
  test/infrastructure/application_center_vm_test.dart \
  --plain-name 'pinned VM: read-only identity gate'
```

只读门退出码 0，1 passed；此步骤没有远端写操作。

```bash
VALHALLA_APP_CENTER_VM_CREDENTIALS=/tmp/valhalla-test-vm/credentials.json \
VALHALLA_CLEANUP_VM=1 \
flutter test --reporter expanded --concurrency=1 \
  test/infrastructure/application_center_vm_test.dart \
  test/infrastructure/application_cleanup_vm_test.dart
```

**退出码 0；08:43，4 passed、0 failed、0 skipped。** 包含再次执行的只读身份门、
完整部署生命周期、child-only 清理、whole-dataRoot 清理。这里不是 skip-only 结果，
SSH、Docker daemon、Compose worker、Python 清理脚本及实际文件删除均真实执行。

## 已验证

- 实际 daemon 接受当前 `docker ps -a --no-trunc --format` JSON Go template；
  主/副容器名称精确为实例名和实例名加服务后缀。实际 Docker inspect 验证原项目名、
  `com.valhalla.app.instance`、模板自定义标签、服务标签、原 `container_name` 别名、
  自定义网络别名及项目隔离网络保留。
- 运行中和停止后的同名容器均阻止新实例 prepare；在名称尚空闲时预览的另一个实例，
  等原实例安装占名后 execute 再次拒绝，而且没有 persistBeforeLaunch、数据目录或控制目录写入。
- 实际 install → SSH 断开/重连 → stop → start → configure → restart → update → restore →
  保留数据卸载全部成功，实时任务阶段确实出现当前命令、输出和更新时间。
- Web 主服务绑定 loopback；辅助端口从 VM 的非 loopback 接口可访问，主端口不能从该接口访问。
  恢复后版本、配置及容器名、标签、网络、别名仍正确。Nginx Proxy Manager 路径只读预览也通过，
  没有安装真实 NPM。
- 在两个全新清理实例内，未挂载的 `unmounted/.ssh/sentinel` 导致 root 候选明确
  `APP_CENTER_CLEANUP_PROTECTED_PATH`；验证后只删除这些本轮哨兵文件和空目录。
- 本轮额外创建一个停止的独立容器，共享该实例 `kept` bind；root/kept 的清理预览明确
  `APP_CENTER_CLEANUP_SHARED_PATH`。验证后检查 fixture label 匹配随机实例 ID，精确移除该容器。
- child-only 只删除 `selected`，`kept/kept-sentinel` 和未挂载 `root-sentinel` 内容保留。
- whole-root 同时选择 root 和两个子目录后，计划与实际结果均归并为一个 root 目标；
  root 整棵目录实际不存在，包括未挂载 sentinel；没有扩大到父目录或其他实例。
- 两种卸载均保留命名卷，前后 `docker volume inspect` 的 Name/Mountpoint 一致；
  非 bind 卷在清理预览中不可选。部署容器和各自网络由 Compose down 移除。

## 本轮精确对象及残留

共同数据父目录是 `/home/valhalla/.local/share/valhalla/apps`，审计父目录是
`/home/valhalla/.local/share/valhalla/app-center`。这些父目录未被删除。

### 完整生命周期实例

- ID：`0ccb45a85fbdb6dabe277d159bbf2408`。
- 已移除容器：`acceptance-0ccb45a85fbd`、`acceptance-0ccb45a85fbd-public`。
- 已移除网络：`valhalla-app-0ccb45a85fbdb6dabe277d159bbf2408_fixture`。
- 保留数据：`/home/valhalla/.local/share/valhalla/apps/0ccb45a85fbdb6dabe277d159bbf2408`，
  其中 `sentinel` 内容仍为 `sentinel`。
- 保留控制审计：`/home/valhalla/.local/share/valhalla/app-center/deployments/0ccb45a85fbdb6dabe277d159bbf2408`。
- `app-center/tasks/` 中保留以下任务目录：
  `627a5a3d6a048762d9329a711a0b8127`、`e87380d0795fee2a8b0c6e8dc8c95561`、
  `a600b1f77830041b2e23fced6c967ab7`、`ca01046ecac0597d4fe0e2ea163a9638`、
  `01d3da628a59b9180bd2722158a43171`、`640570c5dfb79daaac98b1c1f8b6d815`、
  `2dea1222a2e1fe8fb0712820035fae27`、`52f29d59e77235bed03f3a183799ac4b`。

### Child-only 清理实例

- ID：`d2f0bd2bbba3b428c89bc54b58be75d6`。
- 已移除应用容器：`selective-cleanup-d2f0bd2bbba3b428c89bc54b58be75d6`。
- 已移除临时共享容器：`acceptance-shared-d2f0bd2bbba3`。
- 已移除网络：`valhalla-app-d2f0bd2bbba3b428c89bc54b58be75d6_default`。
- 已删除：`/home/valhalla/.local/share/valhalla/apps/d2f0bd2bbba3b428c89bc54b58be75d6/selected`。
- 保留：该 root、`kept/kept-sentinel`、`root-sentinel`；两个保留文件的内容仍为该实例 ID。
- 保护测试的 `unmounted/.ssh/sentinel` 和两个空父目录已精确移除。
- 保留命名卷：`valhalla-app-d2f0bd2bbba3b428c89bc54b58be75d6_fixture-cache`。
- 保留控制审计：`/home/valhalla/.local/share/valhalla/app-center/deployments/d2f0bd2bbba3b428c89bc54b58be75d6`。
- 保留任务目录 ID：`5027b624259111b6d3c8bedd281f7878`、`0109e43f031b469c5834ac5fb6c597a6`。

### Whole-root 清理实例

- ID：`c904920ed9439baea0da40393d979e93`。
- 已移除应用容器：`selective-cleanup-c904920ed9439baea0da40393d979e93`。
- 已移除临时共享容器：`acceptance-shared-c904920ed943`。
- 已移除网络：`valhalla-app-c904920ed9439baea0da40393d979e93_default`。
- 整体已删除：`/home/valhalla/.local/share/valhalla/apps/c904920ed9439baea0da40393d979e93`。
- 保留命名卷：`valhalla-app-c904920ed9439baea0da40393d979e93_fixture-cache`。
- 保留控制审计：`/home/valhalla/.local/share/valhalla/app-center/deployments/c904920ed9439baea0da40393d979e93`。
- 保留任务目录 ID：`ee0bbbb6eb80ce9c4d0f385a4dcb4d97`、`84eb966c355b03fe3d010ca8a5f874c1`。

以上删除对象仅为本轮测试新建内容，删除不可恢复，但都是固定测试数据；
保留数据、命名卷和审计有意不作额外清理，便于复核，不代表用户应用数据。

## 未覆盖

- 没有创建真实 host bind mount 或 overmount；外部 mount alias 的 filesystem-coordinate
  安全检查仍由本地受控 mountinfo 回归证明，不把本 VM 的 Docker bind 共享等同于 host mount 别名证明。
- 本 VM 为普通 Linux/Docker 环境；未覆盖 ACL、特殊文件系统、百万文件性能、并发文件攻击的实机压力测试。
- 实际新模式主动改名、多副本拒绝和 legacy 兼容已有 focused core 回归，未额外在 VM 迁移旧实例。
- 未验证安装向导/卸载 UI、手机布局、ADB、真实手机性能或生产 NAS/agent。
- 这两测试文件尚未在本轮单独格式化或 analyze；后续统一 source gate 可处理，
  不将当前 4 项 VM 成功写成整个仓库或交付全部通过。
