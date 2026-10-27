import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

String _key(String scope) => 'valhalla_composer_v1::$scope';

Future<LocalStorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStorageService(await SharedPreferences.getInstance());
}

Future<SharedPreferences> _prefs() async {
  return SharedPreferences.getInstance();
}

void main() {
  group('composer command favorites', () {
    test('favorites persist across a fresh service read', () async {
      final storage = await _storage();

      await storage.setComposerCommandFavorite('scope-a', 'skill:review', true);
      await storage.setComposerCommandFavorite(
        'scope-a',
        'command:review',
        true,
      );

      final reread = LocalStorageService(await _prefs());
      final preferences = reread.getComposerCommandPreferences('scope-a');

      expect(preferences.favorites, {'skill:review', 'command:review'});
      expect(preferences.recent, isEmpty);
    });

    test(
      'removing a favorite persists and leaves the other id alone',
      () async {
        final storage = await _storage();
        await storage.setComposerCommandFavorite(
          'scope-a',
          'skill:review',
          true,
        );
        await storage.setComposerCommandFavorite(
          'scope-a',
          'command:review',
          true,
        );

        await storage.setComposerCommandFavorite(
          'scope-a',
          'skill:review',
          false,
        );

        final reread = LocalStorageService(await _prefs());
        final preferences = reread.getComposerCommandPreferences('scope-a');
        expect(preferences.favorites, {'command:review'});

        await storage.setComposerCommandFavorite(
          'scope-a',
          'command:review',
          false,
        );
        expect(
          LocalStorageService(
            await _prefs(),
          ).getComposerCommandPreferences('scope-a').favorites,
          isEmpty,
        );
      },
    );

    test('favorites and recent ids are namespaced independently', () async {
      final storage = await _storage();

      await storage.setComposerCommandFavorite('scope-a', 'skill:review', true);
      await storage.setComposerCommandFavorite(
        'scope-a',
        'command:review',
        true,
      );
      await storage.recordComposerCommandUse('scope-a', 'skill:review');

      final preferences = storage.getComposerCommandPreferences('scope-a');
      expect(preferences.favorites, {'skill:review', 'command:review'});
      expect(preferences.recent, ['skill:review']);

      await storage.setComposerCommandFavorite(
        'scope-a',
        'command:review',
        false,
      );
      final afterRemoval = storage.getComposerCommandPreferences('scope-a');
      expect(afterRemoval.favorites, {'skill:review'});
      expect(afterRemoval.recent, ['skill:review']);
    });
  });

  group('composer command recent', () {
    test('recent deduplicates and moves the used id to the front', () async {
      final storage = await _storage();

      await storage.recordComposerCommandUse('scope-a', 'a');
      await storage.recordComposerCommandUse('scope-a', 'b');
      await storage.recordComposerCommandUse('scope-a', 'c');
      expect(storage.getComposerCommandPreferences('scope-a').recent, [
        'c',
        'b',
        'a',
      ]);

      await storage.recordComposerCommandUse('scope-a', 'a');
      expect(storage.getComposerCommandPreferences('scope-a').recent, [
        'a',
        'c',
        'b',
      ]);

      await storage.recordComposerCommandUse('scope-a', 'b');
      expect(storage.getComposerCommandPreferences('scope-a').recent, [
        'b',
        'a',
        'c',
      ]);
    });

    test('recent is capped at ten entries, newest first', () async {
      final storage = await _storage();

      for (var index = 1; index <= 12; index++) {
        await storage.recordComposerCommandUse('scope-a', 'id-$index');
      }

      final recent = storage.getComposerCommandPreferences('scope-a').recent;
      expect(recent, hasLength(10));
      expect(recent.first, 'id-12');
      expect(recent.last, 'id-3');
      expect(recent, isNot(contains('id-1')));
      expect(recent, isNot(contains('id-2')));
    });

    test(
      'recording a use preserves favorites and re-reading persists',
      () async {
        final storage = await _storage();
        await storage.setComposerCommandFavorite(
          'scope-a',
          'skill:review',
          true,
        );

        await storage.recordComposerCommandUse('scope-a', 'command:review');

        final preferences = LocalStorageService(
          await _prefs(),
        ).getComposerCommandPreferences('scope-a');
        expect(preferences.favorites, {'skill:review'});
        expect(preferences.recent, ['command:review']);
      },
    );
  });

  group('composer command scoping', () {
    test('different scope keys are isolated', () async {
      final storage = await _storage();

      await storage.setComposerCommandFavorite('scope-a', 'skill:a', true);
      await storage.recordComposerCommandUse('scope-a', 'skill:a');
      await storage.setComposerCommandFavorite('scope-b', 'skill:b', true);
      await storage.recordComposerCommandUse('scope-b', 'skill:b');

      final a = storage.getComposerCommandPreferences('scope-a');
      final b = storage.getComposerCommandPreferences('scope-b');
      final missing = storage.getComposerCommandPreferences('scope-c');

      expect(a.favorites, {'skill:a'});
      expect(a.recent, ['skill:a']);
      expect(b.favorites, {'skill:b'});
      expect(b.recent, ['skill:b']);
      expect(missing.favorites, isEmpty);
      expect(missing.recent, isEmpty);
    });
  });

  group('composer command validation', () {
    test('malformed stored JSON reads as empty', () async {
      final storage = await _storage();
      final prefs = await _prefs();

      await prefs.setString(_key('broken-json'), '{not-json');
      await prefs.setString(_key('broken-shape'), '[]');
      await prefs.setString(
        _key('broken-favorites'),
        '{"favorites": "not-a-list", "recent": "also-not-a-list"}',
      );

      for (final scope in ['broken-json', 'broken-shape', 'broken-favorites']) {
        final preferences = storage.getComposerCommandPreferences(scope);
        expect(preferences.favorites, isEmpty, reason: scope);
        expect(preferences.recent, isEmpty, reason: scope);
      }
    });

    test(
      'a write after malformed data recovers with only the new entry',
      () async {
        final storage = await _storage();
        final prefs = await _prefs();
        await prefs.setString(_key('scope-a'), '{not-json');

        await storage.setComposerCommandFavorite(
          'scope-a',
          'skill:review',
          true,
        );

        final preferences = storage.getComposerCommandPreferences('scope-a');
        expect(preferences.favorites, {'skill:review'});
        expect(preferences.recent, isEmpty);
      },
    );

    test('invalid ids are rejected before any write', () async {
      final storage = await _storage();
      final prefs = await _prefs();
      final before = prefs.getString(_key('scope-a'));

      final invalidIds = ['', 'a\nb', 'a\u0000b', 'x' * 1025];

      for (final id in invalidIds) {
        await expectLater(
          storage.setComposerCommandFavorite('scope-a', id, true),
          throwsArgumentError,
          reason: 'favorite id ${id.length}',
        );
        await expectLater(
          storage.recordComposerCommandUse('scope-a', id),
          throwsArgumentError,
          reason: 'recent id ${id.length}',
        );
      }

      expect(prefs.getString(_key('scope-a')), before);
      expect(
        storage.getComposerCommandPreferences('scope-a').favorites,
        isEmpty,
      );
      expect(storage.getComposerCommandPreferences('scope-a').recent, isEmpty);
    });

    test('an invalid id does not disturb existing entries', () async {
      final storage = await _storage();
      final prefs = await _prefs();
      await storage.setComposerCommandFavorite('scope-a', 'skill:review', true);
      final before = prefs.getString(_key('scope-a'));

      await expectLater(
        storage.setComposerCommandFavorite('scope-a', '', true),
        throwsArgumentError,
      );
      await expectLater(
        storage.recordComposerCommandUse('scope-a', 'bad\u007fid'),
        throwsArgumentError,
      );

      expect(prefs.getString(_key('scope-a')), before);
      expect(storage.getComposerCommandPreferences('scope-a').favorites, {
        'skill:review',
      });
    });
  });

  group('composer command immutability', () {
    test('returned favorites cannot be mutated', () async {
      final storage = await _storage();
      await storage.setComposerCommandFavorite('scope-a', 'skill:review', true);

      final favorites = storage
          .getComposerCommandPreferences('scope-a')
          .favorites;
      expect(() => favorites.add('command:review'), throwsUnsupportedError);
      expect(() => favorites.remove('skill:review'), throwsUnsupportedError);
      expect(favorites, {'skill:review'});
    });

    test('returned recent cannot be mutated', () async {
      final storage = await _storage();
      await storage.recordComposerCommandUse('scope-a', 'skill:review');

      final recent = storage.getComposerCommandPreferences('scope-a').recent;
      expect(() => recent.add('command:review'), throwsUnsupportedError);
      expect(() => recent.removeAt(0), throwsUnsupportedError);
      expect(recent, ['skill:review']);
    });

    test('empty defaults are immutable too', () async {
      final storage = await _storage();

      final preferences = storage.getComposerCommandPreferences('missing');
      expect(() => preferences.favorites.add('x'), throwsUnsupportedError);
      expect(() => preferences.recent.add('x'), throwsUnsupportedError);
    });
  });
}
