import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_rooms/core/providers/firestore_provider.dart';
import 'package:scoring_rooms/features/auth/providers/auth_providers.dart';
import 'package:scoring_rooms/features/rooms/models/board_participant.dart';
import 'package:scoring_rooms/features/rooms/models/room.dart';
import 'package:scoring_rooms/features/rooms/providers/scoreboard_providers.dart';
import 'package:uuid/uuid.dart';

const _enableJoinLogs = true;

void _joinLog(String message) {
  if (!_enableJoinLogs) return;
  developer.log(message, name: 'rooms.join');
}

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository(ref.watch(firestoreProvider));
});

final boardJoinControllerProvider =
    AsyncNotifierProvider<BoardJoinController, void>(BoardJoinController.new);

final createRoomControllerProvider =
    AsyncNotifierProvider<CreateRoomController, void>(CreateRoomController.new);

final roomStreamProvider = StreamProvider.family<Room, String>((ref, roomId) {
  return ref
      .watch(firestoreProvider)
      .collection('rooms')
      .doc(roomId)
      .snapshots()
      .map((snapshot) => Room.fromMap(snapshot.id, snapshot.data() ?? {}));
});

final creatorRoomsProvider = StreamProvider.family<List<Room>, String>((
  ref,
  creatorUid,
) {
  return ref
      .watch(firestoreProvider)
      .collection('rooms')
      .where('creatorUid', isEqualTo: creatorUid)
      .snapshots()
      .map((query) {
        final rooms = query.docs
            .map((doc) => Room.fromMap(doc.id, doc.data()))
            .toList();
        rooms.sort((a, b) => b.roomId.compareTo(a.roomId));
        return rooms;
      });
});

final roomBoardsProvider =
    StreamProvider.family<List<BoardParticipant>, String>((ref, roomId) {
      return ref
          .watch(firestoreProvider)
          .collection('rooms')
          .doc(roomId)
          .collection('boards')
          .snapshots()
          .map(
            (query) => query.docs
                .map((doc) => BoardParticipant.fromMap(doc.id, doc.data()))
                .toList(),
          );
    });

final lobbyControllerProvider = Provider.family<LobbyController, String>((
  ref,
  roomId,
) {
  return LobbyController(
    roomId: roomId,
    repository: ref.watch(roomRepositoryProvider),
  );
});

final creatorScoringControllerProvider =
    Provider.family<CreatorScoringController, String>((ref, roomId) {
      return CreatorScoringController(
        roomId: roomId,
        repository: ref.watch(roomRepositoryProvider),
      );
    });

class RoomJoinResult {
  const RoomJoinResult({
    required this.roomId,
    required this.boardId,
    required this.boardLabel,
  });

  final String roomId;
  final String boardId;
  final String boardLabel;
}

class RoomRepository {
  RoomRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<String> createRoom({
    required String creatorUid,
    required int maxBoards,
    required int scoreStep,
  }) async {
    final roomId = const Uuid().v4();
    final roomCode = const Uuid().v4().substring(0, 6).toUpperCase();

    _joinLog(
      'createRoom start creatorUid=$creatorUid roomId=$roomId roomCode=$roomCode maxBoards=$maxBoards scoreStep=$scoreStep',
    );

    await _firestore.collection('rooms').doc(roomId).set({
      'roomId': roomId,
      'roomCode': roomCode,
      'creatorUid': creatorUid,
      'status': 'open',
      'maxBoards': maxBoards,
      'scoreStep': scoreStep,
      'roomLocked': false,
      'identifyUntilMs': 0,
      'boardBrightness': 1.0,
      'hideScores': false,
      'timerStatus': 'idle',
      'timerDurationMs': 0,
      'timerEndAtMs': 0,
      'timerRemainingMs': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });

    _joinLog('createRoom success roomId=$roomId roomCode=$roomCode');

    return roomId;
  }

  Future<RoomJoinResult> joinWithCode({
    required String roomCode,
    required String deviceKey,
  }) async {
    final normalizedCode = roomCode.trim().toUpperCase();
    _joinLog(
      'joinWithCode start input=$roomCode normalized=$normalizedCode deviceKey=$deviceKey',
    );

    final rooms = await _firestore
        .collection('rooms')
        .where('roomCode', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    _joinLog('joinWithCode query resultCount=${rooms.docs.length}');

    if (rooms.docs.isEmpty) {
      _joinLog('joinWithCode no room matched code=$normalizedCode');
      throw Exception(
        'Room not found for this code. Check the code and make sure the room is still open for joining.',
      );
    }

    final roomDoc = rooms.docs.first;
    final roomId = roomDoc.id;
    final roomData = roomDoc.data();

    final status = (roomData['status'] as String?) ?? 'open';
    final maxBoards = (roomData['maxBoards'] as num?)?.toInt() ?? 0;
    final roomLocked = roomData['roomLocked'] as bool? ?? false;

    final boardLinksCollection = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boardLinks');
    final boardCollection = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards');

    final existingLinkDoc = await boardLinksCollection.doc(deviceKey).get();
    if (existingLinkDoc.exists) {
      final linkedBoardId = existingLinkDoc.data()?['boardId'] as String?;
      if (linkedBoardId != null) {
        await boardCollection.doc(linkedBoardId).set({
          'inRoom': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final boardDoc = await boardCollection.doc(linkedBoardId).get();
        final boardLabel =
            (boardDoc.data()?['boardLabel'] as String?) ?? 'Board';
        _joinLog(
          'joinWithCode reused board roomId=$roomId boardId=$linkedBoardId boardLabel=$boardLabel status=$status roomLocked=$roomLocked',
        );
        return RoomJoinResult(
          roomId: roomId,
          boardId: linkedBoardId,
          boardLabel: boardLabel,
        );
      }
    }

    _joinLog(
      'joinWithCode matched roomId=$roomId status=$status roomLocked=$roomLocked maxBoards=$maxBoards',
    );

    if (status != 'open' || roomLocked) {
      _joinLog('joinWithCode room not joinable roomId=$roomId');
      throw Exception('Room is not joinable.');
    }

    final existingBoards = await boardCollection.get();
    _joinLog(
      'joinWithCode existing boards count=${existingBoards.docs.length} maxBoards=$maxBoards',
    );

    if (maxBoards > 0 && existingBoards.docs.length >= maxBoards) {
      _joinLog('joinWithCode room full roomId=$roomId');
      throw Exception('Room is full.');
    }

    final boardIndex = existingBoards.docs.length;
    final boardLabel = String.fromCharCode(65 + boardIndex);
    final boardId = const Uuid().v4();

    await boardCollection.doc(boardId).set({
      'boardId': boardId,
      'boardLabel': boardLabel,
      'score': 0,
      'inRoom': true,
      'brightnessManaged': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'joinedAt': FieldValue.serverTimestamp(),
      'deviceKey': deviceKey,
    });

    await boardLinksCollection.doc(deviceKey).set({
      'boardId': boardId,
      'boardLabel': boardLabel,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _joinLog(
      'joinWithCode new board assigned roomId=$roomId boardId=$boardId boardLabel=$boardLabel',
    );

    return RoomJoinResult(
      roomId: roomId,
      boardId: boardId,
      boardLabel: boardLabel,
    );
  }

  Future<void> removeBoard({
    required String roomId,
    required String boardId,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId)
        .delete();
  }

  Future<void> renameBoard({
    required String roomId,
    required String boardId,
    required String boardLabel,
  }) async {
    final normalizedLabel = boardLabel.trim();
    if (normalizedLabel.isEmpty) {
      throw Exception('Board name cannot be empty.');
    }

    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId)
        .set({
          'boardLabel': normalizedLabel,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> startScoring(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).set({
      'status': 'started',
      'roomLocked': true,
      'identifyUntilMs': 0,
      'hideScores': false,
      'timerStatus': 'idle',
      'timerDurationMs': 0,
      'timerEndAtMs': 0,
      'timerRemainingMs': 0,
      'startedAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> pauseScoring(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).set({
      'status': 'paused',
      'lastActivityAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> resumeScoring(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).set({
      'status': 'started',
      'lastActivityAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> adjustScore({
    required String roomId,
    required String boardId,
    required int direction,
  }) async {
    final roomSnapshot = await _firestore.collection('rooms').doc(roomId).get();
    final roomData = roomSnapshot.data();
    if (roomData == null) {
      throw Exception('Room not found.');
    }

    final status = (roomData['status'] as String?) ?? 'open';
    if (status != 'started' && status != 'paused') {
      throw Exception('Scoring is not active.');
    }

    final scoreStep = (roomData['scoreStep'] as num?)?.toInt() ?? 1;
    final delta = scoreStep * direction;

    final boardRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId);

    await _firestore.runTransaction((transaction) async {
      final boardDoc = await transaction.get(boardRef);
      final currentScore = (boardDoc.data()?['score'] as num?)?.toInt() ?? 0;
      final nextScore = currentScore + delta;
      transaction.set(boardRef, {
        'score': nextScore,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> setBoardScore({
    required String roomId,
    required String boardId,
    required int score,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId)
        .set({
          'score': score,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> closeScoring(String roomId) async {
    final roomSnapshot = await _firestore.collection('rooms').doc(roomId).get();
    final roomData = roomSnapshot.data() ?? {};
    final startedAt = roomData['startedAt'];
    final previousElapsedMs = (roomData['elapsedMs'] as num?)?.toInt() ?? 0;

    int elapsedMs = previousElapsedMs;
    if (startedAt is Timestamp) {
      elapsedMs += DateTime.now().difference(startedAt.toDate()).inMilliseconds;
    }

    await _firestore.collection('rooms').doc(roomId).set({
      'status': 'closed',
      'closedAt': FieldValue.serverTimestamp(),
      'elapsedMs': elapsedMs,
      'timerStatus': 'idle',
      'timerDurationMs': 0,
      'timerEndAtMs': 0,
      'timerRemainingMs': 0,
      'lastActivityAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> continueScoring(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).set({
      'status': 'started',
      'roomLocked': true,
      'identifyUntilMs': 0,
      'hideScores': false,
      'timerStatus': 'idle',
      'timerDurationMs': 0,
      'timerEndAtMs': 0,
      'timerRemainingMs': 0,
      'startedAt': FieldValue.serverTimestamp(),
      'closedAt': FieldValue.delete(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> startBoardTimer({
    required String roomId,
    required String boardId,
    required int durationMs,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId)
        .set({
          'timerStatus': 'running',
          'timerDurationMs': durationMs,
          'timerRunDurationMs': durationMs,
          'timerRemainingMs': durationMs,
          'timerStartedAtMs': nowMs,
          'timerEndAtMs': nowMs + durationMs,
          'timerEndedAtMs': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> pauseBoardTimer({
    required String roomId,
    required String boardId,
  }) async {
    final boardSnapshot = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId)
        .get();
    final boardData = boardSnapshot.data() ?? {};
    final timerStatus = (boardData['timerStatus'] as String?) ?? 'idle';
    if (timerStatus != 'running') return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final timerEndAtMs = (boardData['timerEndAtMs'] as num?)?.toInt() ?? 0;
    final timerStartedAtMs =
        (boardData['timerStartedAtMs'] as num?)?.toInt() ?? 0;
    final timerRunDurationMs =
        (boardData['timerRunDurationMs'] as num?)?.toInt() ?? 0;
    final calculatedEndAtMs = timerStartedAtMs > 0 && timerRunDurationMs > 0
        ? timerStartedAtMs + timerRunDurationMs
        : timerEndAtMs;
    final remainingMs = calculatedEndAtMs > 0 ? (calculatedEndAtMs - nowMs) : 0;

    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId)
        .set({
          'timerStatus': 'paused',
          'timerRemainingMs': remainingMs < 0 ? 0 : remainingMs,
          'timerRunDurationMs': 0,
          'timerStartedAtMs': 0,
          'timerEndAtMs': 0,
          'timerEndedAtMs': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> restartBoardTimer({
    required String roomId,
    required String boardId,
  }) async {
    final boardSnapshot = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId)
        .get();
    final boardData = boardSnapshot.data() ?? {};
    final durationMs = (boardData['timerDurationMs'] as num?)?.toInt() ?? 0;
    if (durationMs <= 0) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId)
        .set({
          'timerStatus': 'running',
          'timerRemainingMs': durationMs,
          'timerRunDurationMs': durationMs,
          'timerStartedAtMs': nowMs,
          'timerEndAtMs': nowMs + durationMs,
          'timerEndedAtMs': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> continueBoardTimer({
    required String roomId,
    required String boardId,
  }) async {
    final boardSnapshot = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId)
        .get();
    final boardData = boardSnapshot.data() ?? {};
    final timerStatus = (boardData['timerStatus'] as String?) ?? 'idle';
    if (timerStatus != 'paused') return;

    final remainingMs = (boardData['timerRemainingMs'] as num?)?.toInt() ?? 0;
    if (remainingMs <= 0) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId)
        .set({
          'timerStatus': 'running',
          'timerRunDurationMs': remainingMs,
          'timerStartedAtMs': nowMs,
          'timerEndAtMs': nowMs + remainingMs,
          'timerEndedAtMs': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> endBoardTimer({
    required String roomId,
    required String boardId,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId)
        .set({
          'timerStatus': 'idle',
          'timerRemainingMs': 0,
          'timerRunDurationMs': 0,
          'timerStartedAtMs': 0,
          'timerEndAtMs': 0,
          'timerEndedAtMs': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> completeBoardTimerIfElapsed({
    required String roomId,
    required String boardId,
    int? nowMs,
  }) async {
    final boardRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(boardRef);
      final boardData = snapshot.data() ?? {};
      final timerStatus = (boardData['timerStatus'] as String?) ?? 'idle';
      final timerEndAtMs = (boardData['timerEndAtMs'] as num?)?.toInt() ?? 0;
      if (timerStatus != 'running' || timerEndAtMs <= 0) {
        return;
      }

      final effectiveNowMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      if (timerEndAtMs > effectiveNowMs) {
        return;
      }

      transaction.set(boardRef, {
        'timerStatus': 'ended',
        'timerRemainingMs': 0,
        'timerRunDurationMs': 0,
        'timerStartedAtMs': 0,
        'timerEndAtMs': 0,
        'timerEndedAtMs': effectiveNowMs,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> resetEndedBoardTimerIfExpired({
    required String roomId,
    required String boardId,
    required int expiredBeforeMs,
  }) async {
    final boardRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(boardRef);
      final boardData = snapshot.data() ?? {};
      final timerStatus = (boardData['timerStatus'] as String?) ?? 'idle';
      final timerEndedAtMs =
          (boardData['timerEndedAtMs'] as num?)?.toInt() ?? 0;
      if (timerStatus != 'ended' || timerEndedAtMs <= 0) {
        return;
      }
      if (timerEndedAtMs > expiredBeforeMs) {
        return;
      }

      transaction.set(boardRef, {
        'timerStatus': 'idle',
        'timerRemainingMs': 0,
        'timerRunDurationMs': 0,
        'timerStartedAtMs': 0,
        'timerEndAtMs': 0,
        'timerEndedAtMs': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> identifyBoards(String roomId) async {
    final identifyUntilMs =
        DateTime.now().millisecondsSinceEpoch +
        const Duration(seconds: 2).inMilliseconds;
    await _firestore.collection('rooms').doc(roomId).set({
      'identifyUntilMs': identifyUntilMs,
      'lastActivityAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setHideScores({
    required String roomId,
    required bool hideScores,
  }) async {
    await _firestore.collection('rooms').doc(roomId).set({
      'hideScores': hideScores,
      'lastActivityAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setBoardBrightness({
    required String roomId,
    required double brightness,
  }) async {
    final clamped = brightness.clamp(0.05, 1.0) as double;
    await _firestore.collection('rooms').doc(roomId).set({
      'boardBrightness': clamped,
      'lastActivityAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setBoardBrightnessManaged({
    required String roomId,
    required String boardId,
    required bool managed,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('boards')
        .doc(boardId)
        .set({
          'brightnessManaged': managed,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}

class BoardJoinController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<RoomJoinResult> joinRoom(String roomCode) async {
    final normalizedRoomCode = roomCode.trim();
    _joinLog(
      'joinRoom controller start raw=$roomCode normalized=$normalizedRoomCode',
    );

    if (normalizedRoomCode.isEmpty) {
      _joinLog('joinRoom controller empty code');
      throw Exception('Please enter a room code.');
    }

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      ref.invalidate(deviceKeyProvider);
      final deviceKey = await ref.read(deviceKeyProvider.future);
      _joinLog('joinRoom controller got deviceKey=$deviceKey');
      return ref
          .read(roomRepositoryProvider)
          .joinWithCode(roomCode: normalizedRoomCode, deviceKey: deviceKey);
    });

    state = result.when(
      data: (_) => const AsyncData(null),
      error: (error, stackTrace) => AsyncError(error, stackTrace),
      loading: () => const AsyncLoading(),
    );

    return result.when(
      data: (value) {
        _joinLog(
          'joinRoom controller success roomId=${value.roomId} boardId=${value.boardId} boardLabel=${value.boardLabel}',
        );
        return value;
      },
      loading: () {
        _joinLog('joinRoom controller still loading unexpectedly');
        throw Exception('Joining room...');
      },
      error: (error, _) {
        _joinLog('joinRoom controller error=${error.toString()}');
        throw Exception(error.toString().replaceFirst('Exception: ', ''));
      },
    );
  }
}

class CreateRoomController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> createRoom({
    required int maxBoards,
    required int scoreStep,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      final creatorUid = user?.uid;
      if (creatorUid == null) {
        throw Exception('Creator must be signed in.');
      }
      return ref
          .read(roomRepositoryProvider)
          .createRoom(
            creatorUid: creatorUid,
            maxBoards: maxBoards,
            scoreStep: scoreStep,
          );
    });

    state = result.when(
      data: (_) => const AsyncData(null),
      error: (error, stackTrace) => AsyncError(error, stackTrace),
      loading: () => const AsyncLoading(),
    );

    return result.requireValue;
  }
}

class LobbyController {
  LobbyController({required this.roomId, required this.repository});

  final String roomId;
  final RoomRepository repository;

  Future<void> removeBoard(String boardId) {
    return repository.removeBoard(roomId: roomId, boardId: boardId);
  }

  Future<void> renameBoard({
    required String boardId,
    required String boardLabel,
  }) {
    return repository.renameBoard(
      roomId: roomId,
      boardId: boardId,
      boardLabel: boardLabel,
    );
  }

  Future<void> startScoring() {
    return repository.startScoring(roomId);
  }

  Future<void> identifyBoards() {
    return repository.identifyBoards(roomId);
  }

  Future<void> setScoresHidden(bool hidden) {
    return repository.setHideScores(roomId: roomId, hideScores: hidden);
  }

  Future<void> setBoardBrightness(double brightness) {
    return repository.setBoardBrightness(
      roomId: roomId,
      brightness: brightness,
    );
  }

  Future<void> setBoardBrightnessManaged({
    required String boardId,
    required bool managed,
  }) {
    return repository.setBoardBrightnessManaged(
      roomId: roomId,
      boardId: boardId,
      managed: managed,
    );
  }

  Future<void> continueSession() {
    return repository.continueScoring(roomId);
  }
}

class CreatorScoringController {
  CreatorScoringController({required this.roomId, required this.repository});

  final String roomId;
  final RoomRepository repository;

  Future<void> incrementScore(String boardId) {
    return repository.adjustScore(
      roomId: roomId,
      boardId: boardId,
      direction: 1,
    );
  }

  Future<void> decrementScore(String boardId) {
    return repository.adjustScore(
      roomId: roomId,
      boardId: boardId,
      direction: -1,
    );
  }

  Future<void> setBoardScore({required String boardId, required int score}) {
    return repository.setBoardScore(
      roomId: roomId,
      boardId: boardId,
      score: score,
    );
  }

  Future<void> pause() {
    return repository.pauseScoring(roomId);
  }

  Future<void> resume() {
    return repository.resumeScoring(roomId);
  }

  Future<void> close() {
    return repository.closeScoring(roomId);
  }

  Future<void> identifyBoards() {
    return repository.identifyBoards(roomId);
  }

  Future<void> setScoresHidden(bool hidden) {
    return repository.setHideScores(roomId: roomId, hideScores: hidden);
  }

  Future<void> setBoardBrightness(double brightness) {
    return repository.setBoardBrightness(
      roomId: roomId,
      brightness: brightness,
    );
  }

  Future<void> setBoardBrightnessManaged({
    required String boardId,
    required bool managed,
  }) {
    return repository.setBoardBrightnessManaged(
      roomId: roomId,
      boardId: boardId,
      managed: managed,
    );
  }

  Future<void> startTimer({required String boardId, required int durationMs}) {
    return repository.startBoardTimer(
      roomId: roomId,
      boardId: boardId,
      durationMs: durationMs,
    );
  }

  Future<void> pauseTimer(String boardId) {
    return repository.pauseBoardTimer(roomId: roomId, boardId: boardId);
  }

  Future<void> restartTimer(String boardId) {
    return repository.restartBoardTimer(roomId: roomId, boardId: boardId);
  }

  Future<void> continueTimer(String boardId) {
    return repository.continueBoardTimer(roomId: roomId, boardId: boardId);
  }

  Future<void> endTimer(String boardId) {
    return repository.endBoardTimer(roomId: roomId, boardId: boardId);
  }

  Future<void> completeTimerIfElapsed(String boardId, {int? nowMs}) {
    return repository.completeBoardTimerIfElapsed(
      roomId: roomId,
      boardId: boardId,
      nowMs: nowMs,
    );
  }
}
