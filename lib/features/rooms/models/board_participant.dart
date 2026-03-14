class BoardParticipant {
  const BoardParticipant({
    required this.boardId,
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

  final String boardId;
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

  factory BoardParticipant.fromMap(String boardId, Map<String, dynamic>? data) {
    final timerStatusValue = data?['timerStatus'];
    final timerStatus = timerStatusValue is String
        ? timerStatusValue
        : timerStatusValue?.toString();
    return BoardParticipant(
      boardId: boardId,
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
