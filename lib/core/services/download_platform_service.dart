import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DownloadPlatformService {
  final Future<Directory> Function()? directoryProvider;
  DownloadPlatformService({this.directoryProvider});
  static const channel = MethodChannel('valhalla/downloads');
  final Set<String> _reserved = {};
  Future<String> reservePath(String filename) async {
    final directory = directoryProvider != null
        ? await directoryProvider!()
        : Platform.isAndroid
        ? Directory(
            '${(await getApplicationSupportDirectory()).path}/downloads',
          )
        : Directory(
            '${(await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory()).path}/Valhalla',
          );
    await directory.create(recursive: true);
    final name = filename.replaceAll(RegExp(r'[/\\<>:"|?*\x00-\x1f]'), '_');
    if (name.isEmpty || name == '.' || name == '..') {
      throw const FormatException('DOWNLOAD_FILENAME_INVALID');
    }
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '';
    var candidate = '${directory.path}/$name';
    var number = 1;
    while (true) {
      if (_reserved.add(candidate) &&
          !await File(candidate).exists() &&
          !await File('$candidate.part').exists()) {
        return candidate;
      }
      candidate = '${directory.path}/$stem (${number++})$extension';
    }
  }

  Future<void> openFile(String path) async {
    if (!await File(path).exists()) {
      throw const FileSystemException('DOWNLOAD_FILE_MISSING');
    }
    await channel.invokeMethod<void>('openFile', {'path': path});
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
