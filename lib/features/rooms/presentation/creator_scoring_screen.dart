import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_rooms/features/rooms/models/board_participant.dart';
import 'package:scoring_rooms/features/rooms/presentation/final_results_screen.dart';
import 'package:scoring_rooms/features/rooms/providers/room_providers.dart';

class CreatorScoringScreen extends ConsumerStatefulWidget {
  const CreatorScoringScreen({super.key, required this.roomId});

  final String roomId;
  static const _backgroundAsset = 'assets/images/scoreboard_background.png';

  @override
  ConsumerState<CreatorScoringScreen> createState() =>
      _CreatorScoringScreenState();
}

class _CreatorScoringScreenState extends ConsumerState<CreatorScoringScreen> {
  static const _hapticsChannel = MethodChannel('score_haptics');
  Timer? _countdownTicker;
  Timer? _scoreSyncTimer;
  bool _syncingScores = false;
  bool _completingTimer = false;
  final Map<String, TextEditingController> _timerDurationControllers = {};
  final Map<String, int> _localScoreOverrides = {};
  final Map<String, int> _lastSyncedScores = {};
  List<BoardParticipant> _latestBoards = const [];
  final ScrollController _pageScrollController = ScrollController();
  bool _isNearBottom = false;
  Timer? _brightnessDebounce;
  double? _brightnessOverride;

  @override
  void initState() {
    super.initState();
    _pageScrollController.addListener(_onScroll);
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    _scoreSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _syncScoresToBoards();
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _scoreSyncTimer?.cancel();
    _brightnessDebounce?.cancel();
    _pageScrollController
      ..removeListener(_onScroll)
      ..dispose();
    for (final controller in _timerDurationControllers.values) {
      controller.dispose();
    }
    _timerDurationControllers.clear();
    super.dispose();
  }

  void _onScroll() {
    if (!_pageScrollController.hasClients) return;
    final position = _pageScrollController.position;
    final nearBottom = position.pixels >= (position.maxScrollExtent - 120);
    if (nearBottom != _isNearBottom && mounted) {
      setState(() {
        _isNearBottom = nearBottom;
      });
    }
  }

  Future<void> _toggleScrollPosition() async {
    if (!_pageScrollController.hasClients) return;
    final position = _pageScrollController.position;
    final target = _isNearBottom ? 0.0 : position.maxScrollExtent;
    await _pageScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  TextEditingController _durationControllerFor(String boardId) {
    final existing = _timerDurationControllers[boardId];
    if (existing != null) return existing;
    final controller = TextEditingController(text: '45');
    _timerDurationControllers[boardId] = controller;
    return controller;
  }

  int _clampTimerSeconds(int value) {
    if (value < 1) return 1;
    if (value > 99) return 99;
    return value;
  }

  Future<void> _triggerScoreHaptic() async {
    try {
      await _hapticsChannel.invokeMethod('vibrate', {
        'duration': 40,
        'amplitude': 180,
      });
      return;
    } catch (_) {}
    await HapticFeedback.heavyImpact();
  }

  void _scheduleBrightnessUpdate(
    CreatorScoringController controller,
    double value,
  ) {
    _brightnessDebounce?.cancel();
    _brightnessDebounce = Timer(const Duration(milliseconds: 120), () {
      controller.setBoardBrightness(value);
    });
  }

  void _syncScoreOverrides(List boards) {
    final activeIds = boards.map((board) => board.boardId).toSet();
    _localScoreOverrides.removeWhere(
      (boardId, _) => !activeIds.contains(boardId),
    );
    _lastSyncedScores.removeWhere((boardId, _) => !activeIds.contains(boardId));
    for (final board in boards) {
      final override = _localScoreOverrides[board.boardId];
      if (override != null && override == board.score) {
        _localScoreOverrides.remove(board.boardId);
      }
    }
  }

  Future<void> _syncScoresToBoards() async {
    if (!mounted || _syncingScores) return;
    if (_latestBoards.isEmpty) return;
    _syncingScores = true;
    try {
      final controller = ref.read(
        creatorScoringControllerProvider(widget.roomId),
      );
      final futures = <Future<void>>[];
      for (final board in _latestBoards) {
        final score = _localScoreOverrides[board.boardId] ?? board.score;
        final lastSynced = _lastSyncedScores[board.boardId];
        if (lastSynced == score) continue;
        _lastSyncedScores[board.boardId] = score;
        futures.add(
          controller.setBoardScore(boardId: board.boardId, score: score),
        );
      }
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
    } catch (_) {
    } finally {
      _syncingScores = false;
    }
  }

  void _applyLocalScoreDelta({
    required String boardId,
    required int delta,
    required int currentScore,
  }) {
    setState(() {
      _localScoreOverrides[boardId] = currentScore + delta;
    });
  }

  int _timerRemainingMs(room) {
    if (room.timerStatus == 'running' && room.timerEndAtMs > 0) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (room.timerStartedAtMs > 0 && room.timerRunDurationMs > 0) {
        final expectedEndAtMs = room.timerStartedAtMs + room.timerRunDurationMs;
        final remaining = expectedEndAtMs - nowMs;
        return remaining > 0 ? remaining : 0;
      }
      final remaining = room.timerEndAtMs - nowMs;
      return remaining > 0 ? remaining : 0;
    }
    if (room.timerStatus == 'paused') {
      return room.timerRemainingMs > 0 ? room.timerRemainingMs : 0;
    }
    return 0;
  }

  String _formatCountdown(int milliseconds) {
    final totalSeconds = (milliseconds / 1000).floor();
    final seconds = totalSeconds % 60;
    return seconds.toString().padLeft(2, '0');
  }

  Future<void> _completeTimerIfElapsed(String boardId) async {
    if (_completingTimer) return;
    _completingTimer = true;
    try {
      await ref
          .read(creatorScoringControllerProvider(widget.roomId))
          .completeTimerIfElapsed(boardId);
    } catch (_) {
    } finally {
      _completingTimer = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final boardsAsync = ref.watch(roomBoardsProvider(widget.roomId));
    final controller = ref.read(
      creatorScoringControllerProvider(widget.roomId),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Creator Scoring'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _toggleScrollPosition,
        child: Icon(
          _isNearBottom
              ? Icons.keyboard_double_arrow_up
              : Icons.keyboard_double_arrow_down,
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            CreatorScoringScreen._backgroundAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: Theme.of(context).colorScheme.surface),
          ),
          Container(color: Colors.black.withValues(alpha: 0.2)),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + kToolbarHeight + 12,
              16,
              16,
            ),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(roomStreamProvider(widget.roomId));
                ref.invalidate(roomBoardsProvider(widget.roomId));
                await Future<void>.delayed(const Duration(milliseconds: 250));
              },
              child: roomAsync.when(
                data: (room) {
                  return boardsAsync.when(
                    data: (boards) {
                      _latestBoards = boards;
                      _syncScoreOverrides(boards);
                      final isStarted = room.status == 'started';
                      final isPaused = room.status == 'paused';
                      final isClosed = room.status == 'closed';
                      const minCardWidth = 220.0;
                      const cardSpacing = 10.0;

                      return ListView(
                        controller: _pageScrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Text('Status: ${room.status.toUpperCase()}'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.brightness_6),
                              const SizedBox(width: 8),
                              const Text('Board Brightness'),
                              Expanded(
                                child: Slider(
                                  min: 0.05,
                                  max: 1.0,
                                  divisions: 95,
                                  value:
                                      (_brightnessOverride ??
                                              room.boardBrightness)
                                          .clamp(0.05, 1.0),
                                  onChangeStart: (_) {},
                                  onChanged: (value) {
                                    setState(() {
                                      _brightnessOverride = value;
                                    });
                                    _scheduleBrightnessUpdate(
                                      controller,
                                      value,
                                    );
                                  },
                                  onChangeEnd: (value) {
                                    _scheduleBrightnessUpdate(
                                      controller,
                                      value,
                                    );
                                    setState(() {
                                      _brightnessOverride = null;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final availableWidth = constraints.maxWidth;
                              final maxColumns =
                                  (availableWidth /
                                          (minCardWidth + cardSpacing))
                                      .floor()
                                      .clamp(1, 6);
                              final columns =
                                  boards.length < maxColumns &&
                                      boards.isNotEmpty
                                  ? boards.length
                                  : maxColumns;
                              final totalSpacing = cardSpacing * (columns - 1);
                              final cardWidth =
                                  (availableWidth - totalSpacing) / columns;

                              return Wrap(
                                spacing: cardSpacing,
                                runSpacing: cardSpacing,
                                children: boards.map((board) {
                                  final isBoardTimerRunning =
                                      board.timerStatus == 'running';
                                  final isBoardTimerPaused =
                                      board.timerStatus == 'paused';
                                  final hasBoardTimer =
                                      isBoardTimerRunning || isBoardTimerPaused;
                                  final displayScore =
                                      _localScoreOverrides[board.boardId] ??
                                      board.score;
                                  final boardTimerRemainingMs =
                                      _timerRemainingMs(board);
                                  final durationController =
                                      _durationControllerFor(board.boardId);

                                  if (isBoardTimerRunning &&
                                      boardTimerRemainingMs <= 0) {
                                    _completeTimerIfElapsed(board.boardId);
                                  }

                                  return SizedBox(
                                    width: cardWidth,
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              'Board ${board.boardLabel}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            CheckboxListTile(
                                              value: board.brightnessManaged,
                                              onChanged: (value) {
                                                if (value == null) return;
                                                controller
                                                    .setBoardBrightnessManaged(
                                                      boardId: board.boardId,
                                                      managed: value,
                                                    );
                                              },
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 0,
                                                  ),
                                              dense: true,
                                              visualDensity:
                                                  const VisualDensity(
                                                    horizontal: -4,
                                                    vertical: -2,
                                                  ),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              controlAffinity:
                                                  ListTileControlAffinity
                                                      .leading,
                                              title: const Text(
                                                'App controls brightness',
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '$displayScore',
                                              textAlign: TextAlign.center,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.headlineMedium,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              hasBoardTimer
                                                  ? _formatCountdown(
                                                      boardTimerRemainingMs,
                                                    )
                                                  : '--:--',
                                              textAlign: TextAlign.center,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            if (!hasBoardTimer) ...[
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                height: 40,
                                                child: TextField(
                                                  controller:
                                                      durationController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  onTapOutside: (_) {
                                                    FocusScope.of(
                                                      context,
                                                    ).unfocus();
                                                  },
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'Timer (sec)',
                                                        isDense: true,
                                                      ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                IconButton(
                                                  onPressed:
                                                      (isStarted || isPaused)
                                                      ? () async {
                                                          _applyLocalScoreDelta(
                                                            boardId:
                                                                board.boardId,
                                                            delta:
                                                                -room.scoreStep,
                                                            currentScore:
                                                                displayScore,
                                                          );
                                                          await _triggerScoreHaptic();
                                                          await controller
                                                              .decrementScore(
                                                                board.boardId,
                                                              );
                                                        }
                                                      : null,
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed:
                                                      (isStarted || isPaused)
                                                      ? () async {
                                                          _applyLocalScoreDelta(
                                                            boardId:
                                                                board.boardId,
                                                            delta:
                                                                room.scoreStep,
                                                            currentScore:
                                                                displayScore,
                                                          );
                                                          await _triggerScoreHaptic();
                                                          await controller
                                                              .incrementScore(
                                                                board.boardId,
                                                              );
                                                        }
                                                      : null,
                                                  icon: const Icon(
                                                    Icons.add_circle_outline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              alignment: WrapAlignment.end,
                                              children: [
                                                if (!hasBoardTimer)
                                                  OutlinedButton(
                                                    onPressed: () async {
                                                      final seconds =
                                                          int.tryParse(
                                                            durationController
                                                                .text
                                                                .trim(),
                                                          );
                                                      if (seconds == null) {
                                                        return;
                                                      }
                                                      final clampedSeconds =
                                                          _clampTimerSeconds(
                                                            seconds,
                                                          );
                                                      if (clampedSeconds !=
                                                          seconds) {
                                                        durationController
                                                                .text =
                                                            clampedSeconds
                                                                .toString();
                                                      }
                                                      await controller
                                                          .startTimer(
                                                            boardId:
                                                                board.boardId,
                                                            durationMs:
                                                                clampedSeconds *
                                                                1000,
                                                          );
                                                    },
                                                    child: const Text('Start'),
                                                  ),
                                                if (isBoardTimerRunning)
                                                  OutlinedButton(
                                                    onPressed: () async {
                                                      await controller
                                                          .pauseTimer(
                                                            board.boardId,
                                                          );
                                                    },
                                                    child: const Text('Pause'),
                                                  ),
                                                if (isBoardTimerPaused)
                                                  OutlinedButton(
                                                    onPressed: () async {
                                                      await controller
                                                          .continueTimer(
                                                            board.boardId,
                                                          );
                                                    },
                                                    child: const Text(
                                                      'Continue',
                                                    ),
                                                  ),
                                                if (hasBoardTimer)
                                                  OutlinedButton(
                                                    onPressed: () async {
                                                      await controller
                                                          .restartTimer(
                                                            board.boardId,
                                                          );
                                                    },
                                                    child: const Text(
                                                      'Restart',
                                                    ),
                                                  ),
                                                if (hasBoardTimer)
                                                  OutlinedButton(
                                                    onPressed: () async {
                                                      await controller.endTimer(
                                                        board.boardId,
                                                      );
                                                    },
                                                    child: const Text('End'),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          if (!isClosed)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await controller.identifyBoards();
                                },
                                child: const Text('Identify Boards'),
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (isStarted || isPaused)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await controller.setScoresHidden(
                                    !room.hideScores,
                                  );
                                },
                                child: Text(
                                  room.hideScores
                                      ? 'Show Scores'
                                      : 'Hide Scores',
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (isStarted || isPaused)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () async {
                                  if (isStarted) {
                                    await controller.pause();
                                  } else {
                                    await controller.resume();
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white),
                                ),
                                child: Text(isStarted ? 'Pause' : 'Resume'),
                              ),
                            ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isClosed
                                  ? () {
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => FinalResultsScreen(
                                            roomId: widget.roomId,
                                          ),
                                        ),
                                      );
                                    }
                                  : () async {
                                      await controller.close();
                                      if (!context.mounted) return;
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => FinalResultsScreen(
                                            roomId: widget.roomId,
                                          ),
                                        ),
                                      );
                                    },
                              child: const Text('Close Scoring'),
                            ),
                          ),
                          const SizedBox(height: 72),
                        ],
                      );
                    },
                    loading: () => ListView(
                      controller: _pageScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 180),
                        Center(child: CircularProgressIndicator()),
                      ],
                    ),
                    error: (error, _) => ListView(
                      controller: _pageScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 180),
                        Center(child: Text(error.toString())),
                      ],
                    ),
                  );
                },
                loading: () => ListView(
                  controller: _pageScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
                error: (error, _) => ListView(
                  controller: _pageScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 180),
                    Center(child: Text(error.toString())),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
