import 'package:flutter_test/flutter_test.dart';
import 'package:scoring_rooms/features/startup/startup_screen.dart';
import '../../test_helpers.dart';

void main() {
  testWidgets('shows both startup options', (tester) async {
    await tester.pumpWidget(wrapWithApp(const StartupScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Login / Sign-up with Google'), findsOneWidget);
    expect(find.text('Join a Room'), findsOneWidget);
  });
}
