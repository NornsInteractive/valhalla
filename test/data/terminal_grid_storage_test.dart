import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/terminal_accessory_layout.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

const _keyV1 = 'valhalla_terminal_grid_v1';
const _keyV2 = 'valhalla_terminal_grid_v2';

String _layoutJson({List<AccessoryItem>? items, int pages = 1}) => jsonEncode(
  TerminalAccessoryLayout(
    items: items ?? [AccessoryItem(id: 'a', l: 'Tab')],
    pages: pages,
  ).toJson(),
);

final _validV2 = _layoutJson();
final _validV1 = jsonEncode({'schemaVersion': 1, 'items': <dynamic>[]});

Future<LocalStorageService> _storage({
  Map<String, Object> raw = const {},
}) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(raw));
  return LocalStorageService(await SharedPreferences.getInstance());
}

class RejectingPrefs extends Fake implements SharedPreferences {
  RejectingPrefs(this.delegate);
  final SharedPreferences delegate;
  @override
  Object? get(String key) => delegate.get(key);
  @override
  Future<bool> setString(String key, String value) async => false;
  @override
  Future<void> reload() => delegate.reload();
}

void main() {
  group('terminal grid storage', () {
    test('save writes v2 only and preserves existing v1', () async {
      final storage = await _storage(raw: {_keyV1: _validV1});
      await storage.setTerminalGridConfig(_validV2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_keyV2), jsonEncode(jsonDecode(_validV2)));
      expect(prefs.getString(_keyV1), _validV1);
    });

    test('valid v2 is preferred over valid v1', () async {
      final storage = await _storage(raw: {_keyV1: _validV1, _keyV2: _validV2});
      expect(storage.getTerminalGridConfig(), jsonEncode(jsonDecode(_validV2)));
      expect(storage.getTerminalGridConfigError(), isNull);
    });

    test('bad v2 falls back to valid v1 and reports invalid', () async {
      final storage = await _storage(
        raw: {_keyV1: _validV1, _keyV2: '{not-json'},
      );
      expect(storage.getTerminalGridConfig(), _validV1);
      expect(storage.getTerminalGridConfigError(), 'TERMINAL_GRID_INVALID');
    });

    test('all corrupt records yield null and no write', () async {
      final storage = await _storage(
        raw: {_keyV1: 'nope', _keyV2: '{"schemaVersion":9,"items":[]}'},
      );
      expect(storage.getTerminalGridConfig(), isNull);
      expect(storage.getTerminalGridConfigError(), 'TERMINAL_GRID_INVALID');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_keyV1), 'nope');
      expect(prefs.getString(_keyV2), '{"schemaVersion":9,"items":[]}');
    });

    test('explicit empty layout round-trips', () async {
      final empty = _layoutJson(items: const [], pages: 1);
      final storage = await _storage();
      await storage.setTerminalGridConfig(empty);
      expect(storage.getTerminalGridConfig(), jsonEncode(jsonDecode(empty)));
      expect(storage.getTerminalGridConfigError(), isNull);
    });

    test('invalid JSON and colliding items are rejected on save', () async {
      final storage = await _storage();
      await expectLater(
        storage.setTerminalGridConfig('{broken'),
        throwsA(isA<FormatException>()),
      );
      final colliding = _layoutJson(
        items: [
          AccessoryItem(id: 'a', l: 'Tab'),
          AccessoryItem(id: 'b', l: 'Esc'),
        ],
      );
      await expectLater(
        storage.setTerminalGridConfig(colliding),
        throwsA(isA<FormatException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_keyV2), isNull);
    });

    test('failed atomic write throws and reloads', () async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final rejecting = LocalStorageService(RejectingPrefs(prefs));
      await expectLater(
        rejecting.setTerminalGridConfig(_validV2),
        throwsA(isA<StateError>()),
      );
      expect(prefs.getString(_keyV2), isNull);
    });

    test('configuration whitelist carries both grid keys as strings', () {
      final types = LocalStorageService.configurationPreferenceTypes;
      expect(types[_keyV1], 'string');
      expect(types[_keyV2], 'string');
    });
  });
}
