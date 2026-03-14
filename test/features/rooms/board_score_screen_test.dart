import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoring_rooms/core/providers/firestore_provider.dart';
import 'package:scoring_rooms/features/rooms/models/room.dart';
import 'package:scoring_rooms/features/rooms/presentation/board_score_screen.dart';
import 'package:scoring_rooms/features/rooms/providers/room_providers.dart';
import 'package:scoring_rooms/features/rooms/providers/scoreboard_providers.dart';

void main() {
  testWidgets('shows full-screen score without visible move-out button', (
    tester,
  ) async {
    const args = BoardRouteArgs(roomId: 'room-1', boardId: 'board-1');
    const room = Room(
      roomId: 'room-1',
      roomCode: 'ABC123',
      creatorUid: 'creator-1',
      status: 'started',
      maxBoards: 4,
      scoreStep: 1,
      roomLocked: true,
      elapsedMs: 0,
      identifyUntilMs: 0,
    );
    final firestore = FakeFirebaseFirestore();
    final controller = BoardPresenceController(
      args: args,
      firestore: firestore,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          boardViewProvider(args).overrideWith(
            (ref) => Stream.value(
              const BoardViewState(
                boardLabel: 'A',
                score: 9,
                inRoom: true,
                timerStatus: 'idle',
                timerDurationMs: 0,
                timerEndAtMs: 0,
                timerRemainingMs: 0,
              ),
            ),
          ),
          roomStreamProvider(
            'room-1',
          ).overrideWith((ref) => Stream.value(room)),
          boardPresenceControllerProvider(args).overrideWithValue(controller),
        ],
        child: const MaterialApp(
          home: BoardScoreScreen(
            roomId: 'room-1',
            boardId: 'board-1',
            boardLabel: 'A',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('9'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(find.text('Move out of room'), findsNothing);
  });

  testWidgets('shows identify popup in pre-scoring state', (tester) async {
    const args = BoardRouteArgs(roomId: 'room-2', boardId: 'board-2');
    final room = Room(
      roomId: 'room-2',
      roomCode: 'XYZ999',
      creatorUid: 'creator-1',
      status: 'open',
      maxBoards: 4,
      scoreStep: 1,
      roomLocked: false,
      elapsedMs: 0,
      identifyUntilMs:
          DateTime.now().millisecondsSinceEpoch +
          const Duration(seconds: 2).inMilliseconds,
    );
    final firestore = FakeFirebaseFirestore();
    final controller = BoardPresenceController(
      args: args,
      firestore: firestore,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          boardViewProvider(args).overrideWith(
            (ref) => Stream.value(
              const BoardViewState(
                boardLabel: 'A',
                score: 0,
                inRoom: true,
                timerStatus: 'idle',
                timerDurationMs: 0,
                timerEndAtMs: 0,
                timerRemainingMs: 0,
              ),
            ),
          ),
          roomStreamProvider(
            'room-2',
          ).overrideWith((ref) => Stream.value(room)),
          boardPresenceControllerProvider(args).overrideWithValue(controller),
        ],
        child: const MaterialApp(
          home: BoardScoreScreen(
            roomId: 'room-2',
            boardId: 'board-2',
            boardLabel: 'A',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('hides score text in scoring state when hideScores is enabled', (
    tester,
  ) async {
    const args = BoardRouteArgs(roomId: 'room-3', boardId: 'board-3');
    const room = Room(
      roomId: 'room-3',
      roomCode: 'HIDE01',
      creatorUid: 'creator-1',
      status: 'started',
      maxBoards: 4,
      scoreStep: 1,
      roomLocked: true,
      elapsedMs: 0,
      identifyUntilMs: 0,
      hideScores: true,
    );
    final firestore = FakeFirebaseFirestore();
    final controller = BoardPresenceController(
      args: args,
      firestore: firestore,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          boardViewProvider(args).overrideWith(
            (ref) => Stream.value(
              const BoardViewState(
                boardLabel: 'A',
                score: 9,
                inRoom: true,
                timerStatus: 'idle',
                timerDurationMs: 0,
                timerEndAtMs: 0,
                timerRemainingMs: 0,
              ),
            ),
          ),
          roomStreamProvider(
            'room-3',
          ).overrideWith((ref) => Stream.value(room)),
          boardPresenceControllerProvider(args).overrideWithValue(controller),
        ],
        child: const MaterialApp(
          home: BoardScoreScreen(
            roomId: 'room-3',
            boardId: 'board-3',
            boardLabel: 'A',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('9'), findsNothing);
  });
}
