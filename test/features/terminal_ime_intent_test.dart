import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/src/ui/custom_text_edit.dart';

/// 回归测试：CustomTextEdit 的"显式键盘意图"（_keyboardRequested）语义。
///
/// 背景（见 packages/xterm/lib/src/ui/custom_text_edit.dart）：
///   移动端（Android/iOS）上，只有 requestKeyboard() 设置的显式意图才会打开
///   输入连接；被动获得焦点（初始 autofocus、被模态框抢走焦点后又恢复）
///   不得弹出 IME；生命周期进入非 resumed 状态、以及软键盘收起都会清空意图
///   并关闭连接。桌面端仍然遵循 focusNode 的 keyboard token。
///
/// 所有断言都读 CustomTextEditState 的公开状态：
///   - hasInputConnection：输入连接是否已 attach（IME 是否会显示）
///   - focusNode.hasFocus：焦点是否在终端上
/// 以及 onKeyEvent / onInsert 等回调的记录，用来证明物理键盘路径未被破坏。

class _Recorder {
  final List<String> inserted = <String>[];
  int deletes = 0;
  final List<String> composing = <String>[];
  final List<TextInputAction> actions = <TextInputAction>[];
  final List<String> keyEvents = <String>[];
  final List<KeyEventResult> keyResults = <KeyEventResult>[];
}

class _TerminalHost extends StatelessWidget {
  const _TerminalHost({
    required this.recorder,
    required this.focusNode,
    required this.editKey,
    this.autofocus = false,
  });

  final _Recorder recorder;
  final FocusNode focusNode;
  final GlobalKey<CustomTextEditState> editKey;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CustomTextEdit(
            key: editKey,
            focusNode: focusNode,
            autofocus: autofocus,
            onInsert: recorder.inserted.add,
            onDelete: () => recorder.deletes++,
            onComposing: (String? text) => recorder.composing.add(text ?? ''),
            onAction: recorder.actions.add,
            onKeyEvent: (FocusNode node, KeyEvent event) {
              recorder.keyEvents.add(event.logicalKey.keyLabel);
              recorder.keyResults.add(KeyEventResult.handled);
              return KeyEventResult.handled;
            },
            child: const SizedBox(
              width: 320,
              height: 200,
              child: ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }
}

/// 在测试体内切换到 Android 平台并在结束后立即还原。
///
/// flutter_test 会在每个 testWidgets 结束时校验
/// debugDefaultTargetPlatformOverride 必须为空，因此在 body 内部设置并还原，
/// 而不是放在 setUp / tearDown 里。
Future<void> android(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// 在测试体内切换到桌面平台并在结束后立即还原（Windows / Linux 各覆盖一次）。
Future<void> desktop(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

CustomTextEditState _editState(
  WidgetTester tester,
  GlobalKey<CustomTextEditState> key,
) => tester.state<CustomTextEditState>(find.byKey(key));

void main() {
  late _Recorder recorder;
  late FocusNode focusNode;
  late GlobalKey<CustomTextEditState> editKey;

  setUp(() {
    recorder = _Recorder();
    focusNode = FocusNode();
    editKey = GlobalKey<CustomTextEditState>();
  });

  // FocusNode 交由 GC：测试进程内不需要手动 dispose，且在 binding 关闭后
  // dispose 会触发 "FocusManager used after being disposed" 噪声。

  /// 打开键盘：设置显式意图（必要时先拿焦点），然后 pump 让连接建立。
  Future<void> requestKeyboard(WidgetTester tester) async {
    _editState(tester, editKey).requestKeyboard();
    await tester.pump();
    await tester.pump();
  }

  group('CustomTextEdit 显式键盘意图（移动端）', () {
    testWidgets(
      '被动获得焦点不得弹出 IME',
      (tester) => android(() async {
        await tester.pumpWidget(
          _TerminalHost(
            recorder: recorder,
            focusNode: focusNode,
            editKey: editKey,
          ),
        );

        // 被动拿焦点：这正是页面重建 / 路由返回时会发生的事。
        focusNode.requestFocus();
        await tester.pump();
        await tester.pump();

        expect(focusNode.hasFocus, isTrue, reason: '焦点确实落在终端上');
        expect(
          _editState(tester, editKey).hasInputConnection,
          isFalse,
          reason: '移动端仅被动聚焦不得打开输入连接，否则会弹出 IME',
        );
      }),
    );

    testWidgets(
      'autofocus 也不得弹出 IME',
      (tester) => android(() async {
        await tester.pumpWidget(
          _TerminalHost(
            recorder: recorder,
            focusNode: focusNode,
            editKey: editKey,
            autofocus: true,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(focusNode.hasFocus, isTrue);
        expect(_editState(tester, editKey).hasInputConnection, isFalse);
      }),
    );

    testWidgets(
      '显式 requestKeyboard 会打开输入连接',
      (tester) => android(() async {
        await tester.pumpWidget(
          _TerminalHost(
            recorder: recorder,
            focusNode: focusNode,
            editKey: editKey,
          ),
        );

        expect(_editState(tester, editKey).hasInputConnection, isFalse);

        await requestKeyboard(tester);

        expect(focusNode.hasFocus, isTrue, reason: 'requestKeyboard 应同时取得焦点');
        expect(
          _editState(tester, editKey).hasInputConnection,
          isTrue,
          reason: '显式请求后必须建立输入连接以显示 IME',
        );
        expect(recorder.inserted, isEmpty);
        expect(recorder.deletes, 0);
      }),
    );

    testWidgets(
      '焦点被模态框抢走再恢复，不得重新弹出 IME',
      (tester) => android(() async {
        await tester.pumpWidget(
          _TerminalHost(
            recorder: recorder,
            focusNode: focusNode,
            editKey: editKey,
          ),
        );

        await requestKeyboard(tester);
        expect(_editState(tester, editKey).hasInputConnection, isTrue);

        // 模态框抢走焦点：此时终端失焦，连接必须关闭。
        final otherFocus = FocusNode();
        addTearDown(otherFocus.dispose);
        showDialog<void>(
          context: tester.element(find.byType(Scaffold)),
          builder: (BuildContext context) => AlertDialog(
            content: Focus(
              focusNode: otherFocus,
              autofocus: true,
              child: const Text('modal'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(focusNode.hasFocus, isFalse);
        expect(_editState(tester, editKey).hasInputConnection, isFalse);

        // 关闭模态框：焦点恢复到终端，但显式意图已在失焦时清空。
        Navigator.of(tester.element(find.byType(Scaffold))).pop();
        await tester.pumpAndSettle();

        expect(focusNode.hasFocus, isTrue, reason: '模态框关闭后焦点应回到终端');
        expect(
          _editState(tester, editKey).hasInputConnection,
          isFalse,
          reason: '恢复的焦点是被动的，不得在用户未再次点击时重新弹出 IME',
        );
      }),
    );

    testWidgets(
      '生命周期 inactive/resumed 会清空显式意图',
      (tester) => android(() async {
        await tester.pumpWidget(
          _TerminalHost(
            recorder: recorder,
            focusNode: focusNode,
            editKey: editKey,
          ),
        );

        await requestKeyboard(tester);
        expect(_editState(tester, editKey).hasInputConnection, isTrue);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();

        expect(
          _editState(tester, editKey).hasInputConnection,
          isFalse,
          reason: '切后台必须关闭输入连接',
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();

        expect(
          _editState(tester, editKey).hasInputConnection,
          isFalse,
          reason: '回到前台不得靠残留意图重新弹出 IME',
        );
        expect(focusNode.hasFocus, isTrue, reason: '焦点本身应保留，只有键盘意图被重置');
      }),
    );

    testWidgets(
      '软键盘收起后关闭输入连接并清空意图',
      (tester) => android(() async {
        await tester.pumpWidget(
          _TerminalHost(
            recorder: recorder,
            focusNode: focusNode,
            editKey: editKey,
          ),
        );

        await requestKeyboard(tester);
        expect(_editState(tester, editKey).hasInputConnection, isTrue);

        // IME 弹出：viewInsets.bottom > 0。
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        addTearDown(tester.view.reset);
        await tester.pump();

        expect(
          _editState(tester, editKey).hasInputConnection,
          isTrue,
          reason: '键盘仍在显示时连接不得被关掉',
        );

        // 键盘收起：viewInsets.bottom 回到 0。
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pump();

        expect(
          _editState(tester, editKey).hasInputConnection,
          isFalse,
          reason: '键盘收起时必须关闭输入连接',
        );
        expect(focusNode.hasFocus, isTrue, reason: '键盘收起不影响终端焦点');
      }),
    );

    testWidgets(
      'IME 关闭时物理键盘事件仍被处理',
      (tester) => android(() async {
        await tester.pumpWidget(
          _TerminalHost(
            recorder: recorder,
            focusNode: focusNode,
            editKey: editKey,
          ),
        );

        focusNode.requestFocus();
        await tester.pump();

        expect(
          _editState(tester, editKey).hasInputConnection,
          isFalse,
          reason: '前置条件：物理键盘路径没有打开 IME',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);

        expect(
          recorder.keyEvents,
          containsAll(<String>['A', 'Enter']),
          reason: '硬件键盘事件必须照常送达终端回调',
        );
        // 每次 sendKeyEvent 都会派发 down + up 两个 KeyEvent。
        expect(recorder.keyResults, hasLength(4));
        expect(
          recorder.keyResults,
          everyElement(KeyEventResult.handled),
          reason: '终端必须吞掉硬件按键（handled），不得冒泡成未处理',
        );
        expect(
          _editState(tester, editKey).hasInputConnection,
          isFalse,
          reason: '处理物理按键不应触发输入连接',
        );
        expect(recorder.inserted, isEmpty);
      }),
    );

    testWidgets(
      'IME 打开期间的输入仍回传给回调',
      (tester) => android(() async {
        await tester.pumpWidget(
          _TerminalHost(
            recorder: recorder,
            focusNode: focusNode,
            editKey: editKey,
          ),
        );

        await requestKeyboard(tester);

        final initial = tester
            .state<CustomTextEditState>(find.byKey(editKey))
            .currentTextEditingValue;
        expect(initial?.text, isEmpty);

        // 通过真实 TextInput 通道喂入一次插入。
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'x',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();

        expect(recorder.inserted, <String>['x']);
      }),
    );
  });

  // 桌面端路径：与移动端的“显式意图”语义不同，桌面只看 focusNode 的键盘
  // token，且 Windows 的输入连接必须带上 viewId。这里覆盖硬件按键与 CJK 组合，
  // 防止桌面端改动时误伤物理键盘 / 输入法。
  group('CustomTextEdit 桌面端路径', () {
    for (final platform in <TargetPlatform>[
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      testWidgets(
        '$platform：被动聚焦也会建立输入连接（桌面语义）',
        (tester) => desktop(platform, () async {
          await tester.pumpWidget(
            _TerminalHost(
              recorder: recorder,
              focusNode: focusNode,
              editKey: editKey,
            ),
          );

          focusNode.requestFocus();
          await tester.pump();
          await tester.pump();

          expect(
            _editState(tester, editKey).hasInputConnection,
            isTrue,
            reason: '桌面端不区分显式意图，聚焦即应打开输入连接',
          );
        }),
      );

      testWidgets(
        '$platform：硬件 Ctrl+C 等组合键照常回传，不受 IME 影响',
        (tester) => desktop(platform, () async {
          await tester.pumpWidget(
            _TerminalHost(
              recorder: recorder,
              focusNode: focusNode,
              editKey: editKey,
            ),
          );

          focusNode.requestFocus();
          await tester.pump();
          await tester.pump();

          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

          expect(
            recorder.keyEvents,
            containsAll(<String>['Control Left', 'C']),
            reason: '物理组合键必须原样送达终端回调',
          );
          expect(
            recorder.keyResults,
            everyElement(KeyEventResult.handled),
            reason: '硬件事件必须被终端吞掉',
          );
          expect(recorder.inserted, isEmpty);
        }),
      );

      testWidgets(
        '$platform：CJK 组合先 composing、提交后才插入',
        (tester) => desktop(platform, () async {
          await tester.pumpWidget(
            _TerminalHost(
              recorder: recorder,
              focusNode: focusNode,
              editKey: editKey,
            ),
          );

          focusNode.requestFocus();
          await tester.pump();
          await tester.pump();

          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: 'zhong',
              selection: TextSelection.collapsed(offset: 5),
              composing: TextRange(start: 0, end: 5),
            ),
          );
          await tester.pump();
          expect(recorder.inserted, isEmpty, reason: '组合中的拼音不得插入');
          expect(recorder.composing, ['zhong']);

          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: '中文',
              selection: TextSelection.collapsed(offset: 2),
            ),
          );
          await tester.pump();
          expect(recorder.inserted, ['中文']);
        }),
      );
    }

    for (final entry in <TargetPlatform, bool>{
      TargetPlatform.windows: true,
      TargetPlatform.linux: false,
    }.entries) {
      testWidgets(
        '${entry.key} 输入连接的 viewId '
        '${entry.value ? '必须为当前 view' : '必须为 null'}',
        (tester) => desktop(entry.key, () async {
          await tester.pumpWidget(
            _TerminalHost(
              recorder: recorder,
              focusNode: focusNode,
              editKey: editKey,
            ),
          );
          focusNode.requestFocus();
          await tester.pump();
          await tester.pump();

          final call = tester.testTextInput.log.lastWhere(
            (c) => c.method == 'TextInput.setClient',
          );
          final config = (call.arguments as List)[1] as Map;
          final viewId = config['viewId'] as int?;
          if (entry.value) {
            expect(viewId, tester.view.viewId);
          } else {
            expect(viewId, isNull);
          }
        }),
      );
    }
  });
}
