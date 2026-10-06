import 'package:flutter/widgets.dart';

/// Explicit language choices; must match generated ARB supported locales.
const appLanguageLocales = <Locale>[
  Locale('en'),
  Locale('zh'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  Locale('ja'),
  Locale('ko'),
  Locale('de'),
  Locale('fr'),
  Locale('es'),
  Locale('pt'),
  Locale('ru'),
  Locale('ar'),
  Locale('hi'),
  Locale('id'),
  Locale('it'),
  Locale('tr'),
  Locale('vi'),
  Locale('th'),
];

Locale? _matchLocale(Locale requested, Iterable<Locale> supported) {
  final candidates = supported
      .where((locale) => locale.languageCode == requested.languageCode)
      .toList(growable: false);
  if (candidates.isEmpty) return null;
  if (requested.languageCode == 'zh') {
    final traditional =
        requested.scriptCode == 'Hant' ||
        (requested.scriptCode == null &&
            const ['TW', 'HK', 'MO'].contains(requested.countryCode));
    final script = traditional ? 'Hant' : 'Hans';
    for (final candidate in candidates) {
      if (candidate.scriptCode == script) return candidate;
    }
    for (final candidate in candidates) {
      if (candidate.scriptCode == null) return candidate;
    }
  }
  for (final candidate in candidates) {
    if (candidate == requested) return candidate;
  }
  return candidates.first;
}

/// Read legacy language-only values and BCP-47/script values without rewriting
/// stored preferences. Missing, invalid and unsupported values follow system.
Locale appLocaleFromStorage(String? raw) {
  if (raw == null || raw.toLowerCase() == 'system') {
    return const Locale('system');
  }
  final match = RegExp(
    r'^([a-zA-Z]{2,3})(?:[-_]([a-zA-Z]{4}))?(?:[-_]([a-zA-Z]{2}|[0-9]{3}))?$',
  ).firstMatch(raw);
  if (match == null) return const Locale('system');
  final script = match[2];
  final requested = Locale.fromSubtags(
    languageCode: match[1]!.toLowerCase(),
    scriptCode: script == null
        ? null
        : '${script[0].toUpperCase()}${script.substring(1).toLowerCase()}',
    countryCode: match[3]?.toUpperCase(),
  );
  return _matchLocale(requested, appLanguageLocales) ?? const Locale('system');
}

String appLocaleToStorage(Locale locale) {
  if (locale.languageCode == 'system') return 'system';
  final supported = _matchLocale(locale, appLanguageLocales);
  if (supported == null) throw ArgumentError.value(locale, 'locale');
  return supported.toLanguageTag();
}

/// System preferences are considered in order, with an explicit English
/// fallback independent of the generator's alphabetical locale ordering.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final requested in preferred ?? const <Locale>[]) {
    final match = _matchLocale(requested, supported);
    if (match != null) return match;
  }
  return _matchLocale(const Locale('en'), supported) ?? supported.first;
}
