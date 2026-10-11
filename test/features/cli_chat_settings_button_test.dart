import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/agents/agent_management_view.dart';
import 'package:valhalla/features/chat/cli_chat_view.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/fixed_terminal_settings.dart';

class _FakeCliChatNotifier extends CliChatNotifier {
  final CliChatState _initialState;
  final List<String> sentTerminalKeys = [];
  final List<String> pastedTerminalTexts = [];
  bool pasteTerminalClipboardCalled = false;

  _FakeCliChatNotifier(this._initialState);

  @override
  CliChatState build() => _initialState;

  @override
  void sendTerminalKey(String key, {bool isCtrl = false, bool isAlt = false}) {
    sentTerminalKeys.add(key);
  }

  @override
  Future<void> pasteTerminalClipboard() async {
    pasteTerminalClipboardCalled = true;
  }

  @override
  void pasteTerminalText(String text) {
    pastedTerminalTexts.add(text);
  }
}

class _TestServerConnectionNotifier extends ServerConnectionNotifier {
  final bool connected;
  _TestServerConnectionNotifier({this.connected = true});

  @override
  ServerConnectionState build() {
    return ServerConnectionState(
      status: connected
          ? ConnectionStateEnum.connected
          : ConnectionStateEnum.disconnected,
    );
  }
}

class _TestActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _TestActiveServerNotifier([this._server]);

  @override
  ServerProfile? build() => _server;
}

class _TestAgentRegistryNotifier extends AgentRegistryNotifier {
  @override
  AgentRegistryState build() {
    return const AgentRegistryState(agents: [], isLoading: false);
  }
}

const _server = ServerProfile(
  id: 'srv-1',
  name: 'Dev Server',
  host: '10.0.0.1',
  port: 22,
  username: 'root',
);

final _testAgent = AgentProfile(
  id: 'agent-codex',
  serverId: 'srv-1',
  name: 'Codex CLI',
  description: 'Codex AI assistant',
  cliCommand: 'codex',
);

Future<void> _pumpCliChat(
  WidgetTester tester, {
  required _FakeCliChatNotifier notifier,
  Size size = const Size(500, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeServerProvider.overrideWith(
          () => _TestActiveServerNotifier(_server),
        ),
        serverConnectionProvider.overrideWith(
          () => _TestServerConnectionNotifier(connected: true),
        ),
        agentRegistryProvider.overrideWith(_TestAgentRegistryNotifier.new),
        cliChatProvider.overrideWith(() => notifier),
        ...fixedTerminalSettingsOverrides(),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CliChatView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CliChatView Settings Gear Button and SharedTerminalCanvas Integration', () {
    testWidgets(
      'mobile AppBar has permanent gear button navigating to AgentManagementView',
      (tester) async {
        final fakeNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_testAgent],
            activeAgent: _testAgent,
          ),
        );

        await _pumpCliChat(
          tester,
          notifier: fakeNotifier,
          size: const Size(500, 900),
        );

        final gearFinder = find.byKey(
          const Key('cli_mobile_appbar_settings_button'),
        );
        expect(gearFinder, findsOneWidget);

        await tester.tap(gearFinder);
        await tester.pumpAndSettle();

        expect(find.byType(AgentManagementView), findsOneWidget);
      },
    );

    testWidgets(
      'desktop agent area has permanent gear button navigating to AgentManagementView',
      (tester) async {
        final fakeNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_testAgent],
            activeAgent: _testAgent,
          ),
        );

        await _pumpCliChat(
          tester,
          notifier: fakeNotifier,
          size: const Size(1000, 800),
        );

        final gearFinder = find.byKey(const Key('cli_sidebar_settings_button'));
        expect(gearFinder, findsOneWidget);

        await tester.tap(gearFinder);
        await tester.pumpAndSettle();

        expect(find.byType(AgentManagementView), findsOneWidget);
      },
    );

    testWidgets(
      'renders SharedTerminalCanvas when terminal is active and connects key/paste calls',
      (tester) async {
        const clipboardText = 'echo hello';
        var clipboardReads = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.getData') {
                clipboardReads++;
                return {'text': clipboardText};
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        final terminal = Terminal(maxLines: 50);
        final fakeNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [_testAgent],
            activeAgent: _testAgent,
            terminal: terminal,
          ),
        );

        await _pumpCliChat(
          tester,
          notifier: fakeNotifier,
          size: const Size(1000, 800),
        );

        expect(find.byType(SharedTerminalCanvas), findsOneWidget);

        // Tap an accessory key (e.g. TAB)
        final tabFinder = find.text('TAB');
        expect(tabFinder, findsOneWidget);
        await tester.tap(tabFinder);
        await tester.pumpAndSettle();

        expect(fakeNotifier.sentTerminalKeys, contains('TAB'));

        // Tap paste button
        final pasteFinder = find.byIcon(Icons.content_paste);
        expect(pasteFinder, findsOneWidget);
        await tester.tap(pasteFinder);
        await tester.pumpAndSettle();

        expect(clipboardReads, 1, reason: 'PASTE 只应在进入流程时读一次剪贴板');
        expect(
          fakeNotifier.pastedTerminalTexts,
          [clipboardText],
          reason: '应将快照后的单行剪贴板文本一次性发给 pasteTerminalText',
        );
        expect(
          fakeNotifier.pasteTerminalClipboardCalled,
          isFalse,
          reason: 'onPasteText 已固化文本，legacy onPaste 不得再读剪贴板',
        );
      },
    );
  });
}
