// Focused provider tests for daily automatic update checks and prompt claims.
//
// Scope: calendar gating, prompt claims and failure backoff only. HTTP,
// package info and prefs are in-test fakes; no real server or device.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _FakeUpdateService implements AppUpdateService {
  int checkCalls = 0;
  Object? checkError;
  AppUpdateRelease? nextRelease;
  Map<String, dynamic>? nextResponse;

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
    checkCalls++;
    final error = checkError;
    if (error != null) throw error;
    return AppUpdateCheck(release: nextRelease, response: nextResponse);
  }

  @override
  Future<void> download(
    AppUpdateArtifact artifact,
    String destination, {
    required void Function(int) onProgress,
    void Function(AppUpdateDownloadPhase)? onPhase,
  }) async {}

  @override
  void cancelDownload() {}

  @override
  void dispose() {}
}

Map<String, dynamic> _releaseJson({required String tag}) {
  final version = tag.startsWith('v') ? tag.substring(1) : tag;
  return updatePayload(
    versionName: '$version+42',
    packages: [
      updatePackage(version: version),
      updatePackage(version: version, arch: 'arm64-v8a', hash: updateHashB),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeUpdateService service;
  late LocalStorageService storage;
  late DateTime now;
  ProviderContainer? container;

  ProviderContainer startContainer({required bool automaticChecks}) =>
      ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          appUpdateServiceProvider.overrideWithValue(service),
          automaticUpdateChecksEnabledProvider.overrideWithValue(
            automaticChecks,
          ),
          appUpdateNowProvider.overrideWithValue(() => now),
        ],
      );

  AppUpdateState currentState() => container!.read(appUpdateProvider);

  Future<void> pump() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> settleDailyCheck({
    AppUpdateRelease? release,
    Object? error,
    Map<String, dynamic>? response,
  }) async {
    service.nextRelease = release;
    service.checkError = error;
    service.nextResponse = response;
    final pending = container!.read(appUpdateProvider.notifier).checkIfDue();
    await pump();
    await pending;
    await pump();
  }

  setUp(() async {
    now = DateTime(2026, 10, 23, 10, 0, 0);
    service = _FakeUpdateService();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);

    PackageInfo.setMockInitialValues(
      appName: 'Valhalla',
      packageName: 'com.norns.valhalla',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(_updatesChannel), (call) async {
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          MethodChannel(_downloadsChannel),
          (call) async => {'storeInstall': false, 'baseBuildNumber': 1},
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          MethodChannel(_packageInfoChannel),
          (call) async => {
            'appName': 'Valhalla',
            'packageName': 'com.norns.valhalla',
            'version': '1.0.0',
            'buildNumber': '1',
            'buildSignature': '',
          },
        );

    container = startContainer(automaticChecks: true);
    addTearDown(() {
      container?.dispose();
      container = null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(_updatesChannel), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(_downloadsChannel), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(_packageInfoChannel), null);
  });

  test(
    'daily auto check uses the local calendar day from appUpdateNowProvider',
    () async {
      final release = AppUpdateService.parseRelease(
        _releaseJson(tag: 'v9.9.9'),
      );
      // Day one: an available update arms the automatic prompt.
      await settleDailyCheck(release: release);
      expect(service.checkCalls, 1);
      expect(currentState().updateAvailable, isTrue);
      expect(currentState().pendingAutomaticPrompt, isTrue);
      expect(storage.getUpdatePromptRecord()['lastSuccessDate'], '2026-10-23');
      expect(storage.getUpdatePromptRecord()['lastAttemptAt'], isNotNull);

      // Same local day: lastSuccessDate blocks a second automatic check.
      await settleDailyCheck(release: release);
      expect(service.checkCalls, 1);

      // Next local calendar day: the daily window opens again.
      now = DateTime(2026, 10, 24, 9, 0, 0);
      await settleDailyCheck(release: release);
      expect(service.checkCalls, 2);
      expect(storage.getUpdatePromptRecord()['lastSuccessDate'], '2026-10-24');
      expect(currentState().pendingAutomaticPrompt, isTrue);
    },
  );

  test('a successful check with no update never arms a prompt', () async {
    await settleDailyCheck(release: null);
    expect(service.checkCalls, 1);
    expect(currentState().updateAvailable, isFalse);
    expect(currentState().pendingAutomaticPrompt, isFalse);
    expect(storage.getUpdatePromptRecord()['lastSuccessDate'], '2026-10-23');

    final claimed = await container!
        .read(appUpdateProvider.notifier)
        .claimAutomaticPrompt();
    expect(claimed, isFalse);
    expect(currentState().pendingAutomaticPrompt, isFalse);
  });

  test('claimAutomaticPrompt allows one claim per local day', () async {
    final release = AppUpdateService.parseRelease(_releaseJson(tag: 'v9.9.9'));
    await settleDailyCheck(release: release);
    expect(currentState().pendingAutomaticPrompt, isTrue);

    final first = await container!
        .read(appUpdateProvider.notifier)
        .claimAutomaticPrompt();
    expect(first, isTrue);
    expect(currentState().pendingAutomaticPrompt, isFalse);
    expect(storage.getUpdatePromptRecord()['lastPromptDate'], '2026-10-23');

    // A later claim the same local day must not show a second dialog.
    final second = await container!
        .read(appUpdateProvider.notifier)
        .claimAutomaticPrompt();
    expect(second, isFalse);

    // Same local day: lastSuccessDate still blocks a new automatic check, so
    // the prompt cannot re-arm until the calendar day rolls.
    await settleDailyCheck(release: release);
    expect(currentState().pendingAutomaticPrompt, isFalse);

    now = DateTime(2026, 10, 24, 8, 0, 0);
    await settleDailyCheck(release: release);
    expect(currentState().pendingAutomaticPrompt, isTrue);
    final nextDay = await container!
        .read(appUpdateProvider.notifier)
        .claimAutomaticPrompt();
    expect(nextDay, isTrue);
    expect(storage.getUpdatePromptRecord()['lastPromptDate'], '2026-10-24');
  });

  test('a failed daily check retries only after at least 15 minutes', () async {
    service.checkError = StateError('UPDATE_CHECK_FAILED');
    await container!.read(appUpdateProvider.notifier).checkIfDue();
    await pump();
    expect(service.checkCalls, 1);
    expect(currentState().error, contains('UPDATE_CHECK_FAILED'));
    expect(storage.getUpdatePromptRecord()['lastAttemptAt'], isNotNull);
    expect(storage.getUpdatePromptRecord()['lastSuccessDate'], isNull);
    expect(currentState().pendingAutomaticPrompt, isFalse);

    // Still inside the 15-minute backoff: no second HTTP attempt.
    now = now.add(const Duration(minutes: 14));
    await container!.read(appUpdateProvider.notifier).checkIfDue();
    await pump();
    expect(service.checkCalls, 1);

    // At the 15-minute boundary the automatic check may run again.
    now = now.add(const Duration(minutes: 1));
    service.checkError = null;
    service.nextRelease = AppUpdateService.parseRelease(
      _releaseJson(tag: 'v9.9.9'),
    );
    await container!.read(appUpdateProvider.notifier).checkIfDue();
    await pump();
    await container!.read(appUpdateProvider.notifier).checkIfDue();
    await pump();
    // One retry after the backoff window (daily success then blocks).
    expect(service.checkCalls, 2);
    expect(currentState().error, isNull);
    expect(currentState().pendingAutomaticPrompt, isTrue);
    expect(storage.getUpdatePromptRecord()['lastSuccessDate'], '2026-10-23');
  });

  test('background defers both the daily check and the prompt claim', () async {
    final visibility = container!.read(appVisibilityProvider.notifier);
    visibility.setForeground(false);
    await pump();

    await settleDailyCheck(
      release: AppUpdateService.parseRelease(_releaseJson(tag: 'v9.9.9')),
    );
    expect(service.checkCalls, 0, reason: 'no background HTTP check');
    expect(currentState().pendingAutomaticPrompt, isFalse);

    visibility.setForeground(true);
    await settleDailyCheck(
      release: AppUpdateService.parseRelease(_releaseJson(tag: 'v9.9.9')),
    );
    expect(service.checkCalls, 1);
    expect(currentState().pendingAutomaticPrompt, isTrue);

    visibility.setForeground(false);
    final claimedWhileBackgrounded = await container!
        .read(appUpdateProvider.notifier)
        .claimAutomaticPrompt();
    expect(claimedWhileBackgrounded, isFalse);
    expect(
      currentState().pendingAutomaticPrompt,
      isTrue,
      reason: 'a background claim must not consume the pending prompt',
    );

    visibility.setForeground(true);
    final claimedInForeground = await container!
        .read(appUpdateProvider.notifier)
        .claimAutomaticPrompt();
    expect(claimedInForeground, isTrue);
    expect(currentState().pendingAutomaticPrompt, isFalse);
  });

  test(
    'disabling automatic checks blocks checks and clears a pending prompt',
    () async {
      final release = AppUpdateService.parseRelease(
        _releaseJson(tag: 'v9.9.9'),
      );
      await settleDailyCheck(release: release);
      expect(service.checkCalls, 1);
      expect(currentState().pendingAutomaticPrompt, isTrue);

      await container!
          .read(appUpdateProvider.notifier)
          .setAutomaticCheck(false);
      await pump();
      expect(currentState().automaticCheck, isFalse);
      expect(currentState().pendingAutomaticPrompt, isFalse);
      expect(storage.getAutomaticUpdateCheck(), isFalse);

      // The local day is still open; a disabled automatic check must not run.
      now = DateTime(2026, 10, 24, 8, 0, 0);
      await settleDailyCheck(release: release);
      expect(service.checkCalls, 1);

      final claimed = await container!
          .read(appUpdateProvider.notifier)
          .claimAutomaticPrompt();
      expect(claimed, isFalse);
    },
  );

  test(
    'verified cached new release with today success and no prompt date restores pending',
    () async {
      // Dispose the container created in setUp before seeding persisted state.
      container!.dispose();
      container = null;
      await pump();

      final releaseJson = _releaseJson(tag: 'v9.9.9');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      await storage.saveUpdateCheckCache({
        'source': AppUpdateService.cacheSource,
        'checkedAt': now.toUtc().toIso8601String(),
        'release': releaseJson,
      });
      await storage.saveUpdatePromptRecord({
        'lastSuccessDate': '2026-10-23',
        'lastAttemptAt': now.toUtc().toIso8601String(),
      });

      container = startContainer(automaticChecks: true);
      container!.read(appUpdateProvider);
      await pump();
      await pump();
      await pump();
      expect(currentState().updateAvailable, isTrue);
      expect(currentState().pendingAutomaticPrompt, isTrue);
      expect(service.checkCalls, 0);
    },
  );

  test(
    'a prompt claimed or marked today is never repeated the same day',
    () async {
      final releaseJson = _releaseJson(tag: 'v9.9.9');
      final release = AppUpdateService.parseRelease(releaseJson);
      await settleDailyCheck(release: release, response: releaseJson);
      final claimed = await container!
          .read(appUpdateProvider.notifier)
          .claimAutomaticPrompt();
      expect(claimed, isTrue);
      expect(storage.getUpdatePromptRecord()['lastPromptDate'], '2026-10-23');

      await settleDailyCheck(release: release, response: releaseJson);
      expect(service.checkCalls, 1);
      expect(currentState().pendingAutomaticPrompt, isFalse);
      expect(
        await container!
            .read(appUpdateProvider.notifier)
            .claimAutomaticPrompt(),
        isFalse,
      );

      // A pre-seeded claimed day also stays quiet after a fresh container.
      container!.dispose();
      container = null;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      await storage.saveUpdateCheckCache({
        'source': AppUpdateService.cacheSource,
        'checkedAt': now.toUtc().toIso8601String(),
        'release': releaseJson,
      });
      await storage.saveUpdatePromptRecord({
        'lastSuccessDate': '2026-10-23',
        'lastPromptDate': '2026-10-23',
        'lastAttemptAt': now.toUtc().toIso8601String(),
      });
      container = startContainer(automaticChecks: true);
      container!.read(appUpdateProvider);
      await pump();
      await pump();
      expect(currentState().pendingAutomaticPrompt, isFalse);
    },
  );

  test(
    'the next local calendar day checks again even under 24 hours',
    () async {
      final releaseJson = _releaseJson(tag: 'v9.9.9');
      final release = AppUpdateService.parseRelease(releaseJson);
      await settleDailyCheck(release: release, response: releaseJson);
      expect(service.checkCalls, 1);

      now = DateTime(2026, 10, 23, 23, 50, 0);
      // Force a successful day rollover shortly after, under 24 hours later.
      now = DateTime(2026, 10, 24, 0, 10, 0);
      await settleDailyCheck(release: release, response: releaseJson);
      expect(service.checkCalls, 2);
      expect(storage.getUpdatePromptRecord()['lastSuccessDate'], '2026-10-24');
      expect(currentState().pendingAutomaticPrompt, isTrue);
    },
  );

  test('a backward clock does not throttle the daily retry forever', () async {
    service.checkError = StateError('UPDATE_CHECK_FAILED');
    final pending = container!.read(appUpdateProvider.notifier).checkIfDue();
    await pump();
    await pending;
    await pump();
    expect(service.checkCalls, 1);
    expect(storage.getUpdatePromptRecord()['lastSuccessDate'], isNull);

    now = now.subtract(const Duration(minutes: 5));
    service.checkError = null;
    service.nextRelease = AppUpdateService.parseRelease(
      _releaseJson(tag: 'v9.9.9'),
    );
    service.nextResponse = _releaseJson(tag: 'v9.9.9');

    final retry = container!.read(appUpdateProvider.notifier).checkIfDue();
    await pump();
    await retry;
    await pump();
    expect(service.checkCalls, 2);
    expect(currentState().error, isNull);
    expect(currentState().pendingAutomaticPrompt, isTrue);
  });

  test(
    'deferAutomaticPrompt after a claim undoes today mark and requeues pending',
    () async {
      final releaseJson = _releaseJson(tag: 'v9.9.9');
      final release = AppUpdateService.parseRelease(releaseJson);
      await settleDailyCheck(release: release, response: releaseJson);
      expect(currentState().pendingAutomaticPrompt, isTrue);

      final first = await container!
          .read(appUpdateProvider.notifier)
          .claimAutomaticPrompt();
      expect(first, isTrue);
      expect(storage.getUpdatePromptRecord()['lastPromptDate'], '2026-10-23');

      await container!.read(appUpdateProvider.notifier).deferAutomaticPrompt();
      expect(storage.getUpdatePromptRecord()['lastPromptDate'], isNull);
      expect(currentState().pendingAutomaticPrompt, isTrue);

      final second = await container!
          .read(appUpdateProvider.notifier)
          .claimAutomaticPrompt();
      expect(second, isTrue);
      expect(storage.getUpdatePromptRecord()['lastPromptDate'], '2026-10-23');
    },
  );
}
