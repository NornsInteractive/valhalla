/// 远端 tmux 缺失时的安装命令构造（纯逻辑，不执行）。
///
/// 安装必须由用户在 UI 确认后才调用执行器。本类只根据包管理器 id
/// 给出命令字符串；识别不到则返回 null，上层应走「不装、直接 SSH」。
abstract final class TmuxInstallPlanner {
  /// 探测包管理器。只 echo 一个 id，不安装任何软件。
  static const detectPackageManagerCommand =
      r'if command -v apt-get >/dev/null 2>&1; then echo apt; '
      r'elif command -v dnf >/dev/null 2>&1; then echo dnf; '
      r'elif command -v yum >/dev/null 2>&1; then echo yum; '
      r'elif command -v pacman >/dev/null 2>&1; then echo pacman; '
      r'elif command -v zypper >/dev/null 2>&1; then echo zypper; '
      r'elif command -v apk >/dev/null 2>&1; then echo apk; '
      r'elif command -v brew >/dev/null 2>&1; then echo brew; '
      r'else echo none; fi';

  /// 将探测输出收成包管理器 id。无法识别时返回 null。
  static String? parsePackageManager(String? output) {
    final id = output?.trim().split(RegExp(r'\s+')).first ?? '';
    const known = {'apt', 'dnf', 'yum', 'pacman', 'zypper', 'apk', 'brew'};
    if (!known.contains(id)) return null;
    return id;
  }

  /// 对应包管理器的 tmux 安装命令。未知 id 返回 null。
  static String? installCommandFor(String? packageManager) {
    switch (packageManager) {
      case 'apt':
        return 'sudo apt-get update && sudo apt-get install -y tmux';
      case 'dnf':
        return 'sudo dnf install -y tmux';
      case 'yum':
        return 'sudo yum install -y tmux';
      case 'pacman':
        return 'sudo pacman -Sy --noconfirm tmux';
      case 'zypper':
        return 'sudo zypper --non-interactive install tmux';
      case 'apk':
        return 'sudo apk add tmux';
      case 'brew':
        return 'brew install tmux';
      default:
        return null;
    }
  }
}
