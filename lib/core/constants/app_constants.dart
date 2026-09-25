import '../../data/models/quick_command.dart';

class AppConstants {
  static const defaultSshPort = 22;
  static const connectTimeoutSeconds = 15;
  static const keepAliveIntervalSeconds = 30;

  /// SSH 传输层心跳间隔，交给 dartssh2 自己调度。
  ///
  /// 比 [keepAliveIntervalSeconds] 短，好让传输层先发现半开连接；
  /// 业务层的 ping 是第二道保险。
  static const sshTransportKeepAliveSeconds = 10;

  /// 主动探活（[SSHClientManager.verifyAlive]）的等待上限。
  ///
  /// 必须显式超时：`SSHClient.ping()` 在传输层已半开时会永远挂着不返回，
  /// 既不会成功也不会抛错，超时是唯一能把它变成确定结果的手段。
  static const sshVerifyAliveTimeoutSeconds = 8;

  /// 预置的快捷指令模版库
  static const List<QuickCommand> defaultQuickCommands = [
    QuickCommand(
      id: 'docker-restart-nginx',
      title: '重启 Nginx 容器',
      command: 'docker restart nginx',
      category: 'Docker',
      description: '热重启生产前端与反向代理服务',
      iconName: 'restart_alt',
    ),
    QuickCommand(
      id: 'docker-system-prune',
      title: 'Docker 全面系统修剪',
      command: 'docker system prune -a --volumes',
      category: 'Docker',
      description: '清除所有无用镜像、停止的容器和孤儿数据卷',
      iconName: 'delete_forever',
      isDangerous: true,
    ),
    QuickCommand(
      id: 'docker-compose-up',
      title: 'Docker Compose 后台拉起',
      command: 'docker compose up -d --remove-orphans',
      category: 'Docker',
      description: '在当前目录构建并部署容器组',
      iconName: 'play_arrow',
    ),
    QuickCommand(
      id: 'docker-inspect',
      title: '容器 Inspect 详细元数据',
      command: 'docker inspect {{container_id}}',
      category: 'Docker',
      description: '查看指定容器挂载卷与网络端口',
      iconName: 'search',
      paramPlaceholder: 'container_id',
    ),
    QuickCommand(
      id: 'sys-disk-usage',
      title: '磁盘空间占用排查',
      command: 'df -h && du -sh /* 2>/dev/null | sort -rh | head -n 10',
      category: 'System',
      description: '检查根分区剩余空间与排名前十的膨胀目录',
      iconName: 'pie_chart',
    ),
    QuickCommand(
      id: 'sys-memory-flush',
      title: '清理 Linux 页面缓存',
      command: 'sync && echo 3 > /proc/sys/vm/drop_caches',
      category: 'System',
      description: '释放无用的系统 Buffer 与 Cache 物理内存',
      iconName: 'cleaning_services',
      isDangerous: true,
    ),
    QuickCommand(
      id: 'k8s-pod-status',
      title: 'K8s 异常 Pod 筛选',
      command: 'kubectl get pods -A --field-selector status.phase!=Running',
      category: 'K8s',
      description: '快速定位 CrashLoopBackOff 或 Pending 的 Pod',
      iconName: 'view_in_ar',
    ),
    QuickCommand(
      id: 'k8s-pod-logs',
      title: '查看 Pod 实时日志',
      command: 'kubectl logs -f --tail=100 {{pod_name}} -n {{namespace}}',
      category: 'K8s',
      description: '实时跟踪捕获指定命名空间中 Pod 的标准输出',
      iconName: 'terminal',
      paramPlaceholder: 'pod_name',
    ),
  ];
}
