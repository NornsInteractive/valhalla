import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../logging/sanitizer.dart';

/// Local, bounded diagnostics. Never uploads logs or stores connection profiles.
class AppDiagnostics {
  AppDiagnostics({this.directoryProvider, this.maxFileBytes = 1024 * 1024})
    : assert(maxFileBytes >= 128);

  static final instance = AppDiagnostics();
  static const channel = MethodChannel('valhalla/diagnostics');
  final Future<Directory> Function()? directoryProvider;
  final int maxFileBytes;
  final _incidents = StreamController<String>.broadcast();
  Stream<String> get incidents => _incidents.stream;
  Directory? _directory;
  Future<void> _writes = Future.value();
  int _queued = 0;
  int _dropped = 0;
  String? storageError;

  Future<void> initialize() async {
    try {
      _directory = directoryProvider == null
          ? Directory(
              '${(await getApplicationSupportDirectory()).path}/diagnostics',
            )
          : await directoryProvider!();
      await _directory!.create(recursive: true);
      await record('startup', 'Application started');
      if (Platform.isAndroid && directoryProvider == null) {
        try {
          final exits = await channel.invokeMethod<List<dynamic>>(
            'previousExits',
          );
          await record('android.previousExits', jsonEncode(exits));
        } on MissingPluginException {
          // Older builds and other platforms have no native exit history.
        } on PlatformException catch (error, stack) {
          await record('android.previousExits.unavailable', error, stack);
        }
      }
    } catch (error) {
      storageError = LogSanitizer.sanitize(error.toString());
    }
  }

  /// Queue size is bounded too: an error storm cannot retain unlimited stacks.
  Future<void> record(String source, Object error, [StackTrace? stack]) {
    if (_queued >= 32 || _directory == null) {
      _dropped++;
      return Future.value();
    }
    final sanitized = LogSanitizer.sanitize(
      '${DateTime.now().toUtc().toIso8601String()} [$source] $error\n${stack ?? ''}\n',
    );
    final bytes = utf8.encode(sanitized);
    final limit = maxFileBytes < 64 * 1024 ? maxFileBytes : 64 * 1024;
    final entry = bytes.length <= limit
        ? bytes
        : utf8.encode(
            '${utf8.decode(bytes.take(limit - 32).toList(), allowMalformed: true)}\n[entry truncated]\n',
          );
    _queued++;
    _writes = _writes.then((_) async {
      try {
        if (_dropped > 0) {
          final dropped = _dropped;
          _dropped = 0;
          await _append(
            utf8.encode('[diagnostics] $dropped entries dropped\n'),
          );
        }
        await _append(entry);
      } catch (error) {
        storageError = LogSanitizer.sanitize(error.toString());
      } finally {
        _queued--;
      }
    });
    return _writes;
  }

  void unhandled(String source, Object error, StackTrace stack) {
    unawaited(record(source, error, stack));
    // Only the category crosses into UI; localized UI explains where to see logs.
    _incidents.add(source);
  }

  File _file(int index) => File('${_directory!.path}/app-$index.log');

  Future<void> _append(List<int> bytes) async {
    final current = _file(0);
    if (await current.exists() &&
        await current.length() + bytes.length > maxFileBytes) {
      if (await _file(2).exists()) await _file(2).delete();
      if (await _file(1).exists()) await _file(1).rename(_file(2).path);
      await current.rename(_file(1).path);
    }
    await current.writeAsBytes(bytes, mode: FileMode.append, flush: true);
  }

  /// The on-screen tail stays small even when all three files are full.
  Future<String> read({int maxBytes = 256 * 1024}) async {
    await _writes;
    if (_directory == null) return storageError ?? 'DIAGNOSTICS_UNAVAILABLE';
    final chunks = <List<int>>[];
    var remaining = maxBytes;
    for (var index = 0; index < 3 && remaining > 0; index++) {
      final file = _file(index);
      if (!await file.exists()) continue;
      final handle = await file.open();
      try {
        final size = await handle.length();
        final count = size < remaining ? size : remaining;
        await handle.setPosition(size - count);
        chunks.insert(0, await handle.read(count));
        remaining -= count;
      } finally {
        await handle.close();
      }
    }
    return LogSanitizer.sanitize(
      utf8.decode(chunks.expand((e) => e).toList(), allowMalformed: true),
    );
  }

  Future<String?> export() async => (await FilePicker.saveFile(
    fileName: 'valhalla-diagnostics.txt',
    type: FileType.custom,
    allowedExtensions: ['txt'],
    mimeType: 'text/plain',
    bytes: Uint8List.fromList(
      utf8.encode(await read(maxBytes: 3 * maxFileBytes)),
    ),
  ))?.toString();
}
