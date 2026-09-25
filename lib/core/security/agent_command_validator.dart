import '../errors/app_exceptions.dart';

/// 拒绝不安全（不可插入 login shell）的命令字符串。
///
/// 纯函数、无副作用：仅做显式字符检查与引号配对扫描，绝不解析或改写 shell
/// 语义。校验失败抛出 [ValidationException]，其 `details` 携带稳定 reason code
/// 供上层（UI）映射本地化文案。
class AgentCommandValidator {
  AgentCommandValidator._();

  /// 不安全则抛 [ValidationException]。接受：非空、无 `\n` `\r` `\0`、
  /// 单双引号配对。
  static void validate(String command) {
    if (command.trim().isEmpty) {
      throw const ValidationException('Command must not be empty', 'CMD_EMPTY');
    }
    if (command.contains('\n') || command.contains('\r')) {
      throw const ValidationException(
        'Command must not contain newline characters',
        'CMD_NEWLINE',
      );
    }
    if (command.contains('\u0000')) {
      throw const ValidationException(
        'Command must not contain NUL bytes',
        'CMD_NUL',
      );
    }
    if (!_hasBalancedQuotes(command)) {
      throw const ValidationException(
        'Command has unbalanced quotes',
        'CMD_UNBALANCED_QUOTES',
      );
    }
  }

  /// [command] 为 null 或空白时抛 [ValidationException]；否则与 [validate] 一致。
  static void require(String? command, {String? label}) {
    if (command == null) {
      throw ValidationException(
        'Required command is missing',
        label == null ? 'CMD_MISSING' : 'CMD_MISSING:$label',
      );
    }
    validate(command);
  }

  /// 左到右扫描引号配对。
  ///
  /// 单引号内双引号是字面量；反斜杠仅在双引号内转义下一个字符。若扫描结束
  /// 时仍处于开启状态，则判定为不配对。
  static bool _hasBalancedQuotes(String command) {
    var inSingle = false;
    var inDouble = false;

    for (var i = 0; i < command.length; i++) {
      final ch = command[i];

      if (inSingle) {
        if (ch == "'") inSingle = false;
        continue;
      }

      if (inDouble) {
        if (ch == r'\') {
          i++; // 跳过被转义的下一个字符
          continue;
        }
        if (ch == '"') inDouble = false;
        continue;
      }

      if (ch == "'") {
        inSingle = true;
      } else if (ch == '"') {
        inDouble = true;
      } else if (ch == r'\') {
        i++; // 未加引号的反斜杠转义下一个字符
      }
    }

    return !inSingle && !inDouble;
  }
}
