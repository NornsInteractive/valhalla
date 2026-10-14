import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart' show StringCharacters;

import 'server_profile.dart';

enum TerminalHistoryStatus { unknown, available, open, ended }

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

  const TerminalHistoryRecord({
    required this.id,
    required this.serverId,
    required this.targetKey,
    required this.remoteSessionName,
    required this.title,
    required this.createdAt,
    required this.lastUsedAt,
    this.isLegacy = false,
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
  }) => TerminalHistoryRecord(
    id: id,
    serverId: serverId,
    targetKey: targetKey,
    remoteSessionName: remoteSessionName,
    title: title ?? this.title,
    createdAt: createdAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    isLegacy: isLegacy ?? this.isLegacy,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'serverId': serverId,
    'targetKey': targetKey,
    'remoteSessionName': remoteSessionName,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lastUsedAt': lastUsedAt.toUtc().toIso8601String(),
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
    );
    if (record.id.isEmpty ||
        record.serverId.isEmpty ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(record.targetKey) ||
        !RegExp(
          r'^valhalla_[A-Za-z0-9_-]+$',
        ).hasMatch(record.remoteSessionName)) {
      throw const FormatException('TERMINAL_HISTORY_INVALID');
    }
    return record;
  }
}

@immutable
class TerminalHistorySnapshot {
  final List<TerminalHistoryRecord> records;
  final String? defaultRecordId;

  const TerminalHistorySnapshot({
    this.records = const [],
    this.defaultRecordId,
  });

  Map<String, Object?> toJson() => {
    'version': 1,
    'records': records
        .where((item) => !item.isLegacy)
        .map((item) => item.toJson())
        .toList(),
    'defaultRecordId': defaultRecordId,
  };

  factory TerminalHistorySnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
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
        records.map((item) => item.remoteSessionName).toSet().length !=
            records.length) {
      throw const FormatException('TERMINAL_HISTORY_INVALID');
    }
    return TerminalHistorySnapshot(
      records: List.unmodifiable(records),
      defaultRecordId: json['defaultRecordId'] as String?,
    );
  }
}
