import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/infrastructure/acp/acp_oauth_request.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import '../support/temp_chat_db.dart';

const _marker = 'Open the following link to authenticate the ACP server: ';

const _authorizationUrl =
    'https://accounts.google.com/o/oauth2/v2/auth'
    '?client_id=dummy'
    '&response_type=code'
    '&redirect_uri=http%3A%2F%2F127.0.0.1%3A8765%2Fcb'
    '&state=dummy-state';

const _validCallback =
    'http://127.0.0.1:8765/cb?code=dummy-code&state=dummy-state';
const _mismatchedStateCallback =
    'http://127.0.0.1:8765/cb?code=dummy-code&state=other-state';
const _mismatchedRedirectCallback =
    'http://127.0.0.1:9999/cb?code=dummy-code&state=dummy-state';
const _invalidCallback = 'not-a-callback-url';

const _launchFailedText =
    'Could not open external browser. Please reopen or copy the authorization link below.';
const _invalidCallbackText = 'Invalid callback URL format or delivery failed';
const _retryHintText = 'After logging in, send your message again.';

const _reopenKey = Key('chat_auth_reopen_browser_button');
const _manualKey = Key('chat_auth_manual_callback_button');
const _dialogKey = Key('chat_auth_manual_callback_dialog');
const _inputKey = Key('chat_auth_callback_input');
const _submitKey = Key('chat_auth_callback_submit_button');

Future<void> _pumpBeats(WidgetTester tester, {int beats = 12}) async {
  for (var i = 0; i < beats; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void _setLogicalView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

AcpOAuthRequest _validatedRequest() {
  final request = AcpOAuthRequest.fromLine('$_marker$_authorizationUrl');
  expect(request, isNotNull, reason: 'synthetic challenge must validate');
  return request!;
}

AgentProfile _agyProfile() => AgentProfile(
  id: 'builtin-agy',
  serverId: 'srv-test-1',
  name: 'Antigravity AGY',
  description: 'ACP agent',
  cliCommand: 'agy',
  acpCommand: 'agy_acp_server.par',
  loginCommand: 'agy',
);

AiChatState _pendingAuthState({
  required AgentProfile profile,
  AcpOAuthRequest? request,
  bool isAuthenticating = true,
}) => AiChatState(
  activeAgentProfile: profile,
  authChallenge: AuthChallenge(
    agentId: profile.id,
    methods: const [
      AcpAuthMethod(
        id: 'oauth-personal',
        name: 'Google Account',
        description: 'Sign in with Google',
      ),
    ],
  ),
  authRequest: request,
  isAuthenticating: isAuthenticating,
);

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launchedUrls = <String>[];
  bool succeed = true;
  Object? failure;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    final failure = this.failure;
    if (failure != null) throw failure;
    return succeed;
  }

  @override
  LinkDelegate? get linkDelegate => null;
}

class _ScriptedAiChatNotifier extends AiChatNotifier {
  _ScriptedAiChatNotifier(this.initialState);

  final AiChatState initialState;
  final List<AcpOAuthRequest> claimAttempts = <AcpOAuthRequest>[];
  AcpOAuthRequest? _claimed;

  @override
  AiChatState build() => initialState;

  void emit(AiChatState next) => state = next;

  @override
  bool claimAuthBrowserLaunch(AcpOAuthRequest request) {
    claimAttempts.add(request);
    if (_claimed != null && identical(_claimed, request)) return false;
    _claimed = request;
    return true;
  }

  @override
  Future<void> submitAuthCallback(String callback) async {
    final request = state.authRequest;
    final profile = state.activeAgentProfile;
    if (request == null || profile == null || !state.isAuthenticating) {
      throw StateError('ACP_AUTH_NOT_PENDING');
    }
    try {
      request.validateCallback(callback);
    } catch (_) {
      if (state.authRequest == request) {
        state = state.copyWith(authError: 'ACP_AUTH_CALLBACK_DELIVERY_FAILED');
      }
      throw StateError('ACP_AUTH_CALLBACK_DELIVERY_FAILED');
    }
  }

  @override
  Future<void> respondAuth(String? methodId) async {
    if (methodId == null) {
      state = state.copyWith(clearAuthChallenge: true);
      return;
    }
    state = state.copyWith(isAuthenticating: true);
    state = state.copyWith(
      authenticationConfirmed: true,
      clearAuthChallenge: true,
    );
  }
}

class _StubAgentRegistryNotifier extends AgentRegistryNotifier {
  _StubAgentRegistryNotifier(this.initialState);

  final AgentRegistryState initialState;

  @override
  AgentRegistryState build() => initialState;
}

class _StubActiveServerNotifier extends ActiveServerNotifier {
  _StubActiveServerNotifier(this.server);

  final ServerProfile server;

  @override
  ServerProfile? build() => server;
}

class _StubServerConnectionNotifier extends ServerConnectionNotifier {
  _StubServerConnectionNotifier(this.initialState);

  final ServerConnectionState initialState;

  @override
  ServerConnectionState build() => initialState;
}

const ServerProfile _rackNerd = ServerProfile(
  id: 'srv-test-1',
  name: 'racknerd',
  host: 'racknerd',
  port: 22,
  username: 'admin',
  authType: AuthType.password,
);

Widget _buildApp({
  required LocalStorageService local,
  required _ScriptedAiChatNotifier notifier,
  required AgentProfile profile,
  required Widget home,
}) {
  final runtime = AgentRuntimeState(
    profile: profile,
    status: AgentEnvironmentStatus(
      kind: AgentEnvironmentStatusKind.ready,
      checkedAt: DateTime.now(),
    ),
  );
  return ProviderScope(
    overrides: [
      tempChatRepositoryOverride(),
      localStorageServiceProvider.overrideWithValue(local),
      activeServerProvider.overrideWith(
        () => _StubActiveServerNotifier(_rackNerd),
      ),
      serverConnectionProvider.overrideWith(
        () => _StubServerConnectionNotifier(
          const ServerConnectionState(status: ConnectionStateEnum.connected),
        ),
      ),
      agentRegistryProvider.overrideWith(
        () => _StubAgentRegistryNotifier(
          AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
        ),
      ),
      aiChatProvider.overrideWith(() => notifier),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

Future<({Widget app, _ScriptedAiChatNotifier notifier})> _start(
  WidgetTester tester,
  AiChatState state,
) async {
  SharedPreferences.setMockInitialValues({});
  final local = await LocalStorageService.init();
  final notifier = _ScriptedAiChatNotifier(state);
  final app = _buildApp(
    local: local,
    notifier: notifier,
    profile: state.activeAgentProfile!,
    home: const AiChatView(),
  );
  await tester.pumpWidget(app);
  await _pumpBeats(tester);
  return (app: app, notifier: notifier);
}

void main() {
  late _FakeUrlLauncher launcher;
  late UrlLauncherPlatform originalLauncher;

  setUp(() {
    originalLauncher = UrlLauncherPlatform.instance;
    launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalLauncher;
  });

  testWidgets('auto-opens a validated auth request once despite rebuilds', (
    tester,
  ) async {
    _setLogicalView(tester, 480, 1400);
    final profile = _agyProfile();
    final request = _validatedRequest();
    final started = await _start(tester, _pendingAuthState(profile: profile));

    expect(launcher.launchedUrls, isEmpty);
    expect(started.notifier.claimAttempts, isEmpty);

    started.notifier.emit(
      started.notifier.state.copyWith(authRequest: request),
    );
    await _pumpBeats(tester);

    expect(started.notifier.claimAttempts, hasLength(1));
    expect(launcher.launchedUrls, hasLength(1));
    expect(launcher.launchedUrls.single, request.authorizationUrl.toString());

    await tester.pumpWidget(started.app);
    await _pumpBeats(tester);
    expect(launcher.launchedUrls, hasLength(1));

    started.notifier.emit(
      started.notifier.state.copyWith(authRequest: request),
    );
    await _pumpBeats(tester);
    expect(launcher.launchedUrls, hasLength(1));
    expect(started.notifier.claimAttempts, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a false browser launch shows the localized fallback', (
    tester,
  ) async {
    _setLogicalView(tester, 480, 1400);
    launcher.succeed = false;
    final profile = _agyProfile();
    final request = _validatedRequest();
    final started = await _start(tester, _pendingAuthState(profile: profile));

    started.notifier.emit(
      started.notifier.state.copyWith(authRequest: request),
    );
    await _pumpBeats(tester);

    expect(launcher.launchedUrls, hasLength(1));
    expect(find.text(_launchFailedText), findsOneWidget);

    launcher.succeed = true;
    await tester.tap(find.byKey(_reopenKey));
    await _pumpBeats(tester);

    expect(launcher.launchedUrls, hasLength(2));
    expect(launcher.launchedUrls.last, request.authorizationUrl.toString());
    expect(find.text(_launchFailedText), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a throwing browser launch shows the localized fallback', (
    tester,
  ) async {
    _setLogicalView(tester, 480, 1400);
    launcher.failure = Exception('browser unavailable');
    final profile = _agyProfile();
    final request = _validatedRequest();
    final started = await _start(tester, _pendingAuthState(profile: profile));

    started.notifier.emit(
      started.notifier.state.copyWith(authRequest: request),
    );
    await _pumpBeats(tester);

    expect(launcher.launchedUrls, hasLength(1));
    expect(find.text(_launchFailedText), findsOneWidget);

    launcher.failure = null;
    launcher.succeed = true;
    await tester.tap(find.byKey(_reopenKey));
    await _pumpBeats(tester);

    expect(launcher.launchedUrls, hasLength(2));
    expect(find.text(_launchFailedText), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual callback dialog masks input and rejects bad callbacks', (
    tester,
  ) async {
    _setLogicalView(tester, 480, 1400);
    final profile = _agyProfile();
    final request = _validatedRequest();
    await _start(tester, _pendingAuthState(profile: profile, request: request));
    await _pumpBeats(tester);

    await tester.tap(find.byKey(_manualKey));
    await _pumpBeats(tester);

    expect(find.byKey(_dialogKey), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(_inputKey));
    expect(field.obscureText, isTrue);
    expect(field.controller, isNotNull);

    await tester.enterText(find.byKey(_inputKey), _invalidCallback);
    await tester.tap(find.byKey(_submitKey));
    await _pumpBeats(tester);
    expect(find.byKey(_dialogKey), findsOneWidget);
    expect(find.text(_invalidCallbackText), findsOneWidget);
    expect(find.textContaining(_invalidCallback), findsNothing);

    await tester.enterText(find.byKey(_inputKey), _mismatchedStateCallback);
    await tester.tap(find.byKey(_submitKey));
    await _pumpBeats(tester);
    expect(find.byKey(_dialogKey), findsOneWidget);
    expect(find.text(_invalidCallbackText), findsOneWidget);

    await tester.enterText(find.byKey(_inputKey), _mismatchedRedirectCallback);
    await tester.tap(find.byKey(_submitKey));
    await _pumpBeats(tester);
    expect(find.byKey(_dialogKey), findsOneWidget);
    expect(find.text(_invalidCallbackText), findsOneWidget);

    await tester.enterText(find.byKey(_inputKey), _validCallback);
    await tester.tap(find.byKey(_submitKey));
    await _pumpBeats(tester);

    expect(find.byKey(_dialogKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the manual callback dialog leaves no callback text', (
    tester,
  ) async {
    _setLogicalView(tester, 480, 1400);
    final profile = _agyProfile();
    final request = _validatedRequest();
    final started = await _start(
      tester,
      _pendingAuthState(profile: profile, request: request),
    );
    await _pumpBeats(tester);

    await tester.tap(find.byKey(_manualKey));
    await _pumpBeats(tester);
    expect(find.byKey(_dialogKey), findsOneWidget);

    final controller = tester
        .widget<TextField>(find.byKey(_inputKey))
        .controller!;
    await tester.enterText(find.byKey(_inputKey), _validCallback);
    expect(find.text(_validCallback), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await _pumpBeats(tester);

    expect(find.byKey(_dialogKey), findsNothing);
    expect(controller.text, isEmpty);
    expect(find.textContaining('dummy-code'), findsNothing);
    expect(find.textContaining(_validCallback), findsNothing);
    expect(
      started.notifier.state.authError == null ||
          !started.notifier.state.authError!.contains('dummy-code'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling pending auth does not show the success snackbar', (
    tester,
  ) async {
    _setLogicalView(tester, 480, 1400);
    final profile = _agyProfile();
    await _start(tester, _pendingAuthState(profile: profile));
    expect(find.text(_retryHintText), findsNothing);

    await tester.tap(find.text('Cancel'));
    await _pumpBeats(tester);

    expect(find.text(_retryHintText), findsNothing);
    expect(find.text('Authentication Required'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a confirmed auth rpc shows the success snackbar', (
    tester,
  ) async {
    _setLogicalView(tester, 480, 1400);
    final profile = _agyProfile();
    await _start(
      tester,
      _pendingAuthState(profile: profile, isAuthenticating: false),
    );
    expect(find.text(_retryHintText), findsNothing);

    await tester.tap(find.text('Log In'));
    await _pumpBeats(tester);

    expect(find.text(_retryHintText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth controls and manual dialog stay reachable at 320dp 2x', (
    tester,
  ) async {
    _setLogicalView(tester, 320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final profile = _agyProfile();
    final request = _validatedRequest();
    await _start(tester, _pendingAuthState(profile: profile, request: request));

    expect(find.byKey(_reopenKey), findsOneWidget);
    expect(find.byKey(_manualKey), findsOneWidget);
    expect(find.byKey(Key('chat_auth_copy_link_button')), findsOneWidget);

    await tester.ensureVisible(find.byKey(_reopenKey));
    await _pumpBeats(tester);
    await tester.tap(find.byKey(_reopenKey));
    await _pumpBeats(tester);
    expect(launcher.launchedUrls, hasLength(1));

    await tester.ensureVisible(find.byKey(_manualKey));
    await _pumpBeats(tester);
    await tester.tap(find.byKey(_manualKey));
    await _pumpBeats(tester);

    expect(find.byKey(_dialogKey), findsOneWidget);

    final dialog = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: find.byKey(_dialogKey),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(dialog.child, isA<Column>());

    await tester.ensureVisible(find.byKey(_inputKey));
    await _pumpBeats(tester);
    await tester.tap(find.byKey(_inputKey));
    await _pumpBeats(tester);

    await tester.enterText(find.byKey(_inputKey), _validCallback);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await _pumpBeats(tester);
    expect(find.byKey(_dialogKey), findsNothing);

    final layoutIssues = <Object>[];
    for (var i = 0; i < 16; i++) {
      final error = tester.takeException();
      if (error == null) break;
      layoutIssues.add(error);
    }
    expect(
      layoutIssues,
      isEmpty,
      reason: 'RECORDED_LAYOUT_ISSUES=$layoutIssues',
    );
  });
}
