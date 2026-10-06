import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/localization/app_locales.dart';

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

void main() {
  group('appLanguageLocales', () {
    test('正好 17 个显式语言选择（不含 Follow System）', () {
      expect(appLanguageLocales.length, 17);
      for (final tag in _expectedTags) {
        expect(
          appLanguageLocales.any((locale) => locale.toLanguageTag() == tag),
          isTrue,
          reason: 'catalog must include $tag',
        );
      }
      expect(
        appLanguageLocales.any((l) => l.languageCode == 'system'),
        isFalse,
        reason: 'Follow System 不属于可持久化的显式选择',
      );
    });
  });

  group('appLocaleFromStorage', () {
    test('缺键/ system/ 空字符串等都回系统', () {
      expect(appLocaleFromStorage(null), const Locale('system'));
      expect(appLocaleFromStorage('system'), const Locale('system'));
      expect(appLocaleFromStorage('SYSTEM'), const Locale('system'));
    });

    test('legacy en/zh 值保持可读', () {
      expect(appLocaleFromStorage('en'), const Locale('en'));
      expect(appLocaleFromStorage('zh'), const Locale('zh'));
    });

    test('zh 区域：TW/HK/MO 显式 Hant，CN/SG 简体，无区域回简体', () {
      for (final tag in const ['zh-TW', 'zh_HK', 'zh-MO', 'zh-hant-TW']) {
        final locale = appLocaleFromStorage(tag);
        expect(locale.languageCode, 'zh');
        expect(
          locale.scriptCode,
          'Hant',
          reason: '$tag must resolve Traditional, got $locale',
        );
      }
      for (final tag in const ['zh-CN', 'zh-SG', 'zh', 'zh-Hans']) {
        final locale = appLocaleFromStorage(tag);
        expect(locale.languageCode, 'zh');
        expect(
          locale.scriptCode,
          isNot('Hant'),
          reason: '$tag must stay Simplified, got $locale',
        );
      }
    });

    test('显式 Hant 胜过存储中的其他写法；BCP47 下划线/大小写归一', () {
      final a = appLocaleFromStorage('zh_Hant_TW');
      final b = appLocaleFromStorage('ZH-hant');
      final c = appLocaleFromStorage('zh-Hant-HK');
      for (final l in [a, b, c]) {
        expect(l.scriptCode, 'Hant');
      }
      final pt = appLocaleFromStorage('pt_BR');
      expect(pt.languageCode, 'pt');
      final de = appLocaleFromStorage('DE_de');
      expect(de.languageCode, 'de');
    });

    test('未知/损坏标签回系统而不是抛异常或破坏选项', () {
      expect(appLocaleFromStorage('xx'), const Locale('system'));
      expect(appLocaleFromStorage('klingon'), const Locale('system'));
      expect(appLocaleFromStorage('!!!'), const Locale('system'));
      expect(appLocaleFromStorage('zh!!'), const Locale('system'));
      expect(appLocaleFromStorage('zh--Hant'), const Locale('system'));
    });
  });

  group('appLocaleToStorage', () {
    test('canonical 持久化：zh-Hant 与 legacy en/zh/system', () {
      expect(appLocaleToStorage(const Locale('en')), 'en');
      expect(appLocaleToStorage(const Locale('zh')), 'zh');
      expect(appLocaleToStorage(const Locale('system')), 'system');
      expect(
        appLocaleToStorage(
          Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ),
        'zh-Hant',
      );
      expect(appLocaleToStorage(const Locale('pt', 'BR')), 'pt');
      expect(appLocaleToStorage(const Locale('de', 'DE')), 'de');
    });

    test('不支持的显式 locale 直接拒绝', () {
      expect(() => appLocaleToStorage(const Locale('xx')), throwsArgumentError);
    });
  });

  group('resolveAppLocale', () {
    test('按系统首选顺序匹配：未支持的排在前面也不会漏选后面的支持语言', () {
      expect(
        resolveAppLocale(const [
          Locale('xx'),
          Locale('es'),
        ], appLanguageLocales),
        const Locale('es'),
      );
      expect(
        resolveAppLocale(const [
          Locale('ru'),
          Locale('en'),
        ], appLanguageLocales),
        const Locale('ru'),
      );
    });

    test('空/缺失首选时回 English，而非生成式的字母序首个', () {
      expect(resolveAppLocale(null, appLanguageLocales), const Locale('en'));
      expect(
        resolveAppLocale(const [], appLanguageLocales),
        const Locale('en'),
      );
      expect(
        resolveAppLocale(const [
          Locale('xx'),
          Locale('yy'),
        ], appLanguageLocales),
        const Locale('en'),
      );
    });

    test('不支持 English 时落 supported.first；脚本/区域回 zh-Hant', () {
      expect(
        resolveAppLocale(
          null,
          appLanguageLocales.where((l) => l.languageCode != 'en'),
        ).languageCode,
        'zh',
      );
      expect(
        resolveAppLocale(const [
          Locale('zh', 'TW'),
        ], appLanguageLocales).scriptCode,
        'Hant',
      );
    });
  });
}
