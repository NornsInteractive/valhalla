import 'dart:convert';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import '../models/server_profile.dart';
import '../models/nas_source.dart';
import '../models/terminal_history.dart';
import '../storage/local_storage_service.dart';

/// An explicit configuration allowlist: cache/credentials/trust never enter a
/// workspace.
///
/// Global arrays (quick commands, NAS sources) have no server field, so a
/// local ownership map keeps one workspace from inheriting or publishing
/// another workspace's entries. Ownership is local metadata and is never
/// exported to the remote store.
class WorkspaceConfigCodec {
  final LocalStorageService storage;
  final ServerProfile server;
  final String deviceId, deviceClass;
  final bool includePreferences;

  /// True only for a first migration/preview. Unowned global entries are
  /// included and then claimed by [claimOwnership].
  final bool claimUnowned;

  WorkspaceConfigCodec(
    this.storage,
    this.server,
    this.deviceId,
    this.deviceClass, {
    required this.includePreferences,
    this.claimUnowned = false,
  });

  static const ownershipKey = 'valhalla_workspace_ownership_v1';
  static const arrays = {
    'valhalla_agents_v1': 'agent',
    'valhalla_quick_commands_v1': 'command',
    'valhalla_nas_sources_v1': 'nas_source',
  };
  static const globalKinds = {'command', 'nas_source'};
  static const maps = {
    'valhalla_chat_run_defaults_v1',
    'valhalla_cli_run_settings_v1',
    'valhalla_chat_launch_preferences_v1',
    'valhalla_chat_last_sessions_v1',
    'valhalla_acp_sessions_v1',
    'valhalla_nas_scan_configs_v1',
    'valhalla_nas_last_scans_v1',
  };
  static const scoped = [
    'valhalla_file_bookmarks::',
    'valhalla_recent_directories::',
    'valhalla_default_agent_acp::',
    'valhalla_default_agent_cli::',
    'valhalla_share_agent_sessions::',
    'valhalla_container_shell::',
    'valhalla_terminal_history_v1::',
    'valhalla_terminal_history_v2::',
    'valhalla_terminal_default_v1::',
    'valhalla_terminal_default_v2::',
    'valhalla_terminal_sockets_v1::',
    'valhalla_composer_v1::',
    'valhalla_chat_workspace_v1::',
    'valhalla_app_center_v1::',
    'valhalla_agent_update_v1::',
  ];
  String get terminalKey => TerminalHistoryRecord.targetFor(server);
  String get applicationKey =>
      sha256.convert(utf8.encode(server.connectionKey.toString())).toString();

  String _atom(String s, bool remote) {
    final pairs = {
      server.id: '@server',
      terminalKey: '@terminal',
      applicationKey: '@target',
    };
    final mapping = remote
        ? pairs
        : {for (final e in pairs.entries) e.value: e.key};
    if (mapping.containsKey(s)) return mapping[s]!;
    if (s.startsWith('[') || s.startsWith('{')) {
      try {
        return jsonEncode(_keyJson(jsonDecode(s), remote));
      } on FormatException {
        /* Literal text. */
      }
    }
    return s;
  }

  Object? _keyJson(Object? value, bool remote) {
    if (value is List) return value.map((x) => _keyJson(x, remote)).toList();
    if (value is String) return _atom(value, remote);
    return value;
  }

  Object? _map(Object? value, bool remote) {
    if (value is Map) {
      return {
        for (final e in value.entries)
          _key(e.key as String, remote):
              const {
                    'serverId',
                    'sshServerId',
                    'serverKey',
                    'targetKey',
                  }.contains(e.key) &&
                  e.value is String
              ? _atom(e.value as String, remote)
              : _map(e.value, remote),
      };
    }
    if (value is List) return value.map((x) => _map(x, remote)).toList();
    return value;
  }

  String _key(String value, bool remote) =>
      value.split('::').map((s) => _atom(s, remote)).join('::');

  Map<String, dynamic> record(String kind, String id, Object? value) => {
    'kind': kind,
    'id': id,
    'value': value,
  };

  Map<String, dynamic> _ownership() {
    final raw = storage.workspacePreferences.getString(ownershipKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final value = jsonDecode(raw);
      if (value is Map) return Map<String, dynamic>.from(value);
    } on FormatException {
      throw const FormatException('WORKSPACE_LOCAL_CORRUPT');
    }
    throw const FormatException('WORKSPACE_LOCAL_CORRUPT');
  }

  Future<void> _setOwner(String kind, String id, String? owner) async {
    if (!globalKinds.contains(kind)) return;
    final values = _ownership();
    final key = '$kind/$id';
    if (owner == null) {
      if (values.remove(key) == null) return;
    } else {
      if (values[key] == owner) return;
      values[key] = owner;
    }
    await storage.workspacePreferences.hydrate(() async {
      if (!await storage.workspacePreferences.setString(
        ownershipKey,
        jsonEncode(values),
      )) {
        throw StateError('WORKSPACE_LOCAL_SAVE_FAILED');
      }
    });
  }

  /// Claims every currently unowned command/NAS source for this workspace.
  /// Entries already owned by another server are left untouched.
  Future<void> claimOwnership() async {
    final prefs = storage.workspacePreferences;
    final owned = _ownership();
    var changed = false;
    for (final entry in arrays.entries) {
      final kind = entry.value;
      if (!globalKinds.contains(kind)) continue;
      final raw = prefs.getString(entry.key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final values = jsonDecode(raw);
        if (values is! List) continue;
        for (final value in values) {
          if (value is! Map) continue;
          final id = value['id'];
          if (id is! String || id.isEmpty) continue;
          if (kind == 'nas_source' &&
              value['sshServerId'] != null &&
              value['sshServerId'] != server.id) {
            continue;
          }
          final key = '$kind/$id';
          if (owned[key] == null) {
            owned[key] = server.id;
            changed = true;
          }
        }
      } on FormatException {
        // Leave corrupt local arrays untouched; export/apply will report it.
      }
    }
    if (!changed) return;
    await prefs.hydrate(() async {
      if (!await prefs.setString(ownershipKey, jsonEncode(owned))) {
        throw StateError('WORKSPACE_LOCAL_SAVE_FAILED');
      }
    });
  }

  Map<String, Map<String, dynamic>> export() {
    final out = <String, Map<String, dynamic>>{};
    void add(Map<String, dynamic> r) {
      out['${r['kind']}\x00${r['id']}'] = r;
    }

    final prefs = storage.workspacePreferences;
    final ownership = _ownership();
    for (final key in prefs.getKeys()) {
      final raw = prefs.get(key);
      if (arrays.containsKey(key) && raw is String) {
        final values = jsonDecode(raw) as List;
        for (final value in values) {
          final item = Map<String, dynamic>.from(value as Map);
          final kind = arrays[key]!;
          if (key == 'valhalla_agents_v1' && item['serverId'] != server.id) {
            continue;
          }
          if (key == 'valhalla_nas_sources_v1' &&
              item['sshServerId'] != null &&
              item['sshServerId'] != server.id) {
            continue;
          }
          if (globalKinds.contains(kind)) {
            final owner = ownership['$kind/${item['id']}'];
            if (owner is String && owner != server.id) continue;
            if (owner == null && !claimUnowned) continue;
          }
          add(
            record('config', '$kind/${item['id']}', {
              'storageKey': key,
              'item': _map(item, true),
            }),
          );
        }
      } else if (maps.contains(key) && raw is String) {
        final values = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in values.entries) {
          if (!_ownedMapEntry(key, e.key)) continue;
          add(
            record('config', '$key/${_key(e.key, true)}', {
              'storageKey': key,
              'entryKey': _key(e.key, true),
              'item': _map(e.value, true),
            }),
          );
        }
      } else if (key.startsWith('valhalla_chat_draft_v1::')) {
        if (!_ownedKey(key)) continue;
        add(
          record('draft', '$deviceId/${_key(key, true)}', {
            'key': _key(key, true),
            'deviceId': deviceId,
            'value': _encoded(raw, true),
          }),
        );
      } else if (scoped.any(key.startsWith) && _ownedKey(key)) {
        // Installation task forms can contain secrets; only deployed metadata
        // and sources sync.
        if (key.startsWith('valhalla_app_center_v1::') &&
            !key.contains('::deployments::')) {
          continue;
        }
        add(
          record('config', _key(key, true), {
            'key': _key(key, true),
            'value': _encoded(raw, true),
          }),
        );
      } else if (key == 'valhalla_app_center_v1::sources::global') {
        add(record('config', key, {'key': key, 'value': _encoded(raw, true)}));
      } else if (includePreferences &&
          (LocalStorageService.configurationPreferenceTypes.containsKey(key) ||
              key == 'valhalla_app_store_view_mode_v1')) {
        add(
          record('preference', '$deviceClass/$key', {'key': key, 'value': raw}),
        );
      }
    }
    return out;
  }

  bool _ownedMapEntry(
    String storageKey,
    String entry, {
    bool incoming = false,
  }) {
    if (storageKey != 'valhalla_nas_scan_configs_v1' &&
        storageKey != 'valhalla_nas_last_scans_v1') {
      return _ownedKey(entry);
    }
    if (entry.isEmpty ||
        entry.length > 512 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(entry)) {
      return false;
    }
    final sources =
        jsonDecode(
              storage.workspacePreferences.getString(
                    'valhalla_nas_sources_v1',
                  ) ??
                  '[]',
            )
            as List;
    for (final source in sources.whereType<Map>()) {
      if (source['id'] != entry) continue;
      final owner = source['sshServerId'] ?? _ownership()['nas_source/$entry'];
      return owner == server.id || owner == null && (incoming || claimUnowned);
    }
    // A source definition may follow its rules later in the same remote page.
    return incoming;
  }

  bool _ownedKey(String key) {
    if (key
        .split('::')
        .any(
          (p) => p == server.id || p == terminalKey || p == applicationKey,
        )) {
      return true;
    }
    final i = key.indexOf('::');
    final tail = i < 0 ? key : key.substring(i + 2);
    try {
      final v = jsonDecode(tail);
      return v is List && v.isNotEmpty && v.first == server.id;
    } on FormatException {
      return false;
    }
  }

  Object? _encoded(Object? value, bool remote) {
    if (value is! String) return _map(value, remote);
    try {
      return {'json': _map(jsonDecode(value), remote)};
    } on FormatException {
      return {'string': value};
    }
  }

  Object? _decoded(Object? value) {
    if (value is Map && value.containsKey('json')) {
      return jsonEncode(_map(value['json'], false));
    }
    if (value is Map && value.containsKey('string')) return value['string'];
    return _map(value, false);
  }

  /// Whether this codec is responsible for the record at all.
  ///
  /// Other devices' drafts and other device classes' preferences are skipped
  /// without being staged locally. Malformed records for this workspace are
  /// *not* skipped here: [apply] validates them and throws.
  bool handles(Map<String, dynamic> r, {bool restoreDraft = false}) {
    final kind = r['kind'];
    final id = r['id'];
    if (kind is! String || id is! String) return false;
    if (kind == 'preference') {
      return includePreferences && id.startsWith('$deviceClass/');
    }
    if (kind == 'draft') {
      if (id.contains('/file/')) return false;
      if (!restoreDraft && id.contains('::backup::')) return false;
      if (restoreDraft) return true;
      final value = r['value'];
      return value is Map && value['deviceId'] == deviceId;
    }
    return kind == 'config';
  }

  (String, String)? _draftIdParts(String id) {
    final slash = id.indexOf('/');
    if (slash <= 0 || slash == id.length - 1) return null;
    return (id.substring(0, slash), id.substring(slash + 1));
  }

  /// Structural validation without writing. Callers validate before caching a
  /// remote record, so a malformed record can never be silently skipped on a
  /// retry just because its version is already in the cache.
  void validate(Map<String, dynamic> r, {bool restoreDraft = false}) {
    final kind = r['kind'];
    final id = r['id'];
    if (kind is! String || id is! String) {
      throw const FormatException('WORKSPACE_RECORD_INVALID');
    }
    final rawValue = r['value'];
    if (rawValue != null && rawValue is! Map) {
      throw const FormatException('WORKSPACE_VALUE_INVALID');
    }
    final value = Map<String, dynamic>.from(rawValue as Map? ?? {});
    if (kind == 'preference') {
      if (!includePreferences || !id.startsWith('$deviceClass/')) {
        throw const FormatException('WORKSPACE_SCOPE_INVALID');
      }
      final suffix = id.substring(deviceClass.length + 1);
      final key = value['key'] as String? ?? suffix;
      if (value.containsKey('key') && value['key'] != suffix) {
        throw const FormatException('WORKSPACE_KEY_INVALID');
      }
      if (id != '$deviceClass/$key' ||
          (!LocalStorageService.configurationPreferenceTypes.containsKey(key) &&
              key != 'valhalla_app_store_view_mode_v1')) {
        throw const FormatException('WORKSPACE_KEY_INVALID');
      }
      return;
    }
    if (kind == 'config') {
      final storageKey = value['storageKey'];
      if (storageKey is String) {
        if (arrays.containsKey(storageKey)) {
          final kindName = arrays[storageKey]!;
          final item = value['item'];
          if (item != null && item is! Map) {
            throw const FormatException('WORKSPACE_VALUE_INVALID');
          }
          final itemMap = Map<String, dynamic>.from(item as Map? ?? {});
          final itemId = itemMap['id'] ?? id.substring(id.indexOf('/') + 1);
          if (itemId is! String || itemId.isEmpty) {
            throw const FormatException('WORKSPACE_ID_INVALID');
          }
          if (id != '$kindName/$itemId') {
            throw const FormatException('WORKSPACE_KEY_INVALID');
          }
          if (storageKey == 'valhalla_agents_v1') {
            final sid = itemMap['serverId'];
            if (sid != null && sid != '@server' && sid != server.id) {
              throw const FormatException('WORKSPACE_SCOPE_INVALID');
            }
          }
          if (storageKey == 'valhalla_nas_sources_v1') {
            final sid = itemMap['sshServerId'];
            if (sid != null && sid != '@server' && sid != server.id) {
              throw const FormatException('WORKSPACE_SCOPE_INVALID');
            }
          }
          return;
        }
        if (maps.contains(storageKey)) {
          final entryKey = value['entryKey'];
          if (entryKey is! String || id != '$storageKey/$entryKey') {
            throw const FormatException('WORKSPACE_KEY_INVALID');
          }
          if (!_ownedMapEntry(
            storageKey,
            _key(entryKey, false),
            incoming: true,
          )) {
            throw const FormatException('WORKSPACE_SCOPE_INVALID');
          }
          return;
        }
        throw const FormatException('WORKSPACE_KEY_INVALID');
      }
      final key = value['key'];
      if (key is! String || id != key) {
        throw const FormatException('WORKSPACE_KEY_INVALID');
      }
      final localKey = _key(key, false);
      if (!(scoped.any(localKey.startsWith) && _ownedKey(localKey)) &&
          localKey != 'valhalla_app_center_v1::sources::global') {
        throw const FormatException('WORKSPACE_KEY_INVALID');
      }
      return;
    }
    if (kind == 'draft') {
      final parts = _draftIdParts(id);
      if (parts == null) throw const FormatException('WORKSPACE_ID_INVALID');
      final (recordDevice, key) = parts;
      if (!restoreDraft && recordDevice != deviceId) {
        throw const FormatException('WORKSPACE_SCOPE_INVALID');
      }
      if (value['key'] != key || value['deviceId'] != recordDevice) {
        throw const FormatException('WORKSPACE_KEY_INVALID');
      }
      final localKey = _key(key, false);
      if (!localKey.startsWith('valhalla_chat_draft_v1::') ||
          !_ownedKey(localKey)) {
        throw const FormatException('WORKSPACE_SCOPE_INVALID');
      }
      return;
    }
    throw const FormatException('WORKSPACE_KIND_UNKNOWN');
  }

  Future<List<dynamic>> _decodeList(String raw) async {
    if (raw.length > 256 * 1024) {
      return Isolate.run(() => jsonDecode(raw) as List);
    }
    return jsonDecode(raw) as List;
  }

  Future<Map<String, dynamic>> _decodeMap(String raw) async {
    if (raw.length > 256 * 1024) {
      return Isolate.run(() => jsonDecode(raw) as Map<String, dynamic>);
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> apply(
    Map<String, dynamic> r, {
    bool restoreDraft = false,
  }) async {
    final kind = r['kind'];
    final id = r['id'];
    if (kind is! String || id is! String) {
      throw const FormatException('WORKSPACE_RECORD_INVALID');
    }
    final deleted = r['deleted'] == true;
    final rawValue = r['value'];
    if (rawValue != null && rawValue is! Map) {
      throw const FormatException('WORKSPACE_VALUE_INVALID');
    }
    final value = Map<String, dynamic>.from(rawValue as Map? ?? {});
    final prefs = storage.workspacePreferences;
    if (kind == 'preference') {
      if (!includePreferences || !id.startsWith('$deviceClass/')) return;
      final suffix = id.substring(deviceClass.length + 1);
      final key = value['key'] as String? ?? suffix;
      if (value.containsKey('key') && value['key'] != suffix) {
        throw const FormatException('WORKSPACE_KEY_INVALID');
      }
      if (id != '$deviceClass/$key' ||
          (!LocalStorageService.configurationPreferenceTypes.containsKey(key) &&
              key != 'valhalla_app_store_view_mode_v1')) {
        throw const FormatException('WORKSPACE_KEY_INVALID');
      }
      await _write(key, deleted ? null : value['value']);
    } else if (kind == 'config') {
      final storageKey = value['storageKey'];
      if (storageKey is String) {
        if (arrays.containsKey(storageKey)) {
          final kindName = arrays[storageKey]!;
          final item = value['item'];
          if (item != null && item is! Map) {
            throw const FormatException('WORKSPACE_VALUE_INVALID');
          }
          final itemMap = Map<String, dynamic>.from(item as Map? ?? {});
          final itemId = itemMap['id'] ?? id.substring(id.indexOf('/') + 1);
          if (itemId is! String || itemId.isEmpty) {
            throw const FormatException('WORKSPACE_ID_INVALID');
          }
          if (id != '$kindName/$itemId') {
            throw const FormatException('WORKSPACE_KEY_INVALID');
          }
          if (storageKey == 'valhalla_agents_v1') {
            final sid = itemMap['serverId'];
            if (sid != null && sid != '@server' && sid != server.id) {
              throw const FormatException('WORKSPACE_SCOPE_INVALID');
            }
          }
          final values = (await _decodeList(
            prefs.getString(storageKey) ?? '[]',
          )).map((x) => Map<String, dynamic>.from(x as Map)).toList();
          final decoded = Map<String, dynamic>.from(
            _map(itemMap, false) as Map? ?? {},
          );
          if (storageKey == 'valhalla_nas_sources_v1') {
            final previous = values.where((x) => x['id'] == itemId).firstOrNull;
            final binding = nasCredentialBindingKey(itemId);
            // Bind legacy secrets to their old target before remote metadata replaces it.
            if (previous != null &&
                !prefs.raw.containsKey(binding) &&
                !await prefs.raw.setString(
                  binding,
                  nasCredentialTarget(NasSource.fromJson(previous)),
                )) {
              throw StateError('WORKSPACE_LOCAL_SAVE_FAILED');
            }
          }
          values.removeWhere(
            (x) =>
                x['id'] == itemId &&
                (storageKey != 'valhalla_agents_v1' ||
                    x['serverId'] == server.id),
          );
          if (!deleted) values.add(decoded);
          await _write(storageKey, jsonEncode(values));
          await _setOwner(kindName, itemId, deleted ? null : server.id);
        } else if (maps.contains(storageKey)) {
          final entryKey = value['entryKey'];
          if (entryKey is! String || id != '$storageKey/$entryKey') {
            throw const FormatException('WORKSPACE_KEY_INVALID');
          }
          final entry = _key(entryKey, false);
          if (!_ownedMapEntry(storageKey, entry, incoming: true)) {
            throw const FormatException('WORKSPACE_SCOPE_INVALID');
          }
          final values = await _decodeMap(prefs.getString(storageKey) ?? '{}');
          if (deleted) {
            values.remove(entry);
          } else {
            values[entry] = _map(value['item'], false);
          }
          await _write(storageKey, jsonEncode(values));
        } else {
          throw const FormatException('WORKSPACE_KEY_INVALID');
        }
      } else {
        final key = value['key'] as String? ?? id;
        if (id != key) throw const FormatException('WORKSPACE_KEY_INVALID');
        final localKey = _key(key, false);
        if (!(scoped.any(localKey.startsWith) && _ownedKey(localKey)) &&
            localKey != 'valhalla_app_center_v1::sources::global') {
          throw const FormatException('WORKSPACE_KEY_INVALID');
        }
        await _write(localKey, deleted ? null : _decoded(value['value']));
      }
    } else if (kind == 'draft') {
      final parts = _draftIdParts(id);
      if (parts == null) throw const FormatException('WORKSPACE_ID_INVALID');
      final (recordDevice, key) = parts;
      if (!restoreDraft && recordDevice != deviceId) return;
      if (value['key'] != key || value['deviceId'] != recordDevice) {
        throw const FormatException('WORKSPACE_KEY_INVALID');
      }
      final localKey = _key(key, false);
      if (!localKey.startsWith('valhalla_chat_draft_v1::') ||
          !_ownedKey(localKey)) {
        throw const FormatException('WORKSPACE_SCOPE_INVALID');
      }
      await _write(localKey, deleted ? null : _decoded(value['value']));
    } else {
      throw const FormatException('WORKSPACE_KIND_UNKNOWN');
    }
  }

  Future<void> _write(String key, Object? value) async {
    final p = storage.workspacePreferences;
    await p.hydrate(() async {
      final ok = switch (value) {
        null => await p.remove(key),
        String v => await p.setString(key, v),
        bool v => await p.setBool(key, v),
        int v => await p.setInt(key, v),
        double v => await p.setDouble(key, v),
        List v => await p.setStringList(key, v.cast<String>()),
        _ => throw const FormatException('WORKSPACE_VALUE_INVALID'),
      };
      if (!ok) throw StateError('WORKSPACE_LOCAL_SAVE_FAILED');
    });
  }
}
