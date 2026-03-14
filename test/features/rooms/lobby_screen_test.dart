import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoring_rooms/core/providers/firestore_provider.dart';
import 'package:scoring_rooms/features/rooms/presentation/lobby_screen.dart';

void main() {
  testWidgets('shows joined boards count and start button', (tester) async {
    final firestore = FakeFirebaseFirestore();

    await firestore.collection('rooms').doc('room-1').set({
      'roomCode': 'ABC123',
      'creatorUid': 'creator-1',
      'status': 'open',
      'maxBoards': 4,
      'scoreStep': 1,
      'roomLocked': false,
    });

    await firestore
        .collection('rooms')
        .doc('room-1')
        .collection('boards')
        .doc('b1')
        .set({'boardLabel': 'A', 'score': 0, 'inRoom': true});
    await firestore
        .collection('rooms')
        .doc('room-1')
        .collection('boards')
        .doc('b2')
        .set({'boardLabel': 'B', 'score': 0, 'inRoom': true});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [firestoreProvider.overrideWithValue(firestore)],
        child: const MaterialApp(home: LobbyScreen(roomId: 'room-1')),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Joined Boards: 2/4'), findsOneWidget);
    expect(find.text('Identify Boards'), findsOneWidget);
    expect(find.text('Start Scoring'), findsOneWidget);
  });
}
