import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoring_rooms/features/auth/providers/auth_providers.dart';
import 'package:scoring_rooms/features/rooms/models/room.dart';
import 'package:scoring_rooms/features/rooms/presentation/creator_home_screen.dart';
import 'package:scoring_rooms/features/rooms/presentation/lobby_screen.dart';
import 'package:scoring_rooms/features/rooms/providers/room_providers.dart';

void main() {
  testWidgets('shows create room action and created rooms list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final user = MockUser(uid: 'u1', email: 'creator@test.com');
    final rooms = [
      const Room(
        roomId: 'r1',
        roomCode: 'ABC123',
        creatorUid: 'u1',
        status: 'open',
        maxBoards: 4,
        scoreStep: 1,
        roomLocked: false,
        elapsedMs: 0,
        identifyUntilMs: 0,
      ),
      const Room(
        roomId: 'r2',
        roomCode: 'DEF456',
        creatorUid: 'u1',
        status: 'started',
        maxBoards: 4,
        scoreStep: 1,
        roomLocked: true,
        elapsedMs: 0,
        identifyUntilMs: 0,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          creatorRoomsProvider('u1').overrideWith((ref) => Stream.value(rooms)),
        ],
        child: const MaterialApp(home: CreatorHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Room'), findsOneWidget);
    expect(find.text('creator@test.com'), findsOneWidget);
    expect(find.text('Your Rooms'), findsOneWidget);
    expect(find.text('Code: ABC123'), findsOneWidget);
    expect(find.text('Code: DEF456'), findsOneWidget);
  });

  testWidgets('tapping a room card opens that room screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final user = MockUser(uid: 'u1', email: 'creator@test.com');
    const room = Room(
      roomId: 'r1',
      roomCode: 'ABC123',
      creatorUid: 'u1',
      status: 'open',
      maxBoards: 4,
      scoreStep: 1,
      roomLocked: false,
      elapsedMs: 0,
      identifyUntilMs: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          creatorRoomsProvider(
            'u1',
          ).overrideWith((ref) => Stream.value([room])),
          roomStreamProvider('r1').overrideWith((ref) => Stream.value(room)),
          roomBoardsProvider('r1').overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(home: CreatorHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Code: ABC123'));
    await tester.pumpAndSettle();

    expect(find.byType(LobbyScreen), findsOneWidget);
  });
}
