import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/nas_provider.dart';
import 'package:valhalla/core/providers/nas_sources_provider.dart';
import 'package:valhalla/core/services/nas_download_service.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/features/nas/widgets/nas_diagnostics_dialog.dart';
import 'package:valhalla/features/nas/widgets/nas_downloads_sheet.dart';
import 'package:valhalla/features/nas/widgets/nas_library_settings_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart' show loadRealTextFonts;

const _source = NasSource(
  id: 'source-a',
  name: 'Media A',
  type: NasSourceType.jellyfin,
  endpoint: 'https://private.fixture.invalid',
  username: 'private-user',
);
const _other = NasSource(
  id: 'source-b',
  name: 'Media B',
  type: NasSourceType.webdav,
  endpoint: 'https://other.fixture.invalid',
);

class _SourceState extends NasSourcesState {
  final NasConnectionDiagnostic diagnostic;
  _SourceState(this.diagnostic)
    : super(sources: const [_source, _other], selectedId: _source.id);
  @override
  NasConnectionDiagnostic? diagnosticFor(NasSource source) =>
      source.id == _source.id ? diagnostic : null;
}

class _Sources extends NasSourcesNotifier {
  int probes = 0;
  Completer<void>? barrier;
  @override
  NasSourcesState build() => _SourceState(
    NasConnectionDiagnostic(
      sourceId: _source.id,
      stage: NasConnectionStage.failed,
      updatedAt: DateTime.utc(2026, 10, 13, 12),
      lastSuccess: DateTime.utc(2026, 10, 12, 12),
      errorCode: 'NAS_CONNECTION_TIMEOUT',
      httpStatus: 503,
    ),
  );
  void switchSource() => state = NasSourcesState(
    sources: [_source, _other],
    selectedId: _other.id,
  );
  @override
  Future<void> probeSaved(NasSource source) async {
    probes++;
    expect(source, same(_source));
    await barrier?.future;
  }
}

class _Library extends NasNotifier {
  final cleared = <(String?, bool)>[];
  int usageReads = 0;
  bool failUsage = false;
  @override
  NasState build() => NasState(
    serverId: _source.id,
    scanStage: NasScanStage.failed,
    scannedCount: 23,
    scanErrorCode: 'NAS_SCAN_FAILED',
    scanUpdatedAt: DateTime.utc(2026, 10, 13, 12),
    lastScan: DateTime.utc(2026, 10, 12, 12),
  );
  void switchSource() => state = NasState(serverId: _other.id);
  @override
  int get thumbnailCacheBudget => 128 * 1024 * 1024;
  @override
  Future<Map<String, Map<String, int>>> thumbnailCacheUsageBySource() async {
    usageReads++;
    if (failUsage) throw StateError('NAS_CACHE_FAILED');
    return {
      _source.id: {'bytes': 1024, 'count': 1},
      _other.id: {'bytes': 999999, 'count': 20},
      '': {'bytes': 2048, 'count': 2},
    };
  }

  @override
  Future<void> clearThumbnailCache({
    String? sourceId,
    bool legacyOnly = false,
  }) async {
    cleared.add((sourceId, legacyOnly));
  }

  @override
  Future<void> setThumbnailCacheBudget(int bytes) async {}
}

NasDownloadTask _task(String id, String sourceId, int bytes) => NasDownloadTask(
  id: id,
  item: NasMediaItem(
    serverId: sourceId,
    path: '/$id.mp3',
    kind: NasMediaKind.audio,
    sizeBytes: bytes,
    modifiedEpoch: 1,
  ),
  status: NasDownloadStatus.paused,
  received: bytes,
);

class _Downloads extends Fake implements NasDownloadService {
  final bool empty;
  _Downloads({this.empty = false});
  final removed = <String>[];
  @override
  List<NasDownloadTask> get tasks =>
      empty ? [] : [_task('a', _source.id, 1024), _task('b', _other.id, 8192)];
  @override
  Future<void> remove(String id) async {
    removed.add(id);
  }
}

void main() {
  Future<void> host(
    WidgetTester tester, {
    required Widget Function(BuildContext) child,
    required _Sources sources,
    required _Library library,
    required _Downloads downloads,
    Locale locale = const Locale('en'),
    double scale = 1,
    bool dark = false,
    Stream<List<NasDownloadTask>>? downloadsStream,
  }) async {
    await loadRealTextFonts();
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nasSourcesProvider.overrideWith(() => sources),
          nasProvider.overrideWith(() => library),
          nasDownloadsProvider.overrideWith(
            (ref) => downloadsStream ?? Stream.value(downloads.tasks),
          ),
          nasDownloadServiceProvider.overrideWithValue(downloads),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.buildTheme(
            brightness: dark ? Brightness.dark : Brightness.light,
            seedColor: Colors.green,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(builder: (context) => Scaffold(body: child(context))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget settings({VoidCallback? onScan}) => NasLibrarySettingsDialog(
    source: _source,
    sourceId: _source.id,
    currentPolicy: NasOpenPolicy.inApp,
    onPolicyChanged: (_) {},
    scanConfig: const NasScanConfig(),
    onSaveScanConfig: (_) {},
    isScanning: false,
    onScan: onScan ?? () {},
    onCancelScan: () {},
  );

  Future<void> tapVisible(WidgetTester tester, String key) async {
    final target = find.byKey(Key(key));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'diagnostics use real stages and copy no source credentials or address',
    (tester) async {
      final sources = _Sources(),
          library = _Library(),
          downloads = _Downloads();
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await host(
        tester,
        sources: sources,
        library: library,
        downloads: downloads,
        scale: 2,
        dark: true,
        child: (_) => const NasDiagnosticsDialog(source: _source),
      );
      expect(sources.probes, 0);
      expect(find.text('NAS_CONNECTION_TIMEOUT'), findsOneWidget);
      expect(find.text('HTTP 503'), findsOneWidget);
      await tapVisible(tester, 'nas_diagnostics_copy');
      expect(copied, contains('scanStage: failed'));
      expect(copied, contains('discovered: 23'));
      expect(copied, contains('lastSuccess: 2026-10-12'));
      expect(copied, isNot(contains('private.fixture')));
      expect(copied, isNot(contains('private-user')));
      await tapVisible(tester, 'nas_diagnostics_probe');
      expect(sources.probes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source change disables diagnostics and suppresses late probe failure',
    (tester) async {
      final sources = _Sources()..barrier = Completer<void>();
      final library = _Library(), downloads = _Downloads();
      await host(
        tester,
        sources: sources,
        library: library,
        downloads: downloads,
        child: (_) => const NasDiagnosticsDialog(source: _source),
      );
      await tester.tap(find.byKey(const Key('nas_diagnostics_probe')));
      await tester.pump();
      sources.switchSource();
      library.switchSource();
      sources.barrier!.completeError(StateError('secret failure'));
      await tester.pumpAndSettle();
      final probe = tester.widget<FilledButton>(
        find.byKey(const Key('nas_diagnostics_probe')),
      );
      expect(probe.onPressed, isNull);
      expect(find.text('secret failure'), findsNothing);
      expect(find.text('NAS_SCAN_FAILED'), findsNothing);
      expect(sources.probes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source and legacy thumbnail cleanup require separate explicit confirmations',
    (tester) async {
      final sources = _Sources(),
          library = _Library(),
          downloads = _Downloads();
      await host(
        tester,
        sources: sources,
        library: library,
        downloads: downloads,
        child: (_) => settings(),
      );
      await tapVisible(tester, 'nas_clear_thumbnail_cache_button');
      expect(library.cleared, isEmpty);
      expect(
        find.textContaining('Clear thumbnails for Media A?'),
        findsOneWidget,
      );
      await confirm(tester);
      expect(library.cleared, [(_source.id, false)]);
      await tapVisible(tester, 'nas_clear_legacy_cache_button');
      expect(library.cleared, hasLength(1));
      await confirm(tester);
      expect(library.cleared, [(_source.id, false), (null, true)]);
      expect(downloads.removed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source switch during cache confirmation cannot clear either source or scan new source',
    (tester) async {
      final sources = _Sources(),
          library = _Library(),
          downloads = _Downloads();
      var scans = 0;
      await host(
        tester,
        sources: sources,
        library: library,
        downloads: downloads,
        child: (_) => settings(onScan: () => scans++),
      );
      final scan = tester.widget<FilledButton>(
        find.byKey(const Key('nas_settings_start_scan_button')),
      );
      await tapVisible(tester, 'nas_clear_thumbnail_cache_button');
      sources.switchSource();
      library.switchSource();
      await tester.pump();
      await confirm(tester);
      scan.onPressed!();
      expect(library.cleared, isEmpty);
      expect(scans, 0);
      expect(downloads.removed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed cache measurement retries without clearing or removing data',
    (tester) async {
      final sources = _Sources(), library = _Library()..failUsage = true;
      final downloads = _Downloads();
      await host(
        tester,
        sources: sources,
        library: library,
        downloads: downloads,
        child: (_) => settings(),
      );
      expect(library.usageReads, 1);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(NasLibrarySettingsDialog)),
      );
      expect(find.text(l10n.nasOperationFailed), findsOneWidget);
      library.failUsage = false;
      await tapVisible(tester, 'nas_cache_usage_retry');
      expect(library.usageReads, 2);
      expect(find.byKey(const Key('nas_cache_usage_retry')), findsNothing);
      expect(find.text(l10n.nasOperationFailed), findsNothing);
      expect(library.cleared, isEmpty);
      expect(downloads.removed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'downloads filter source and summarize recorded bytes while removal still asks',
    (tester) async {
      final sources = _Sources(),
          library = _Library(),
          downloads = _Downloads();
      await host(
        tester,
        sources: sources,
        library: library,
        downloads: downloads,
        scale: 2,
        child: (_) => NasDownloadsSheet(sourceId: _source.id),
      );
      expect(find.byKey(const Key('nas_download_task_a')), findsOneWidget);
      expect(find.byKey(const Key('nas_download_task_b')), findsNothing);
      final summary = tester
          .widget<Text>(find.byKey(const Key('nas_download_recorded_bytes')))
          .data!;
      expect(summary, contains('1.0 KB'));
      await tapVisible(tester, 'nas_remove_download_a');
      expect(downloads.removed, isEmpty);
      await confirm(tester);
      expect(downloads.removed, ['a']);
      expect(library.cleared, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed download measurement stays unknown instead of claiming zero bytes',
    (tester) async {
      final sources = _Sources(), library = _Library();
      final downloads = _Downloads(empty: true);
      await host(
        tester,
        sources: sources,
        library: library,
        downloads: downloads,
        downloadsStream: Stream<List<NasDownloadTask>>.error(
          StateError('fixture read failed'),
        ),
        child: (_) => NasDownloadsSheet(sourceId: _source.id),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(NasDownloadsSheet)),
      );
      final summary = tester
          .widget<Text>(find.byKey(const Key('nas_download_recorded_bytes')))
          .data;
      expect(summary, l10n.nasOfflineRecordedBytes(l10n.agentStatusUnknown));
      expect(summary, isNot(contains('0 B')));
      expect(downloads.removed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('library settings fit RTL at 320dp and doubled text', (
    tester,
  ) async {
    final sources = _Sources(), library = _Library(), downloads = _Downloads();
    await host(
      tester,
      sources: sources,
      library: library,
      downloads: downloads,
      locale: const Locale('ar'),
      scale: 2,
      child: (_) => settings(),
    );
    await tester.ensureVisible(
      find.byKey(const Key('nas_source_downloads_button')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tapVisible(tester, 'nas_source_downloads_button');
    expect(
      tester.widget<NasDownloadsSheet>(find.byType(NasDownloadsSheet)).sourceId,
      _source.id,
    );
    expect(find.byKey(const Key('nas_download_task_b')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
