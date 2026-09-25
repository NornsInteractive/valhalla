import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valhalla/main.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

void main() {
  testWidgets('Valhalla smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final local = await LocalStorageService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWithValue(local)],
        child: const ValhallaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ValhallaApp), findsOneWidget);
  });
}
