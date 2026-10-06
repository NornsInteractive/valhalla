import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Catalog quality policy: every supported locale must ship the same message
/// keys with the same placeholder structure, non-empty messages, no English
/// clone catalogs, and representative UI strings must actually be translated.
///
/// This file is prepped BEFORE the 15-catalog AgY translation lands: most
/// catalog checks below intentionally fail until then. They are file-level
/// assertions, not generator probes, so they fail loudly and not as codegen
/// errors.

const _expectedTags = <String>[
  'en',
  'zh',
  'zh-Hant',
  'ja',
  'ko',
  'de',
  'fr',
  'es',
  'pt',
  'ru',
  'ar',
  'hi',
  'id',
  'it',
  'tr',
  'vi',
  'th',
];

String _catalogPath(String tag) =>
    'lib/l10n/app_${tag.replaceAll('-', '_')}.arb';

/// Documented keys/values allowed to contain the same English text as their EN
/// original. Human-facing prose must never be on this list; these are io-equal
/// technical labels, product names, unit labels, and preset palette identities
/// that every catalog keeps unchanged by contract.
const _allowedMultiWordIdenticalKeys = <String>{
  'agentClaudeCode',
  'agentCodex',
  'agentOpenCode',
  'agentGemini',
  'processCpu',
  'processMem',
  'agentPresetClaudeCode',
  'agentPresetCodex',
  'agentPresetOpenCode',
  'agentPresetAgy',
  'nasQuality4Mbps',
  'nasQuality10Mbps',
  'nasQuality20Mbps',
  'serverHost',
  'agentAcpStatusNa',
  'agentCliStatusError',
  'agentAcpStatusError',
  'hardwareSpecsTitle',
  'networkDownloadRate',
  'networkUploadRate',
  'networkTotalRx',
  'networkTotalTx',
  'accentColorAmoledMode',
  'nasDomain',
  'networkInterface',
  'nasEndpoint',
  'nasMiniPlayer',
  'accentCyberEmerald',
  'accentTechBlue',
  'accentElectricViolet',
  'accentCrimsonRed',
  'accentAmberOrange',
};

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Map<String, Map<String, dynamic>> _allCatalogs() {
  return <String, Map<String, dynamic>>{
    for (final tag in _expectedTags) tag: _read(_catalogPath(tag)),
  };
}

Set<String> _messageKeys(Map<String, dynamic> json) => json.keys
    .where((key) => !key.startsWith('@')) // @@locale and @key metadata
    .toSet();

Set<String> _tokensInMessage(dynamic text) {
  if (text is! String) return const <String>{};
  return RegExp(
    r'\{(\w+)\}',
  ).allMatches(text).map((match) => match.group(1)!).toSet();
}

Set<String> _declaredMetadataNames(Map<String, dynamic> json, String key) {
  final meta = json['@$key'];
  if (meta is! Map) return const <String>{};
  final placeholders = meta['placeholders'];
  if (placeholders is! Map) return const <String>{};
  return placeholders.keys.map((k) => k.toString()).toSet();
}

void main() {
  test('all expected ARB catalogs exist with @@locale', () {
    for (final tag in _expectedTags) {
      final path = _catalogPath(tag);
      expect(File(path).existsSync(), isTrue, reason: '$path missing');
      final json = _read(path);
      expect(json['@@locale'], tag.replaceAll('-', '_'));
    }
  });

  test('every catalog declares exactly the same keys as en', () {
    final catalogs = _allCatalogs();
    final en = _messageKeys(catalogs['en']!);
    expect(en, isNotEmpty);
    for (final tag in _expectedTags) {
      if (tag == 'en') continue;
      final keys = _messageKeys(catalogs[tag]!);
      final missing = en.difference(keys).toList()..sort();
      final extra = keys.difference(en).toList()..sort();
      expect(missing, isEmpty, reason: '$tag missing: $missing');
      expect(extra, isEmpty, reason: '$tag extra: $extra');
    }
  });

  test('placeholder tokens in each locale message match the EN template', () {
    final catalogs = _allCatalogs();
    final en = catalogs['en']!;
    for (final key in _messageKeys(en)) {
      final expected = _tokensInMessage(en[key]);
      for (final tag in _expectedTags) {
        if (tag == 'en') continue;
        expect(
          _tokensInMessage(catalogs[tag]![key]),
          expected,
          reason: '$tag: $key {tokens} must match en',
        );
      }
    }
  });

  test(
    '@metadata placeholder names follow the EN template, explicit or not',
    () {
      // Flutter evaluates placeholders purely from the message text; @metadata
      // entries are optional hints. We require each catalog's explicit metadata
      // names (when present) to be the same set as en's. We intentionally do
      // NOT require every message token to have explicit metadata in every
      // locale: that is not a Flutter rule.
      final catalogs = _allCatalogs();
      final en = catalogs['en']!;
      for (final key in _messageKeys(en)) {
        final templateNames = _declaredMetadataNames(en, key);
        for (final tag in _expectedTags) {
          if (tag == 'en') continue;
          expect(
            _declaredMetadataNames(catalogs[tag]!, key),
            templateNames,
            reason: '$tag: $key @-metadata names must equal en',
          );
        }
      }
    },
  );

  test('every message value in every catalog is a non-empty string', () {
    final catalogs = _allCatalogs();
    for (final tag in _expectedTags) {
      for (final key in _messageKeys(catalogs[tag]!)) {
        final value = catalogs[tag]![key];
        expect(value, isA<String>(), reason: '$tag:$key');
        expect((value as String).trim(), isNotEmpty, reason: '$tag:$key empty');
      }
    }
  });

  // Language autonyms (lang*) may be identical across locales by design: their
  // carrier message is the language's own name. Brand/technical nouns and
  // units that legitimately read the same in every language are listed in
  // _identityLike keys, not silently accepted. Anything else identical to the
  // EN value in a non-EN catalog is evidence of an English clone / untouched
  // copy-paste, and fails. We additionally require that large human-facing
  // multi-word strings have been translated, so simply keeping brand tokens
  // identical cannot satisfy the coverage bar.
  test('no non-en catalog clones English for non-identity messages', () {
    final catalogs = _allCatalogs();
    final en = catalogs['en']!;
    const identityLike = <String>{
      // tokens that are intentionally language-independent brand/technical IDs
      'Valhalla',
      'Codex',
      'Claude',
      'ACP',
      'CLI',
      'SSH',
      'SFTP',
      'Mosh',
      'tmux',
      'NAS',
      'macOS',
      'Linux',
    };
    for (final tag in _expectedTags) {
      if (tag == 'en') continue;
      final json = catalogs[tag]!;
      final offenders = <String>[];
      var eligibleCount = 0;
      var identicalCount = 0;
      for (final key in _messageKeys(json)) {
        if (key.startsWith('lang')) continue;
        final enValue = en[key];
        final value = json[key];
        if (value is! String || enValue is! String) continue;
        eligibleCount++;
        // Genuine identical single lexical tokens — brand/technical markers
        // (Valhalla, Codex, SSH, NAS, tmux), units, and natural short words
        // like "Terminal" — are allowed; whole multi-word UI sentences must be
        // translated before exempt list mention is consulted.
        if (enValue.contains(' ') &&
            value == enValue &&
            !identityLike.contains(enValue.trim()) &&
            !_allowedMultiWordIdenticalKeys.contains(key)) {
          identicalCount++;
          offenders.add(key);
        }
      }
      // Identity-ish exceptions aside, no message may mirror English wholesale.
      expect(
        identicalCount,
        0,
        reason: '$tag identical to EN (non-identity): $offenders',
      );
      expect(eligibleCount, greaterThan(0));
    }
  });

  test('representative human-facing multi-word messages are translated', () {
    const multiWordSampleKeys = <String>[
      'settingsLanguageSaveFailed',
      'selectLanguageTitle',
      'cmdDangerousWarning',
      'settingsExperimentalFeaturesDesc',
      'appSubtitle',
    ];
    final catalogs = _allCatalogs();
    final en = catalogs['en']!;
    for (final key in multiWordSampleKeys) {
      final enValue = en[key];
      expect(enValue, isA<String>());
      expect(
        (enValue as String).contains(' '),
        isTrue,
        reason: '$key should be a multi-word example',
      );
      for (final tag in _expectedTags) {
        if (tag == 'en') continue;
        final value = catalogs[tag]![key];
        expect(value, isA<String>());
        expect(
          value,
          isNot(equals(enValue)),
          reason: '$key in $tag must not equal the EN source',
        );
      }
    }
  });

  test('no pseudo-translation prefixes such as EN:/EN ]/[EN]', () {
    final catalogs = _allCatalogs();
    for (final tag in _expectedTags) {
      if (tag == 'en') continue;
      for (final key in _messageKeys(catalogs[tag]!)) {
        final value = catalogs[tag]![key];
        if (value is! String) continue;
        expect(
          value.trimLeft().startsWith('EN:') ||
              value.trimLeft().startsWith('[EN]') ||
              value.trimLeft().startsWith('EN ]'),
          isFalse,
          reason: '$tag:$key looks like an untranslated copy',
        );
      }
    }
  });

  test('legacy en/zh equality invariant still holds', () {
    final en = _messageKeys(_read(_catalogPath('en')));
    final zh = _messageKeys(_read(_catalogPath('zh')));
    expect(en, isNotEmpty);
    expect(en.difference(zh), isEmpty);
    expect(zh.difference(en), isEmpty);
  });
}
