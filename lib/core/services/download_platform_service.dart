import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DownloadPlatformService {
  final Future<Directory> Function()? directoryProvider;
  DownloadPlatformService({this.directoryProvider});
  static const channel = MethodChannel('valhalla/downloads');
  final Set<String> _reserved = {};
  Future<Directory> _directory() async => directoryProvider != null
      ? await directoryProvider!()
      : Platform.isAndroid
      ? Directory('${(await getApplicationSupportDirectory()).path}/downloads')
      : Directory(
          '${(await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory()).path}/Valhalla',
        );

  Future<bool> ownsPath(String path) async {
    final directory = await _directory();
    if (!await directory.exists()) return false;
    final canonical = await directory.resolveSymbolicLinks();
    if (p.normalize(p.absolute(p.dirname(path))) != p.normalize(canonical)) {
      return false;
    }
    final type = await FileSystemEntity.type(path, followLinks: false);
    return type == FileSystemEntityType.file ||
        type == FileSystemEntityType.notFound;
  }

  Future<String> reservePath(String filename) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final name = filename.replaceAll(RegExp(r'[/\\<>:"|?*\x00-\x1f]'), '_');
    if (name.isEmpty || name == '.' || name == '..') {
      throw const FormatException('DOWNLOAD_FILENAME_INVALID');
    }
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '';
    final canonical = await directory.resolveSymbolicLinks();
    var candidate = '$canonical/$name';
    var number = 1;
    while (true) {
      if (_reserved.add(candidate) &&
          await FileSystemEntity.type(candidate, followLinks: false) ==
              FileSystemEntityType.notFound &&
          await FileSystemEntity.type('$candidate.part', followLinks: false) ==
              FileSystemEntityType.notFound) {
        return candidate;
      }
      candidate = '$canonical/$stem (${number++})$extension';
    }
  }

  Future<void> openFile(String path) async {
    if (!await File(path).exists()) {
      throw const FileSystemException('DOWNLOAD_FILE_MISSING');
    }
    await channel.invokeMethod<void>('openFile', {'path': path});
  }

  Future<void> revealFile(String path) async {
    if (!Platform.isWindows) throw UnsupportedError('Windows only');
    if (!await File(path).parent.exists()) {
      throw const FileSystemException('DOWNLOAD_DIRECTORY_MISSING');
    }
    await channel.invokeMethod<void>('revealFile', {'path': path});
  }

  Future<bool> report(Map<String, Object?> transfer) async {
    try {
      return await channel.invokeMethod<bool>('reportProgress', transfer) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
