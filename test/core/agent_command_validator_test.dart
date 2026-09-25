import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/security/agent_command_validator.dart';

void main() {
  group('AgentCommandValidator.validate', () {
    test('accepts typical probe and install commands', () {
      expect(
        () => AgentCommandValidator.validate('command -v claude'),
        returnsNormally,
      );
      expect(
        () => AgentCommandValidator.validate('claude-code-acp --stdio'),
        returnsNormally,
      );
      expect(
        () => AgentCommandValidator.validate(
          'npm install -g @anthropic-ai/claude-code',
        ),
        returnsNormally,
      );
    });

    test('accepts balanced quotes with spaces', () {
      expect(
        () =>
            AgentCommandValidator.validate("bash -l -c 'echo \"hello world\"'"),
        returnsNormally,
      );
      expect(
        () => AgentCommandValidator.validate('echo "it\'s fine"'),
        returnsNormally,
      );
    });

    test('rejects empty and whitespace only', () {
      expect(
        () => AgentCommandValidator.validate(''),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => AgentCommandValidator.validate('   \t  '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects newline and carriage return injection', () {
      expect(
        () => AgentCommandValidator.validate('claude\nrm -rf /'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => AgentCommandValidator.validate('claude\rrm -rf /'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects nul byte', () {
      expect(
        () => AgentCommandValidator.validate('claude\u0000'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects unbalanced single quote', () {
      expect(
        () => AgentCommandValidator.validate("echo 'unterminated"),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects unbalanced double quote', () {
      expect(
        () => AgentCommandValidator.validate('echo "unterminated'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('AgentCommandValidator.require', () {
    test('rejects null and blank commands', () {
      expect(
        () => AgentCommandValidator.require(null),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => AgentCommandValidator.require('  '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('accepts a non-empty command', () {
      expect(
        () => AgentCommandValidator.require('echo ok', label: 'installCommand'),
        returnsNormally,
      );
    });
  });
}
