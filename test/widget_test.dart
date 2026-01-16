// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:app_vinho_taverna/main.dart';
import 'package:app_vinho_taverna/services/wine_service.dart';

void main() {
  testWidgets('App should start with empty wine list', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final wineService = WineService();
    await wineService.init();
    await tester.pumpWidget(MyApp(wineService: wineService));

    // Verify that the app shows empty state
    expect(find.text('Carta dos Vinhos'), findsOneWidget);
    expect(find.text('Nenhum vinho cadastrado'), findsOneWidget);
  });
}
