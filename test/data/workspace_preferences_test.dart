import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/storage/workspace_preferences.dart';

void main() {
  group('WorkspacePreferences', () {
    test('successful write emits change', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = WorkspacePreferences(await SharedPreferences.getInstance());
      final events = <String>[];
      final sub = prefs.changes.listen(events.add);
      final ok = await prefs.setString('k', 'v');
      await Future<void>.delayed(Duration.zero);
      expect(ok, isTrue);
      expect(events, ['k']);
      await sub.cancel();
    });

    test('hydration suppresses echo', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = WorkspacePreferences(await SharedPreferences.getInstance());
      final events = <String>[];
      final sub = prefs.changes.listen(events.add);
      await prefs.hydrate(() async {
        await prefs.setString('k', 'v');
        await prefs.setInt('n', 1);
        await prefs.remove('k');
      });
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      expect(prefs.getString('k'), isNull);
      expect(prefs.getInt('n'), 1);
      await sub.cancel();
    });

    test('non-hydrated successful writes emit each key', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = WorkspacePreferences(await SharedPreferences.getInstance());
      final events = <String>[];
      final sub = prefs.changes.listen(events.add);
      await prefs.setBool('b', true);
      await prefs.setDouble('d', 1.5);
      await prefs.setStringList('l', ['a']);
      await Future<void>.delayed(Duration.zero);
      expect(events, ['b', 'd', 'l']);
      await sub.cancel();
    });

    test('hydration zone does not suppress a concurrent local write', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = WorkspacePreferences(await SharedPreferences.getInstance());
      final events = <String>[];
      final sub = prefs.changes.listen(events.add);
      final gate = Completer<void>();
      final generationBefore = prefs.generation;

      final hydration = prefs.hydrate(() async {
        await prefs.setString('remote', 'v');
        await gate.future;
        await prefs.setInt('remote2', 1);
      });
      await Future<void>.delayed(Duration.zero);

      // A UI write lands while the hydration zone is still open.
      await prefs.setString('local', 'x');
      await Future<void>.delayed(Duration.zero);
      expect(prefs.generation, greaterThan(generationBefore));
      expect(events, ['local']);

      gate.complete();
      await hydration;
      await Future<void>.delayed(Duration.zero);
      // The remote writes stayed suppressed; the concurrent local write did
      // not get swallowed by the zone.
      expect(events, ['local']);
      expect(prefs.getString('remote'), 'v');
      expect(prefs.getInt('remote2'), 1);
      await sub.cancel();
    });
  });
}
