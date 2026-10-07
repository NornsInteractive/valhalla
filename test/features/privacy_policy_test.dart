import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:valhalla/features/settings/widgets/about_privacy_card.dart';
import 'package:valhalla/features/settings/widgets/privacy_policy_view.dart';
import 'package:valhalla/features/settings/widgets/license_view.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _WebsiteLauncher extends UrlLauncherPlatform {
  String? url;
  PreferredLaunchMode? mode;
  bool succeed = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    this.url = url;
    mode = options.mode;
    return succeed;
  }
}

Future<void> pumpPrivacy(
  WidgetTester tester,
  Locale locale,
  Widget child,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  );
  await settlePolicy(tester);
}

Future<void> settlePolicy(WidgetTester tester) async {
  // Asset-channel I/O needs real event-loop time in a widget test.
  await tester.runAsync(() async {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Valhalla',
      packageName: 'valhalla',
      version: '1.0.2',
      buildNumber: '3',
      buildSignature: '',
    );
  });

  testWidgets('about card shows actual version and opens bundled policy', (
    tester,
  ) async {
    await pumpPrivacy(
      tester,
      const Locale('en'),
      const SingleChildScrollView(child: AboutPrivacyCard()),
    );
    expect(find.text('v1.0.2 (3)\nNorns Interactive'), findsOneWidget);
    expect(find.text(privacyContactEmail), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('settings_privacy_policy_button')),
    );
    await tester.tap(find.byKey(const Key('settings_privacy_policy_button')));
    await settlePolicy(tester);
    final markdown = tester.widget<Markdown>(find.byType(Markdown));
    expect(markdown.data, contains('Valhalla Privacy Policy'));
    expect(markdown.data, contains(privacyContactEmail));
    expect(markdown.data, isNot(contains('(PRIVACY.md)')));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AboutPrivacyCard), findsOneWidget);
  });

  testWidgets('website uses external browser and reports unavailable handler', (
    tester,
  ) async {
    final previous = UrlLauncherPlatform.instance;
    final launcher = _WebsiteLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    await pumpPrivacy(
      tester,
      const Locale('en'),
      const SingleChildScrollView(child: AboutPrivacyCard()),
    );
    final website = find.byKey(const Key('settings_website_button'));
    await tester.tap(website);
    await tester.pumpAndSettle();
    expect(launcher.url, 'https://norns.cc.cd');
    expect(launcher.mode, PreferredLaunchMode.externalApplication);
    launcher.succeed = false;
    await tester.tap(website);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Unable to open the link. Please open https://norns.cc.cd in your browser.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('license entry displays unmodified bundled LICENSE and NOTICE', (
    tester,
  ) async {
    await pumpPrivacy(
      tester,
      const Locale('zh'),
      const SingleChildScrollView(child: AboutPrivacyCard()),
    );
    await tester.tap(find.byKey(const Key('settings_license_button')));
    await settlePolicy(tester);
    expect(find.byType(LicenseView), findsOneWidget);
    final documents = await tester.runAsync(
      () async => Future.wait([
        rootBundle.loadString('LICENSE'),
        rootBundle.loadString('NOTICE'),
      ]),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('license_full_text'))).data,
      documents![0],
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('license_notice_text'))).data,
      documents[1],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('third-party licenses entry shows the installed app version', (
    tester,
  ) async {
    await pumpPrivacy(
      tester,
      const Locale('en'),
      const SingleChildScrollView(child: AboutPrivacyCard()),
    );
    await tester.tap(
      find.byKey(const Key('settings_third_party_licenses_button')),
    );
    await settlePolicy(tester);
    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text('v1.0.2 (3)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese policy is offline and can switch to English', (
    tester,
  ) async {
    await pumpPrivacy(tester, const Locale('zh'), const PrivacyPolicyView());
    expect(
      tester.widget<Markdown>(find.byType(Markdown)).data,
      contains('Valhalla 隐私政策'),
    );
    expect(
      tester.widget<Markdown>(find.byType(Markdown)).data,
      isNot(contains('(PRIVACY.en.md)')),
    );
    await tester.tap(find.text('English'));
    await settlePolicy(tester);
    expect(
      tester.widget<Markdown>(find.byType(Markdown)).data,
      contains('Valhalla Privacy Policy'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('about card supports a narrow window with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPrivacy(
      tester,
      const Locale('zh'),
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: SingleChildScrollView(child: AboutPrivacyCard()),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
