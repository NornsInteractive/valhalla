import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import '../support/application_center_fakes.dart';

void main() {
  test(
    'old cleanup targets preserve shape and new volume targets retain identity and references',
    () {
      const legacy = ApplicationCleanupTarget(
        key: 'old',
        source: '/fixture/data',
        identity: {'inode': '1'},
      );
      final oldJson = legacy.toJson();
      expect(oldJson, isNot(contains('kind')));
      expect(oldJson, isNot(contains('references')));
      final restored = ApplicationCleanupTarget.fromJson(oldJson);
      expect(restored.kind, 'bind');
      expect(restored.references, isEmpty);
      expect(restored.toJson(), oldJson);
      const volume = ApplicationCleanupTarget(
        key: 'new',
        source: 'fixture-volume',
        kind: 'volume',
        references: ['container:fixture'],
        risks: ['volume', 'shared'],
        identity: {'fingerprint': 'identity'},
      );
      expect(
        ApplicationCleanupTarget.fromJson(volume.toJson()).toJson(),
        volume.toJson(),
      );
    },
  );
  test('application center is available without experimental features', () {
    const settings = SettingsState(
      bottomNavigationSections: [AppSection.appCenter],
      startupSection: AppSection.appCenter,
    );
    expect(settings.enabledExperimentalFeatures, isEmpty);
    expect(settings.availableSections, contains(AppSection.appCenter));
    expect(settings.visibleBottomNavigationSections, [AppSection.appCenter]);
    expect(settings.effectiveStartupSection, AppSection.appCenter);
    expect(experimentalFeaturesFromStorage(['appCenter']), isEmpty);
  });
  test('records isolate targets and preserve unrelated preferences', () async {
    SharedPreferences.setMockInitialValues({'unrelated': 'keep'});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    await storage.saveApplicationCenterRecords('tasks', 'a', [
      {'id': 'one'},
    ]);
    await storage.saveApplicationCenterRecords('tasks', 'b', [
      {'id': 'two'},
    ]);
    expect(
      storage.getApplicationCenterRecords('tasks', 'a').single['id'],
      'one',
    );
    expect(
      storage.getApplicationCenterRecords('tasks', 'b').single['id'],
      'two',
    );
    expect(prefs.getString('unrelated'), 'keep');
    await expectLater(
      storage.saveApplicationCenterRecords(
        'tasks',
        'a',
        List.filled(1001, <String, dynamic>{}),
      ),
      throwsStateError,
    );
    expect(
      storage.getApplicationCenterRecords('tasks', 'a').single['id'],
      'one',
    );
  });
  test('task persistence excludes output and credentials', () {
    final saved = centerTask(centerDeployment())
        .copyWith(
          logTail: 'token=log-secret',
          currentCommand: 'docker compose --token=command-secret pull',
          syncError: 'transport-secret',
          lastSyncedAt: DateTime.utc(2026, 10, 12),
        )
        .toJson();
    expect(saved.containsKey('logTail'), false);
    expect(jsonEncode(saved), isNot(contains('secret')));
    for (final field in [
      'configuration',
      'variables',
      'environment',
      'password',
      'currentCommand',
      'syncError',
      'lastSyncedAt',
    ]) {
      expect(saved.containsKey(field), false);
    }
  });
  test(
    'task metadata roundtrips without persisting transient diagnostic content',
    () {
      final task = centerTask(centerDeployment()).copyWith(
        stage: ApplicationTaskStage.succeeded,
        exitCode: 0,
        commandStartedAt: DateTime.utc(2026, 10, 12, 1),
        lastOutputAt: DateTime.utc(2026, 10, 12, 2),
        logTail: 'private output',
        currentCommand: 'private command',
        syncError: 'private diagnostic',
      );
      final restored = ApplicationTask.fromJson(task.toJson());
      expect(restored.id, task.id);
      expect(restored.stage, ApplicationTaskStage.succeeded);
      expect(restored.exitCode, 0);
      expect(restored.commandStartedAt, task.commandStartedAt);
      expect(restored.lastOutputAt, task.lastOutputAt);
      expect(restored.logTail, isEmpty);
      expect(restored.currentCommand, isEmpty);
      expect(restored.syncError, isNull);
      expect(restored.lastSyncedAt, isNull);
    },
  );
  test('legacy tasks without optional timestamps remain readable', () {
    final record = centerTask(centerDeployment()).toJson()
      ..remove('commandStartedAt')
      ..remove('lastOutputAt');
    final restored = ApplicationTask.fromJson(record);
    expect(restored.commandStartedAt, isNull);
    expect(restored.lastOutputAt, isNull);
    expect(restored.stage, ApplicationTaskStage.queued);
    expect(restored.isBusy, isTrue);
    expect(restored.currentCommand, isEmpty);
  });
  test('sync error clearing preserves known task output and progress', () {
    final task = centerTask(centerDeployment()).copyWith(
      stage: ApplicationTaskStage.pulling,
      logTail: 'previous output',
      currentCommand: 'docker compose pull',
      syncError: 'temporarily offline',
    );
    final recovered = task.copyWith(clearSyncError: true);
    expect(recovered.syncError, isNull);
    expect(recovered.stage, task.stage);
    expect(recovered.logTail, task.logTail);
    expect(recovered.currentCommand, task.currentCommand);
  });
}
