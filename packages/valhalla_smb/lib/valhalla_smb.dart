import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';

/// Immutable connection details. Credentials are never embedded in URLs.
class SmbConnection {
  final String host, share, username, password, domain;
  const SmbConnection({
    required this.host,
    required this.share,
    required this.username,
    required this.password,
    this.domain = '',
  });
}

class SmbEntry {
  final String path;
  final int size, modifiedSeconds;
  final bool isDirectory;
  const SmbEntry(this.path, this.size, this.modifiedSeconds, this.isDirectory);
}

class SmbException implements Exception {
  final String message;
  const SmbException(this.message);
  @override
  String toString() => message;
}

/// A dedicated isolate owns each connection. Consumers pull one page/chunk at
/// a time; pausing a stream never queues the remainder of a directory or file.
class SmbClient {
  final SmbConnection connection;
  final String? libraryPath;
  const SmbClient(this.connection, {this.libraryPath});

  Future<void> probe({Future<void>? cancelled}) async {
    await for (final _ in _request('probe', const [], cancelled)) {}
  }

  Stream<List<SmbEntry>> walk({
    required List<String> roots,
    List<String> excludes = const [],
    Future<void>? cancelled,
  }) async* {
    final normalizedRoots = roots.map(normalizePath).toSet().toList()..sort();
    final normalizedExcludes = excludes.map(normalizePath).toList();
    // Avoid scanning a subtree twice when both parent and child are configured.
    final selected = <String>[];
    for (final root in normalizedRoots) {
      if (!selected.any((parent) => _inside(root, parent))) selected.add(root);
    }
    await for (final value in _request('walk', [
      selected,
      normalizedExcludes,
    ], cancelled)) {
      yield (value as List).cast<SmbEntry>();
    }
  }

  Stream<List<int>> read(
    String path, {
    int start = 0,
    int? end,
    Future<void>? cancelled,
  }) async* {
    if (start < 0 || (end != null && end < start)) {
      throw const SmbException('SMB_INVALID_RANGE');
    }
    if (end == start) return;
    await for (final value in _request('read', [
      normalizePath(path),
      start,
      end,
    ], cancelled)) {
      yield (value as TransferableTypedData).materialize().asUint8List();
    }
  }

  Stream<Object> _request(
    String method,
    List<Object?> arguments,
    Future<void>? cancelled,
  ) async* {
    for (final value in [
      connection.host,
      connection.share,
      connection.username,
      connection.password,
      connection.domain,
    ]) {
      if (value.contains('\x00')) {
        throw const SmbException('SMB_INVALID_CONNECTION');
      }
    }
    if (connection.host.isEmpty ||
        connection.share.isEmpty ||
        connection.share.contains('/') ||
        connection.share.contains('\\')) {
      throw const SmbException('SMB_INVALID_CONNECTION');
    }
    final bindings = _Bindings(libraryPath);
    final cancel = bindings.cancelNew();
    if (cancel == nullptr) throw const SmbException('SMB_OUT_OF_MEMORY');
    final messages = ReceivePort();
    final exitMessages = ReceivePort();
    final exited = Completer<void>();
    final exitSubscription = exitMessages.listen((_) {
      if (!exited.isCompleted) exited.complete();
      messages.sendPort.send(null);
    });
    SendPort? control;
    var active = true;
    var spawned = false;
    cancelled?.then((_) {
      if (active) {
        bindings.cancelSet(cancel);
        control?.send(false);
      }
    });
    try {
      await Isolate.spawn(
        _worker,
        [
          messages.sendPort,
          connection,
          method,
          arguments,
          cancel.address,
          libraryPath,
        ],
        onExit: exitMessages.sendPort,
        onError: messages.sendPort,
        errorsAreFatal: true,
      );
      spawned = true;
      await for (final message in messages) {
        if (message == null) break;
        if (message is SendPort) {
          control = message;
        } else if (message is _Failure) {
          throw SmbException(message.message);
        } else if (message is _Data) {
          yield message.value;
          control?.send(true);
        } else {
          // Uncaught isolate errors must not appear to be an empty directory.
          throw const SmbException('SMB_WORKER_FAILED');
        }
      }
    } finally {
      active = false;
      bindings.cancelSet(cancel);
      control?.send(false);
      if (spawned) await exited.future;
      await exitSubscription.cancel();
      messages.close();
      exitMessages.close();
      bindings.cancelFree(cancel);
    }
  }

  /// Paths are share-relative; traversal and alternate separators are rejected.
  static String normalizePath(String path) {
    if (path.contains('\x00') || path.contains('\\')) {
      throw const SmbException('SMB_INVALID_PATH');
    }
    final parts = path
        .split('/')
        .where((part) => part.isNotEmpty && part != '.');
    if (parts.any((part) => part == '..')) {
      throw const SmbException('SMB_INVALID_PATH');
    }
    return parts.join('/');
  }
}

bool _inside(String path, String parent) =>
    parent.isEmpty || path == parent || path.startsWith('$parent/');

class _Failure {
  final String message;
  const _Failure(this.message);
}

class _Data {
  final Object value;
  const _Data(this.value);
}

Future<void> _worker(List<Object?> request) async {
  final parent = request[0] as SendPort;
  final controls = ReceivePort();
  final commands = StreamIterator(controls);
  parent.send(controls.sendPort);
  _Bindings? native;
  Pointer<Void> session = nullptr;
  try {
    native = _Bindings(request[5] as String?);
    final cancel = Pointer<Void>.fromAddress(request[4] as int);
    session = native.sessionNew(cancel);
    if (session == nullptr) throw const SmbException('SMB_OUT_OF_MEMORY');
    final connection = request[1] as SmbConnection;
    final connected = using(
      (arena) => native!.connect(
        session,
        connection.host.toNativeUtf8(allocator: arena),
        connection.share.toNativeUtf8(allocator: arena),
        connection.username.toNativeUtf8(allocator: arena),
        connection.password.toNativeUtf8(allocator: arena),
        connection.domain.toNativeUtf8(allocator: arena),
      ),
    );
    void check(int result) {
      if (result < 0) throw SmbException(native!.error(session).toDartString());
    }

    check(connected);
    Future<void> send(Object data) async {
      parent.send(_Data(data));
      if (!await commands.moveNext() || commands.current != true) {
        throw const SmbException('SMB_CANCELLED');
      }
    }

    final arguments = request[3] as List<Object?>;
    if (request[2] == 'walk') {
      final roots = arguments[0] as List<String>;
      final excludes = arguments[1] as List<String>;
      Future<void> walk(String path, int depth) async {
        if (excludes.any((excluded) => _inside(path, excluded))) return;
        // SMB paths have finite length; fail visibly rather than loop on a
        // malicious tree. Reparse points are never traversed.
        if (depth > 128) throw const SmbException('SMB_DIRECTORY_DEPTH_LIMIT');
        final directory = using(
          (arena) => native!.directoryOpen(
            session,
            path.toNativeUtf8(allocator: arena),
          ),
        );
        if (directory == nullptr) check(-1);
        try {
          while (true) {
            final count = native!.directoryNext(session, directory);
            check(count);
            if (count == 0) break;
            final page = <SmbEntry>[];
            final directories = <String>[];
            for (var i = 0; i < count; i++) {
              final entry = native.directoryEntry(directory, i).ref;
              final name = entry.name.toDartString();
              if (name == '.' || name == '..') continue;
              if (name.isEmpty ||
                  name.contains('/') ||
                  name.contains('\\') ||
                  name.contains('\x00')) {
                throw const SmbException('SMB_INVALID_DIRECTORY_ENTRY');
              }
              final child = path.isEmpty ? name : '$path/$name';
              if (excludes.any((excluded) => _inside(child, excluded))) {
                continue;
              }
              if (entry.attributes & 0x400 != 0) continue; // Reparse point.
              final isDirectory = entry.attributes & 0x10 != 0;
              page.add(
                SmbEntry(child, entry.size, entry.modifiedSeconds, isDirectory),
              );
              if (isDirectory) directories.add(child);
            }
            if (page.isNotEmpty) await send(page);
            // Depth-first traversal holds only one bounded page per ancestor.
            for (final child in directories) {
              await walk(child, depth + 1);
            }
          }
        } finally {
          native!.directoryClose(session, directory);
        }
      }

      for (final root in roots) {
        await walk(root, 0);
      }
    } else if (request[2] == 'read') {
      final path = arguments[0] as String;
      var offset = arguments[1] as int;
      final end = arguments[2] as int?;
      check(
        using(
          (arena) =>
              native!.fileOpen(session, path.toNativeUtf8(allocator: arena)),
        ),
      );
      final buffer = calloc<Uint8>(262144);
      try {
        while (end == null || offset < end) {
          final wanted = end == null ? 262144 : math.min(262144, end - offset);
          final count = native.fileRead(session, buffer, wanted, offset);
          check(count);
          if (count == 0) {
            if (end != null && offset < end) {
              throw const SmbException('SMB_UNEXPECTED_EOF');
            }
            break;
          }
          await send(
            TransferableTypedData.fromList([buffer.asTypedList(count)]),
          );
          offset += count;
        }
      } finally {
        calloc.free(buffer);
      }
    }
  } catch (error) {
    parent.send(
      _Failure(error is SmbException ? error.message : 'SMB_WORKER_FAILED'),
    );
  } finally {
    if (session != nullptr) native!.sessionFree(session);
    await commands.cancel();
    controls.close();
  }
}

final class _NativeEntry extends Struct {
  external Pointer<Utf8> name;
  @Uint64()
  external int size;
  @Int64()
  external int modifiedSeconds;
  @Uint32()
  external int attributes;
}

class _Bindings {
  final DynamicLibrary library;
  _Bindings(String? path)
    : library = path != null
          ? DynamicLibrary.open(path)
          : Platform.isIOS || Platform.isMacOS
          ? _appleLibrary()
          : DynamicLibrary.open(
              Platform.isWindows ? 'valhalla_smb.dll' : 'libvalhalla_smb.so',
            );
  static DynamicLibrary _appleLibrary() {
    try {
      return DynamicLibrary.open('valhalla_smb.framework/valhalla_smb');
    } on ArgumentError {
      return DynamicLibrary.process(); // CocoaPods with static linkage.
    }
  }

  late final cancelNew = library
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'vh_smb_cancel_new',
      );
  late final cancelSet = library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('vh_smb_cancel_set');
  late final cancelFree = library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('vh_smb_cancel_free');
  late final sessionNew = library
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('vh_smb_session_new');
  late final sessionFree = library
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('vh_smb_session_free');
  late final error = library
      .lookupFunction<
        Pointer<Utf8> Function(Pointer<Void>),
        Pointer<Utf8> Function(Pointer<Void>)
      >('vh_smb_error');
  late final connect = library
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Utf8>,
        ),
        int Function(
          Pointer<Void>,
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Utf8>,
        )
      >('vh_smb_connect');
  late final directoryOpen = library
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>)
      >('vh_smb_dir_open');
  late final directoryNext = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>),
        int Function(Pointer<Void>, Pointer<Void>)
      >('vh_smb_dir_next');
  late final directoryEntry = library
      .lookupFunction<
        Pointer<_NativeEntry> Function(Pointer<Void>, Int32),
        Pointer<_NativeEntry> Function(Pointer<Void>, int)
      >('vh_smb_dir_entry');
  late final directoryClose = library
      .lookupFunction<
        Void Function(Pointer<Void>, Pointer<Void>),
        void Function(Pointer<Void>, Pointer<Void>)
      >('vh_smb_dir_close');
  late final fileOpen = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf8>),
        int Function(Pointer<Void>, Pointer<Utf8>)
      >('vh_smb_file_open');
  late final fileRead = library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Uint8>, Uint32, Uint64),
        int Function(Pointer<Void>, Pointer<Uint8>, int, int)
      >('vh_smb_file_read');
}
