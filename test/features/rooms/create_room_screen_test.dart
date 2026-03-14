import 'package:flutter_test/flutter_test.dart';
import 'package:scoring_rooms/features/rooms/presentation/create_room_screen.dart';
import '../../test_helpers.dart';

void main() {
  testWidgets('shows create room form fields', (tester) async {
    await tester.pumpWidget(wrapWithApp(const CreateRoomScreen()));

    expect(find.text('Max boards'), findsOneWidget);
    expect(find.text('Score step'), findsOneWidget);
    expect(find.text('Create Room'), findsOneWidget);
  });
}
