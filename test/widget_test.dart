import 'package:flutter_test/flutter_test.dart';

import 'package:scoring_rooms/main.dart';

void main() {
  testWidgets('Shows firebase setup required by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Firebase Setup Required'), findsOneWidget);
    expect(find.textContaining('Firebase is not initialized'), findsOneWidget);
  });
}
