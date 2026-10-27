import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_workspace.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/features/chat/widgets/chat_commands_skills_dialog.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart';

const _dialogKey = Key('chat_commands_skills_dialog');
const _promptKey = Key('chatPromptInput');

const _commands = [
  AcpSlashCommand('status', 'Show session status', 'query'),
  AcpSlashCommand('compact', 'Compact the transcript', null),
  AcpSlashCommand(r'$review', 'Review the diff', 'skill'),
];

class _PreferencesNotifier extends FakeAcpChatNotifier {
  _PreferencesNotifier(super.initialState);

  final Set<String> favorites = <String>{};
  final List<String> recent = <String>[];
  final List<(String, bool)> favoriteCalls = <(String, bool)>[];
  final List<String> recordCalls = <String>[];

  bool failFavorite = false;
  Completer<void>? recordGate;
  int prepareCalls = 0;

  void emit(AiChatState next) => state = next;

  @override
  String? get commandPreferenceKey {
    final profile = state.activeAgentProfile;
    final serverId = ref.read(activeServerProvider)?.id;
    if (profile == null || serverId == null || profile.serverId != serverId) {
      return null;
    }
    return jsonEncode([serverId, profile.id, chatExecutionKey(profile)]);
  }

  @override
  ({Set<String> favorites, List<String> recent}) get commandPreferences {
    if (commandPreferenceKey == null) {
      return (favorites: const <String>{}, recent: const <String>[]);
    }
    return (
      favorites: Set<String>.unmodifiable(favorites),
      recent: List<String>.unmodifiable(recent),
    );
  }

  @override
  Future<void> setCommandFavorite(
    String id,
    bool favorite, {
    required String expectedScopeKey,
  }) async {
    if (expectedScopeKey != commandPreferenceKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    favoriteCalls.add((id, favorite));
    if (failFavorite) {
      throw StateError('CHAT_COMMAND_PREFERENCES_SAVE_FAILED');
    }
    if (favorite) {
      favorites.add(id);
    } else {
      favorites.remove(id);
    }
  }

  @override
  Future<void> recordCommandUse(
    String id, {
    required String expectedScopeKey,
  }) async {
    if (expectedScopeKey != commandPreferenceKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    recordCalls.add(id);
    final gate = recordGate;
    if (gate != null) await gate.future;
    recent
      ..remove(id)
      ..insert(0, id);
    if (recent.length > 10) recent.removeRange(10, recent.length);
  }

  @override
  Future<bool> prepareComposerCatalog() async {
    prepareCalls++;
    return true;
  }
}

AiChatState _draftState({List<AcpSlashCommand> commands = _commands}) =>
    AiChatState(
      activeAgentProfile: harnessAgent,
      readyAgents: [harnessAgent],
      commands: commands,
    );

Future<void> _pumpChat(
  WidgetTester tester,
  _PreferencesNotifier notifier,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpAcpHarness(tester, child: const AiChatView(), notifier: notifier);
  await tester.pumpAndSettle();
}

Future<void> _openCommands(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('chat_commands_menu_button')));
  await tester.pumpAndSettle();
  expect(find.byKey(_dialogKey), findsOneWidget);
}

Finder _tileFor(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(ListTile)).first;

/// The All / Favorites / Recent segments live in a horizontal scroll view and
/// the Recent segment starts off-screen on a 390dp viewport. Scroll it into
/// view before tapping so the filter actually changes.
Future<void> _tapFilter(WidgetTester tester, String label) async {
  final finder = find.text(label);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapStar(
  WidgetTester tester,
  String name, {
  required bool add,
}) async {
  final tooltip = add ? 'Add to favorites' : 'Remove from favorites';
  await tester.tap(
    find.descendant(of: _tileFor(name), matching: find.byTooltip(tooltip)),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required List<AcpSlashCommand> commands,
  Set<String> favorites = const <String>{},
  List<String> recent = const <String>[],
  Future<void> Function(String id, bool favorite)? onToggleFavorite,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatCommandsSkillsDialog(
          commands: commands,
          favorites: favorites,
          recent: recent,
          onToggleFavorite: onToggleFavorite,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _setActiveServer(WidgetTester tester, ServerProfile server) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(AiChatView)),
    listen: false,
  );
  // ignore: invalid_use_of_protected_member
  container.read(activeServerProvider.notifier).state = server;
}

Future<void> _expectStaleSelectionIgnored(
  WidgetTester tester,
  _PreferencesNotifier notifier,
  Future<void> Function() changeTarget,
) async {
  notifier.recordGate = Completer<void>();

  await tester.enterText(find.byKey(_promptKey), 'keep me');
  await tester.pump();
  await _openCommands(tester);

  await tester.tap(find.text('status'));
  await tester.pumpAndSettle();
  expect(notifier.recordCalls, ['command:status']);

  await changeTarget();
  await tester.pump();
  notifier.recordGate!.complete();
  await tester.pumpAndSettle();

  final field = tester.widget<TextField>(find.byKey(_promptKey));
  expect(field.controller?.text, 'keep me');
  expect(notifier.state.draftText, 'keep me');
  expect(notifier.sendMessageCalls, 0);
  expect(notifier.state.sessions, isEmpty);
  expect(notifier.state.activeSessionId, isNull);

  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('command preference filters', () {
    testWidgets('all, favorites and recent filter the namespaced lists', (
      tester,
    ) async {
      await _pumpDialog(
        tester,
        commands: _commands,
        favorites: {'command:compact', 'skill:ghost'},
        recent: ['command:status', r'skill:$review', 'command:ghost'],
      );

      expect(find.text('Commands (2)'), findsOneWidget);
      expect(find.text('Skills (1)'), findsOneWidget);
      expect(find.text('status'), findsOneWidget);
      expect(find.text('compact'), findsOneWidget);
      expect(find.text('ghost'), findsNothing);

      await _tapFilter(tester, 'Favorites (2)');
      expect(find.text('Commands (1)'), findsOneWidget);
      expect(find.text('compact'), findsOneWidget);
      expect(find.text('status'), findsNothing);

      await tester.tap(find.text('Skills (1)'));
      await tester.pumpAndSettle();
      expect(find.text('ghost'), findsOneWidget);
      expect(find.text('Unavailable in current agent'), findsWidgets);

      await _tapFilter(tester, 'Recent (3)');
      await tester.tap(find.text('Commands (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Commands (2)'), findsOneWidget);
      expect(find.text('status'), findsOneWidget);
      expect(find.text('ghost'), findsOneWidget);
      expect(find.text('compact'), findsNothing);

      await tester.tap(find.text('Skills (1)'));
      await tester.pumpAndSettle();
      expect(find.text(r'$review'), findsOneWidget);
      expect(find.text('status'), findsNothing);

      await _tapFilter(tester, 'All');
      await tester.tap(find.text('Commands (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Commands (2)'), findsOneWidget);
      expect(find.text('status'), findsOneWidget);
      expect(find.text('compact'), findsOneWidget);
    });

    testWidgets(
      'unavailable favorite cannot be selected but can be unfavorited',
      (tester) async {
        final toggles = <(String, bool)>[];
        await _pumpDialog(
          tester,
          commands: _commands,
          favorites: {'skill:ghost'},
          onToggleFavorite: (id, favorite) async {
            toggles.add((id, favorite));
          },
        );

        await _tapFilter(tester, 'Favorites (1)');
        await tester.tap(find.text('Skills (1)'));
        await tester.pumpAndSettle();

        final ghost = find.text('ghost');
        expect(ghost, findsOneWidget);
        final tile = tester.widget<ListTile>(
          find.ancestor(of: ghost, matching: find.byType(ListTile)).first,
        );
        expect(tile.enabled, isFalse);
        expect(tile.onTap, isNull);
        expect(find.text('Unavailable in current agent'), findsWidgets);

        // A disabled row must not select or dismiss the dialog.
        await tester.tap(ghost);
        await tester.pumpAndSettle();
        expect(find.byKey(_dialogKey), findsOneWidget);
        expect(toggles, isEmpty);

        // The star stays active even though the command is unavailable.
        await tester.tap(find.byTooltip('Remove from favorites'));
        await tester.pumpAndSettle();
        expect(toggles, [('skill:ghost', false)]);
        expect(find.text('ghost'), findsNothing);
      },
    );
  });

  group('favorites from the composer', () {
    testWidgets(
      'star toggles use skill:/command: ids and survive close and reopen',
      (tester) async {
        final notifier = _PreferencesNotifier(_draftState());
        await _pumpChat(tester, notifier);
        await _openCommands(tester);

        await _tapStar(tester, 'status', add: true);
        expect(notifier.favoriteCalls, [('command:status', true)]);
        expect(notifier.favorites, {'command:status'});

        await tester.tap(find.text('Skills (1)'));
        await tester.pumpAndSettle();
        await _tapStar(tester, r'$review', add: true);
        expect(notifier.favoriteCalls, [
          ('command:status', true),
          (r'skill:$review', true),
        ]);
        expect(notifier.favorites, {'command:status', r'skill:$review'});

        await tester.tap(
          find.descendant(
            of: find.byKey(_dialogKey),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(_dialogKey), findsNothing);

        await _openCommands(tester);
        expect(
          find.descendant(
            of: _tileFor('status'),
            matching: find.byTooltip('Remove from favorites'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Skills (1)'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: _tileFor(r'$review'),
            matching: find.byTooltip('Remove from favorites'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a failed favorite save reverts the star and shows the error', (
      tester,
    ) async {
      final notifier = _PreferencesNotifier(_draftState());
      notifier.failFavorite = true;
      await _pumpChat(tester, notifier);
      await _openCommands(tester);

      await tester.tap(
        find.descendant(
          of: _tileFor('status'),
          matching: find.byTooltip('Add to favorites'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.descendant(
          of: _tileFor('status'),
          matching: find.byTooltip('Add to favorites'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _tileFor('status'),
          matching: find.byTooltip('Remove from favorites'),
        ),
        findsNothing,
      );
      expect(find.text('Failed to save command preferences'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'rapid clicks while a favorite save is pending stay single and roll back on failure',
      (tester) async {
        var calls = 0;
        final gate = Completer<void>();
        await _pumpDialog(
          tester,
          commands: _commands,
          onToggleFavorite: (id, favorite) async {
            calls++;
            await gate.future;
            throw StateError('CHAT_COMMAND_PREFERENCES_SAVE_FAILED');
          },
        );

        await tester.tap(
          find.descendant(
            of: _tileFor('status'),
            matching: find.byTooltip('Add to favorites'),
          ),
        );
        await tester.pump();
        expect(calls, 1);
        expect(
          find.descendant(
            of: _tileFor('status'),
            matching: find.byTooltip('Remove from favorites'),
          ),
          findsOneWidget,
          reason: '第一次点击可以先做乐观显示',
        );

        // 第一次保存还挂起时星标必须已禁用。
        final pendingStar = find.descendant(
          of: _tileFor('status'),
          matching: find.byType(IconButton),
        );
        expect(pendingStar, findsOneWidget);
        expect(
          tester.widget<IconButton>(pendingStar).onPressed,
          isNull,
          reason: 'pending 期间星标必须禁用，第二次点击无法再发起保存',
        );

        // 真实点第二下禁用态星标：trailing 的 GestureDetector 必须吞掉这次
        // 点击，既不能再发起保存，也不能穿透到 ListTile.onTap 关闭面板。
        await tester.tap(pendingStar);
        await tester.pump();
        expect(
          find.byKey(_dialogKey),
          findsOneWidget,
          reason: 'pending 星标的第二次点击不能穿透到 ListTile 关闭面板',
        );
        expect(_tileFor('status'), findsOneWidget);
        expect(calls, 1, reason: 'pending 期间必须挡住第二次收藏写入，避免竞态回滚');

        gate.complete();
        await tester.pumpAndSettle();

        expect(calls, 1);
        expect(
          find.descendant(
            of: _tileFor('status'),
            matching: find.byTooltip('Add to favorites'),
          ),
          findsOneWidget,
          reason: '保存失败后必须回到未收藏状态',
        );
        expect(
          find.descendant(
            of: _tileFor('status'),
            matching: find.byTooltip('Remove from favorites'),
          ),
          findsNothing,
        );
        expect(find.text('Failed to save command preferences'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      },
    );
  });

  group('recent selection and stale targets', () {
    testWidgets(
      'recent selection fills the draft without sending or creating a session',
      (tester) async {
        final notifier = _PreferencesNotifier(_draftState());
        notifier.recent.add('command:status');
        await _pumpChat(tester, notifier);
        await _openCommands(tester);

        await tester.tap(find.text('Recent (1)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('status'));
        await tester.pumpAndSettle();

        final field = tester.widget<TextField>(find.byKey(_promptKey));
        expect(field.controller?.text, '/status ');
        expect(notifier.draftTexts.last, '/status ');
        expect(notifier.recordCalls, ['command:status']);
        expect(notifier.sendMessageCalls, 0);
        expect(notifier.state.sessions, isEmpty);
        expect(notifier.state.activeSessionId, isNull);

        await tester.pump(const Duration(milliseconds: 500));
      },
    );

    testWidgets(
      'pending recordCommandUse plus a workspace change blocks insertion',
      (tester) async {
        final notifier = _PreferencesNotifier(_draftState());
        await _pumpChat(tester, notifier);

        await _expectStaleSelectionIgnored(tester, notifier, () async {
          notifier.emit(
            notifier.state.copyWith(draftWorkingDirectory: '/srv/other'),
          );
        });
      },
    );

    testWidgets(
      'pending recordCommandUse plus an agent change blocks insertion',
      (tester) async {
        final notifier = _PreferencesNotifier(_draftState());
        await _pumpChat(tester, notifier);

        final otherAgent = AgentProfile(
          id: 'agent-harness-other',
          serverId: harnessServerId,
          name: 'Other ACP Agent',
          description: 'another agent',
          cliCommand: 'other-cli',
          acpCommand: 'other-acp',
        );

        await _expectStaleSelectionIgnored(tester, notifier, () async {
          notifier.emit(
            notifier.state.copyWith(activeAgentProfile: otherAgent),
          );
        });
      },
    );

    testWidgets(
      'pending recordCommandUse plus a server change blocks insertion',
      (tester) async {
        final notifier = _PreferencesNotifier(_draftState());
        await _pumpChat(tester, notifier);

        await _expectStaleSelectionIgnored(tester, notifier, () async {
          _setActiveServer(
            tester,
            harnessServer.copyWith(id: 'srv-harness-2', host: '127.0.0.2'),
          );
        });
      },
    );
  });
}
