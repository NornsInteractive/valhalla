import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/tmux_install_planner.dart';
import 'package:valhalla/core/utils/tmux_session_planner.dart';

void main() {
  group('TmuxSessionPlanner 命令构造', () {
    test('create 命令使用独立 socket 且不复用旧会话', () {
      final command = TmuxSessionPlanner.createCommand('s1', 'tab-1');

      expect(command, startsWith('tmux -L ${TmuxSessionPlanner.socketName} '));
      expect(command, contains('-L valhalla'));
      expect(command, contains("new-session -s 'valhalla_s1_tab-1'"));
      expect(command, isNot(contains('new-session -A')));
      expect(command, isNot(contains('-A')));
    });

    test('attach 使用精确名称，不创建、不分离其他客户端', () {
      final command = TmuxSessionPlanner.attachCommand('valhalla_s1_tab-1');

      expect(command, startsWith('tmux -L ${TmuxSessionPlanner.socketName} '));
      expect(command, contains("attach-session -t '=valhalla_s1_tab-1'"));
      expect(command, isNot(contains('-A')));
      expect(command, isNot(contains(' -d')));
    });

    test('has-session 查询精确名称', () {
      final command = TmuxSessionPlanner.hasSessionCommand('valhalla_s1_tab-1');

      expect(command, startsWith('tmux -L ${TmuxSessionPlanner.socketName} '));
      expect(command, contains("has-session -t '=valhalla_s1_tab-1'"));
    });

    test('restore rejects foreign names and shell or tmux target syntax', () {
      for (final name in [
        'main',
        'valhalla_s1_tab:1',
        'valhalla_s1_tab\n',
        "valhalla_s1_x'; id",
        'valhalla_s1_\u0000',
      ]) {
        expect(
          () => TmuxSessionPlanner.attachCommand(name),
          throwsArgumentError,
        );
        expect(
          () => TmuxSessionPlanner.hasSessionCommand(name),
          throwsArgumentError,
        );
      }
    });

    test(
      'history listing is isolated and keeps machine-readable separators',
      () {
        expect(
          TmuxSessionPlanner.listSessionsCommand,
          startsWith('tmux -L valhalla list-sessions -F '),
        );
        expect(TmuxSessionPlanner.listSessionsCommand, contains('\t'));
        expect(
          TmuxSessionPlanner.isSessionForServer('valhalla_s1_0', 's1'),
          isTrue,
        );
        expect(
          TmuxSessionPlanner.isSessionForServer('valhalla_s2_0', 's1'),
          isFalse,
        );
        expect(
          TmuxSessionPlanner.isSessionForServer('valhalla_s1_', 's1'),
          isFalse,
        );
      },
    );

    test('带上初始尺寸', () {
      final command = TmuxSessionPlanner.createCommand(
        's1',
        'tab-1',
        initialWidth: 120,
        initialHeight: 40,
      );

      expect(command, contains('-x 120'));
      expect(command, contains('-y 40'));
    });

    test('非法尺寸回退到 80x24', () {
      final command = TmuxSessionPlanner.createCommand(
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
      final names = ['s1', 'prod; rm -rf /', r'$(id)', 'a b'];
      for (final name in names) {
        final command = TmuxSessionPlanner.createCommand(name, 'tab-1');
        expect(
          command,
          isNot(matches(RegExp(r'(?<!-L )\btmux (kill|attach|new)'))),
          reason: '命令 "$command" 缺少 -L socket 隔离',
        );
        expect(command, contains('tmux -L '));
      }
    });

    test('绝不生成 kill-server 或 kill-session', () {
      final command = TmuxSessionPlanner.createCommand('s1', 'tab-1');

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
      expect(
        TmuxSessionPlanner.isTmuxAvailable('bash: tmux: command not found'),
        isFalse,
      );
      expect(TmuxSessionPlanner.isTmuxAvailable('tmux'), isFalse);
      expect(
        TmuxSessionPlanner.isTmuxAvailable('/usr/bin/tmux\n/bin/other'),
        isFalse,
      );
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
