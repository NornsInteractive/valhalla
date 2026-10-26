import 'package:path/path.dart' as p;

enum ChatLinkKind { web, mail, remoteFile, anchor, unsupported }

class ChatLinkTarget {
  final ChatLinkKind kind;
  final Uri? uri;
  final String? path;
  final int? line;
  final bool outsideWorkspace;
  const ChatLinkTarget(
    this.kind, {
    this.uri,
    this.path,
    this.line,
    this.outsideWorkspace = false,
  });

  static ChatLinkTarget parse(
    String value, {
    required String workingDirectory,
  }) {
    final raw = value.trim();
    if (raw.isEmpty || RegExp(r'[\x00-\x1f\x7f]').hasMatch(raw)) {
      return const ChatLinkTarget(ChatLinkKind.unsupported);
    }
    if (raw.startsWith('#')) {
      return ChatLinkTarget(ChatLinkKind.anchor, path: raw.substring(1));
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) return const ChatLinkTarget(ChatLinkKind.unsupported);
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty) {
      return ChatLinkTarget(ChatLinkKind.web, uri: uri);
    }
    if (uri.scheme == 'mailto' && uri.path.isNotEmpty) {
      return ChatLinkTarget(ChatLinkKind.mail, uri: uri);
    }
    // A path:line suffix is a file reference, not a custom URI scheme.
    final reference = RegExp(
      r'^(.*?)(?::([1-9][0-9]*)(?::[1-9][0-9]*)?|#L([1-9][0-9]*))?$',
    ).firstMatch(raw)!;
    var file = reference.group(1)!;
    final line = int.tryParse(reference.group(2) ?? reference.group(3) ?? '');
    final fileUri = Uri.tryParse(file);
    if (fileUri == null ||
        (fileUri.hasScheme && fileUri.scheme != 'file') ||
        (fileUri.scheme == 'file' && fileUri.host.isNotEmpty)) {
      return const ChatLinkTarget(ChatLinkKind.unsupported);
    }
    try {
      file = fileUri.scheme == 'file'
          ? fileUri.path
          : Uri.decodeComponent(file);
    } on FormatException {
      return const ChatLinkTarget(ChatLinkKind.unsupported);
    }
    if (file.isEmpty ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(file) ||
        !p.posix.isAbsolute(workingDirectory)) {
      return const ChatLinkTarget(ChatLinkKind.unsupported);
    }
    final root = p.posix.normalize(workingDirectory);
    final resolved = p.posix.normalize(
      p.posix.isAbsolute(file) ? file : p.posix.join(root, file),
    );
    return ChatLinkTarget(
      ChatLinkKind.remoteFile,
      path: resolved,
      line: line,
      outsideWorkspace: resolved != root && !p.posix.isWithin(root, resolved),
    );
  }

  bool get isRemoteLoopback =>
      kind == ChatLinkKind.web &&
      const ['localhost', '127.0.0.1', '::1'].contains(uri!.host.toLowerCase());
}
