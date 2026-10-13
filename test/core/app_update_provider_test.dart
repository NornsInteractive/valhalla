// Provider-level regression tests for AppUpdateNotifier.
//
// Scope: state-machine behaviour only. Native (method channel), package info,
// path provider and every HTTP exchange are served by in-test fakes; no real
// device, no real server and no production code is touched.

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:valhalla/core/providers/app_update_provider.dart';
import 'package:valhalla/core/providers/app_visibility_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/services/app_update_service.dart';
import 'package:valhalla/data/models/app_update.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

import 'fixtures/app_update_payload.dart';

const _updatesChannel = 'valhalla/updates';
const _downloadsChannel = 'valhalla/downloads';
const _packageInfoChannel = 'dev.fluttercommunity.plus/package_info';

const _hexB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

/// A fake that hands the test a [Completer] per `check`/`download` call so the
/// exact await points inside the notifier can be controlled deterministically.
class _FakeUpdateService implements AppUpdateService {
  final List<Completer<AppUpdateCheck>> checkGates = [];
  final List<Completer<void>> downloadGates = [];

  /// Completed by the matching [download] entry. The real `reservePath`
  /// mkdir/exists I/O has finished by then, so the writer is genuinely open — a
  /// fixed number of event-loop turns is not an I/O acknowledgment.
  final List<Completer<void>> downloadEntries = [];
  final List<Completer<void>> _openRequests = [];
  final List<Map<String, Object>> checkContexts = [];
  int checkCalls = 0;
  int downloadCalls = 0;
  int cancelCalls = 0;
  final List<AppUpdateArtifact> downloadedArtifacts = [];
  final List<String> downloadDestinations = [];
  Object? checkError;
  Object? downloadError;

  Completer<AppUpdateCheck> get nextCheckGate => checkGates.last;

  /// Awaits the next download writer actually opening. Must be called *before*
  /// triggering the download so the handshake never guesses an ordering.
  Future<void> nextWriterOpened() {
    final request = Completer<void>();
    _openRequests.add(request);
    return request.future;
  }

  @override
  HttpClient Function() get clientFactory => HttpClient.new;

  @override
  Future<AppUpdateCheck> check({
    String? etag,
    Map<String, dynamic>? cached,
    int currentVersionCode = 0,
    String channel = 'default',
    String platform = 'android',
    String architecture = 'arm64-v8a',
  }) async {
    checkContexts.add({
      'version_code': currentVersionCode,
      'platform': platform,
      'arch': architecture,
      'channel': channel,
    });
    checkCalls++;
    final gate = Completer<AppUpdateCheck>();
    checkGates.add(gate);
    final error = checkError;
    if (error != null) throw error;
    return gate.future;
  }

  @override
  Future<void> download(
    AppUpdateArtifact artifact,
    String destination, {
    required void Function(int) onProgress,
  }) async {
    // Acknowledge the entry (a pre-registered request if the test made one) so
    // the caller can assert this writer exists without polling the loop.
    final opened = _openRequests.isNotEmpty
        ? _openRequests.removeAt(0)
        : Completer<void>();
    downloadEntries.add(opened);
    opened.complete();
    downloadCalls++;
    downloadDestinations.add(destination);
    downloadedArtifacts.add(artifact);
    final gate = Completer<void>();
    downloadGates.add(gate);
    final error = downloadError;
    if (error != null) throw error;
    return gate.future;
  }

  @override
  void cancelDownload() => cancelCalls++;

  @override
  void dispose() {}
}

Map<String, dynamic> _releaseJson({
  required String tag,
  String body = 'notes',
}) {
  final version = tag.startsWith('v') ? tag.substring(1) : tag;
  return updatePayload(
    versionName: '$version+42',
    notes: body,
    packages: [
      updatePackage(version: version),
      updatePackage(version: version, arch: 'arm64-v8a', hash: _hexB),
      updatePackage(
        version: version,
        platform: 'macos',
        arch: 'universal',
        size: 8192,
      ),
      updatePackage(version: version, platform: 'windows', hash: _hexB),
    ],
  );
}

/// Owned path-provider fake: replaces the default `MethodChannelPathProvider`,
/// whose `getDownloadsPath` throws on non-macOS hosts before touching any
/// channel, so a channel stub alone cannot isolate `reservePath`.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.downloadsDirectory, this.documentsDirectory);

  final String downloadsDirectory;
  final String documentsDirectory;

  /// When set, `getDownloadsPath` blocks here to park the download inside path
  /// allocation until the test releases it.
  Completer<void>? allocationGate;

  int downloadPathCalls = 0;
  int documentsPathCalls = 0;

  @override
  Future<String?> getDownloadsPath() async {
    downloadPathCalls++;
    await allocationGate?.future;
    return downloadsDirectory;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    documentsPathCalls++;
    return documentsDirectory;
  }
}

/// Owned launcher fake so "no OS handoff happened" is an observation, not an
/// assumption. Records every URL the production code asked to open.
class _FakeLauncher extends UrlLauncherPlatform {
  final List<String> launched = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late _FakeUpdateService service;
  late LocalStorageService storage;
  ProviderContainer? container;
  final methodCalls = <MethodCall>[];
  late PathProviderPlatform originalPathPlatform;
  late _FakePathProvider pathPlatform;
  late UrlLauncherPlatform originalLauncherPlatform;
  late _FakeLauncher launcherPlatform;

  void disposeContainer() {
    container?.dispose();
    container = null;
  }

  /// A fresh container over the same fixtures; the toggle decides whether the
  /// production default (no automatic checks) or an explicit opt-in is used.
  ProviderContainer startContainer({required bool automaticChecks}) =>
      ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          appUpdateServiceProvider.overrideWithValue(service),
          automaticUpdateChecksEnabledProvider.overrideWithValue(
            automaticChecks,
          ),
        ],
      );

  /// State is read through the provider, never through the notifier instance.
  AppUpdateState currentState() => container!.read(appUpdateProvider);

  void stubChannel(String name, {Object? value}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), (call) async {
          methodCalls.add(call);
          if (name == _downloadsChannel && call.method == 'runtimeInfo') {
            return {'storeInstall': false, 'baseBuildNumber': 1};
          }
          return value;
        });
  }

  Future<void> pump() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Status payload of every `reportProgress` call the native download bridge
  /// received, in order.
  List<Object?> reportedStatuses() => methodCalls
      .where((c) => c.method == 'reportProgress')
      .map((c) => (c.arguments as Map)['status'])
      .toList();

  setUp(() async {
    methodCalls.clear();
    temp = Directory.systemTemp.createTempSync('valhalla_update_provider');
    service = _FakeUpdateService();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);

    PackageInfo.setMockInitialValues(
      appName: 'Valhalla',
      packageName: 'com.antigravity.valhalla.valhalla',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    stubChannel(_updatesChannel);
    stubChannel(_downloadsChannel, value: true);
    stubChannel(
      _packageInfoChannel,
      value: {
        'appName': 'Valhalla',
        'packageName': 'com.antigravity.valhalla.valhalla',
        'version': '1.0.0',
        'buildNumber': '1',
        'buildSignature': '',
      },
    );

    // Owned path provider (see _FakePathProvider): the platform channel stub is
    // not consulted on non-macOS hosts.
    originalPathPlatform = PathProviderPlatform.instance;
    pathPlatform = _FakePathProvider(
      '${temp.path}${Platform.pathSeparator}downloads',
      temp.path,
    );
    PathProviderPlatform.instance = pathPlatform;

    originalLauncherPlatform = UrlLauncherPlatform.instance;
    launcherPlatform = _FakeLauncher();
    UrlLauncherPlatform.instance = launcherPlatform;

    container = startContainer(automaticChecks: false);
    addTearDown(disposeContainer);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(_updatesChannel), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(_downloadsChannel), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(_packageInfoChannel), null);
    PathProviderPlatform.instance = originalPathPlatform;
    UrlLauncherPlatform.instance = originalLauncherPlatform;
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test(
    'concurrent checks deduplicate to a single deferred HTTP call',
    () async {
      final notifier = container!.read(appUpdateProvider.notifier);

      final first = notifier.check();
      final second = notifier.check();
      await pump();

      expect(service.checkCalls, 1);
      expect(service.checkContexts.single, {
        'version_code': 1,
        'platform': Platform.operatingSystem,
        'arch': Abi.current().toString().split('_').last,
        'channel': 'default',
      });
      expect(service.checkGates, hasLength(1));
      expect(identical(first, second), isTrue);

      service.nextCheckGate.complete(
        AppUpdateCheck(
          release: AppUpdateService.parseRelease(_releaseJson(tag: 'v9.9.9')),
        ),
      );
      await pump();
      await first;
      expect(second, same(first));
      expect(service.checkCalls, 1);
      expect(currentState().release?.version, '9.9.9');
      expect(currentState().updateAvailable, isTrue);
    },
  );

  test(
    'disposal while a check waits publishes nothing and never calls natives',
    () async {
      final published = <AppUpdateState>[];
      final subscription = container!.listen(
        appUpdateProvider,
        (_, next) => published.add(next),
        fireImmediately: true,
      );
      final notifier = container!.read(appUpdateProvider.notifier);

      final pending = notifier.check();
      await pump();
      expect(service.checkCalls, 1);
      expect(service.checkGates, hasLength(1));
      expect(currentState().checking, isTrue);
      final publishedBeforeDisposal = List<AppUpdateState>.of(published);

      // Provider goes away while the (still mocked) HTTP check is in flight.
      container!.dispose();
      container = null;
      await pump();

      service.nextCheckGate.complete(
        AppUpdateCheck(
          release: AppUpdateService.parseRelease(_releaseJson(tag: 'v9.9.9')),
        ),
      );
      await pump();
      await pending;

      // No durable write, no native install/reveal, no published state.
      expect(storage.getUpdateCheckCache(), isNull);
      expect(storage.getUpdateDownloadRecord(), isNull);
      expect(methodCalls.where((c) => c.method == 'runtimeInfo'), isEmpty);
      expect(methodCalls.where((c) => c.method == 'install'), isEmpty);
      expect(methodCalls.where((c) => c.method == 'revealFile'), isEmpty);
      expect(published, equals(publishedBeforeDisposal));
      expect(published.every((s) => s.release == null), isTrue);
      expect(published.every((s) => !s.updateAvailable), isTrue);
      expect(
        published.any((s) => s.checking),
        isTrue,
        reason: 'the in-flight check must have been observable before disposal',
      );
      subscription.close();
    },
  );

  // One release check that is answered by the fake HTTP gate.
  Future<void> settleRelease({
    String tag = 'v9.9.9',
    ProviderContainer? target,
    Map<String, dynamic>? payload,
  }) async {
    final scope = target ?? container!;
    final notifier = scope.read(appUpdateProvider.notifier);
    final pending = notifier.check();
    await pump();
    expect(
      service.checkGates,
      isNotEmpty,
      reason: 'one fake HTTP call must be in flight',
    );
    service.nextCheckGate.complete(
      AppUpdateCheck(
        release: AppUpdateService.parseRelease(
          payload ?? _releaseJson(tag: tag),
        ),
      ),
    );
    await pump();
    await pending;
  }

  Future<void> completeVerifiedDownload() async {
    final bytes = List<int>.generate(4096, (i) => i % 251);
    await settleRelease(
      payload: updatePayload(
        versionName: '9.9.9+42',
        packages: [
          updatePackage(
            version: '9.9.9',
            platform: Platform.operatingSystem,
            hash: sha256.convert(bytes).toString(),
          ),
        ],
      ),
    );
    final opened = service.nextWriterOpened();
    final task = container!.read(appUpdateProvider.notifier).download();
    await opened;
    await File(
      service.downloadDestinations.single,
    ).writeAsBytes(bytes, flush: true);
    service.downloadGates.single.complete();
    await task;
    expect(currentState().downloadStatus, AppUpdateDownloadStatus.completed);
    launcherPlatform.launched.clear();
  }

  test(
    'repeated opens share verification and launch the completed file once',
    () async {
      await completeVerifiedDownload();
      final notifier = container!.read(appUpdateProvider.notifier);
      final first = notifier.openDownloaded();
      final second = notifier.openDownloaded();
      expect(second, same(first));
      await first;
      if (Platform.isWindows) {
        expect(
          methodCalls.where((call) => call.method == 'revealFile'),
          hasLength(1),
        );
      } else {
        expect(launcherPlatform.launched, hasLength(1));
      }
    },
  );

  test(
    'disposal during file verification prevents a late OS handoff',
    () async {
      await completeVerifiedDownload();
      final notifier = container!.read(appUpdateProvider.notifier);
      final pending = notifier.openDownloaded();
      disposeContainer();
      await pending;
      expect(launcherPlatform.launched, isEmpty);
      expect(methodCalls.where((call) => call.method == 'install'), isEmpty);
    },
  );

  test(
    'a replacement release invalidates an in-flight completed-file open',
    () async {
      await completeVerifiedDownload();
      final notifier = container!.read(appUpdateProvider.notifier);
      final check = notifier.check();
      await pump();
      service.nextCheckGate.complete(
        AppUpdateCheck(
          release: AppUpdateService.parseRelease(_releaseJson(tag: 'v10.0.0')),
        ),
      );
      final opening = notifier.openDownloaded();
      await Future.wait([check, opening]);
      expect(currentState().release!.version, '10.0.0');
      expect(launcherPlatform.launched, isEmpty);
    },
  );

  test(
    'pause then immediate resume waits for the gated writer and reuses the path',
    () async {
      await settleRelease();
      final notifier = container!.read(appUpdateProvider.notifier);
      expect(currentState().updateAvailable, isTrue);
      final artifact = currentState().artifact!;

      final statuses = <AppUpdateDownloadStatus>[];
      final errors = <String?>[];
      final subscription = container!.listen(appUpdateProvider, (_, next) {
        statuses.add(next.downloadStatus);
        errors.add(next.error);
      }, fireImmediately: true);

      // First writer starts and stays blocked inside the fake download.
      final firstWriterOpened = service.nextWriterOpened();
      final first = notifier.download();
      // Bounded I/O acknowledgment: reservePath's mkdir/exists are done and the
      // writer is genuinely open inside the fake download.
      await firstWriterOpened;
      expect(service.downloadCalls, 1, reason: 'one writer must open');
      expect(
        currentState().downloadStatus,
        AppUpdateDownloadStatus.downloading,
      );

      // Two more taps while downloading must not duplicate the writer.
      await notifier.download();
      await notifier.download();
      await pump();
      expect(service.downloadCalls, 1);

      final firstDestination = service.downloadDestinations.single;

      // Pause cancels the old writer; it is still finishing (cancel cleanup).
      notifier.pauseDownload();
      expect(currentState().downloadStatus, AppUpdateDownloadStatus.paused);
      expect(service.cancelCalls, 1);
      // Resuming immediately must await the still-pending old writer.
      final secondWriterOpened = service.nextWriterOpened();
      final resumed = notifier.download();
      await pump();
      // The resume is parked on the old writer, so writer 1 has not opened yet.
      expect(service.downloadEntries, hasLength(1));
      expect(
        service.downloadCalls,
        1,
        reason:
            'the old writer must settle before a second one opens the '
            'same .part',
      );
      expect(
        currentState().downloadStatus,
        AppUpdateDownloadStatus.downloading,
      );

      // Releasing the old writer lets the resume open the second one.
      service.downloadGates.single.complete();
      await secondWriterOpened;
      expect(
        service.downloadCalls,
        2,
        reason: 'the resumed writer must open only after the old one settled',
      );

      await first;
      await pump();

      // Only now does the second writer open, on the exact same path/artifact.
      expect(service.downloadCalls, 2);
      expect(service.downloadDestinations, [
        firstDestination,
        firstDestination,
      ]);
      expect(service.downloadedArtifacts, everyElement(same(artifact)));
      expect(currentState().localPath, firstDestination);

      service.downloadGates.last.complete();
      await resumed;
      await pump();

      expect(currentState().downloadStatus, AppUpdateDownloadStatus.completed);
      expect(currentState().downloadedBytes, artifact.size);
      expect(
        errors.every((e) => e == null),
        isTrue,
        reason: 'no false failed state from the canceled writer',
      );
      expect(
        statuses,
        isNot(contains(AppUpdateDownloadStatus.failed)),
        reason: 'a canceled writer must never publish failed',
      );
      subscription.close();
    },
  );

  test(
    'cancel while path allocation is pending leaves no writer and no record',
    () async {
      await settleRelease();
      final notifier = container!.read(appUpdateProvider.notifier);
      // Only this test's native calls matter from here on.
      methodCalls.clear();

      // Gate the path-provider exchange reservePath awaits.
      final allocationDone = Completer<void>();
      pathPlatform.allocationGate = allocationDone;

      final pending = notifier.download();
      await pump();
      expect(
        pathPlatform.downloadPathCalls,
        1,
        reason: 'the download must be parked inside path allocation',
      );
      expect(
        currentState().downloadStatus,
        AppUpdateDownloadStatus.downloading,
      );
      expect(service.downloadCalls, 0);
      expect(service.checkGates, hasLength(1));
      expect(currentState().localPath, isNull);
      // Allocation has not returned, so no durable record exists yet.
      expect(storage.getUpdateDownloadRecord(), isNull);

      // The user cancels before allocation returns.
      notifier.pauseDownload();
      expect(service.cancelCalls, 1);
      expect(currentState().downloadStatus, AppUpdateDownloadStatus.paused);

      // Allocation resolves after the epoch went stale.
      allocationDone.complete();
      await pending;
      await pump();

      expect(
        service.downloadCalls,
        0,
        reason: 'no download may start for a canceled epoch',
      );
      expect(
        storage.getUpdateDownloadRecord(),
        isNull,
        reason: 'no durable record may be written for a canceled epoch',
      );
      expect(service.downloadGates, isEmpty);
      expect(currentState().downloadStatus, AppUpdateDownloadStatus.paused);
      expect(currentState().error, isNull);
      expect(
        reportedStatuses(),
        ['paused'],
        reason:
            'the canceled epoch may report pausing to the native bridge, but '
            'never running or completed progress',
      );
    },
  );

  test(
    'a failed check keeps the previous release; an empty result clears it',
    () async {
      await settleRelease();
      final notifier = container!.read(appUpdateProvider.notifier);
      final release = currentState().release!;
      expect(currentState().updateAvailable, isTrue);
      expect(storage.getUpdateCheckCache(), isNotNull);

      // The next check fails: previous content must survive. The notifier never
      // rethrows; the failure is published as a state error.
      service.checkError = StateError('UPDATE_CHECK_FAILED');
      await notifier.check();
      await pump();
      expect(currentState().checking, isFalse);
      expect(currentState().error, contains('UPDATE_CHECK_FAILED'));
      expect(currentState().release, same(release));
      expect(currentState().artifact, isNotNull);
      expect(currentState().updateAvailable, isTrue);
      expect(
        storage.getUpdateCheckCache(),
        isNotNull,
        reason: 'the previously successful cache must not be discarded',
      );

      // A clean 404-style check clears the previous release.
      service.checkError = null;
      final pending = notifier.check();
      await pump();
      expect(service.checkGates, hasLength(3));
      service.nextCheckGate.complete(const AppUpdateCheck(release: null));
      await pending;
      await pump();

      expect(currentState().release, isNull);
      expect(currentState().artifact, isNull);
      expect(currentState().updateAvailable, isFalse);
      expect(currentState().error, isNull);
    },
  );

  test('the production default performs no HTTP check on its own', () async {
    // No automaticUpdateChecksEnabledProvider override: the production default
    // (isolated widgets never check) must keep every entry point silent.
    final isolated = startContainer(automaticChecks: false);
    addTearDown(isolated.dispose);
    final notifier = isolated.read(appUpdateProvider.notifier);

    await pump();
    await notifier.checkIfDue();
    await pump();

    final visibility = isolated.read(appVisibilityProvider.notifier);
    visibility.setForeground(false);
    await pump();
    visibility.setForeground(true);
    await pump();
    await notifier.checkIfDue();
    await pump();

    expect(service.checkCalls, 0, reason: 'no fake HTTP call may happen');
    expect(service.checkGates, isEmpty);
    expect(storage.getUpdateCheckCache(), isNull);
    expect(isolated.read(appUpdateProvider).checking, isFalse);
  });

  test(
    'an enabled automatic check fires once and not again within 24h',
    () async {
      final enabled = startContainer(automaticChecks: true);
      addTearDown(enabled.dispose);
      final notifier = enabled.read(appUpdateProvider.notifier);

      // build() -> _restore -> checkIfDue: no cached checkedAt, so one check.
      await pump();
      expect(service.checkCalls, 1);
      expect(service.checkGates, hasLength(1));
      // Same in-flight future: a second call must not open a second HTTP call.
      final first = notifier.check();
      expect(first, same(notifier.check()));
      service.nextCheckGate.complete(
        AppUpdateCheck(
          release: AppUpdateService.parseRelease(_releaseJson(tag: 'v9.9.9')),
        ),
      );
      await pump();
      await first;
      expect(enabled.read(appUpdateProvider).release?.version, '9.9.9');
      expect(storage.getUpdateCheckCache(), isNotNull);

      // Both entry points must stay silent inside the 24h window.
      await notifier.checkIfDue();
      await pump();
      final visibility = enabled.read(appVisibilityProvider.notifier);
      visibility.setForeground(false);
      await pump();
      visibility.setForeground(true);
      await pump();
      await notifier.checkIfDue();
      await pump();

      expect(
        service.checkCalls,
        1,
        reason: 'the 24h guard must block every further check',
      );
    },
  );

  test('a completed download with a wrong hash never reaches the OS', () async {
    await settleRelease();
    final notifier = container!.read(appUpdateProvider.notifier);
    final artifact = currentState().artifact!;
    methodCalls.clear();

    final writerOpened = service.nextWriterOpened();
    final pending = notifier.download();
    // Bounded I/O acknowledgment instead of a fixed turn count: reservePath's
    // mkdir/exists are done and the destination path is allocated.
    await writerOpened;
    expect(service.downloadCalls, 1);
    final destination = service.downloadDestinations.single;
    service.downloadGates.single.complete();
    await pending;
    await pump();

    expect(currentState().downloadStatus, AppUpdateDownloadStatus.completed);
    expect(currentState().localPath, destination);

    // The writer lands the exact byte count but with the wrong content.
    await File(
      destination,
    ).writeAsBytes(List<int>.filled(artifact.size, 0x41), flush: true);
    expect(await File(destination).length(), artifact.size);

    await expectLater(
      notifier.openDownloaded(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'UPDATE_DOWNLOAD_INTEGRITY_FAILED',
        ),
      ),
    );

    // No installer, no reveal, no external launch of any kind.
    expect(methodCalls.where((c) => c.method == 'install'), isEmpty);
    expect(methodCalls.where((c) => c.method == 'revealFile'), isEmpty);
    expect(
      launcherPlatform.launched,
      isEmpty,
      reason: 'a tampered download must not be opened or revealed',
    );
    // State is left exactly as the verified download had it.
    expect(currentState().downloadStatus, AppUpdateDownloadStatus.completed);
    expect(currentState().error, isNull);
  });
}
