import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/model_authorization_browser.dart';

/// 浏览器桥 `ModelAuthorizationBrowser` 的纯通道契约。
///
/// 全程 mock method channel：不拉起真实浏览器、不构造真实 OAuth 流程、
/// 不读写任何凭据，也不触碰真实平台实现。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dispatched = <MethodCall>[];
  Object? reply;

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void installHandler() {
    messenger.setMockMethodCallHandler(ModelAuthorizationBrowser.channel, (
      call,
    ) async {
      dispatched.add(call);
      final result = reply;
      if (result is Exception) throw result;
      return result;
    });
  }

  void removeHandler() {
    messenger.setMockMethodCallHandler(ModelAuthorizationBrowser.channel, null);
  }

  setUp(() {
    dispatched.clear();
    reply = true;
    installHandler();
  });

  tearDown(() {
    removeHandler();
    dispatched.clear();
    reply = true;
  });

  Future<void> expectEndpointRejected(String raw) async {
    await expectLater(
      ModelAuthorizationBrowser.open(Uri.parse(raw)),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'AGENT_MODEL_ENDPOINT_INVALID',
        ),
      ),
      reason: '$raw 必须抛固定端点码',
    );
    expect(dispatched, isEmpty, reason: '$raw 必须在派发到平台之前就被拒绝');
  }

  Future<void> expectBrowserFailed(Future<void> future, String reason) async {
    await expectLater(
      future,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'AGENT_MODEL_BROWSER_FAILED',
        ),
      ),
      reason: reason,
    );
  }

  group('官方 HTTPS 端点放行并原样派发', () {
    test(
      'https + auth.openai.com + 无 userinfo + 默认 443：派发一次 openBrowser',
      () async {
        const raw = 'https://auth.openai.com/authorize?state=unit-test';
        final url = Uri.parse(raw);

        await ModelAuthorizationBrowser.open(url);

        expect(dispatched, hasLength(1));
        expect(dispatched.single.method, 'openBrowser');
        expect(dispatched.single.arguments, {
          'url': url.toString(),
        }, reason: '必须原样传递 URL，不得改写或剥离参数');
        expect(url.toString(), raw, reason: '默认 443 的官方 URL 不被改写');
        expect(reply, isTrue);
      },
    );

    test('显式 :443 端口同样放行', () async {
      const raw = 'https://auth.openai.com:443/authorize?state=unit-test';
      final url = Uri.parse(raw);
      expect(url.port, 443);

      await ModelAuthorizationBrowser.open(url);

      expect(dispatched, hasLength(1));
      expect(
        dispatched.single.arguments,
        {'url': url.toString()},
        reason: '派发的就是 Uri.toString()（Dart 会规范化掉显式 :443）',
      );
      expect(url.toString(), isNot(contains(':443')));
    });
  });

  group('派发前拒绝（平台通道不得被调用）', () {
    test('明文 http 拒绝', () async {
      await expectEndpointRejected('http://auth.openai.com/authorize');
    });

    test('非官方主机拒绝', () async {
      await expectEndpointRejected('https://evil.example/authorize');
      await expectEndpointRejected('https://auth.openai.com.evil.example/x');
    });

    test('带 userinfo 拒绝', () async {
      await expectEndpointRejected(
        'https://user:secret@auth.openai.com/authorize',
      );
    });

    test('非 443 端口拒绝', () async {
      await expectEndpointRejected('https://auth.openai.com:8443/authorize');
      await expectEndpointRejected('https://auth.openai.com:4443/authorize');
    });
  });

  group('桥失败一律折叠成 AGENT_MODEL_BROWSER_FAILED', () {
    test('桥返回 false', () async {
      reply = false;
      await expectBrowserFailed(
        ModelAuthorizationBrowser.open(
          Uri.parse('https://auth.openai.com/authorize?state=unit-test'),
        ),
        'false 必须折叠成固定失败码',
      );
      expect(dispatched, hasLength(1), reason: 'false 说明已经派发过');
    });

    test('桥返回 null', () async {
      reply = null;
      await expectBrowserFailed(
        ModelAuthorizationBrowser.open(
          Uri.parse('https://auth.openai.com/authorize?state=unit-test'),
        ),
        'null 必须折叠成固定失败码',
      );
      expect(dispatched, hasLength(1), reason: 'null 说明已经派发过');
    });

    test('平台抛 PlatformException', () async {
      reply = PlatformException(
        code: 'ACTIVITY_NOT_FOUND',
        message: 'no activity',
      );
      await expectBrowserFailed(
        ModelAuthorizationBrowser.open(
          Uri.parse('https://auth.openai.com/authorize?state=unit-test'),
        ),
        '平台错误必须折叠成固定失败码，不得外泄原始 code/message',
      );
      expect(dispatched, hasLength(1));
    });

    test('没有平台实现（MissingPluginException）', () async {
      removeHandler();
      await expectBrowserFailed(
        ModelAuthorizationBrowser.open(
          Uri.parse('https://auth.openai.com/authorize?state=unit-test'),
        ),
        '插件缺失必须折叠成固定失败码',
      );
      expect(dispatched, isEmpty, reason: '没有 mock 实现就没有派发记录');
    });
  });
}
