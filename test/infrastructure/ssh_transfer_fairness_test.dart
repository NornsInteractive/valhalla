import 'dart:typed_data';

// ignore: implementation_imports
import 'package:dartssh2/src/utils/chunk_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChunkBuffer fairness tests', () {
    Uint8List fixture(int length) {
      return Uint8List.fromList(List.generate(length, (i) => i % 251));
    }

    void expectDataCorrect(ChunkBuffer buffer, Uint8List expected) {
      final data = buffer.data;
      expect(data.length, equals(expected.length));
      for (var i = 0; i < data.length; i++) {
        expect(data[i], equals(expected[i]), reason: 'byte at index $i');
      }
    }

    test('fill4096 skip4095 append4095 repeated 100 times', () {
      final buffer = ChunkBuffer();
      final chunk4096 = fixture(4096);
      final chunk4095 = fixture(4095);

      buffer.add(chunk4096);
      expect(buffer.length, equals(4096));
      expect(buffer.data.buffer.lengthInBytes, equals(4096));

      final firstView = buffer.view(0, 4096);
      Uint8List priorLast = Uint8List.fromList(buffer.data);

      for (var iter = 0; iter < 100; iter++) {
        buffer.skip(4095);
        buffer.add(chunk4095);
        expect(buffer.length, equals(4096), reason: 'iteration $iter length');
        expect(
          buffer.data.buffer.lengthInBytes,
          equals(4096),
          reason: 'iteration $iter capacity',
        );
        final expected = Uint8List.fromList([
          ...priorLast.sublist(priorLast.length - 1),
          ...chunk4095,
        ]);
        expectDataCorrect(buffer, expected);
        expect(
          firstView,
          equals(chunk4096),
          reason: 'iteration $iter prior view unchanged',
        );
        priorLast = Uint8List.fromList(buffer.data);
      }
    });

    test('fill4096 then skip1 add1 repeated 100 times', () {
      final buffer = ChunkBuffer();
      final chunk4096 = fixture(4096);

      buffer.add(chunk4096);
      expect(buffer.length, equals(4096));
      expect(buffer.data.buffer.lengthInBytes, equals(4096));

      int? initialOffset;
      int? lastOffset;

      for (var iter = 0; iter < 100; iter++) {
        buffer.skip(1);
        buffer.add(Uint8List.fromList([(4096 + iter) % 251]));
        if (iter == 0) {
          initialOffset = buffer.data.offsetInBytes;
        }
        lastOffset = buffer.data.offsetInBytes;
        expect(buffer.length, equals(4096), reason: 'iteration $iter length');
        if (iter > 0) {
          expect(
            buffer.data.buffer.lengthInBytes,
            equals(8192),
            reason: 'iteration $iter capacity',
          );
          expect(
            lastOffset > initialOffset!,
            isTrue,
            reason: 'offsetInBytes must increase each iteration (iter $iter)',
          );
        }
        final expected = Uint8List.fromList(
          List.generate(4096, (i) => (i + iter + 1) % 251),
        );
        expectDataCorrect(buffer, expected);
      }
      expect(buffer.data.buffer.lengthInBytes, equals(8192));
    });

    test(
      'needed exceeds capacity grows enough, old consume/view copies unchanged and drain releases',
      () {
        final buffer = ChunkBuffer();
        final initial = fixture(4096);
        buffer.add(initial);

        final consumedCopy = buffer.consume(2048);
        final viewCopy = buffer.view(0, 1024);

        final largeChunk = fixture(10000);
        buffer.add(largeChunk);

        expect(buffer.length, equals(2048 + 10000));
        expect(
          buffer.data.buffer.lengthInBytes,
          greaterThanOrEqualTo(2048 + 10000),
        );

        for (var i = 0; i < consumedCopy.length; i++) {
          expect(
            consumedCopy[i],
            equals(initial[i]),
            reason: 'consumed copy byte $i unchanged',
          );
        }
        for (var i = 0; i < viewCopy.length; i++) {
          expect(
            viewCopy[i],
            equals(initial[i + 2048]),
            reason: 'view copy byte $i unchanged',
          );
        }

        buffer.skip(buffer.length);
        expect(buffer.isEmpty, isTrue);
        expect(
          buffer.data.buffer.lengthInBytes,
          equals(0),
          reason: 'drain releases backing array',
        );
      },
    );

    test('range errors', () {
      final buffer = ChunkBuffer();
      buffer.add(fixture(100));

      expect(() => buffer.consume(-1), throwsRangeError);
      expect(() => buffer.consume(101), throwsRangeError);
      expect(() => buffer.consumeView(-1), throwsRangeError);
      expect(() => buffer.consumeView(101), throwsRangeError);
      expect(() => buffer.skip(-1), throwsRangeError);
      expect(() => buffer.skip(101), throwsRangeError);
      expect(() => buffer.view(-1, 10), throwsRangeError);
      expect(() => buffer.view(0, -1), throwsRangeError);
      expect(() => buffer.view(95, 10), throwsRangeError);
      expect(() => buffer.view(100, 1), throwsRangeError);
    });
  });
}
