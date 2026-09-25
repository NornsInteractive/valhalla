import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/tmux_install_planner.dart';
import 'package:valhalla/core/utils/tmux_session_planner.dart';

void main() {
  group('TmuxSessionPlanner 命令构造', () {
    test('attach 命令使用独立 socket', () {
      final command = TmuxSessionPlanner.attachOrCreateCommand('s1', 'tab-1');

      expect(command, startsWith('tmux -L ${TmuxSessionPlanner.socketName} '));
      expect(command, contains('-L valhalla'));
    });

    test('attach 使用 -A 以复用已有会话', () {
      final command = TmuxSessionPlanner.attachOrCreateCommand('s1', 'tab-1');

      // -A 是「存在则 attach，不存在则创建」的核心，缺了它就变成
      // 每次新建，断线重连也就拿不回原来的内容。
      expect(command, contains('new-session -A'));
      expect(command, contains('-s valhalla_s1_tab-1'));
    });

    test('带上初始尺寸', () {
      final command = TmuxSessionPlanner.attachOrCreateCommand(
        's1',
        'tab-1',
        initialWidth: 120,
        initialHeight: 40,
      );

      expect(command, contains('-x 120'));
      expect(command, contains('-y 40'));
    });

    test('非法尺寸回退到 80x24', () {
      final command = TmuxSessionPlanner.attachOrCreateCommand(
        's1',
        'tab-1',
        initialWidth: 0,
        initialHeight: -5,
      );

      expect(command, contains('-x 80'));
      expect(command, contains('-y 24'));
    });

    test('会话名过滤掉不安全字符（防命令注入）', () {
      final name = TmuxSessionPlanner.sessionName(
        r's1; rm -rf /',
        r'$(whoami)',
      );

      expect(name, isNot(contains(';')));
      expect(name, isNot(contains(r'$')));
      expect(name, isNot(contains(' ')));
      expect(name, isNot(contains('/')));
      expect(name, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });

    test('生成的命令里绝不出现裸 tmux 调用（必须始终带 -L）', () {
      // 自我防护回归：默认 socket 上是用户自己的 tmux 会话，
      // 任何不带 -L 的调用都可能影响它。
      final names = ['s1', 'prod; rm -rf /', r'$(id)', 'a b'];
      for (final name in names) {
        final command = TmuxSessionPlanner.attachOrCreateCommand(name, 'tab-1');
        expect(
          command,
          isNot(matches(RegExp(r'(?<!-L )\btmux (kill|attach|new)'))),
          reason: '命令 "$command" 缺少 -L socket 隔离',
        );
        // 更强的断言：命令里唯一的 tmux 调用必须紧跟 -L。
        expect(command, contains('tmux -L '));
      }
    });

    test('绝不生成 kill-server 或 kill-session', () {
      final command = TmuxSessionPlanner.attachOrCreateCommand('s1', 'tab-1');

      expect(command, isNot(contains('kill-server')));
      expect(command, isNot(contains('kill-session')));
    });

    test('探测命令只做检测', () {
      expect(TmuxSessionPlanner.detectCommand, 'command -v tmux');
      expect(TmuxSessionPlanner.detectCommand, isNot(contains('install')));
      expect(TmuxSessionPlanner.detectCommand, isNot(contains('apt')));
      expect(TmuxSessionPlanner.detectCommand, isNot(contains('yum')));
    });
  });

  group('会话名归属判定', () {
    test('本项目创建的会话被识别', () {
      expect(TmuxSessionPlanner.isOwnSession('valhalla_s1_tab-1'), isTrue);
    });

    test('用户自己的会话不被误认', () {
      expect(TmuxSessionPlanner.isOwnSession('main'), isFalse);
      expect(TmuxSessionPlanner.isOwnSession('work'), isFalse);
      expect(TmuxSessionPlanner.isOwnSession(''), isFalse);
    });
  });

  group('tmux 可用性解析', () {
    test('绝对路径视为可用', () {
      expect(TmuxSessionPlanner.isTmuxAvailable('/usr/bin/tmux'), isTrue);
      expect(TmuxSessionPlanner.isTmuxAvailable('/usr/bin/tmux\n'), isTrue);
    });

    test('空输出视为不可用', () {
      expect(TmuxSessionPlanner.isTmuxAvailable(null), isFalse);
      expect(TmuxSessionPlanner.isTmuxAvailable(''), isFalse);
      expect(TmuxSessionPlanner.isTmuxAvailable('   \n'), isFalse);
    });

    test('shell 错误信息不被误判为可用', () {
      // `command -v` 失败时会打印到 stderr，某些配置下也可能混进 stdout。
      expect(
        TmuxSessionPlanner.isTmuxAvailable('bash: tmux: command not found'),
        isFalse,
      );
      expect(TmuxSessionPlanner.isTmuxAvailable('tmux'), isFalse);
    });
  });

  group('会话名稳定性', () {
    test('同一输入总是生成同一个名字（重连才能接回原会话）', () {
      final first = TmuxSessionPlanner.sessionName('srv-1', 'tab-3');
      final second = TmuxSessionPlanner.sessionName('srv-1', 'tab-3');

      expect(first, second);
    });

    test('不同终端/服务器互不冲突', () {
      expect(
        TmuxSessionPlanner.sessionName('s1', 't1'),
        isNot(TmuxSessionPlanner.sessionName('s1', 't2')),
      );
      expect(
        TmuxSessionPlanner.sessionName('s1', 't1'),
        isNot(TmuxSessionPlanner.sessionName('s2', 't1')),
      );
    });
  });

  group('TmuxInstallPlanner', () {
    test('探测命令本身不安装', () {
      expect(
        TmuxInstallPlanner.detectPackageManagerCommand,
        isNot(contains('install')),
      );
    });

    test('识别已知包管理器并给出命令', () {
      expect(TmuxInstallPlanner.parsePackageManager('apt\n'), 'apt');
      expect(
        TmuxInstallPlanner.installCommandFor('apt'),
        'sudo apt-get update && sudo apt-get install -y tmux',
      );
      expect(
        TmuxInstallPlanner.installCommandFor('dnf'),
        'sudo dnf install -y tmux',
      );
    });

    test('未知包管理器返回 null，上层应走普通 SSH', () {
      expect(TmuxInstallPlanner.parsePackageManager('none'), isNull);
      expect(TmuxInstallPlanner.parsePackageManager(''), isNull);
      expect(TmuxInstallPlanner.installCommandFor(null), isNull);
      expect(TmuxInstallPlanner.installCommandFor('none'), isNull);
    });
  });
}
