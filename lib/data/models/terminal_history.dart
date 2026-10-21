import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart' show StringCharacters;

import 'server_profile.dart';
import 'tmux_socket_source.dart';

export 'tmux_socket_source.dart';

enum TerminalHistoryStatus { unknown, available, open, ended, unavailable }

/// Device-local metadata only; terminal output and authentication are never saved.
@immutable
class TerminalHistoryRecord {
  final String id;
  final String serverId;
  final String targetKey;
  final String remoteSessionName;
  final String title;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final bool isLegacy;
  final TmuxSocketSource socket;
  final TmuxSessionIdentity? identity;
  final bool isExternal;
  final int attachedClients;

  const TerminalHistoryRecord({
    required this.id,
    required this.serverId,
    required this.targetKey,
    required this.remoteSessionName,
    required this.title,
    required this.createdAt,
    required this.lastUsedAt,
    this.isLegacy = false,
    this.socket = TmuxSocketSource.app,
    this.identity,
    this.isExternal = false,
    this.attachedClients = 0,
  });

  static String targetFor(ServerProfile server) => sha256
      .convert(
        utf8.encode(
          jsonEncode([server.id, server.host, server.port, server.username]),
        ),
      )
      .toString();

  static String validateTitle(String value) {
    final title = value.trim();
    if (title.isEmpty ||
        title.characters.length > 64 ||
        RegExp(r'[\x00-\x1f\x7f-\x9f\u2028\u2029]').hasMatch(value)) {
      throw const FormatException('TERMINAL_TITLE_INVALID');
    }
    return title;
  }

  TerminalHistoryRecord copyWith({
    String? title,
    DateTime? lastUsedAt,
    bool? isLegacy,
    TmuxSessionIdentity? identity,
    int? attachedClients,
    String? remoteSessionName,
    TmuxSocketSource? socket,
  }) => TerminalHistoryRecord(
    id: id,
    serverId: serverId,
    targetKey: targetKey,
    remoteSessionName: remoteSessionName ?? this.remoteSessionName,
    title: title ?? this.title,
    createdAt: createdAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    isLegacy: isLegacy ?? this.isLegacy,
    socket: socket ?? this.socket,
    identity: identity ?? this.identity,
    isExternal: isExternal,
    attachedClients: attachedClients ?? this.attachedClients,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'serverId': serverId,
    'targetKey': targetKey,
    'remoteSessionName': remoteSessionName,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lastUsedAt': lastUsedAt.toUtc().toIso8601String(),
    'socket': socket.toJson(),
    if (identity != null) 'identity': identity!.toJson(),
    'isExternal': isExternal,
  };

  factory TerminalHistoryRecord.fromJson(Map<String, dynamic> json) {
    final record = TerminalHistoryRecord(
      id: json['id'] as String,
      serverId: json['serverId'] as String,
      targetKey: json['targetKey'] as String,
      remoteSessionName: json['remoteSessionName'] as String,
      title: validateTitle(json['title'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      socket: json['socket'] == null
          ? TmuxSocketSource.app
          : TmuxSocketSource.fromJson(
              Map<String, dynamic>.from(json['socket'] as Map),
            ),
      identity: json['identity'] == null
          ? null
          : TmuxSessionIdentity.fromJson(
              Map<String, dynamic>.from(json['identity'] as Map),
            ),
      isExternal: json['isExternal'] == true,
    );
    if (record.id.isEmpty ||
        record.serverId.isEmpty ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(record.targetKey) ||
        (record.identity == null &&
            !RegExp(
              r'^valhalla_[A-Za-z0-9_-]+$',
            ).hasMatch(record.remoteSessionName)) ||
        record.remoteSessionName.isEmpty ||
        RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(record.remoteSessionName)) {
      throw const FormatException('TERMINAL_HISTORY_INVALID');
    }
    if (record.identity == null &&
        record.socket.id != TmuxSocketSource.app.id) {
      throw const FormatException('TERMINAL_HISTORY_INVALID');
    }
    return record;
  }
}

@immutable
class TerminalHistorySnapshot {
  final List<TerminalHistoryRecord> records;
  final String? defaultRecordId;
  final List<String> forgottenSessionNames;
  final List<TmuxSocketSource> socketSources;
  final List<String> hiddenRecordIds;

  const TerminalHistorySnapshot({
    this.records = const [],
    this.defaultRecordId,
    this.forgottenSessionNames = const [],
    this.socketSources = const [],
    this.hiddenRecordIds = const [],
  });

  Map<String, Object?> toJson() => {
    'version': 2,
    'records': records
        .where((item) => !item.isLegacy)
        .map((item) => item.toJson())
        .toList(),
    'defaultRecordId': defaultRecordId,
    if (forgottenSessionNames.isNotEmpty)
      'forgottenSessionNames': forgottenSessionNames,
    'socketSources': socketSources.map((s) => s.toJson()).toList(),
    'hiddenRecordIds': hiddenRecordIds,
  };

  factory TerminalHistorySnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 && json['version'] != 2) {
      throw const FormatException('TERMINAL_HISTORY_INVALID');
    }
    final records = (json['records'] as List)
        .map(
          (item) => TerminalHistoryRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    if (records.map((item) => item.id).toSet().length != records.length ||
        records
                .map(
                  (item) =>
                      '${item.socket.id}/${item.identity?.key ?? item.remoteSessionName}',
                )
                .toSet()
                .length !=
            records.length) {
      throw const FormatException('TERMINAL_HISTORY_INVALID');
    }
    final forgotten = List<String>.from(
      json['forgottenSessionNames'] as List? ?? const [],
    );
    if (forgotten.any(
      (name) => !RegExp(r'^valhalla_[A-Za-z0-9_-]+$').hasMatch(name),
    )) {
      throw const FormatException('TERMINAL_HISTORY_INVALID');
    }
    return TerminalHistorySnapshot(
      records: List.unmodifiable(records),
      defaultRecordId: json['defaultRecordId'] as String?,
      forgottenSessionNames: List.unmodifiable(forgotten.toSet()),
      socketSources: List.unmodifiable(
        (json['socketSources'] as List? ?? []).map(
          (s) => TmuxSocketSource.fromJson(Map<String, dynamic>.from(s as Map)),
        ),
      ),
      hiddenRecordIds: List.unmodifiable(
        List<String>.from(json['hiddenRecordIds'] as List? ?? []),
      ),
    );
  }
}
