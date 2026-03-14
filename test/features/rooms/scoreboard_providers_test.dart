import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoring_rooms/features/rooms/providers/scoreboard_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('device key persists across reads', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = await container.read(deviceKeyProvider.future);
    final second = await container.read(deviceKeyProvider.future);

    expect(first, isNotEmpty);
    expect(second, first);
  });

  test('board presence moveOut sets inRoom to false', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('rooms')
        .doc('room-1')
        .collection('boards')
        .doc('board-1')
        .set({'inRoom': true});

    final controller = BoardPresenceController(
      args: const BoardRouteArgs(roomId: 'room-1', boardId: 'board-1'),
      firestore: firestore,
    );

    await controller.moveOut();

    final snapshot = await firestore
        .collection('rooms')
        .doc('room-1')
        .collection('boards')
        .doc('board-1')
        .get();
    expect(snapshot.data()?['inRoom'], isFalse);
  });

  test('BoardViewState.fromMap parses defaults', () {
    final state = BoardViewState.fromMap(null);
    expect(state.boardLabel, 'Board');
    expect(state.score, 0);
    expect(state.inRoom, isTrue);
  });
}
