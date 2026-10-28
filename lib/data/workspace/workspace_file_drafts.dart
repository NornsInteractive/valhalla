import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../infrastructure/sftp/sftp_client_service.dart';
import '../models/remote_workspace.dart';
import '../models/server_profile.dart';
import '../storage/secure_storage_service.dart';
import 'workspace_chat_attachments.dart';
import 'workspace_gateway.dart';

/// Raised when an explicit file-draft restore cannot be honoured.
///
/// The code is stable so the editor/UI can map it without rendering an
/// exception message.
class WorkspaceFileDraftException implements Exception {
  final String code;
  const WorkspaceFileDraftException(this.code);
  @override
  String toString() => code;
}

/// Result of an explicit restore. [backupLocalKey] is the encrypted local key
/// that holds the draft replaced by this restore, when one existed.
class FileDraftRestoreResult {
  final String path;
  final String digest;
  final String content;
  final String? backupLocalKey;
  const FileDraftRestoreResult({
    required this.path,
    required this.digest,
    required this.content,
    this.backupLocalKey,
  });
}

/// A bounded, durable record of remote draft work that has not been accepted
/// by the gateway yet.
///
/// Only metadata is stored here. Draft text remains in encrypted storage; the
/// retry path re-reads it by [localKey]. This keeps plaintext out of
/// SharedPreferences and keeps the bookkeeping bounded.
class FileDraftIntentStore {
  static const int maxEntries = 100;
  static const String storageKey = 'valhalla_workspace_file_draft_outbox_v1';

  static Future<void> _tail = Future<void>.value();

  static Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<List<Map<String, dynamic>>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    if (decoded.isEmpty) return [];
    if (decoded.any((value) => value is! Map)) {
      throw const FormatException('WORKSPACE_LOCAL_STATE_CORRUPT');
    }
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _write(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(storageKey, jsonEncode(entries));
    if (!saved) throw StateError('WORKSPACE_DRAFT_INTENTS_WRITE_FAILED');
  }

  Future<void> upsert(Map<String, dynamic> intent) => _serial(() async {
    final entries = await _read();
    entries.removeWhere(
      (e) => e['serverId'] == intent['serverId'] && e['path'] == intent['path'],
    );
    if (entries.length >= maxEntries) {
      throw StateError('WORKSPACE_DRAFT_INTENT_FULL');
    }
    entries.add(intent);
    await _write(entries);
  });

  Future<List<Map<String, dynamic>>> pending(String serverId) =>
      _serial(() async {
        final entries = await _read();
        return entries
            .where((e) => e['serverId'] == serverId)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });

  Future<void> remove(String serverId, String path) => _serial(() async {
    final entries = await _read();
    entries.removeWhere((e) => e['serverId'] == serverId && e['path'] == path);
    await _write(entries);
  });

  /// Removes only the intent that was actually drained. A newer save/delete
  /// staged while the flush was in flight must survive.
  Future<void> removeIf(String serverId, String path, String token) =>
      _serial(() async {
        final entries = await _read();
        entries.removeWhere(
          (e) =>
              e['serverId'] == serverId &&
              e['path'] == path &&
              e['token'] == token,
        );
        await _write(entries);
      });

  /// Test/DI hook: discard all durable intents.
  Future<void> clear() => _serial(() async => _write(const []));
}

/// Per-device file-editor drafts stored in the server workspace.
///
/// The helper deliberately never touches SSH credentials or remote user files:
/// it only uploads the already-edited text to the workspace blob store and
/// commits a typed `draft` record. The remote id is
/// `<deviceId>/file/<sha256(path)>` and the value is
/// `{type: file, deviceId, path, digest, blob: {hash, size}}`, where `digest`
/// is the original remote revision (for stale-draft detection) and `blob.hash`
/// is the SHA-256 of the edited bytes.
class WorkspaceFileDrafts {
  static const int maxBytes = SftpClientService.maxPreviewBytes;

  final WorkspaceGateway gateway;
  final SecureStorageService secureStorage;
  final FileDraftIntentStore intents;
  final WorkspaceChatAttachments attachments;
  final void Function(String scope, Object error, StackTrace stack)?
  onDiagnostic;

  StreamSubscription<WorkspaceChange>? _changes;
  static Future<void> _flushTail = Future<void>.value();
  bool _disposed = false;

  WorkspaceFileDrafts({
    required this.gateway,
    required this.secureStorage,
    FileDraftIntentStore? intents,
    WorkspaceChatAttachments? attachments,
    this.onDiagnostic,
  }) : intents = intents ?? FileDraftIntentStore(),
       attachments = attachments ?? WorkspaceChatAttachments(gateway: gateway) {
    _changes = gateway.changes.listen((change) {
      if (_disposed) return;
      unawaited(
        flushPending(change.serverId).catchError((
          Object error,
          StackTrace stack,
        ) {
          _diagnose('sftp.draft.remote', error, stack);
          return false;
        }),
      );
    });
  }

  static bool isSha256(Object? value) =>
      value is String &&
      value.length == 64 &&
      RegExp(r'^[0-9a-f]+$').hasMatch(value);

  static String pathHash(String path) =>
      sha256.convert(utf8.encode(path)).toString();

  /// Remote record id. The path itself never appears in the id.
  static String remoteDraftId(String deviceId, String path) =>
      '$deviceId/file/${pathHash(path)}';

  /// Encrypted local editor draft key, matching the SFTP editor's key.
  static String localDraftKey(ServerProfile server, String path) => sha256
      .convert(utf8.encode('${server.connectionKey}\u0000$path'))
      .toString();

  /// Stable encrypted backup key used before an explicit restore replaces the
  /// current device's local draft.
  static String backupLocalDraftKey(ServerProfile server, String path) =>
      '${localDraftKey(server, path)}::backup';

  static bool _validPath(Object? value) =>
      value is String &&
      value.isNotEmpty &&
      value.length <= 4096 &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);

  static bool _validDevice(Object? value) =>
      value is String &&
      value.isNotEmpty &&
      value.length <= 128 &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);

  void _diagnose(String scope, Object error, StackTrace stack) {
    onDiagnostic?.call(scope, error, stack);
  }

  String _nextToken() => const Uuid().v4();

  /// Persists the intent to publish this device's draft. No network is used.
  Future<void> stageSave({
    required ServerProfile server,
    required String path,
    required String content,
    required String digest,
  }) async {
    if (!gateway.isEnabled(server.id)) return;
    if (!_validPath(path) || !isSha256(digest)) return;
    final size = utf8.encode(content).length;
    if (size > maxBytes) return;
    try {
      await intents.upsert({
        'serverId': server.id,
        'path': path,
        'localKey': localDraftKey(server, path),
        'deviceId': gateway.deviceId,
        'id': remoteDraftId(gateway.deviceId, path),
        'digest': digest,
        'size': size,
        'deleted': false,
        'token': _nextToken(),
        'updatedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
      });
    } catch (error, stack) {
      _diagnose('sftp.draft.remote.intent', error, stack);
    }
  }

  /// Persists a delete intent. Later saves on the same path replace it.
  Future<void> stageDelete({
    required ServerProfile server,
    required String path,
  }) async {
    if (!gateway.isEnabled(server.id)) return;
    if (!_validPath(path)) return;
    try {
      await intents.upsert({
        'serverId': server.id,
        'path': path,
        'localKey': localDraftKey(server, path),
        'deviceId': gateway.deviceId,
        'id': remoteDraftId(gateway.deviceId, path),
        'deleted': true,
        'token': _nextToken(),
        'updatedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
      });
    } catch (error, stack) {
      _diagnose('sftp.draft.remote.intent', error, stack);
    }
  }

  /// Stages and then tries to publish. Remote failures are diagnostic-only:
  /// the caller's local encrypted save has already succeeded.
  Future<void> saveDraft({
    required ServerProfile server,
    required String path,
    required String content,
    required String digest,
  }) async {
    await stageSave(
      server: server,
      path: path,
      content: content,
      digest: digest,
    );
    await flushPending(server.id);
  }

  Future<void> deleteDraft({
    required ServerProfile server,
    required String path,
  }) async {
    await stageDelete(server: server, path: path);
    await flushPending(server.id);
  }

  /// Drains durable intents for one server. Serialized so a save cannot
  /// overtake a later delete (or the reverse).
  Future<bool> flushPending(String serverId) {
    final next = _flushTail.then((_) => _flush(serverId));
    _flushTail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<bool> _flush(String serverId) async {
    if (!gateway.isEnabled(serverId)) return false;
    final List<Map<String, dynamic>> pending;
    try {
      pending = await intents.pending(serverId);
    } catch (error, stack) {
      // Corrupt or unreadable intent bookkeeping must stay untouched and stay
      // observable instead of silently resetting to an empty queue.
      _diagnose('sftp.draft.intent', error, stack);
      return false;
    }
    for (final raw in pending) {
      final intent = _Intent.fromJson(raw);
      if (intent == null) {
        await intents.remove(serverId, raw['path'] as String? ?? '');
        continue;
      }
      try {
        if (intent.deleted) {
          await gateway.putRecords(serverId, [
            {'kind': 'draft', 'id': intent.id, 'value': null, 'deleted': true},
          ]);
        } else {
          final local = await secureStorage.getFileEditorDraft(intent.localKey);
          final content = local?['content'];
          if (content is! String) {
            // The user discarded locally; never resurrect a stale draft.
            await intents.removeIf(serverId, intent.path, intent.token);
            continue;
          }
          final bytes = utf8.encode(content);
          if (bytes.length > maxBytes) {
            _diagnose(
              'sftp.draft.remote',
              StateError('SFTP_DRAFT_TOO_LARGE'),
              StackTrace.current,
            );
            await intents.removeIf(serverId, intent.path, intent.token);
            continue;
          }
          final hash = sha256.convert(bytes).toString();
          await attachments.uploadBytes(
            serverId,
            hash,
            Uint8List.fromList(bytes),
          );
          await gateway.putRecords(serverId, [
            {
              'kind': 'draft',
              'id': intent.id,
              'value': {
                'type': 'file',
                'deviceId': intent.deviceId,
                'path': intent.path,
                'digest': intent.digest,
                'blob': {'hash': hash, 'size': bytes.length},
              },
              'deleted': false,
            },
          ]);
        }
        await intents.removeIf(serverId, intent.path, intent.token);
      } catch (error, stack) {
        _diagnose('sftp.draft.remote', error, stack);
        return false;
      }
    }
    return true;
  }

  /// Finds this device's remote draft for [path]. Other devices' drafts are
  /// never returned, so they can never be hydrated automatically.
  Future<WorkspaceDraft?> findOwnDraft(
    ServerProfile server,
    String path,
  ) async {
    if (!gateway.isEnabled(server.id) || !_validPath(path)) return null;
    final id = remoteDraftId(gateway.deviceId, path);
    try {
      final response = await gateway.request(server.id, {
        'op': 'snapshot',
        'kind': 'draft',
        'id': id,
        'limit': 1,
      });
      if (response['ok'] == false) return null;
      final records = response['records'];
      if (records is! List) return null;
      for (final raw in records) {
        if (raw is! Map) continue;
        if (raw['id'] != id || raw['deleted'] == true) continue;
        final value = raw['value'];
        if (value is! Map) continue;
        final typed = Map<String, dynamic>.from(value);
        if (typed['type'] != 'file') continue;
        if (typed['deviceId'] != gateway.deviceId) continue;
        if (typed['path'] != path) continue;
        if (!isSha256(typed['digest'])) continue;
        return WorkspaceDraft(
          id: id,
          deviceId: gateway.deviceId,
          title: path,
          value: typed,
        );
      }
    } catch (error, stack) {
      _diagnose('sftp.draft.remote.fetch', error, stack);
    }
    return null;
  }

  /// Explicit user restore. Validates the record, hydrates the blob on demand,
  /// preserves any current local draft as an encrypted backup, and writes the
  /// local editor draft. It never writes a remote user file.
  Future<FileDraftRestoreResult> restore(
    ServerProfile server,
    WorkspaceDraft draft,
  ) async {
    final value = draft.value;
    final type = value['type'];
    final deviceId = value['deviceId'];
    final path = value['path'];
    final digest = value['digest'];
    final blob = value['blob'];
    if (type != 'file') {
      throw const WorkspaceFileDraftException('WORKSPACE_FILE_DRAFT_TYPE');
    }
    if (!_validDevice(deviceId)) {
      throw const WorkspaceFileDraftException('WORKSPACE_FILE_DRAFT_DEVICE');
    }
    if (!_validPath(path)) {
      throw const WorkspaceFileDraftException('WORKSPACE_FILE_DRAFT_PATH');
    }
    if (!isSha256(digest)) {
      throw const WorkspaceFileDraftException('WORKSPACE_FILE_DRAFT_DIGEST');
    }
    if (draft.id != remoteDraftId(deviceId as String, path as String)) {
      throw const WorkspaceFileDraftException('WORKSPACE_FILE_DRAFT_ID');
    }
    if (draft.deviceId.isNotEmpty && draft.deviceId != deviceId) {
      throw const WorkspaceFileDraftException('WORKSPACE_FILE_DRAFT_DEVICE');
    }
    if (blob is! Map) {
      throw const WorkspaceFileDraftException('WORKSPACE_FILE_DRAFT_BLOB');
    }
    final hash = blob['hash'];
    final size = blob['size'];
    if (!isSha256(hash)) {
      throw const WorkspaceFileDraftException('WORKSPACE_FILE_DRAFT_HASH');
    }
    if (size is! int || size < 0 || size > maxBytes) {
      throw const WorkspaceFileDraftException('WORKSPACE_FILE_DRAFT_SIZE');
    }

    final bytes = await attachments.downloadBytes(
      server.id,
      hash as String,
      size,
    );
    if (bytes.length != size) {
      throw const WorkspaceFileDraftException('WORKSPACE_FILE_DRAFT_SIZE');
    }
    final content = utf8.decode(bytes);

    final localKey = localDraftKey(server, path);
    final existing = await secureStorage.getFileEditorDraft(localKey);
    String? backupKey;
    if (existing != null &&
        !(existing['content'] == content && existing['digest'] == digest)) {
      backupKey = backupLocalDraftKey(server, path);
      await secureStorage.saveFileEditorDraft(backupKey, {
        ...existing,
        'backedUpAt': DateTime.now().toUtc().toIso8601String(),
        'replacedDraftId': draft.id,
      });
    }
    await secureStorage.saveFileEditorDraft(localKey, {
      'content': content,
      'digest': digest,
    });
    return FileDraftRestoreResult(
      path: path,
      digest: digest as String,
      content: content,
      backupLocalKey: backupKey,
    );
  }

  void dispose() {
    _disposed = true;
    unawaited(_changes?.cancel());
    _changes = null;
  }
}

class _Intent {
  final String serverId;
  final String path;
  final String localKey;
  final String deviceId;
  final String id;
  final String digest;
  final bool deleted;
  final String token;

  const _Intent({
    required this.serverId,
    required this.path,
    required this.localKey,
    required this.deviceId,
    required this.id,
    required this.digest,
    required this.deleted,
    required this.token,
  });

  static _Intent? fromJson(Map<String, dynamic> raw) {
    final serverId = raw['serverId'];
    final path = raw['path'];
    final localKey = raw['localKey'];
    final deviceId = raw['deviceId'];
    final id = raw['id'];
    final digest = raw['digest'];
    final token = raw['token'];
    final deleted = raw['deleted'] == true;
    if (serverId is! String ||
        path is! String ||
        localKey is! String ||
        deviceId is! String ||
        id is! String ||
        token is! String ||
        (!deleted && digest is! String)) {
      return null;
    }
    return _Intent(
      serverId: serverId,
      path: path,
      localKey: localKey,
      deviceId: deviceId,
      id: id,
      digest: deleted ? '' : digest as String,
      deleted: deleted,
      token: token,
    );
  }
}
