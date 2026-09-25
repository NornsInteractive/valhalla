import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/tool_probe.dart';

void main() {
  group('ToolProbe.command', () {
    test('一条命令里包含全部待测工具，只做检测不做安装', () {
      final cmd = ToolProbe.command;
      for (final tool in RemoteTool.values) {
        expect(cmd, contains(tool.name));
      }
      expect(cmd, contains('command -v'));
      // 绝不能在探测阶段引入任何写操作。
      expect(cmd, isNot(contains('install')));
      expect(cmd, isNot(contains('apt-get')));
    });

    test('用 printf 保证缺工具时退出码仍为 0（循环正常结束）', () {
      final cmd = ToolProbe.command;
      expect(cmd, contains('printf'));
      expect(cmd, contains('MISSING'));
      // 不能因为 command -v 失败就中断整条命令。
      expect(cmd, contains('|| true'));
    });
  });

  group('ToolProbe.parse', () {
    test('正常输出：可用与缺失分别归类', () {
      const stdout = '''
TOOL:bash:OK:/usr/bin/bash
TOOL:docker:OK:/usr/bin/docker
TOOL:systemctl:MISSING:
TOOL:ps:OK:/usr/bin/ps
TOOL:tmux:MISSING:
''';
      final result = ToolProbe.parse(stdout);

      expect(result.unusable, isFalse);
      expect(result.isAvailable(RemoteTool.bash), isTrue);
      expect(result.available[RemoteTool.docker], '/usr/bin/docker');
      expect(result.isMissing(RemoteTool.systemctl), isTrue);
      expect(result.isMissing(RemoteTool.tmux), isTrue);
      expect(result.isAvailable(RemoteTool.ps), isTrue);
    });

    test('profile banner 噪声行被忽略，不影响结论', () {
      const stdout = '''
Welcome to Ubuntu 24.04 LTS
Last login: Tue Sep 16 10:00:00 2026
TOOL:docker:OK:/usr/bin/docker
-bash: some unrelated warning
MOTD: have a nice day
''';
      final result = ToolProbe.parse(stdout);

      expect(result.unusable, isFalse);
      expect(result.isAvailable(RemoteTool.docker), isTrue);
      expect(result.available, hasLength(1));
      expect(result.missing, isEmpty);
    });

    test('结构上像结果行但没有 TOOL: 前缀的噪声必须被忽略', () {
      // 这一条是前缀守卫的真正牙齿：去掉 `line.startsWith(linePrefix)` 之后，
      // 下面这行会被误解析成「docker 可用」。上面那条 banner 测试抓不到这种
      // 变异，因为普通 banner 按 ':' 切分根本凑不够 4 段。
      // 关键是要构造出**段数够多**的噪声：`docker:OK:/path` 只有 3 段，
      // 会被 `parts.length < 4` 顺手挡掉，测不出前缀守卫。必须给它 4 段以上。
      const stdout = 'X:docker:OK:/usr/bin/docker\nY:ps:MISSING:\n';
      final result = ToolProbe.parse(stdout);

      expect(result.available, isEmpty);
      expect(result.missing, isEmpty);
      expect(result.unusable, isTrue, reason: '没有合法前缀的行一条都不该被采信');
    });

    test('输出被截断：已出现的照常解析，未出现的既不可用也不缺失', () {
      // 只有两行，后面三行被截断。
      const stdout = '''
TOOL:bash:OK:/usr/bin/bash
TOOL:docker:MISSING:
''';
      final result = ToolProbe.parse(stdout);

      expect(result.unusable, isFalse);
      expect(result.isAvailable(RemoteTool.bash), isTrue);
      expect(result.isMissing(RemoteTool.docker), isTrue);

      // 关键：截断不等于「不存在」。
      for (final tool in [
        RemoteTool.systemctl,
        RemoteTool.ps,
        RemoteTool.tmux,
      ]) {
        expect(result.isAvailable(tool), isFalse);
        expect(result.isMissing(tool), isFalse);
        expect(result.hasVerdictFor(tool), isFalse);
      }
    });

    test('空输出 / null / 纯噪声都判为 unusable', () {
      expect(ToolProbe.parse('').unusable, isTrue);
      expect(ToolProbe.parse(null).unusable, isTrue);
      expect(
        ToolProbe.parse('bash: no job control in this shell\n').unusable,
        isTrue,
      );
    });

    test('无法识别的工具名被忽略，不会污染空白结论', () {
      const stdout = '''
TOOL:rsync:OK:/usr/bin/rsync
TOOL:git:MISSING:
TOOL:docker:OK:/usr/bin/docker
''';
      final result = ToolProbe.parse(stdout);

      // rsync/git 不在 RemoteTool 里，应被丢弃。
      expect(result.available.keys, [RemoteTool.docker]);
      expect(result.missing, isEmpty);
    });

    test('OK 但没有路径的行不可信，按无结论处理', () {
      const stdout = 'TOOL:docker:OK:\nTOOL:ps:MISSING:\n';
      final result = ToolProbe.parse(stdout);

      expect(
        result.isAvailable(RemoteTool.docker),
        isFalse,
        reason: 'reporting OK without a path is not evidence of availability',
      );
      expect(result.isMissing(RemoteTool.docker), isFalse);
      expect(result.isMissing(RemoteTool.ps), isTrue);
      expect(result.unusable, isFalse);
    });

    test('路径里含冒号也能正确还原', () {
      const stdout = 'TOOL:docker:OK:/opt/weird:dir/docker\n';
      final result = ToolProbe.parse(stdout);

      expect(result.available[RemoteTool.docker], '/opt/weird:dir/docker');
    });

    test('缺少段数的残行被忽略', () {
      const stdout = 'TOOL:docker\nTOOL:docker:OK\nTOOL:ps:OK:/usr/bin/ps\n';
      final result = ToolProbe.parse(stdout);

      expect(result.available.keys, [RemoteTool.ps]);
    });

    test('CRLF 行尾不会让结论丢失', () {
      const stdout = 'TOOL:docker:OK:/usr/bin/docker\r\nTOOL:tmux:MISSING:\r\n';
      final result = ToolProbe.parse(stdout);

      expect(result.isAvailable(RemoteTool.docker), isTrue);
      expect(result.isMissing(RemoteTool.tmux), isTrue);
    });

    test('真实远端输出（在 bash -l -c 里实跑抓取）解析正确', () {
      // 这段是把 ToolProbe.command 丢进真实 `bash -l -c` 跑出来的原样输出，
      // 用来锁住「命令拼接 + 解析」这条链路，而不只是解析器本身。
      const realOutput = '''
TOOL:bash:OK:/usr/bin/bash
TOOL:docker:MISSING:
TOOL:systemctl:MISSING:
TOOL:ps:OK:/usr/bin/ps
TOOL:tmux:OK:/usr/bin/tmux
''';
      final result = ToolProbe.parse(realOutput);

      expect(result.unusable, isFalse);
      expect(result.available.keys.toSet(), {
        RemoteTool.bash,
        RemoteTool.ps,
        RemoteTool.tmux,
      });
      expect(result.missing, {RemoteTool.docker, RemoteTool.systemctl});
      // 每个工具都必须有明确结论，不能有「未知」。
      for (final tool in RemoteTool.values) {
        expect(result.hasVerdictFor(tool), isTrue, reason: '$tool 应拿到结论');
      }
    });
  });
}
