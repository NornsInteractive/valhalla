import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

Future<String> fileSha256(String path) => Isolate.run(() async {
  return (await sha256.bind(File(path).openRead()).first).toString();
});
