import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/reconnect_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/core/utils/reconnect_backoff.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

class _FixedSettingsNotifier extends TerminalSettingsNotifier {
  @override
  TerminalSettings build() => const TerminalSettings(fontSize: 14);
}

class _FixedServerNotifier extends ActiveServerNotifier {
  _FixedServerNotifier(this._server);
  final ServerProfile? _server;
  @override
  ServerProfile? build() => _server;
}

class _FixedAppSettingsNotifier extends SettingsNotifier {
  _FixedAppSettingsNotifier(this._settings);
  final SettingsState _settings;
  @override
  SettingsState build() => _settings;
}

class _MockReconnectController extends ReconnectController {
  _MockReconnectController() : super(connectAttempt: (_) async {});

  ReconnectState _state = const ReconnectState(status: ReconnectStatus.idle);

  @override
  ReconnectState get state => _state;

  void setStatus(ReconnectStatus status) {
    _state = ReconnectState(status: status, attempt: 1);
    debugEmit(_state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Terminal vertical scroll gesture tests', () {
    testWidgets('vertical drag scrolls normal buffer history', (tester) async {
      final terminal = Terminal(maxLines: 500);
      final buffer = StringBuffer();
      for (var i = 0; i < 80; i++) {
        buffer.writeln('line $i: log output data for testing scrollback');
      }
      terminal.write(buffer.toString());

      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 300,
              child: TerminalView(
                terminal,
                scrollController: scrollController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // At bottom initially
      expect(scrollController.position.maxScrollExtent, greaterThan(0));
      final initialOffset = scrollController.offset;
      expect(initialOffset, equals(scrollController.position.maxScrollExtent));

      // Drag downwards (pull finger down): should scroll UP into earlier history
      await tester.drag(find.byType(TerminalView), const Offset(0, 150));
      await tester.pumpAndSettle();

      // Offset should have decreased (scrolled up towards 0)
      expect(scrollController.offset, lessThan(initialOffset));

      // Drag upwards (pull finger up): should scroll back DOWN towards latest output
      await tester.drag(find.byType(TerminalView), const Offset(0, -150));
      await tester.pumpAndSettle();

      expect(scrollController.offset, greaterThan(0));
    });

    testWidgets('vertical drag in alt buffer translates to mouse wheel input', (
      tester,
    ) async {
      final terminal = Terminal(maxLines: 500);
      // Switch terminal to alternate buffer (like tmux / vim)
      terminal.write('\x1b[?1049h'); // Enter alt screen buffer
      expect(terminal.isUsingAltBuffer, isTrue);

      final inputs = <String>[];
      terminal.onOutput = (data) {
        inputs.add(data);
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 300,
              child: TerminalView(terminal),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag downwards: simulate wheelUp / arrowUp
      await tester.drag(find.byType(TerminalView), const Offset(0, 100));
      await tester.pumpAndSettle();

      // In alt buffer without mouse tracking mode, simulateScroll sends Arrow keys
      // Arrow Up escape sequence is \x1b[A (or \x1bOA)
      expect(
        inputs.any((s) => s.contains('\x1b[A') || s.contains('\x1bOA')),
        isTrue,
        reason: 'Dragging down in alt buffer should send simulated wheelUp / arrowUp',
      );

      inputs.clear();

      // Drag upwards: simulate wheelDown / arrowDown
      await tester.drag(find.byType(TerminalView), const Offset(0, -100));
      await tester.pumpAndSettle();

      // Arrow Down escape sequence is \x1b[B (or \x1bOB)
      expect(
        inputs.any((s) => s.contains('\x1b[B') || s.contains('\x1bOB')),
        isTrue,
        reason: 'Dragging up in alt buffer should send simulated wheelDown / arrowDown',
      );
    });

    testWidgets(
      'vertical drag in tmux (alt buffer + SGR mouse mode) sends standard wheel escape sequences',
      (tester) async {
        final terminal = Terminal(maxLines: 500);
        // Switch terminal to alternate buffer and enable SGR mouse tracking (like tmux with mouse on)
        terminal.write('\x1b[?1049h\x1b[?1000h\x1b[?1006h');
        expect(terminal.isUsingAltBuffer, isTrue);
        expect(terminal.mouseMode, equals(MouseMode.upDownScroll));
        expect(terminal.mouseReportMode, equals(MouseReportMode.sgr));

        final inputs = <String>[];
        terminal.onOutput = (data) {
          inputs.add(data);
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 300,
                child: TerminalView(terminal),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Drag downwards (pull finger down): should emit SGR WheelUp: \x1b[<64;col;rowM
        await tester.drag(find.byType(TerminalView), const Offset(0, 100));
        await tester.pumpAndSettle();

        expect(
          inputs.any((s) => s.contains('\x1b[<64;')),
          isTrue,
          reason: 'Dragging down in tmux SGR mode must emit standard wheelUp (64)',
        );
        expect(
          inputs.any((s) => s.contains('\x1b[<68;')),
          isFalse,
          reason: 'Must NOT emit shifted button 68',
        );

        inputs.clear();

        // Drag upwards (pull finger up): should emit SGR WheelDown: \x1b[<65;col;rowM
        await tester.drag(find.byType(TerminalView), const Offset(0, -100));
        await tester.pumpAndSettle();

        expect(
          inputs.any((s) => s.contains('\x1b[<65;')),
          isTrue,
          reason: 'Dragging up in tmux SGR mode must emit standard wheelDown (65)',
        );
        expect(
          inputs.any((s) => s.contains('\x1b[<69;')),
          isFalse,
          reason: 'Must NOT emit shifted button 69',
        );
      },
    );
  });

  group('Top notice removal and loading spinner tests', () {
    testWidgets(
      'upper-right server name displays loading spinner when reconnecting or connecting',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();
        final reconnectCtrl = _MockReconnectController();
        addTearDown(reconnectCtrl.dispose);

        const testServer = ServerProfile(
          id: 'server-1',
          name: 'Production Node',
          host: '10.0.0.1',
          port: 22,
          username: 'root',
        );

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            terminalSettingsProvider.overrideWith(
              () => _FixedSettingsNotifier(),
            ),
            activeServerProvider.overrideWith(
              () => _FixedServerNotifier(testServer),
            ),
            reconnectControllerProvider.overrideWithValue(reconnectCtrl),
            settingsProvider.overrideWith(
              () => _FixedAppSettingsNotifier(
                const SettingsState(
                  startupSection: AppSection.terminal,
                  bottomNavigationSections: [AppSection.terminal],
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MainShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially idle: no loading spinner
        expect(
          find.byKey(const Key('top_bar_server_loading_indicator')),
          findsNothing,
        );
        // Top prompt boxes should NOT exist
        expect(find.byKey(const Key('reconnectingBanner')), findsNothing);
        expect(find.byKey(const Key('sessionRecoveryFailedBanner')), findsNothing);
        expect(find.byKey(const Key('terminalErrorBanner')), findsNothing);

        // Transition to reconnecting
        reconnectCtrl.setStatus(ReconnectStatus.reconnecting);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Loading spinner should be visible next to server name
        expect(
          find.byKey(const Key('top_bar_server_loading_indicator')),
          findsOneWidget,
        );
        // Top banner should STILL NOT exist
        expect(find.byKey(const Key('reconnectingBanner')), findsNothing);
        expect(find.byKey(const Key('sessionRecoveryFailedBanner')), findsNothing);

        // Transition back to connected
        reconnectCtrl.setStatus(ReconnectStatus.connected);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Spinner hides
        expect(
          find.byKey(const Key('top_bar_server_loading_indicator')),
          findsNothing,
        );
      },
    );
  });
}
