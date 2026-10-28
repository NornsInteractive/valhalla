import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/commands_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/data/models/quick_command.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/workspace/workspace_gateway.dart';
import 'package:valhalla/features/terminal/terminal_view.dart';
import 'package:valhalla/features/terminal/widgets/terminal_saved_commands_dialog.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

import '../support/fixed_terminal_settings.dart';
import '../support/seeded_terminal_notifier.dart';

const _serverA = ServerProfile(
  id: 'server-a',
  name: 'Server A',
  host: '192.0.2.10',
  username: 'dev',
);

const _serverB = ServerProfile(
  id: 'server-b',
  name: 'Server B',
  host: '192.0.2.11',
  username: 'dev',
);

const _plainCommand = QuickCommand(
  id: 'plain',
  title: 'Echo hello',
  command: 'echo hello',
  category: 'Test',
  description: 'Print a greeting',
);

const _twoParamCommand = QuickCommand(
  id: 'copy',
  title: 'Copy file',
  command: 'cp {{src}} {{dst}}',
  category: 'Test',
  description: 'Copy one file to another',
);

const _dangerCommand = QuickCommand(
  id: 'danger',
  title: 'Danger cleanup',
  command: 'rm -rf /tmp/{{target}}',
  category: 'Test',
  description: 'Delete temporary data',
  isDangerous: true,
);

const _multilineCommand = QuickCommand(
  id: 'multiline',
  title: 'Run script',
  command: 'echo one\necho two',
  category: 'Test',
  description: 'Runs two lines',
);

const _markedDangerousCommand = QuickCommand(
  id: 'marked-danger',
  title: 'Danger marker',
  command: 'echo danger-marker',
  category: 'Test',
  description: 'Benign text explicitly marked dangerous',
  isDangerous: true,
);

const _commands = <QuickCommand>[
  _plainCommand,
  _twoParamCommand,
  _dangerCommand,
  _multilineCommand,
  _markedDangerousCommand,
];

class _FakeCommands extends CommandsNotifier {
  _FakeCommands(this.commands);

  final List<QuickCommand> commands;

  @override
  CommandsState build() => CommandsState(allCommands: commands);
}

class _Storage implements LocalStorageService {
  /// Local-only fixture: no remote workspace is attached.
  @override
  WorkspaceGateway? workspaceGateway;

  @override
  TerminalHistorySnapshot getTerminalHistory(
    String serverId,
    String targetKey,
  ) => const TerminalHistorySnapshot();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MutableActive extends ActiveServerNotifier {
  _MutableActive(this.server);

  ServerProfile? server;

  @override
  ServerProfile? build() => server;

  void select(ServerProfile next) {
    server = next;
    state = next;
  }
}

class _Servers extends ServerListNotifier {
  _Servers(this.servers);

  final List<ServerProfile> servers;

  @override
  List<ServerProfile> build() => servers;
}

class _Connection extends ServerConnectionNotifier {
  _Connection(this.server);

  final ServerProfile server;

  @override
  ServerConnectionState build() => ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: server.id,
  );
}

class _RecordingBridge extends TerminalSessionBridge {
  _RecordingBridge({
    TerminalConnectionState state = TerminalConnectionState.connected,
  }) : super(terminal: Terminal(), serverName: 'test') {
    stateListenable.value = state;
  }

  final List<String> sent = <String>[];

  @override
  TerminalConnectionState get state => stateListenable.value;

  @override
  void sendCommand(String cmd) => sent.add(cmd);

  void setConnectionState(TerminalConnectionState next) {
    stateListenable.value = next;
  }
}

class _SavedNotifier extends SeededTerminalNotifier {
  _SavedNotifier(super.initial);

  final List<({String command, String tabId, TerminalSessionBridge bridge})>
  sends = [];

  void emit(SshTerminalState next) => state = next;

  @override
  void sendCommand(String cmd) {
    final tab = state.activeTab;
    if (tab == null) return;
    sends.add((command: cmd, tabId: tab.id, bridge: tab.bridge));
    (tab.bridge as _RecordingBridge).sent.add(cmd);
  }
}

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

Finder _runButton() =>
    find.byKey(const Key('terminal_saved_commands_run_button'));

FilledButton _run(WidgetTester tester) =>
    tester.widget<FilledButton>(_runButton());

Finder _paramField(String name) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == name,
);

Finder _previewField() => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.maxLines == 4,
);

String _previewText(WidgetTester tester) =>
    tester.widget<TextField>(_previewField()).controller!.text;

Future<void> _selectCommand(WidgetTester tester, String title) async {
  final target = find.text(title);
  if (target.evaluate().isEmpty) {
    // Narrow viewports (320dp) with a keyboard inset shrink the dialog enough
    // that later list rows are not built until the list is scrolled. Target the
    // command ListView's scrollable, not the search field's inner scrollable.
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  Size size = const Size(800, 800),
  double textScale = 1,
  double keyboardInset = 0,
  required ValueChanged<TerminalSavedCommandResult?> onResult,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        commandsProvider.overrideWith(() => _FakeCommands(_commands)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const Key('open_saved_commands'),
                onPressed: () async {
                  onResult(await TerminalSavedCommandsDialog.show(context));
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open_saved_commands')));
  await tester.pumpAndSettle();
}

Future<void> _pumpView(
  WidgetTester tester, {
  required _SavedNotifier notifier,
  required _MutableActive active,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_Storage()),
        activeServerProvider.overrideWith(() => active),
        serverListProvider.overrideWith(() => _Servers([_serverA, _serverB])),
        serverConnectionProvider.overrideWith(
          () => _Connection(active.server!),
        ),
        terminalProvider.overrideWith(() => notifier),
        terminalSettingsProvider.overrideWith(
          FixedTerminalSettingsNotifier.new,
        ),
        commandsProvider.overrideWith(() => _FakeCommands(_commands)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SshTerminalView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSavedCommands(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('terminal_more_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('terminal_saved_commands_menu_item')));
  await tester.pumpAndSettle();
}

Future<void> _chooseSavedCommand(WidgetTester tester, String title) async {
  await _openSavedCommands(tester);
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

TerminalTab _tab(String id, _RecordingBridge bridge) =>
    TerminalTab(id: id, title: id, terminal: bridge.terminal, bridge: bridge);

enum _Target { server, tab, bridge }

enum _Phase { preview, confirmation }

void main() {
  group('TerminalSavedCommandsDialog', () {
    testWidgets(
      'every template parameter is required before the run action enables',
      (tester) async {
        TerminalSavedCommandResult? result;
        await _pumpDialog(tester, onResult: (value) => result = value);

        await _selectCommand(tester, 'Copy file');

        expect(_run(tester).onPressed, isNull);
        expect(_previewText(tester), 'cp {{src}} {{dst}}');

        await tester.enterText(_paramField('src'), 'a.txt');
        await tester.pump();

        expect(_run(tester).onPressed, isNull);
        expect(_previewText(tester), 'cp a.txt {{dst}}');

        await tester.enterText(_paramField('dst'), 'b.txt');
        await tester.pump();

        expect(_run(tester).onPressed, isNotNull);
        expect(_previewText(tester), 'cp a.txt b.txt');
        expect(result, isNull);
      },
    );

    testWidgets('edited preview is returned verbatim with dangerous metadata', (
      tester,
    ) async {
      TerminalSavedCommandResult? result;
      var returned = false;
      await _pumpDialog(
        tester,
        onResult: (value) {
          result = value;
          returned = true;
        },
      );

      await _selectCommand(tester, 'Danger cleanup');
      await tester.enterText(_paramField('target'), 'cache');
      await tester.pump();
      expect(_previewText(tester), 'rm -rf /tmp/cache');

      await tester.enterText(_previewField(), 'rm -rf /tmp/edited');
      await tester.pump();
      expect(_previewText(tester), 'rm -rf /tmp/edited');

      await tester.tap(_runButton());
      await tester.pumpAndSettle();

      expect(returned, isTrue);
      expect(result, isNotNull);
      expect(result!.command, 'rm -rf /tmp/edited');
      expect(result!.isDangerous, isTrue);
    });

    testWidgets('closing the dialog returns null', (tester) async {
      TerminalSavedCommandResult? result;
      var returned = false;
      await _pumpDialog(
        tester,
        onResult: (value) {
          result = value;
          returned = true;
        },
      );

      await _selectCommand(tester, 'Echo hello');
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(returned, isTrue);
      expect(result, isNull);
    });

    testWidgets(
      '320dp, 1.5x text and keyboard insets keep the run action reachable',
      (tester) async {
        TerminalSavedCommandResult? result;
        await _pumpDialog(
          tester,
          size: const Size(320, 640),
          textScale: 1.5,
          keyboardInset: 300,
          onResult: (value) => result = value,
        );

        await _selectCommand(tester, 'Copy file');
        await tester.enterText(_paramField('src'), 'a');
        await tester.enterText(_paramField('dst'), 'b');
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final button = _runButton();
        expect(button.hitTestable(), findsOneWidget);

        final rect = tester.getRect(button);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(640));

        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.command, 'cp a b');
      },
    );
  });

  group('SshTerminalView saved commands target guard', () {
    testWidgets(
      'explicit confirmation sends exactly once to the original tab',
      (tester) async {
        final bridge = _RecordingBridge();
        final tab = _tab('original', bridge);
        final notifier = _SavedNotifier(
          SshTerminalState(tabs: [tab], isInitialized: true),
        );
        final active = _MutableActive(_serverA);
        await _pumpView(tester, notifier: notifier, active: active);

        await _chooseSavedCommand(tester, 'Echo hello');
        await tester.tap(_runButton());
        await tester.pumpAndSettle();

        final l10n = await _l10n();
        expect(find.text(l10n.riskConfirmButton), findsNothing);
        expect(notifier.sends, hasLength(1));
        expect(notifier.sends.single.command, 'echo hello');
        expect(notifier.sends.single.tabId, 'original');
        expect(notifier.sends.single.bridge, same(bridge));
        expect(bridge.sent, ['echo hello']);
        expect(notifier.state.activeTab, same(tab));

        await tester.pumpWidget(const SizedBox());
        bridge.dispose();
      },
    );

    for (final target in _Target.values) {
      for (final phase in _Phase.values) {
        testWidgets(
          '${target.name} change during ${phase.name} sends nothing',
          (tester) async {
            final originalBridge = _RecordingBridge();
            final original = _tab('original', originalBridge);
            final replacementBridge = _RecordingBridge();
            final replacement = _tab('replacement', replacementBridge);
            final notifier = _SavedNotifier(
              SshTerminalState(tabs: [original], isInitialized: true),
            );
            final active = _MutableActive(_serverA);
            await _pumpView(tester, notifier: notifier, active: active);

            void mutateTarget() {
              switch (target) {
                case _Target.server:
                  active.select(_serverB);
                case _Target.tab:
                  notifier.emit(
                    notifier.state.copyWith(
                      tabs: [replacement],
                      activeTabIndex: 0,
                    ),
                  );
                case _Target.bridge:
                  notifier.emit(
                    notifier.state.copyWith(
                      tabs: [
                        TerminalTab(
                          id: original.id,
                          title: original.title,
                          terminal: replacementBridge.terminal,
                          bridge: replacementBridge,
                        ),
                      ],
                      activeTabIndex: 0,
                    ),
                  );
              }
            }

            if (phase == _Phase.preview) {
              await _chooseSavedCommand(tester, 'Echo hello');
              mutateTarget();
              await tester.pumpAndSettle();
              await tester.tap(_runButton());
              await tester.pumpAndSettle();
            } else {
              await _chooseSavedCommand(tester, 'Danger marker');
              await tester.tap(_runButton());
              await tester.pumpAndSettle();

              final l10n = await _l10n();
              expect(find.text(l10n.riskConfirmButton), findsOneWidget);

              mutateTarget();
              await tester.pumpAndSettle();
              await tester.tap(find.text(l10n.riskConfirmButton));
              await tester.pumpAndSettle();
            }

            expect(notifier.sends, isEmpty);
            expect(originalBridge.sent, isEmpty);
            expect(replacementBridge.sent, isEmpty);

            await tester.pumpWidget(const SizedBox());
            originalBridge.dispose();
            replacementBridge.dispose();
          },
        );
      }
    }

    for (final phase in _Phase.values) {
      testWidgets(
        'same bridge disconnect and reconnect during ${phase.name} sends nothing',
        (tester) async {
          final bridge = _RecordingBridge();
          final tab = _tab('original', bridge);
          final notifier = _SavedNotifier(
            SshTerminalState(tabs: [tab], isInitialized: true),
          );
          final active = _MutableActive(_serverA);
          await _pumpView(tester, notifier: notifier, active: active);
          final l10n = await _l10n();

          if (phase == _Phase.preview) {
            await _chooseSavedCommand(tester, 'Echo hello');
          } else {
            await _chooseSavedCommand(tester, 'Danger marker');
            await tester.tap(_runButton());
            await tester.pumpAndSettle();
            expect(find.text(l10n.riskConfirmButton), findsOneWidget);
          }

          // Only the connection changes: server, tab and bridge stay identical,
          // so the parent's saved-command epoch is the guard under test.
          bridge.setConnectionState(TerminalConnectionState.disconnected);
          await tester.pumpAndSettle();
          bridge.setConnectionState(TerminalConnectionState.connected);
          await tester.pumpAndSettle();

          expect(bridge.state, TerminalConnectionState.connected);
          expect(notifier.sends, isEmpty);
          expect(bridge.sent, isEmpty);

          if (phase == _Phase.preview) {
            await tester.tap(_runButton());
          } else {
            await tester.tap(find.text(l10n.riskConfirmButton));
          }
          await tester.pumpAndSettle();

          expect(notifier.sends, isEmpty);
          expect(bridge.sent, isEmpty);

          await tester.pumpWidget(const SizedBox());
          bridge.dispose();
        },
      );
    }

    for (final entry in <(String, String?)>[
      ('Run script', 'multiline'),
      ('Danger marker', null),
    ]) {
      testWidgets('${entry.$1} requires the danger confirmation dialog', (
        tester,
      ) async {
        final bridge = _RecordingBridge();
        final tab = _tab('original', bridge);
        final notifier = _SavedNotifier(
          SshTerminalState(tabs: [tab], isInitialized: true),
        );
        final active = _MutableActive(_serverA);
        await _pumpView(tester, notifier: notifier, active: active);
        final l10n = await _l10n();

        await _chooseSavedCommand(tester, entry.$1);
        await tester.tap(_runButton());
        await tester.pumpAndSettle();

        expect(find.text(l10n.riskConfirmButton), findsOneWidget);
        if (entry.$2 == 'multiline') {
          expect(
            find.text(l10n.terminalSavedCommandsMultilineWarning),
            findsOneWidget,
          );
        }
        expect(notifier.sends, isEmpty);

        await tester.tap(find.text(l10n.riskCancelButton));
        await tester.pumpAndSettle();
        expect(notifier.sends, isEmpty);
        expect(bridge.sent, isEmpty);

        await _chooseSavedCommand(tester, entry.$1);
        await tester.tap(_runButton());
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.riskConfirmButton));
        await tester.pumpAndSettle();

        expect(notifier.sends, hasLength(1));
        expect(bridge.sent, hasLength(1));

        await tester.pumpWidget(const SizedBox());
        bridge.dispose();
      });
    }
  });
}
