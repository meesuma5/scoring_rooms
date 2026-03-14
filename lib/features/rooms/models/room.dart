class Room {
  const Room({
    required this.roomId,
    required this.roomCode,
    required this.creatorUid,
    required this.status,
    required this.maxBoards,
    required this.scoreStep,
    required this.roomLocked,
    required this.elapsedMs,
    required this.identifyUntilMs,
    this.boardBrightness = 1.0,
    this.hideScores = false,
    this.timerStatus = 'idle',
    this.timerDurationMs = 0,
    this.timerEndAtMs = 0,
    this.timerRemainingMs = 0,
  });

  final String roomId;
  final String roomCode;
  final String creatorUid;
  final String status;
  final int maxBoards;
  final int scoreStep;
  final bool roomLocked;
  final int elapsedMs;
  final int identifyUntilMs;
  final double boardBrightness;
  final bool hideScores;
  final String timerStatus;
  final int timerDurationMs;
  final int timerEndAtMs;
  final int timerRemainingMs;

  factory Room.fromMap(String roomId, Map<String, dynamic> data) {
    return Room(
      roomId: roomId,
      roomCode: (data['roomCode'] as String?) ?? '',
      creatorUid: (data['creatorUid'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'open',
      maxBoards: (data['maxBoards'] as num?)?.toInt() ?? 0,
      scoreStep: (data['scoreStep'] as num?)?.toInt() ?? 1,
      roomLocked: (data['roomLocked'] as bool?) ?? false,
      elapsedMs: (data['elapsedMs'] as num?)?.toInt() ?? 0,
      identifyUntilMs: (data['identifyUntilMs'] as num?)?.toInt() ?? 0,
      boardBrightness: (data['boardBrightness'] as num?)?.toDouble() ?? 1.0,
      hideScores: (data['hideScores'] as bool?) ?? false,
      timerStatus: (data['timerStatus'] as String?) ?? 'idle',
      timerDurationMs: (data['timerDurationMs'] as num?)?.toInt() ?? 0,
      timerEndAtMs: (data['timerEndAtMs'] as num?)?.toInt() ?? 0,
      timerRemainingMs: (data['timerRemainingMs'] as num?)?.toInt() ?? 0,
    );
  }
}
