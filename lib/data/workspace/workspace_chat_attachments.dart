import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/chat_session.dart';
import '../../infrastructure/acp/acp_attachment_store.dart';
import 'workspace_gateway.dart';

/// Portable attachment reference stored inside remote chat records.
///
/// `localPath` is device-local and must never be treated as portable. A remote
/// attachment is identified by the SHA-256 of its bytes and is downloaded only
/// when the user actually opens it.
const String kWorkspaceBlobUriPrefix = 'workspace-blob:';

/// Maximum decoded bytes per `blob_put` / `blob_get` chunk (backend limit).
const int kWorkspaceBlobChunkBytes = 256 * 1024;

/// Uploads and hydrates chat attachments through the workspace blob ops.
///
/// The helper is deliberately independent of the UI and of the chat database:
/// the repository calls it only while staging a remote record or when the UI
/// explicitly asks to open an attachment.
class WorkspaceChatAttachments {
  final WorkspaceGateway gateway;
  final AcpAttachmentStore _store;
  final String? directory;

  WorkspaceChatAttachments({
    required this.gateway,
    AcpAttachmentStore? store,
    this.directory,
  }) : _store = store ?? AcpAttachmentStore(directory: directory);

  static String? hashOf(ChatAttachment attachment) {
    final uri = attachment.uri;
    if (uri != null && uri.startsWith(kWorkspaceBlobUriPrefix)) {
      final hash = uri.substring(kWorkspaceBlobUriPrefix.length);
      if (_isSha256(hash)) return hash;
    }
    // An attachment id is the content hash when produced by AcpAttachmentStore.
    if (_isSha256(attachment.id)) return attachment.id;
    return null;
  }

  static bool _isSha256(String value) =>
      value.length == 64 && RegExp(r'^[0-9a-f]+$').hasMatch(value);

  /// Returns a portable copy of [attachment] with no `localPath`.
  ///
  /// Attachments already carrying a blob URI are returned unchanged. A local
  /// file is hashed and uploaded in <=256 KiB chunks; an absent file is left
  /// untouched so the caller can surface the error rather than silently drop
  /// the user's data.
  Future<ChatAttachment> prepareOutgoing(
    String serverId,
    ChatAttachment attachment,
  ) async {
    final existing = hashOf(attachment);
    if (existing != null &&
        attachment.uri?.startsWith(kWorkspaceBlobUriPrefix) == true) {
      return ChatAttachment(
        id: attachment.id,
        name: attachment.name,
        mimeType: attachment.mimeType,
        sizeBytes: attachment.sizeBytes,
        uri: attachment.uri,
      );
    }
    final localPath = attachment.localPath;
    if (localPath == null || localPath.isEmpty) return attachment;
    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('WORKSPACE_ATTACHMENT_MISSING');
    }
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    await uploadBytes(serverId, hash, bytes);
    return ChatAttachment(
      id: hash,
      name: attachment.name,
      mimeType: attachment.mimeType,
      sizeBytes: bytes.length,
      uri: '$kWorkspaceBlobUriPrefix$hash',
    );
  }

  /// Downloads a remote attachment on demand and materialises it locally via
  /// [AcpAttachmentStore]. Local attachments are returned unchanged.
  Future<ChatAttachment> hydrate(
    String serverId,
    ChatAttachment attachment,
  ) async {
    final localPath = attachment.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      if (await File(localPath).exists()) return attachment;
    }
    final hash = hashOf(attachment);
    if (hash == null) return attachment;
    final bytes = await downloadBytes(serverId, hash, attachment.sizeBytes);
    return _store.save(
      attachment.name,
      attachment.mimeType,
      bytes,
      uri: attachment.uri,
    );
  }

  Future<void> uploadBytes(
    String serverId,
    String hash,
    Uint8List bytes,
  ) async {
    final totalChunks = bytes.isEmpty
        ? 1
        : (bytes.length + kWorkspaceBlobChunkBytes - 1) ~/
              kWorkspaceBlobChunkBytes;
    for (var index = 0; index < totalChunks; index++) {
      final start = index * kWorkspaceBlobChunkBytes;
      final end = (start + kWorkspaceBlobChunkBytes).clamp(0, bytes.length);
      final chunk = bytes.sublist(start, end);
      final response = await gateway.request(serverId, {
        'op': 'blob_put',
        'hash': hash,
        'chunkIndex': index,
        'totalChunks': totalChunks,
        'data': base64Encode(chunk),
        'totalSize': bytes.length,
      });
      if (response['ok'] == false) {
        throw StateError(
          response['error'] as String? ?? 'WORKSPACE_BLOB_PUT_FAILED',
        );
      }
    }
  }

  Future<Uint8List> downloadBytes(
    String serverId,
    String hash,
    int expectedSize,
  ) async {
    final builder = BytesBuilder(copy: false);
    var offset = 0;
    while (true) {
      final response = await gateway.request(serverId, {
        'op': 'blob_get',
        'hash': hash,
        'offset': offset,
        'length': kWorkspaceBlobChunkBytes,
      });
      if (response['ok'] == false) {
        throw StateError(
          response['error'] as String? ?? 'WORKSPACE_BLOB_GET_FAILED',
        );
      }
      final data = response['data'];
      if (data is! String) throw StateError('WORKSPACE_BLOB_CORRUPT');
      final chunk = base64Decode(data);
      builder.add(chunk);
      offset += chunk.length;
      final eof = response['eof'] == true;
      if (eof || chunk.isEmpty) break;
      final size = response['size'];
      if (size is int && offset >= size) break;
      if (expectedSize > 0 && offset >= expectedSize) break;
    }
    final bytes = builder.takeBytes();
    if (sha256.convert(bytes).toString() != hash) {
      throw StateError('WORKSPACE_BLOB_HASH_MISMATCH');
    }
    return bytes;
  }

  /// Default on-disk directory used when no store is injected (production).
  static String defaultDirectory(String supportDirectory) =>
      p.join(supportDirectory, 'chat-attachments');
}
