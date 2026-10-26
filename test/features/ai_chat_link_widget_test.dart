import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';

import '../support/acp_chat_widget_harness.dart';

class _FakeLauncher extends UrlLauncherPlatform {
  final List<String> launched = [];
  final List<PreferredLaunchMode?> modes = [];
  bool succeed = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    modes.add(options.mode);
    return succeed;
  }
}

class _LinkTestNotifier extends FakeAcpChatNotifier {
  _LinkTestNotifier(super.initialState)
    : super(refreshResult: true, refreshError: null);
}

ChatSession _session(String id, List<ChatMessage> messages) => ChatSession(
  id: id,
  title: id,
  serverId: harnessServerId,
  agentId: harnessAgent.id,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  messages: messages,
);

ChatMessage _assistant(String id, String content) => ChatMessage(
  id: id,
  role: MessageRole.assistant,
  content: content,
  createdAt: DateTime.now(),
);

Future<void> _pumpWithMessage(WidgetTester tester, String content) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final session = _session('link-session', [_assistant('link-msg', content)]);
  final notifier = _LinkTestNotifier(
    AiChatState(
      sessions: [session],
      activeSessionId: 'link-session',
      activeAgentProfile: harnessAgent,
      readyAgents: [harnessAgent],
    ),
  );
  await pumpAcpHarness(tester, child: const AiChatView(), notifier: notifier);
  await tester.pumpAndSettle();
}

Future<void> _tapLink(WidgetTester tester, String text) async {
  final link = find.text(text, findRichText: true);
  expect(link, findsOneWidget, reason: 'link text "$text" should render');
  await tester.tap(link);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UrlLauncherPlatform previous;
  late _FakeLauncher launcher;

  setUp(() {
    previous = UrlLauncherPlatform.instance;
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    UrlLauncherPlatform.instance = previous;
  });

  testWidgets('Markdown link opens the system browser', (tester) async {
    await _pumpWithMessage(tester, '[Docs](https://example.com/markdown)');

    await _tapLink(tester, 'Docs');

    expect(launcher.launched, ['https://example.com/markdown']);
    expect(launcher.modes, [PreferredLaunchMode.externalApplication]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('bare HTTPS URL opens the system browser', (tester) async {
    await _pumpWithMessage(tester, 'https://example.com/bare');

    await _tapLink(tester, 'https://example.com/bare');

    expect(launcher.launched, ['https://example.com/bare']);
    expect(launcher.modes, [PreferredLaunchMode.externalApplication]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('false launch result gives visible feedback', (tester) async {
    launcher.succeed = false;
    await _pumpWithMessage(tester, 'https://example.com/unhandled');

    final link = find.text('https://example.com/unhandled', findRichText: true);
    expect(link, findsOneWidget);
    await tester.tap(link);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(launcher.launched, ['https://example.com/unhandled']);
    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason: 'A failed system-browser handoff must tell the user',
    );
    expect(tester.takeException(), isNull);
  });
}
