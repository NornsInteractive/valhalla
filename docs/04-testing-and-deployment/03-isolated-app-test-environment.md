# 隔离 App 验收环境

2026-09-23 的 Android 全功能验收使用一次性 Debian 12 虚拟机。仅这台
`valhalla-test-vm` 允许文件写入、Docker 生命周期、NAS 部署和电源操作；
App 已保存的其他服务器只做只读检查。

## 连接

- VM 在开发容器内使用 QEMU TCG、2 vCPU、3 GiB RAM、8 GiB 稀疏磁盘。
- 开发容器到 VM：`127.0.0.1:22023`，用户 `valhalla`。
- VM 状态、镜像、私有凭据和密钥在 `/tmp/valhalla-test-vm/`，不提交 Git。
- 测试密码在该目录 `credentials.json`，权限 `0600`；不能复制到报告或日志。

```sh
ssh -F /tmp/valhalla-test-vm/ssh_config valhalla-test-vm
adb -s 192.168.1.145:14251 reverse tcp:22023 tcp:22023
```

建立 reverse 后，Android App 的测试服务器填写 `127.0.0.1:22023`。
这里的回环地址是设备侧 reverse 端点；ADB 设备连接仍使用宿主机地址
`192.168.1.145:14251`。重连 ADB 后检查 reverse 是否仍在。

## 测试资源

| 资源 | 路径或名称 | 用途 |
| --- | --- | --- |
| 媒体 | `/home/valhalla/media` | MP3、MP4、PNG，NAS 只读挂载 |
| SFTP | `/home/valhalla/sftp-test` | 小文本、Unicode 文件名、二进制、超过 1 MiB 的文本 |
| NAS 安装目录 | `/home/valhalla/nas-test-<unique>` | 每次安装使用不存在的新目录 |
| systemd 服务 | `valhalla-test-worker.service` | 服务查询、启动、停止 |
| Docker 容器 | `valhalla-test-logs`、`valhalla-test-stopped` | stdout/stderr 日志、生命周期、容器终端 |
| SSH / 终端 | OpenSSH、Bash、tmux | 主机密钥、命令、ANSI、重连 |

Docker Engine 和 Compose 通过 Docker 官方 Debian 软件源安装在客机内，
开发容器和既有服务器均不运行新增 Docker daemon。准备完成标记是
`/home/valhalla/fixture-ready`；在此之前连接的 SSH 会话应重新连接，获取
新增的 Docker 用户组权限。

环境初建时，系统 DNS 把 `registry-1.docker.io` 解析到错误地址，TLS 握手失败。
最初使用临时 `/etc/hosts` 纠正验证了真实 BusyBox 拉取；为避免静态端点
过期，随后在 VM 内使用官方 [AdGuard dnsproxy](https://github.com/AdguardTeam/dnsproxy)
v0.84.2、HTTPS DNS 上游和 `fastest_addr`。服务名
`valhalla-test-dns.service`，监听客机回环和 Docker 网桥，TLS 证书校验
保持启用。只改变一次性 VM，开发容器和用户服务器的 DNS 不变。
原客机解析配置备份在 `/etc/resolv.conf.valhalla-test-backup`。原
`/etc/resolv.conf` 指向 systemd 动态文件，会被重新生成覆盖；原符号链接
保存为 `/etc/resolv.conf.valhalla-test-original-link`，测试使用独立静态文件。
恢复时移回原链接，再停止 `valhalla-test-dns.service`。

```sh
ssh -F /tmp/valhalla-test-vm/ssh_config valhalla-test-vm \
  'test -e ~/fixture-ready && docker info >/dev/null && docker compose version'
```

QEMU 仅在开发容器回环地址额外转发 `18096 → 8096`、`18097 → 8097`、
`18080 → 8080`。NAS 安装默认绑定客机回环地址时，应使用 App 的 SSH
隧道；这些 QEMU 转发不会绕过客机回环绑定。

本环境的 QEMU 7.2.22 在 `-cpu max` 下运行 Emby 的 .NET 程序时，复现了
用户态 IRET / SMAP 客机内核异常，与 [QEMU 上游修复](https://github.com/qemu/qemu/commit/0bd385e7e3c33e987d7a8879918be6df7b111ac4)
描述一致。2026-09-23 的保留数据对照将这台一次性 VM 的 `restart.sh` 改为
`-cpu max,smap=off`；原脚本保存在 `restart.sh.before-smap-ab`。重启后 SSH
主机密钥、WebDAV 容器和三份媒体内容均核对不变，继续使用原 qcow2 磁盘，
未修改产品健康时限或生产环境。这是旧 TCG 的测试环境处理，不是 NAS
部署依赖；长期应使用包含上游修复的 QEMU。原生 HTTP 响应以及旧健康逻辑
下的 Docker 用例通过，均不替代最终产品修复验收；对照还发现了根页面 302
早于媒体 API 就绪的问题。详见[诊断与对照记录](../../build/app-stability-validation/emby-native-diagnosis.md)。

## 停止与清理

```sh
ssh -F /tmp/valhalla-test-vm/ssh_config valhalla-test-vm 'sudo poweroff'
adb -s 192.168.1.145:14251 reverse --remove tcp:22023
```

确认 `qemu.pid` 对应进程已经退出，再删除 `/tmp/valhalla-test-vm/` 即可
释放 VM、Docker 镜像、测试文件和私有凭据。保留磁盘重启时运行该目录的
`restart.sh`。不要依据过期 PID 直接结束进程，不要清除 App 数据。

软件模拟只用于功能、错误状态和资源释放验证，不能代替实体 Android
设备的帧率或解码性能验收。

## 服务层真实部署回归

默认测试不会连接 VM。显式开启后，使用真实 `SSHClientManager`、SSH
主机密钥校验、Docker 和 `NasInstallService`，只模拟进程内的本地偏好存储。
测试校验 VM 的固定主机密钥、`machine-id`、主机名和就绪标记，再执行写入。

```sh
VALHALLA_NAS_VM_CREDENTIALS=/tmp/valhalla-test-vm/credentials.json \
  flutter test --no-pub test/infrastructure/nas_install_vm_test.dart \
  --reporter expanded
```

测试使用客机 `18100–18102` 端口，覆盖目录冲突保护、实际拉取中取消、
三种产品部署、媒体只读挂载以及恢复已保存阶段后的只读核对。各产品串行
测试；结束后移除本次容器和本次新拉取的独占镜像并 `fstrim`，避免磁盘堆积。
测试生成的配置目录保留用于诊断，随 VM 一起销毁。

SSH、Docker、systemd、进程和终端的独立真实回归使用同一 VM：

```sh
VALHALLA_OPERATIONS_VM_CREDENTIALS=/tmp/valhalla-test-vm/credentials.json \
  flutter test --no-pub test/infrastructure/app_operations_vm_test.dart \
  --reporter expanded --timeout 3m
```

该套测试的容器、systemd 单元、tmux 会话均使用唯一测试名称；临时 polkit
规则只授权当前测试创建的单元，测试结束时清除这些资源。
