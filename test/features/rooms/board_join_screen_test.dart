import 'package:flutter_test/flutter_test.dart';
import 'package:scoring_rooms/features/rooms/presentation/board_join_screen.dart';
import '../../test_helpers.dart';

void main() {
  testWidgets('shows room code input and join button', (tester) async {
    await tester.pumpWidget(wrapWithApp(const BoardJoinScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Room code'), findsOneWidget);
    expect(find.text('Join Room'), findsOneWidget);
  });
}
