import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoring_rooms/core/providers/firestore_provider.dart';
import 'package:scoring_rooms/features/rooms/presentation/creator_scoring_screen.dart';

void main() {
  testWidgets('shows scoring controls and updates score', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final firestore = FakeFirebaseFirestore();

    await firestore.collection('rooms').doc('room-1').set({
      'roomCode': 'ABC123',
      'creatorUid': 'creator-1',
      'status': 'started',
      'maxBoards': 4,
      'scoreStep': 2,
      'roomLocked': true,
    });

    await firestore
        .collection('rooms')
        .doc('room-1')
        .collection('boards')
        .doc('b1')
        .set({'boardLabel': 'A', 'score': 0, 'inRoom': true});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [firestoreProvider.overrideWithValue(firestore)],
        child: const MaterialApp(home: CreatorScoringScreen(roomId: 'room-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Status: STARTED'), findsOneWidget);
    expect(find.text('Hide Scores'), findsOneWidget);
    expect(find.text('Close Scoring'), findsOneWidget);

    final incrementButton = find.byIcon(Icons.add_circle_outline).first;
    await tester.ensureVisible(incrementButton);
    await tester.tap(incrementButton);
    await tester.pumpAndSettle();

    final boardDoc = await firestore
        .collection('rooms')
        .doc('room-1')
        .collection('boards')
        .doc('b1')
        .get();
    expect(boardDoc.data()?['score'], 2);
  });
}
