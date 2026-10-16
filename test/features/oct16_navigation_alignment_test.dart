import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/l10n/app_localizations.dart';

void main() {
  for (final count in [3, 4, 5, 6, 9]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'navigation indicator centers on selected icon: $count / $direction',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(420, 760));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final sections = AppSection.values.take(count).toList();
          final scheme = ColorScheme.fromSeed(seedColor: Colors.green);
          for (final selected in [sections.first, sections.last]) {
            await tester.pumpWidget(
              MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: ThemeData(colorScheme: scheme),
                home: Directionality(
                  textDirection: direction,
                  child: Scaffold(
                    bottomNavigationBar: MainBottomNavigationBar(
                      sections: sections,
                      currentIndex: appSectionToViewIndex(selected),
                      onDestinationSelected: (_) {},
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final item = find.byKey(Key('bottom_nav_item_${selected.name}'));
            final icon = find
                .descendant(of: item, matching: find.byType(Icon))
                .first;
            final markers = find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).color == scheme.primary,
            );
            final marker = markers.evaluate().where((element) {
              final box = element.renderObject;
              return box is RenderBox &&
                  box.hasSize &&
                  box.size.height <= 4 &&
                  box.size.width >= 10;
            }).toList();
            expect(marker, hasLength(1));
            expect(
              tester.getCenter(find.byWidget(marker.single.widget)).dx,
              closeTo(tester.getCenter(icon).dx, .5),
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
