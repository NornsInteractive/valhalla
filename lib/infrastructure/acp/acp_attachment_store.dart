import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:acpd/acpd.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/chat_session.dart';
import 'acp_client_adapter.dart';

/// Immutable content-addressed files. Never embed image bytes in message JSON.
class AcpAttachmentStore {
  final String? directory;
  AcpAttachmentStore({this.directory});

  Future<ChatAttachment> save(
    String name,
    String mimeType,
    Uint8List bytes, {
    String? uri,
  }) async {
    final limit = mimeType.startsWith('image/')
        ? AcpPromptAttachment.maxImageBytes
        : AcpPromptAttachment.maxTextBytes;
    if (bytes.length > limit) throw StateError('ACP_ATTACHMENT_TOO_LARGE');
    final root =
        directory ??
        p.join(
          (await getApplicationSupportDirectory()).path,
          'chat-attachments',
        );
    return Isolate.run(() async {
      final id = sha256.convert(bytes).toString();
      await Directory(root).create(recursive: true);
      final file = File(p.join(root, id));
      if (!await file.exists() || await file.length() != bytes.length) {
        final temporary = File(p.join(root, '.${const Uuid().v4()}.part'));
        try {
          await temporary.writeAsBytes(bytes, flush: true);
          await temporary.rename(file.path);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
      }
      return ChatAttachment(
        id: id,
        name: name,
        mimeType: mimeType,
        sizeBytes: bytes.length,
        localPath: file.path,
        uri: uri,
      );
    });
  }

  Future<ChatAttachment> fromBlock(ContentBlock block) async {
    if (block is ImageContent) {
      if (block.data.length >
          (AcpPromptAttachment.maxImageBytes * 4 / 3).ceil() + 4) {
        throw StateError('ACP_ATTACHMENT_TOO_LARGE');
      }
      final Uint8List bytes;
      try {
        bytes = await Isolate.run(() => base64Decode(block.data));
      } on FormatException {
        throw StateError('ACP_ATTACHMENT_CORRUPT');
      }
      return save('image', block.mimeType, bytes, uri: block.uri);
    }
    if (block is EmbeddedResource) {
      final resource = block.resource;
      final name = p.posix.basename(
        Uri.tryParse(resource.uri)?.path ?? resource.uri,
      );
      if (resource is TextResourceContents) {
        if (resource.text.length > AcpPromptAttachment.maxTextBytes) {
          throw StateError('ACP_ATTACHMENT_TOO_LARGE');
        }
        return save(
          name,
          resource.mimeType ?? 'text/plain',
          Uint8List.fromList(utf8.encode(resource.text)),
          uri: resource.uri,
        );
      }
      return ChatAttachment(
        id: resource.uri,
        name: name,
        mimeType: resource.mimeType ?? 'application/octet-stream',
        sizeBytes: 0,
        uri: resource.uri,
      );
    }
    if (block is ResourceLink) {
      return ChatAttachment(
        id: block.uri,
        name: block.name,
        mimeType: block.mimeType ?? 'application/octet-stream',
        sizeBytes: block.size ?? 0,
        uri: block.uri,
      );
    }
    return const ChatAttachment(
      id: 'unsupported',
      name: 'resource',
      mimeType: 'application/octet-stream',
      sizeBytes: 0,
    );
  }
}
