/// 日志脱敏处理器，确保凭证、密钥与私密数据不在控制台或日志文件中明文泄露
class LogSanitizer {
  static final RegExp _passwordRegex = RegExp(
    r'((?:password|passwd|pwd|secret|token|api[_-]?key|authorization|cookie|private[_-]?key))\s*(?:[:=]\s*|\s+)(?:bearer\s+)?([^\s,;"}]+)',
    caseSensitive: false,
  );

  static final RegExp _flagSecretRegex = RegExp(
    r'(--?(?:password|passwd|pwd|secret|token|api[_-]?key))(?:=|\s+)([^\s]+)',
    caseSensitive: false,
  );

  static final RegExp _jsonSecretRegex = RegExp(
    r'''(["'](?:password|passwd|pwd|secret|token|api[_-]?key|authorization|cookie|private[_-]?key)["']\s*:\s*["'])([^"']*)(["'])''',
    caseSensitive: false,
  );

  static final RegExp _privateKeyRegex = RegExp(
    r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|$)',
  );

  static final RegExp _uriCredentials = RegExp(
    r'(\b[a-z][a-z0-9+.-]*://)[^\s/@]+@',
    caseSensitive: false,
  );

  /// Log streams are sanitized after complete lines, never at network boundaries.
  /// Interactive terminals must use their separate PTY path.
  static Stream<String> stream(Stream<String> source) async* {
    final pending = StringBuffer();
    var privateKey = false;
    var silenced = false;
    final delimiters = RegExp(r'[\r\n]');
    final keyBegin = RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----');
    final keyEnd = RegExp(r'-----END [A-Z ]*PRIVATE KEY-----');

    String safeLine(String line) {
      if (keyBegin.hasMatch(line)) privateKey = true;
      if (privateKey) {
        if (keyEnd.hasMatch(line)) privateKey = false;
        return '[REDACTED_PRIVATE_KEY]';
      }
      return sanitize(line);
    }

    await for (final chunk in source) {
      if (silenced) continue;
      var start = 0;
      final boundaries = delimiters.allMatches(chunk).iterator;
      while (start <= chunk.length) {
        final end = boundaries.moveNext()
            ? boundaries.current.start
            : chunk.length;
        if (pending.length + end - start > 16 * 1024) {
          // ponytail: abnormal unbroken log lines suppress this output stream;
          // use a bounded protocol-aware parser only if legitimate logs need more.
          pending.clear();
          silenced = true;
          yield '[REDACTED oversized log line; remaining output omitted]\n';
          break;
        }
        pending.write(chunk.substring(start, end));
        if (end < chunk.length) {
          yield '${safeLine(pending.toString())}${chunk[end]}';
          pending.clear();
        }
        if (end == chunk.length) break;
        start = end + 1;
      }
    }
    if (!silenced && pending.isNotEmpty) yield safeLine(pending.toString());
  }

  /// 对字符串内容进行敏感字段脱敏
  static String sanitize(String input) {
    var result = input;

    // 脱敏私钥
    result = result.replaceAll(
      _privateKeyRegex,
      '-----BEGIN PRIVATE KEY-----\n[REDACTED_PRIVATE_KEY]\n-----END PRIVATE KEY-----',
    );

    result = result.replaceAllMapped(
      _jsonSecretRegex,
      (match) => '${match.group(1)}******${match.group(3)}',
    );

    // 脱敏密码与 Token
    result = result.replaceAllMapped(_passwordRegex, (match) {
      final key = match.group(1);
      return '$key=******';
    });
    result = result.replaceAllMapped(_flagSecretRegex, (match) {
      return '${match.group(1)}=******';
    });
    result = result.replaceAllMapped(
      _uriCredentials,
      (match) => '${match.group(1)}******@',
    );

    return result;
  }
}
