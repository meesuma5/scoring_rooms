import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoring_rooms/features/rooms/providers/room_providers.dart';

void main() {
  group('RoomRepository', () {
    late FakeFirebaseFirestore firestore;
    late RoomRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = RoomRepository(firestore);
    });

    test('createRoom stores room document', () async {
      final roomId = await repository.createRoom(
        creatorUid: 'creator-1',
        maxBoards: 3,
        scoreStep: 2,
      );

      final snapshot = await firestore.collection('rooms').doc(roomId).get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()?['creatorUid'], 'creator-1');
      expect(snapshot.data()?['maxBoards'], 3);
      expect(snapshot.data()?['scoreStep'], 2);
    });

    test('joinWithCode reuses board identity for same device', () async {
      final roomId = await repository.createRoom(
        creatorUid: 'creator-1',
        maxBoards: 3,
        scoreStep: 1,
      );
      final roomCode =
          (await firestore.collection('rooms').doc(roomId).get())
                  .data()!['roomCode']
              as String;

      final first = await repository.joinWithCode(
        roomCode: roomCode,
        deviceKey: 'device-a',
      );
      final second = await repository.joinWithCode(
        roomCode: roomCode,
        deviceKey: 'device-a',
      );

      expect(first.boardId, second.boardId);
      expect(first.boardLabel, second.boardLabel);
    });

    test('same-device rejoin renews moved-out board presence', () async {
      final roomId = await repository.createRoom(
        creatorUid: 'creator-1',
        maxBoards: 3,
        scoreStep: 1,
      );
      final roomCode =
          (await firestore.collection('rooms').doc(roomId).get())
                  .data()!['roomCode']
              as String;

      final first = await repository.joinWithCode(
        roomCode: roomCode,
        deviceKey: 'device-a',
      );

      await firestore
          .collection('rooms')
          .doc(roomId)
          .collection('boards')
          .doc(first.boardId)
          .set({'inRoom': false}, SetOptions(merge: true));

      final second = await repository.joinWithCode(
        roomCode: roomCode,
        deviceKey: 'device-a',
      );

      final boardDoc = await firestore
          .collection('rooms')
          .doc(roomId)
          .collection('boards')
          .doc(second.boardId)
          .get();

      expect(first.boardId, second.boardId);
      expect(boardDoc.data()?['inRoom'], isTrue);
    });

    test('same-device rejoin works after scoring has started', () async {
      final roomId = await repository.createRoom(
        creatorUid: 'creator-1',
        maxBoards: 3,
        scoreStep: 1,
      );
      final roomCode =
          (await firestore.collection('rooms').doc(roomId).get())
                  .data()!['roomCode']
              as String;

      final first = await repository.joinWithCode(
        roomCode: roomCode,
        deviceKey: 'device-a',
      );

      await repository.startScoring(roomId);

      final second = await repository.joinWithCode(
        roomCode: roomCode,
        deviceKey: 'device-a',
      );

      expect(second.roomId, roomId);
      expect(second.boardId, first.boardId);
      expect(second.boardLabel, first.boardLabel);
    });

    test('joinWithCode throws when room is full', () async {
      final roomId = await repository.createRoom(
        creatorUid: 'creator-1',
        maxBoards: 1,
        scoreStep: 1,
      );
      final roomCode =
          (await firestore.collection('rooms').doc(roomId).get())
                  .data()!['roomCode']
              as String;

      await repository.joinWithCode(roomCode: roomCode, deviceKey: 'device-a');

      expect(
        () =>
            repository.joinWithCode(roomCode: roomCode, deviceKey: 'device-b'),
        throwsException,
      );
    });

    test('renameBoard updates board label', () async {
      final roomId = await repository.createRoom(
        creatorUid: 'creator-1',
        maxBoards: 3,
        scoreStep: 1,
      );
      final roomCode =
          (await firestore.collection('rooms').doc(roomId).get())
                  .data()!['roomCode']
              as String;

      final join = await repository.joinWithCode(
        roomCode: roomCode,
        deviceKey: 'device-a',
      );

      await repository.renameBoard(
        roomId: roomId,
        boardId: join.boardId,
        boardLabel: 'Blue Team',
      );

      final boardDoc = await firestore
          .collection('rooms')
          .doc(roomId)
          .collection('boards')
          .doc(join.boardId)
          .get();

      expect(boardDoc.data()?['boardLabel'], 'Blue Team');
    });

    test('adjustScore applies configured score step when started', () async {
      final roomId = await repository.createRoom(
        creatorUid: 'creator-1',
        maxBoards: 3,
        scoreStep: 2,
      );
      final roomCode =
          (await firestore.collection('rooms').doc(roomId).get())
                  .data()!['roomCode']
              as String;

      final join = await repository.joinWithCode(
        roomCode: roomCode,
        deviceKey: 'device-a',
      );

      await repository.startScoring(roomId);
      await repository.adjustScore(
        roomId: roomId,
        boardId: join.boardId,
        direction: 1,
      );

      final boardDoc = await firestore
          .collection('rooms')
          .doc(roomId)
          .collection('boards')
          .doc(join.boardId)
          .get();

      expect(boardDoc.data()?['score'], 2);
    });

    test('pause resume and close update room status', () async {
      final roomId = await repository.createRoom(
        creatorUid: 'creator-1',
        maxBoards: 3,
        scoreStep: 1,
      );

      await repository.startScoring(roomId);
      await repository.pauseScoring(roomId);
      expect(
        (await firestore.collection('rooms').doc(roomId).get())
            .data()?['status'],
        'paused',
      );

      await repository.resumeScoring(roomId);
      expect(
        (await firestore.collection('rooms').doc(roomId).get())
            .data()?['status'],
        'started',
      );

      await repository.closeScoring(roomId);
      final roomData = (await firestore.collection('rooms').doc(roomId).get())
          .data();
      expect(roomData?['status'], 'closed');
      expect(roomData?['elapsedMs'], isA<int>());
    });

    test('continueScoring reopens closed room', () async {
      final roomId = await repository.createRoom(
        creatorUid: 'creator-1',
        maxBoards: 3,
        scoreStep: 1,
      );

      await repository.startScoring(roomId);
      await repository.closeScoring(roomId);

      await repository.continueScoring(roomId);

      final roomData = (await firestore.collection('rooms').doc(roomId).get())
          .data();
      expect(roomData?['status'], 'started');
      expect(roomData?['roomLocked'], isTrue);

      await repository.closeScoring(roomId);
      final closedAgainData =
          (await firestore.collection('rooms').doc(roomId).get()).data();
      expect(closedAgainData?['status'], 'closed');
      expect(closedAgainData?['elapsedMs'], isA<int>());
    });
  });
}
