import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

enum TmuxSocketKind { app, standard, named, path }

@immutable
class TmuxSocketSource {
  final TmuxSocketKind kind;
  final String value;
  const TmuxSocketSource._(this.kind, this.value);
  static const app = TmuxSocketSource._(TmuxSocketKind.app, 'valhalla');
  static const standard = TmuxSocketSource._(
    TmuxSocketKind.standard,
    'default',
  );

  factory TmuxSocketSource.named(String name) {
    // 允许字母数字、下划线、连字符与点号：tmux 的 `-L <name>` 实际接受点号
    // （例如 `team.alpha`），发现阶段不能把这类合法 socket 漏掉。
    if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(name)) {
      throw const FormatException('TMUX_INVALID_SOCKET');
    }
    if (name == 'valhalla') return app;
    if (name == 'default') return standard;
    return TmuxSocketSource._(TmuxSocketKind.named, name);
  }

  factory TmuxSocketSource.path(String path) {
    if (!path.startsWith('/') ||
        path.length > 1024 ||
        RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(path) ||
        path.split('/').contains('..')) {
      throw const FormatException('TMUX_INVALID_SOCKET');
    }
    return TmuxSocketSource._(TmuxSocketKind.path, path);
  }

  String get id => '${kind.name}:$value';
  bool get isBuiltin =>
      kind == TmuxSocketKind.app || kind == TmuxSocketKind.standard;
  Map<String, Object> toJson() => {'kind': kind.name, 'value': value};
  factory TmuxSocketSource.fromJson(Map<String, dynamic> json) {
    final value = json['value'] as String;
    return switch (json['kind']) {
      'app' when value == 'valhalla' => app,
      'standard' when value == 'default' => standard,
      'named' => TmuxSocketSource.named(value),
      'path' => TmuxSocketSource.path(value),
      _ => throw const FormatException('TMUX_INVALID_SOCKET'),
    };
  }
}

@immutable
class TmuxSessionIdentity {
  final String sessionId;
  final int createdSeconds;
  final int serverPid;
  final String socketPath;
  const TmuxSessionIdentity({
    required this.sessionId,
    required this.createdSeconds,
    required this.serverPid,
    required this.socketPath,
  });

  String get key =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();
  Map<String, Object> toJson() => {
    'sessionId': sessionId,
    'createdSeconds': createdSeconds,
    'serverPid': serverPid,
    'socketPath': socketPath,
  };
  factory TmuxSessionIdentity.fromJson(Map<String, dynamic> json) {
    final result = TmuxSessionIdentity(
      sessionId: json['sessionId'] as String,
      createdSeconds: json['createdSeconds'] as int,
      serverPid: json['serverPid'] as int,
      socketPath: json['socketPath'] as String,
    );
    result.validate();
    return result;
  }
  void validate() {
    if (!RegExp(r'^\$[0-9]+$').hasMatch(sessionId) ||
        createdSeconds < 0 ||
        createdSeconds > 8640000000000 ||
        serverPid <= 0 ||
        !socketPath.startsWith('/') ||
        RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(socketPath)) {
      throw const FormatException('TMUX_INVALID_IDENTITY');
    }
  }
}
