import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_rooms/core/providers/firestore_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final deviceKeyProvider = FutureProvider<String>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('scoreboard_device_key');
    if (current != null && current.isNotEmpty) {
      return current;
    }

    final generated = const Uuid().v4();
    await prefs.setString('scoreboard_device_key', generated);
    return generated;
  } catch (_) {
    return const Uuid().v4();
  }
});

class BoardRouteArgs {
  const BoardRouteArgs({required this.roomId, required this.boardId});

  final String roomId;
  final String boardId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BoardRouteArgs &&
        other.roomId == roomId &&
        other.boardId == boardId;
  }

  @override
  int get hashCode => Object.hash(roomId, boardId);
}

class BoardViewState {
  const BoardViewState({
    required this.boardLabel,
    required this.score,
    required this.inRoom,
    required this.brightnessManaged,
    required this.timerStatus,
    required this.timerDurationMs,
    required this.timerRunDurationMs,
    required this.timerEndAtMs,
    required this.timerRemainingMs,
    required this.timerEndedAtMs,
    required this.timerStartedAtMs,
  });

  final String boardLabel;
  final int score;
  final bool inRoom;
  final bool brightnessManaged;
  final String timerStatus;
  final int timerDurationMs;
  final int timerRunDurationMs;
  final int timerEndAtMs;
  final int timerRemainingMs;
  final int timerEndedAtMs;
  final int timerStartedAtMs;

  factory BoardViewState.fromMap(Map<String, dynamic>? data) {
    final timerStatusValue = data?['timerStatus'];
    final timerStatus = timerStatusValue is String
        ? timerStatusValue
        : timerStatusValue?.toString();
    return BoardViewState(
      boardLabel: (data?['boardLabel'] as String?) ?? 'Board',
      score: (data?['score'] as num?)?.toInt() ?? 0,
      inRoom: (data?['inRoom'] as bool?) ?? true,
      brightnessManaged: (data?['brightnessManaged'] as bool?) ?? true,
      timerStatus: timerStatus ?? 'idle',
      timerDurationMs: (data?['timerDurationMs'] as num?)?.toInt() ?? 0,
      timerRunDurationMs: (data?['timerRunDurationMs'] as num?)?.toInt() ?? 0,
      timerEndAtMs: (data?['timerEndAtMs'] as num?)?.toInt() ?? 0,
      timerRemainingMs: (data?['timerRemainingMs'] as num?)?.toInt() ?? 0,
      timerEndedAtMs: (data?['timerEndedAtMs'] as num?)?.toInt() ?? 0,
      timerStartedAtMs: (data?['timerStartedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

final boardViewProvider = StreamProvider.family<BoardViewState, BoardRouteArgs>(
  (ref, args) {
    return ref
        .watch(firestoreProvider)
        .collection('rooms')
        .doc(args.roomId)
        .collection('boards')
        .doc(args.boardId)
        .snapshots()
        .map((snapshot) => BoardViewState.fromMap(snapshot.data()));
  },
);

final boardPresenceControllerProvider =
    Provider.family<BoardPresenceController, BoardRouteArgs>((ref, args) {
      return BoardPresenceController(
        args: args,
        firestore: ref.watch(firestoreProvider),
      );
    });

class BoardPresenceController {
  BoardPresenceController({required this.args, required this.firestore});

  final BoardRouteArgs args;
  final FirebaseFirestore firestore;

  Future<void> renewPresence() async {
    await firestore
        .collection('rooms')
        .doc(args.roomId)
        .collection('boards')
        .doc(args.boardId)
        .set({
          'inRoom': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> moveOut() async {
    await firestore
        .collection('rooms')
        .doc(args.roomId)
        .collection('boards')
        .doc(args.boardId)
        .set({
          'inRoom': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
