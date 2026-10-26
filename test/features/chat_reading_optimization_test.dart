import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart';

class _ReadingTestNotifier extends FakeAcpChatNotifier {
  _ReadingTestNotifier(super.initialState)
    : super(refreshResult: true, refreshError: null);

  void emit(AiChatState value) => state = value;
}

class _FakeLauncher extends UrlLauncherPlatform {
  final List<String> launched = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

final List<String> _codeLines = List.generate(
  80,
  (index) => 'echo line-${(index + 1).toString().padLeft(2, '0')}',
);
final String _fullCode = '${_codeLines.join('\n')}\n';
final String _message = '```bash\n$_fullCode```';

ChatSession _session(String id, List<ChatMessage> messages) => ChatSession(
  id: id,
  title: id,
  serverId: harnessServerId,
  agentId: harnessAgent.id,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  messages: messages,
);

ChatMessage _assistant(
  String id,
  String content, {
  ChatTurnStatus status = ChatTurnStatus.completed,
}) => ChatMessage(
  id: id,
  role: MessageRole.assistant,
  content: content,
  status: status,
  createdAt: DateTime.now(),
);

AiChatState _state(List<ChatMessage> messages, {bool isGenerating = false}) {
  final session = _session('reading-session', messages);
  return AiChatState(
    sessions: [session],
    activeSessionId: 'reading-session',
    activeAgentProfile: harnessAgent,
    readyAgents: [harnessAgent],
    isGenerating: isGenerating,
  );
}

void _configureView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<_ReadingTestNotifier> _pumpChat(
  WidgetTester tester,
  AiChatState state, {
  bool settle = true,
}) async {
  _configureView(tester);
  final notifier = _ReadingTestNotifier(state);
  await pumpAcpHarness(tester, child: const AiChatView(), notifier: notifier);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Generating views animate forever; never wait for a settled frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return notifier;
}

Future<void> _emit(
  WidgetTester tester,
  _ReadingTestNotifier notifier,
  AiChatState state,
) async {
  notifier.emit(state);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<_ReadingTestNotifier> _pumpWithCode(WidgetTester tester) {
  return _pumpChat(tester, _state([_assistant('reading-msg', _message)]));
}

SelectableText _codePreview(WidgetTester tester) {
  return tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .firstWhere((widget) => (widget.data ?? '').contains('echo line-01'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    // A tap that misses its target must fail instead of only warning.
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  tearDown(() {
    WidgetController.hitTestWarningShouldBeFatal = false;
  });

  testWidgets('long completed bash block previews 12 lines then expands and '
      'collapses', (tester) async {
    await _pumpWithCode(tester);

    final preview = _codePreview(tester);
    final previewLines = preview.data!.split('\n');
    expect(previewLines, hasLength(12));
    expect(preview.data, contains('echo line-12'));
    expect(preview.data, isNot(contains('echo line-13')));
    expect(preview.data, isNot(contains('echo line-80')));

    final expand = find.text(l10n.chatExpandCode('80'));
    expect(expand, findsOneWidget);
    await tester.ensureVisible(expand);
    await tester.pumpAndSettle();
    await tester.tap(expand);
    await tester.pumpAndSettle();

    expect(_codePreview(tester).data, _fullCode);
    expect(_codePreview(tester).data, contains('echo line-80'));

    final collapse = find.text(l10n.chatCollapseCode);
    expect(collapse, findsOneWidget);
    await tester.ensureVisible(collapse);
    await tester.pumpAndSettle();
    await tester.tap(collapse);
    await tester.pumpAndSettle();

    expect(_codePreview(tester).data!.split('\n'), hasLength(12));
    expect(_codePreview(tester).data, isNot(contains('echo line-80')));
  });

  testWidgets('copy from collapsed preview writes full code and code reader '
      'shows the original', (tester) async {
    String? clipboardText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await _pumpWithCode(tester);

    expect(_codePreview(tester).data!.split('\n'), hasLength(12));

    // The message itself also has a copy action; scope to the code block.
    final previewFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SelectableText &&
          (widget.data ?? '').contains('echo line-01'),
    );
    final codeBlock = find
        .ancestor(of: previewFinder, matching: find.byType(Container))
        .first;
    final copy = find.descendant(
      of: codeBlock,
      matching: find.byIcon(Icons.copy_rounded),
    );
    expect(copy, findsOneWidget);
    await tester.ensureVisible(copy);
    await tester.pumpAndSettle();
    await tester.tap(copy);
    await tester.pumpAndSettle();

    expect(
      clipboardText,
      _fullCode,
      reason: 'Copy must write the full original, not the 12-line preview',
    );

    await tester.tap(find.byTooltip(l10n.chatCodeReaderTitle));
    await tester.pumpAndSettle();

    expect(find.text('${l10n.chatCodeReaderTitle} (bash)'), findsOneWidget);
    final reader = tester
        .widgetList<SelectableText>(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(SelectableText),
          ),
        )
        .single;
    expect(reader.data, _fullCode);
    expect(reader.data, contains('echo line-80'));

    // Let the copy snackbar timer expire before the test ends.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('expanded code stays expanded after a same-message refresh', (
    tester,
  ) async {
    final notifier = await _pumpWithCode(tester);

    final expand = find.text(l10n.chatExpandCode('80'));
    expect(expand, findsOneWidget);
    await tester.ensureVisible(expand);
    await tester.pumpAndSettle();
    await tester.tap(expand);
    await tester.pumpAndSettle();
    expect(_codePreview(tester).data, _fullCode);

    await _emit(
      tester,
      notifier,
      _state([_assistant('reading-msg', _message)]),
    );

    expect(
      _codePreview(tester).data,
      _fullCode,
      reason: 'Refreshing the same message must not reset its expansion',
    );
    expect(_codePreview(tester).data, contains('echo line-80'));
    expect(find.text(l10n.chatExpandCode('80')), findsNothing);
    expect(find.text(l10n.chatCollapseCode), findsOneWidget);
  });

  testWidgets('a completed stream with unchanged long code never suddenly '
      'folds', (tester) async {
    final notifier = await _pumpChat(
      tester,
      _state([
        _assistant('reading-msg', _message, status: ChatTurnStatus.streaming),
      ], isGenerating: true),
      settle: false,
    );

    expect(_codePreview(tester).data, _fullCode);
    expect(find.text(l10n.chatExpandCode('80')), findsNothing);

    await _emit(
      tester,
      notifier,
      _state([_assistant('reading-msg', _message)]),
    );

    expect(
      _codePreview(tester).data,
      _fullCode,
      reason: 'Completing a stream must not fold code the user already saw',
    );
    expect(_codePreview(tester).data, contains('echo line-80'));
    expect(find.text(l10n.chatExpandCode('80')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('another reply generating must not unfold older historical '
      'code', (tester) async {
    final older = _assistant('older-msg', _message);
    final notifier = await _pumpChat(tester, _state([older]));

    expect(_codePreview(tester).data!.split('\n'), hasLength(12));
    expect(find.text(l10n.chatExpandCode('80')), findsOneWidget);

    final reply = _assistant(
      'new-msg',
      'Working on the next answer',
      status: ChatTurnStatus.streaming,
    );
    await _emit(tester, notifier, _state([older, reply], isGenerating: true));

    final preview = _codePreview(tester);
    expect(
      preview.data!.split('\n'),
      hasLength(12),
      reason: 'A new streaming reply must not expand older history',
    );
    expect(preview.data, isNot(contains('echo line-80')));
    expect(find.text(l10n.chatExpandCode('80')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reference-style link resolves when its definition follows a '
      'blank line', (tester) async {
    final previous = UrlLauncherPlatform.instance;
    final launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);

    await _pumpChat(
      tester,
      _state([
        _assistant(
          'reading-msg',
          '[site][ref]\n\n[ref]: https://example.com/reference-style',
        ),
      ]),
    );

    final link = find.text('site', findRichText: true);
    expect(
      link,
      findsOneWidget,
      reason: 'The reference definition must survive the blank-line split',
    );
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(launcher.launched, ['https://example.com/reference-style']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('inline code stays inline instead of becoming a code block', (
    tester,
  ) async {
    await _pumpChat(
      tester,
      _state([_assistant('reading-msg', 'Run `flutter test` before merging.')]),
    );

    expect(
      find.textContaining(
        'Run flutter test before merging',
        findRichText: true,
      ),
      findsOneWidget,
      reason: 'Inline code must remain part of the surrounding paragraph',
    );
    expect(find.byTooltip(l10n.chatCodeReaderTitle), findsNothing);
    expect(find.byIcon(Icons.fullscreen_outlined), findsNothing);
    expect(
      tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .where((widget) => widget.data == 'flutter test'),
      isEmpty,
      reason: 'Inline code must not be extracted into a standalone block',
    );
  });
}
