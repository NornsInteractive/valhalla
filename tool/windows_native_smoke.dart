// Standalone Windows verification entrypoint. Never included in release packages.
// Pass a temporary report directory as the first command-line argument.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/core/services/download_platform_service.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _FixedSettings extends TerminalSettingsNotifier {
  @override
  TerminalSettings build() =>
      const TerminalSettings(useTmux: false, fontSize: 13);
}

Future<void> main(List<String> arguments) async {
  if (!Platform.isWindows || arguments.isEmpty) exit(2);
  WidgetsFlutterBinding.ensureInitialized();
  final report = Directory(arguments.first);
  await report.create(recursive: true);
  final errors = <String>[];
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    errors.add('$error\n$stack');
    File('${report.path}/errors.json').writeAsStringSync(jsonEncode(errors));
    return true;
  };
  File('${report.path}/errors.json').writeAsStringSync('[]');
  final client = SSHClient(
    await SSHSocket.connect('127.0.0.1', 54322),
    username: 'fixture',
    onPasswordRequest: () => 'fixture-only',
  );
  final session = await client.shell();
  final terminal = Terminal();
  terminal.onOutput = (data) =>
      session.stdin.add(Uint8List.fromList(utf8.encode(data)));
  session.stdout
      .cast<List<int>>()
      .transform(utf8.decoder)
      .listen(terminal.write);
  final surface = GlobalKey();
  runApp(
    ProviderScope(
      overrides: [terminalSettingsProvider.overrideWith(_FixedSettings.new)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SharedTerminalCanvas(
            key: surface,
            terminal: terminal,
            onKey: (key, {isCtrl = false, isAlt = false}) {},
            onPaste: () async {
              final text = (await Clipboard.getData(
                Clipboard.kTextPlain,
              ))?.text;
              if (text != null) terminal.textInput(text);
            },
          ),
        ),
      ),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  final platform = DownloadPlatformService();
  final file = File('${report.path}/中文 space & quote.txt');
  await file.writeAsString('fixture');
  await platform.revealFile(file.path);
  await file.delete();
  await platform.revealFile(file.path);
  bool missingDirectory = false;
  try {
    await platform.revealFile('${report.path}/absent/file.txt');
  } on FileSystemException {
    missingDirectory = true;
  }
  // Exercise the native failure response too, bypassing the Dart existence check.
  bool nativeFailure = false;
  try {
    await DownloadPlatformService.channel.invokeMethod<void>('revealFile', {
      'path': '${report.path}/absent/file.txt',
    });
  } on PlatformException {
    nativeFailure = true;
  }
  File('${report.path}/reveal.json').writeAsStringSync(
    jsonEncode({
      'existingFile': true,
      'missingFileFallback': true,
      'missingDirectory': missingDirectory,
      'nativeFailure': nativeFailure,
    }),
  );
  // Focus the actual shared terminal after Explorer is opened by the shell.
  void focus(Element element) {
    if (element is StatefulElement && element.state is TerminalViewState) {
      (element.state as TerminalViewState).requestKeyboard();
    } else {
      element.visitChildElements(focus);
    }
  }

  focus(surface.currentContext! as Element);
  await Future<void>.delayed(const Duration(milliseconds: 300));
  File('${report.path}/ready').writeAsStringSync('ready');
}
