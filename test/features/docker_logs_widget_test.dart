import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/features/docker/docker_view.dart';
import 'package:valhalla/l10n/app_localizations.dart';

Widget _buildTestApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('DockerLogsDialogContent Widget Tests', () {
    testWidgets('accumulates logs and trims to bounded buffer on overflow', (
      tester,
    ) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      // maxBytes set to 20 for exact boundary verification
      await tester.pumpWidget(
        _buildTestApp(
          child: DockerLogsDialogContent(
            logStream: controller.stream,
            maxBytes: 20,
          ),
        ),
      );

      // Initial loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Push first chunk
      controller.add('1234567890');
      // Wait for 50ms batching flush
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('1234567890'), findsOneWidget);

      // Push second chunk: total 20 bytes
      controller.add('ABCDEFGHIJ');
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('1234567890ABCDEFGHIJ'), findsOneWidget);

      // Push third chunk: total 30 bytes, should trim oldest 10 bytes and retain latest 20 bytes
      controller.add('KLMNOPQRST');
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('ABCDEFGHIJKLMNOPQRST'), findsOneWidget);
    });

    testWidgets('batches multiple fast stream updates into single frame', (
      tester,
    ) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildTestApp(
          child: DockerLogsDialogContent(
            logStream: controller.stream,
            maxBytes: 1000,
          ),
        ),
      );

      // Push multiple chunks immediately
      controller.add('Line 1\n');
      controller.add('Line 2\n');
      controller.add('Line 3\n');

      // Before 50ms flush, pending chunks not yet flushed into _logs
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Line 1\nLine 2\nLine 3\n'), findsNothing);

      // After 50ms flush
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Line 1\nLine 2\nLine 3\n'), findsOneWidget);
    });

    testWidgets('cancels stream subscription when disposed', (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildTestApp(
          child: DockerLogsDialogContent(logStream: controller.stream),
        ),
      );

      expect(controller.hasListener, isTrue);

      // Replace widget with empty container to trigger dispose
      await tester.pumpWidget(_buildTestApp(child: const SizedBox()));

      expect(controller.hasListener, isFalse);
    });

    testWidgets('displays error when stream encounters an error', (
      tester,
    ) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildTestApp(
          child: DockerLogsDialogContent(logStream: controller.stream),
        ),
      );

      controller.addError('Connection terminated unexpectedly');
      await tester.pumpAndSettle();

      expect(find.text('Connection terminated unexpectedly'), findsOneWidget);
    });

    testWidgets('displays empty state when stream finishes with no content', (
      tester,
    ) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(
        _buildTestApp(
          child: DockerLogsDialogContent(logStream: controller.stream),
        ),
      );

      await controller.close();
      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsOneWidget);
    });

    test(
      'trimToUtf8MaxBytes skips continuation bytes on non-3 multiples and does not introduce replacement characters',
      () {
        const text = '一二三四'; // 12 UTF-8 bytes

        // maxBytes = 4 (not a multiple of 3)
        final res4 = DockerLogsDialogContent.trimToUtf8MaxBytes(text, 4);
        expect(res4, equals('四'));
        expect(res4.contains('\uFFFD'), isFalse);
        expect(utf8.encode(res4).length, lessThanOrEqualTo(4));

        // maxBytes = 7 (not a multiple of 3)
        final res7 = DockerLogsDialogContent.trimToUtf8MaxBytes(text, 7);
        expect(res7, equals('三四'));
        expect(res7.contains('\uFFFD'), isFalse);
        expect(utf8.encode(res7).length, lessThanOrEqualTo(7));

        // Production 262144 bytes with flood of multibyte characters (360,000 bytes > 262144)
        final bigText = '中文日志测试数据\n' * 30000;
        final resProd = DockerLogsDialogContent.trimToUtf8MaxBytes(
          bigText,
          262144,
        );
        expect(resProd.contains('\uFFFD'), isFalse);
        expect(utf8.encode(resProd).length, lessThanOrEqualTo(262144));
      },
    );

    testWidgets(
      'trims multibyte characters strictly by UTF-8 bytes without corrupting continuation bytes',
      (tester) async {
        final controller = StreamController<String>();
        addTearDown(controller.close);

        // maxBytes set to 9 bytes: each Chinese character is 3 UTF-8 bytes.
        // '一二三四' is 4 chars (UTF-16 length 4), but 12 UTF-8 bytes.
        // 9 UTF-8 bytes can only fit 3 characters ('二三四').
        await tester.pumpWidget(
          _buildTestApp(
            child: DockerLogsDialogContent(
              logStream: controller.stream,
              maxBytes: 9,
            ),
          ),
        );

        controller.add('一二三四');
        await tester.pump(const Duration(milliseconds: 60));

        expect(find.text('二三四'), findsOneWidget);
      },
    );

    testWidgets(
      'trims multibyte characters with non-3 multiple limit without corrupting UTF-8 or inserting replacement char',
      (tester) async {
        final controller = StreamController<String>();
        addTearDown(controller.close);

        await tester.pumpWidget(
          _buildTestApp(
            child: DockerLogsDialogContent(
              logStream: controller.stream,
              maxBytes: 7, // 7 bytes can only fit 2 chars ('三四' = 6 bytes)
            ),
          ),
        );

        controller.add('一二三四');
        await tester.pump(const Duration(milliseconds: 60));

        final textFinder = find.byType(SelectableText);
        expect(textFinder, findsOneWidget);
        final text = tester.widget<SelectableText>(textFinder).data!;
        expect(text, equals('三四'));
        expect(text.contains('\uFFFD'), isFalse);
        expect(utf8.encode(text).length, lessThanOrEqualTo(7));
      },
    );

    testWidgets('bounds pending queue at ingestion under burst flood', (
      tester,
    ) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildTestApp(
          child: DockerLogsDialogContent(
            logStream: controller.stream,
            maxBytes: 30,
          ),
        ),
      );

      // Ingest 50 chunks of 10 bytes rapidly before flush
      for (var i = 0; i < 50; i++) {
        controller.add('chunk-${i.toString().padLeft(2, '0')}\n');
      }

      // Flush
      await tester.pump(const Duration(milliseconds: 60));

      // Must be trimmed to at most 30 bytes
      final widgetFinder = find.byType(SelectableText);
      expect(widgetFinder, findsOneWidget);
      final text = tester.widget<SelectableText>(widgetFinder).data!;
      expect(utf8.encode(text).length, lessThanOrEqualTo(30));
      expect(text, contains('chunk-49'));
    });
  });
}
