import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/terminal_url_provider.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('terminalUrlProvider', () {
    test('has an empty initial state before any output', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final terminal = Terminal();
      final state = container.read(terminalUrlProvider(terminal));

      expect(state.isEmpty, isTrue);
      expect(state.best, isNull);
    });

    test('has an empty initial state even with no subscriber', () {
      // 回归：provider 不能依赖"有人监听"才产出初值，否则 UI 首帧会卡住。
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final terminal = Terminal();
      expect(container.read(terminalUrlProvider(terminal)).isEmpty, isTrue);
    });

    test('surfaces a URL once the terminal prints one', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final terminal = Terminal();
      container.listen(terminalUrlProvider(terminal), (_, _) {});

      terminal.write(
        'To authenticate, open https://auth.example.com/device?code=ABCD-1234\r\n',
      );

      // Wait past the 250ms debounce.
      await Future<void>.delayed(const Duration(milliseconds: 450));

      final state = container.read(terminalUrlProvider(terminal));
      expect(state.best!.url, 'https://auth.example.com/device?code=ABCD-1234');
    });

    test('rejoins a URL that arrives split across writes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final terminal = Terminal();
      container.listen(terminalUrlProvider(terminal), (_, _) {});

      terminal.write(
        'open https://auth.example.com/oauth2/authorize?client_id=abc&',
      );
      terminal.write('scope=openid&state=xyz\r\n');

      await Future<void>.delayed(const Duration(milliseconds: 450));

      final state = container.read(terminalUrlProvider(terminal));
      // 分片最终落到同一逻辑行，只应产出 1 条链接。
      expect(state.candidates, hasLength(1));
      expect(
        state.best!.url,
        'https://auth.example.com/oauth2/authorize?client_id=abc&scope=openid&state=xyz',
      );
    });

    test('prefers the newest URL when several have been printed', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final terminal = Terminal();
      container.listen(terminalUrlProvider(terminal), (_, _) {});

      terminal.write('stale https://old.example.com/login\r\n');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      terminal.write('fresh https://new.example.com/login?code=zzz\r\n');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final state = container.read(terminalUrlProvider(terminal));
      expect(state.best!.url, 'https://new.example.com/login?code=zzz');
    });

    test('stays empty for output that contains no URL', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final terminal = Terminal();
      container.listen(terminalUrlProvider(terminal), (_, _) {});

      terminal.write('Waiting for authentication...\r\n');
      await Future<void>.delayed(const Duration(milliseconds: 450));

      expect(container.read(terminalUrlProvider(terminal)).isEmpty, isTrue);
    });

    test('unregisters its terminal listener on dispose', () {
      final container = ProviderContainer();
      final terminal = Terminal();

      container.listen(terminalUrlProvider(terminal), (_, _) {});
      expect(
        terminal.listeners,
        isNotEmpty,
        reason: 'provider 存活期间应监听 Terminal',
      );

      container.dispose();

      expect(
        terminal.listeners,
        isEmpty,
        reason: 'provider 销毁必须移除监听，否则 Terminal 会泄漏 provider',
      );
    });
  });
}
