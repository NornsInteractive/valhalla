import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the hard constraint that both ARB files declare the same message keys.
///
/// `flutter gen-l10n` fails when a key exists in only one locale, and the
/// failure surfaces as a confusing codegen error rather than a clear message.
/// Keeping the key sets identical is cheaper to enforce here.
Set<String> _messageKeys(String path) {
  final raw = File(path).readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return json.keys
      .where((key) => !key.startsWith('@')) // @@locale and @key metadata
      .toSet();
}

void main() {
  test('app_en.arb and app_zh.arb declare the same message keys', () {
    const enPath = 'lib/l10n/app_en.arb';
    const zhPath = 'lib/l10n/app_zh.arb';

    final en = _messageKeys(enPath);
    final zh = _messageKeys(zhPath);

    expect(en, isNotEmpty, reason: '$enPath should declare messages');

    final missingInZh = en.difference(zh).toList()..sort();
    final missingInEn = zh.difference(en).toList()..sort();

    expect(
      missingInZh,
      isEmpty,
      reason: 'These keys exist in app_en.arb but not app_zh.arb: $missingInZh',
    );
    expect(
      missingInEn,
      isEmpty,
      reason: 'These keys exist in app_zh.arb but not app_en.arb: $missingInEn',
    );
  });

  test('every placeholder declared in the template exists in every locale', () {
    Map<String, dynamic> read(String path) =>
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

    Set<String> placeholderKeys(Map<String, dynamic> arb) => arb.keys
        .where((k) => k.startsWith('@') && arb[k] is Map)
        .where((k) => (arb[k] as Map).containsKey('placeholders'))
        .map((k) => k.substring(1))
        .toSet();

    final en = read('lib/l10n/app_en.arb');
    final zh = read('lib/l10n/app_zh.arb');

    // app_en.arb is the template, so anything it declares must also be
    // satisfied by the other locale. Extra metadata in a locale is harmless.
    final missingInZh = placeholderKeys(en).difference(placeholderKeys(zh));

    expect(
      missingInZh,
      isEmpty,
      reason:
          'These messages declare {placeholders} in the template (app_en.arb) '
          'but have no @-metadata in app_zh.arb: ${missingInZh.toList()..sort()}',
    );
  });
}
