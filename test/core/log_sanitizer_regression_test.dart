import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/logging/sanitizer.dart';

/// 回归：Codex 修补共享脱敏器之前，OpenCode 探针复现出的真实泄漏。
///
/// 探针脚本 `dart run tool/probe_sanitize.dart` 的输出已并入本文件；
/// 每个 case 的 IN/OUT 都与探针实测一致。
///
/// 同时守护「不得把任意 JSON 状态当凭据」：Docker 状态字面量、
/// JSON-RPC 数字 code、普通 CLI 输出必须原样通过。
void main() {
  group('LogSanitizer.sanitize 泄漏回归', () {
    test('带空格的 key=value 且引号包裹的秘密必须脱敏', () {
      final output = LogSanitizer.sanitize('PASSWORD = "hunter2"');
      expect(output, isNot(contains('hunter2')));
      expect(output, contains('******'));
    });

    test('access_token / refresh_token / id_token 必须脱敏', () {
      expect(
        LogSanitizer.sanitize('{"access_token":"ATSECRET"}'),
        isNot(contains('ATSECRET')),
      );
      final pair = LogSanitizer.sanitize(
        '{"refresh_token":"RTSECRET3","id_token":"ITSECRET3"}',
      );
      expect(pair, isNot(contains('RTSECRET3')));
      expect(pair, isNot(contains('ITSECRET3')));
    });

    test('Bearer 被引号包裹时也要脱敏', () {
      final output = LogSanitizer.sanitize(
        'Authorization: "Bearer eyJhbGciOi"',
      );
      expect(output, isNot(contains('eyJhbGciOi')));
    });

    test('行首 code= 明文授权码必须脱敏', () {
      final output = LogSanitizer.sanitize('code=4/0Aean-SECRETVALUE');
      expect(output, isNot(contains('SECRETVALUE')));
    });

    test('裸 code_verifier= 必须脱敏（不依赖 ? / & 前缀）', () {
      final output = LogSanitizer.sanitize('code_verifier=VERIFIERSECRET');
      expect(output, isNot(contains('VERIFIERSECRET')));
    });

    test('JSON 形式的 code/state 成对出现时两者都脱敏', () {
      final output = LogSanitizer.sanitize(
        '{"code":"SJSONCODE","state":"SJSONSTATE"}',
      );
      expect(output, isNot(contains('SJSONCODE')));
      expect(output, isNot(contains('SJSONSTATE')));
    });

    test('form 编码的 OAuth 交换体整条脱敏', () {
      final output = LogSanitizer.sanitize(
        'grant_type=authorization_code&client_id=abc&code=SECRETCODE&code_verifier=SECRETVER',
      );
      expect(output, isNot(contains('SECRETCODE')));
      expect(output, isNot(contains('SECRETVER')));
      expect(output, contains('grant_type=authorization_code'));
    });

    test('冒号加空格形式的 token 必须脱敏', () {
      expect(
        LogSanitizer.sanitize('token: abc123def'),
        isNot(contains('abc123def')),
      );
    });

    test('引号内含转义引号的密码仍按整体脱敏', () {
      final flat = LogSanitizer.sanitize(r'password="a\"bsecret"');
      expect(flat, isNot(contains('bsecret')));
      final json = LogSanitizer.sanitize(r'{"password":"a\"bsecret"}');
      expect(json, isNot(contains('bsecret')));
      expect(json, contains('******'));
    });

    test('未加引号的多词秘密：key 后的第一段被脱敏', () {
      // 注意：这里只断言「紧邻 key 的第一段」被替换。脱敏器的无引号值
      // 类停在空白处，后续词不会被替换 —— 这是当前契约的行为，本测试
      // 不复述 stronger 的承诺，只锁定已验证的这一段。
      final output = LogSanitizer.sanitize('password=one two three');
      expect(output, startsWith('password=******'));
    });
  });

  group('LogSanitizer.sanitize 不得误伤普通状态', () {
    test('Docker 容器状态字面量原样保留', () {
      const line =
          '{"State":"running","Status":"running","Health":{"Status":"healthy"}}';
      expect(LogSanitizer.sanitize(line), line);
    });

    test('JSON-RPC 数字 error code 原样保留', () {
      expect(
        LogSanitizer.sanitize(
          '"jsonrpc":"2.0","error":{"code":-32603,"message":"Invalid params"}',
        ),
        contains('-32603'),
      );
      expect(
        LogSanitizer.sanitize('{"code":-32601,"message":"Method not found"}'),
        contains('-32601'),
      );
    });

    test('CLI 里的数字 code 原样保留', () {
      expect(LogSanitizer.sanitize('code = 42'), 'code = 42');
      expect(
        LogSanitizer.sanitize('exit code = 0, cmd finished'),
        contains('0'),
      );
      expect(
        LogSanitizer.sanitize('file /etc/hosts: code 2'),
        contains('code 2'),
      );
    });

    test('普通命令行与 JSON-RPC 初始化帧不被改写', () {
      expect(
        LogSanitizer.sanitize('kubectl get pods -o wide'),
        'kubectl get pods -o wide',
      );
      expect(
        LogSanitizer.sanitize('Running "flutter test" ...'),
        'Running "flutter test" ...',
      );
      const init =
          '{"id":"abc","method":"initialize","params":{"clientCapabilities":{}}}';
      expect(LogSanitizer.sanitize(init), init);
    });
  });

  group('LogSanitizer.stream 分块泄漏回归', () {
    test('秘密被拆在两个 chunk 中仍被脱敏', () async {
      final output = await LogSanitizer.stream(
        Stream.fromIterable(['password=hun', 'ter2\n']),
      ).join();
      expect(output, isNot(contains('hunter2')));
      expect(output, contains('******'));
    });

    test('OAuth 授权码跨 chunk 拆分仍被脱敏', () async {
      final output = await LogSanitizer.stream(
        Stream.fromIterable(['code=4/0Aean-SECRETV', 'ALUE\nnext line\n']),
      ).join();
      expect(output, isNot(contains('SECRETVALUE')));
    });

    test('Bearer token 跨 chunk 拆分仍被脱敏', () async {
      final output = await LogSanitizer.stream(
        Stream.fromIterable(['Authorization: Bearer eyJhb', 'GciOi\n']),
      ).join();
      expect(output, isNot(contains('eyJhbGciOi')));
    });
  });
}
