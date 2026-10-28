import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Successful local writes notify the sync layer; remote hydration suppresses echoes.
class WorkspacePreferences {
  final SharedPreferences raw;
  final _changes = StreamController<String>.broadcast();
  static final _hydrationZone = Object();
  int generation = 0;
  WorkspacePreferences(this.raw);
  Stream<String> get changes => _changes.stream;
  Object? get(String key) => raw.get(key);
  bool containsKey(String key) => raw.containsKey(key);
  Set<String> getKeys() => raw.getKeys();
  String? getString(String key) => raw.getString(key);
  List<String>? getStringList(String key) => raw.getStringList(key);
  bool? getBool(String key) => raw.getBool(key);
  int? getInt(String key) => raw.getInt(key);
  double? getDouble(String key) => raw.getDouble(key);
  Future<void> reload() => raw.reload();
  Future<bool> _write(String key, Future<bool> Function() action) async {
    final remote = Zone.current[_hydrationZone] == true;
    if (!remote) generation++;
    final saved = await action();
    if (saved && !remote) _changes.add(key);
    return saved;
  }

  Future<bool> setString(String key, String value) =>
      _write(key, () => raw.setString(key, value));
  Future<bool> setStringList(String key, List<String> value) =>
      _write(key, () => raw.setStringList(key, value));
  Future<bool> setBool(String key, bool value) =>
      _write(key, () => raw.setBool(key, value));
  Future<bool> setInt(String key, int value) =>
      _write(key, () => raw.setInt(key, value));
  Future<bool> setDouble(String key, double value) =>
      _write(key, () => raw.setDouble(key, value));
  Future<bool> remove(String key) => _write(key, () => raw.remove(key));
  Future<void> hydrate(Future<void> Function() action) async {
    await runZoned(action, zoneValues: {_hydrationZone: true});
  }
}
