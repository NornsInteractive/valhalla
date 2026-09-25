/// 从终端纯文本中提取可复制的 http(s) 链接。
///
/// 纯 Dart 实现（只依赖 `dart:core`），不 import Flutter 或 xterm，因此可以
/// 直接单元测试。
///
/// 背景：登录命令（`codex login` 等）会往终端打印很长的 OAuth 链接，而 xterm
/// 的终端视图没有可用的选中复制能力，所以改为从终端缓冲里直接把链接识别出来，
/// 交给 UI 提供一键复制。
library;

/// 在终端文本中找到的一条候选链接。
class ExtractedUrl {
  /// 归一化后的链接（已剥离尾部标点、已按需拼接硬换行续行）。
  final String url;

  /// [url] 在（已剔除 ANSI 序列的）文本中的起始偏移。仅用于判断先后顺序，
  /// 不要用它去索引原始输入。
  final int index;

  const ExtractedUrl({required this.url, required this.index});

  int get length => url.length;

  @override
  String toString() => 'ExtractedUrl($url @$index)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractedUrl && other.url == url && other.index == index;

  @override
  int get hashCode => url.hashCode ^ index.hashCode;
}

abstract final class TerminalUrlExtractor {
  /// 匹配 http/https 链接。刻意宽松（路径/查询里可以出现几乎所有可见字符），
  /// 收紧的部分交给 [_stripTrailingPunctuation] 与调用方。
  static final RegExp _urlPattern = RegExp(
    r'https?://[^\s<>"'
    r"'"
    r']+',
    caseSensitive: false,
  );

  /// ANSI 转义序列（CSI，形如 `ESC [ ... 字母`）。
  ///
  /// 终端缓冲里保留了着色序列，而链接经常被 SGR 包裹（`\x1b[36m<url>\x1b[0m`）。
  /// 若不清除，正则会把这些不可见字节当成链接的一部分吸进去。所以匹配前先整体
  /// 剔除。
  static final RegExp _ansiPattern = RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]');

  /// 行尾出现这些字符时，认为 URL 可能未写完，下一行或许是续行。
  /// 覆盖 query/fragment/百分号编码/路径的分割点。
  static const _continuationEnders = {'?', '&', '=', '#', '%', '/', '+'};

  /// URL 尾部这些字符通常属于标点/引号而不是链接本身，需要剥离。
  static const _trailingJunk = {
    '.',
    ',',
    ';',
    ':',
    '!',
    '"',
    "'",
    '>',
    ')',
    ']',
    '}',
  };

  /// 提取文本中所有 http(s) 链接，按出现顺序返回。
  ///
  /// 会先做硬换行续行拼接，再做逐行正则匹配，最后归一化尾部标点。
  static List<ExtractedUrl> extract(String text) {
    if (text.isEmpty) return const [];

    // 先剔除着色/控制序列，否则 `\x1b[0m` 会被当成链接尾部字符吸进结果。
    final clean = text.replaceAll(_ansiPattern, '');

    final rejoined = _rejoinHardWrappedLines(clean);
    final results = <ExtractedUrl>[];

    for (final match in _urlPattern.allMatches(rejoined)) {
      final cleaned = _stripTrailingPunctuation(match.group(0)!);
      // 剥离后可能退化成 "https://" 这类空壳，直接丢弃。
      if (!_isUsable(cleaned)) continue;
      results.add(ExtractedUrl(url: cleaned, index: match.start));
    }

    return results;
  }

  /// 挑出最适合提供给用户复制的一条：最后出现的可用链接。
  ///
  /// 登录流程里最新的链接才是有效的（旧链接可能已失效），所以取最后一条。
  /// 没有任何可用链接时返回 null。
  static ExtractedUrl? pickBest(String text) {
    final all = extract(text);
    if (all.isEmpty) return null;
    return all.last;
  }

  /// 判断清洗后的字符串是否还像一个可用的链接。
  static bool _isUsable(String url) {
    if (url.length <= 'https://'.length) return false;
    // 必须有主机名部分（scheme 之后到第一个 / ? # 之前不能为空）。
    final afterScheme = url.substring(url.indexOf('://') + 3);
    var hostEnd = afterScheme.length;
    for (var i = 0; i < afterScheme.length; i++) {
      final c = afterScheme[i];
      if (c == '/' || c == '?' || c == '#') {
        hostEnd = i;
        break;
      }
    }
    final host = afterScheme.substring(0, hostEnd);
    return host.trim().isNotEmpty;
  }

  /// 剥离链接尾部的标点与引号。
  ///
  /// 只从尾部剥离；成对的括号只有在链接内不平衡时才剥离，避免破坏
  /// 合法路径（例如维基百科的 `..._(disambiguation)`）。
  static String _stripTrailingPunctuation(String raw) {
    var url = raw;
    while (url.isNotEmpty) {
      final last = url[url.length - 1];
      if (!_trailingJunk.contains(last)) break;

      // 成对判定：若字符是右括号且链接内存在更多左括号，说明它属于路径。
      if (last == ')') {
        final opens = '('.allMatches(url).length;
        final closes = ')'.allMatches(url).length;
        if (opens >= closes) break;
      }
      if (last == ']') {
        final opens = '['.allMatches(url).length;
        final closes = ']'.allMatches(url).length;
        if (opens >= closes) break;
      }
      if (last == '}') {
        final opens = '{'.allMatches(url).length;
        final closes = '}'.allMatches(url).length;
        if (opens >= closes) break;
      }

      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// 把被 CLI 自己插入的硬换行截断的 URL 拼回一行。
  ///
  /// 终端缓冲只有在 PTY **软换行**（auto-wrap）时才会标记 `isWrapped` 并自动
  /// 重接；如果登录命令自己在固定列宽处打了 `\n`，链接在缓冲文本里就是断开的。
  /// 这里做保守拼接：只有当前行看起来"没写完"、且下一行看起来是"续行"时才拼，
  /// 并且拼接结果必须仍能被正则当成**单个** URL 完整匹配，否则放弃（避免把两段
  /// 无关输出粘在一起）。
  static String _rejoinHardWrappedLines(String text) {
    final lines = text.split('\n');
    final out = <String>[];

    for (var i = 0; i < lines.length; i++) {
      var current = lines[i];

      // 只要下一行确实是在续写当前链接，就继续拼（一条长链接可能被截成多行）。
      while (i + 1 < lines.length && _looksIncomplete(current, lines[i + 1])) {
        current = current + lines[i + 1].trimLeft();
        i++;
      }

      out.add(current);
    }

    return out.join('\n');
  }

  /// 判断 [current] 是否可能被硬换行截断、且 [next] 是它的续行。
  static bool _looksIncomplete(String current, String next) {
    final currentMatch = _urlPattern.firstMatch(current);
    if (currentMatch == null) return false;

    final trimmedNext = next.trimLeft();
    if (trimmedNext.isEmpty) return false;

    // 下一行有缩进，通常说明是新的缩进块而不是 URL 续行。
    if (next.length != trimmedNext.length) return false;

    // 当前 URL 必须以"未写完"的字符结尾，否则它已经完整，不该再接。
    final urlTail = _stripTrailingPunctuation(currentMatch.group(0)!);
    if (urlTail.isEmpty) return false;
    if (!_continuationEnders.contains(urlTail[urlTail.length - 1])) {
      return false;
    }

    // 拼接后，接上前缀的那段必须仍然是一个完整 URL，且**链接被延长了**
    // （而不是把无关文本粘进来）。这样既能拼回被截断的链接，又不会误吞下一行。
    final candidate = current + trimmedNext;
    final candidateMatch = _urlPattern.firstMatch(candidate);
    if (candidateMatch == null || candidateMatch.start != currentMatch.start) {
      return false;
    }
    final candidateUrl = _stripTrailingPunctuation(candidateMatch.group(0)!);
    if (candidateUrl.length <= urlTail.length) return false;

    // 拼接结果必须覆盖到整行末尾之外——即续行确实被吸收了。
    return candidateMatch.end > currentMatch.end;
  }
}
