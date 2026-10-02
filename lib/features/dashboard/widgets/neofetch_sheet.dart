import 'package:flutter/material.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/motion_widgets.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../infrastructure/system/system_hardware_service.dart';
import '../../../infrastructure/system/system_metrics_sampler.dart';
import '../dashboard_provider.dart';
import 'metric_trend_dialog.dart' show formatKiB;

/// 发行版字符画枚举 — [NeofetchArt.tux] 为兜底 (未知 / 无法识别的发行版)。
enum NeofetchArt { ubuntu, debian, arch, fedora, centos, alpine, suse, raspberry, tux }

const String _ubuntuRaw = r'''
       _
    ---(_)
  _/  ---  \
 (_) |   |
   \  --- _/
    ---(_)
''';

const String _debianRaw = r'''
      ____
     /    \
    /  __  \
   |  /  \  |
   |  \__/ /
    \     /
     (   /
      \  \
      _) )
     (__/
''';

const String _archRaw = r'''
       /\
      /  \
     /    \
    /  __  \
   /  |  |  \
  /  _|  |_  \
 /__/      \__\
''';

const String _fedoraRaw = r'''
    ____
   /    \
  |  __  |
  | _|_  |
  |  |   |
   \____/
''';

const String _centosRaw = r'''
      /\    /\
     /  \  /  \
     \  /  \  /
      \/    \/
      /\    /\
     /  \  /  \
     \  /  \  /
      \/    \/
''';

const String _alpineRaw = r'''
       /\
      /  \
     /\   \
    /  \   \
   /    \   \
  /______\___\
''';

const String _suseRaw = r'''
      _/\_
     /    \
    | o  o |
    |  __  |
     \____/
''';

const String _raspberryRaw = r'''
        \\ //
         \\//
        .--.
       / oo \
      | oooo |
      | oooo |
       \ oo /
       | oo |
        \ o/
         '-'
''';

const String _tuxRaw = r'''
    .--.
   |o_o |
   |:_/ |
  //   \ \
 (|     | )
/'\_   _/`\
\___)=(___/
''';

/// 按优先级匹配发行版标识 (PRETTY_NAME 小写子串), 未命中一律回退 Tux。
NeofetchArt resolveNeofetchArt(String? distribution) {
  final d = (distribution ?? '').toLowerCase();
  if (d.contains('ubuntu')) return NeofetchArt.ubuntu;
  if (d.contains('debian')) return NeofetchArt.debian;
  if (d.contains('arch')) return NeofetchArt.arch;
  if (d.contains('manjaro')) return NeofetchArt.arch;
  if (d.contains('fedora')) return NeofetchArt.fedora;
  if (d.contains('centos')) return NeofetchArt.centos;
  if (d.contains('rhel') || d.contains('red hat')) return NeofetchArt.centos;
  if (d.contains('rocky') || d.contains('alma') || d.contains('anolis')) {
    return NeofetchArt.centos;
  }
  if (d.contains('alpine')) return NeofetchArt.alpine;
  if (d.contains('opensuse') || d.contains('suse')) return NeofetchArt.suse;
  if (d.contains('kali')) return NeofetchArt.debian;
  if (d.contains('raspbian') || d.contains('raspberry')) {
    return NeofetchArt.raspberry;
  }
  // deepin / uos / kylin / uniontech 及一切未知发行版 → Tux, 永不出空态。
  return NeofetchArt.tux;
}

/// 纯 ASCII 字符画注册表 (每行右补空格对齐, ≤20 列)。
List<String> neofetchArtLines(NeofetchArt art) {
  final raw = switch (art) {
    NeofetchArt.ubuntu => _ubuntuRaw,
    NeofetchArt.debian => _debianRaw,
    NeofetchArt.arch => _archRaw,
    NeofetchArt.fedora => _fedoraRaw,
    NeofetchArt.centos => _centosRaw,
    NeofetchArt.alpine => _alpineRaw,
    NeofetchArt.suse => _suseRaw,
    NeofetchArt.raspberry => _raspberryRaw,
    NeofetchArt.tux => _tuxRaw,
  };
  final lines = raw.trim().split('\n');
  final width = lines.map((l) => l.length).reduce((a, b) => a > b ? a : b);
  return [for (final line in lines) line.padRight(width)];
}

/// 终端面板上的固定亮色文字 (面板永远深底, 不随主题翻转)。
const Color _panelText = Color(0xFFE2E8F0);
const Color _panelMuted = Color(0xFF8C99AB);

/// 打开 "系统信息" 底部弹层: neofetch 风格字符画 + 键值式系统信息。
void showNeofetchSheet(
  BuildContext context, {
  required SystemHardwareInfo hardware,
  required String serverName,
  required String userHost,
  SystemMetricsSnapshot? metrics,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(
      maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
    ),
    builder: (_) => NeofetchSheet(
      hardware: hardware,
      serverName: serverName,
      userHost: userHost,
      metrics: metrics,
    ),
  );
}

class NeofetchSheet extends StatelessWidget {
  final SystemHardwareInfo hardware;
  final String serverName;
  final String userHost;
  final SystemMetricsSnapshot? metrics;

  const NeofetchSheet({
    super.key,
    required this.hardware,
    required this.serverName,
    required this.userHost,
    this.metrics,
  });

  List<(String, String)> _buildInfoLines(BuildContext context) {
    final l10n = context.l10n;
    final unknown = l10n.hardwareUnknown;
    final lines = <(String, String)>[];

    lines.add((l10n.systemInfoHost, userHost.isEmpty ? unknown : userHost));
    lines.add((l10n.hardwareDistribution, hardware.distribution ?? unknown));
    lines.add((l10n.hardwareKernel, hardware.kernel ?? unknown));

    final String cpu;
    if (hardware.cpuModel != null && hardware.cpuCores != null) {
      cpu =
          '${hardware.cpuModel} (${l10n.hardwareCpuCores(hardware.cpuCores!)})';
    } else if (hardware.cpuModel != null) {
      cpu = hardware.cpuModel!;
    } else if (hardware.cpuCores != null) {
      cpu = l10n.hardwareCpuCores(hardware.cpuCores!);
    } else {
      cpu = unknown;
    }
    lines.add((l10n.hardwareCpu, cpu));

    final memKiB = hardware.memoryTotalKiB;
    final String mem;
    if (memKiB != null) {
      mem = metrics == null
          ? formatKiB(memKiB)
          : '${formatKiB(memKiB)} · ${MetricsFormatters.formatPercentage(metrics!.memoryUsedRatio)}';
    } else {
      mem = unknown;
    }
    lines.add((l10n.hardwareMemory, mem));

    lines.add((
      l10n.hardwareDisk,
      hardware.rootDiskTotalKiB != null
          ? formatKiB(hardware.rootDiskTotalKiB!)
          : unknown,
    ));

    final m = metrics;
    if (m != null && m.uptimeSeconds > 0) {
      lines.add((
        l10n.metricsUptime,
        MetricsFormatters.formatUptime(m.uptimeSeconds),
      ));
    }

    return lines;
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.terminal_rounded, size: 20, color: context.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.systemInfoTitle, style: context.textTheme.titleMedium),
              if (serverName.isNotEmpty)
                Text(
                  serverName,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildArtBlock(BuildContext context, List<String> art) {
    return Entrance(
      index: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          art.join('\n'),
          style: monoTextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.colorScheme.primary,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBlock(BuildContext context, List<(String, String)> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++)
          Entrance(
            index: i + 1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lines[i].$1,
                    style: monoTextStyle(fontSize: 11, color: _panelMuted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lines[i].$2,
                      style: monoTextStyle(fontSize: 11.5, color: _panelText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTerminalPanel(
    BuildContext context,
    List<String> art,
    List<(String, String)> lines,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // 与 docker 日志 / 危险命令预览一致的终端底色, 亮色模式下同样保持深底。
        color: const Color(0xFF0F141C),
        borderRadius: BorderRadius.circular(VRadius.input),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 窄屏 (<400dp) 或字符画过宽时改为纵向堆叠 (画在上)。
          final sideBySide =
              constraints.maxWidth >= 400 && art.first.length <= 22;
          final artBlock = _buildArtBlock(context, art);
          final infoBlock = _buildInfoBlock(context, lines);
          if (sideBySide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                artBlock,
                const SizedBox(width: VSpace.lg),
                Expanded(child: infoBlock),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: artBlock),
              const SizedBox(height: VSpace.md),
              infoBlock,
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final art = neofetchArtLines(resolveNeofetchArt(hardware.distribution));
    final lines = _buildInfoLines(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: VSpace.md),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildTerminalPanel(context, art, lines),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
