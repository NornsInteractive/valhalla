// Local-only Gboard probe: no server, storage or network providers are created.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valhalla/core/utils/terminal_keys.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/src/ui/custom_text_edit.dart';
import 'package:xterm/xterm.dart';

import '../test/support/fixed_terminal_settings.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: fixedTerminalSettingsOverrides(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _Probe(),
      ),
    ),
  );
}

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final terminal = Terminal();
  Timer? timer;
  String? lastEditingState;

  @override
  void initState() {
    super.initState();
    terminal.write('LOCAL INPUT PROBE - NO SSH\r\n');
    terminal.onOutput = (text) {
      debugPrint('IME_PROBE output=${text.codeUnits}');
      terminal.write('bytes=${text.codeUnits}\r\n');
    };
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      void visit(Element element) {
        if (element is StatefulElement &&
            element.state is CustomTextEditState) {
          final value =
              (element.state as CustomTextEditState).currentTextEditingValue;
          final snapshot =
              '${value?.text.codeUnits} composing=${value?.composing}';
          if (snapshot != lastEditingState) {
            debugPrint('IME_PROBE editing=$snapshot');
            lastEditingState = snapshot;
          }
        }
        element.visitChildren(visit);
      }

      (context as Element).visitChildren(visit);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Local IME probe — no SSH')),
    body: SharedTerminalCanvas(
      terminal: terminal,
      requestKeyboardOnTap: false,
      pinKeyboardButtonTrailing: true,
      onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) {
        debugPrint('IME_PROBE key=$key ctrl=$isCtrl alt=$isAlt shift=$isShift');
        sendTerminalAccessoryKey(
          terminal,
          key,
          isCtrl: isCtrl,
          isAlt: isAlt,
          isShift: isShift,
        );
      },
    ),
  );
}
