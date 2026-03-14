import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoring_rooms/core/providers/firestore_provider.dart';
import 'package:scoring_rooms/features/rooms/presentation/final_results_screen.dart';

void main() {
  testWidgets('shows sorted final rankings with elapsed time', (tester) async {
    final firestore = FakeFirebaseFirestore();

    await firestore.collection('rooms').doc('room-1').set({
      'roomCode': '',
      'creatorUid': 'creator-1',
      'status': 'closed',
      'maxBoards': 4,
      'scoreStep': 1,
      'roomLocked': true,
      'elapsedMs': 125000,
    });

    await firestore
        .collection('rooms')
        .doc('room-1')
        .collection('boards')
        .doc('b1')
        .set({'boardLabel': 'A', 'score': 4, 'inRoom': true});
    await firestore
        .collection('rooms')
        .doc('room-1')
        .collection('boards')
        .doc('b2')
        .set({'boardLabel': 'B', 'score': 9, 'inRoom': true});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [firestoreProvider.overrideWithValue(firestore)],
        child: const MaterialApp(home: FinalResultsScreen(roomId: 'room-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Elapsed: 02:05'), findsOneWidget);
    expect(find.text('Continue Session'), findsOneWidget);
    expect(find.text('Board B'), findsOneWidget);
    expect(find.text('Board A'), findsOneWidget);

    final listTiles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .toList();
    final firstTitle = listTiles.first.title as Text;
    expect(firstTitle.data, 'Board B');
  });
}
