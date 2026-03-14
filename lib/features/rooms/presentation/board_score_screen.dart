import 'dart:async';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:scoring_rooms/features/rooms/models/room.dart';
import 'package:scoring_rooms/features/rooms/providers/room_providers.dart';
import 'package:scoring_rooms/features/rooms/providers/scoreboard_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class BoardScoreScreen extends ConsumerStatefulWidget {
  const BoardScoreScreen({
    super.key,
    required this.roomId,
    required this.boardId,
    required this.boardLabel,
  });

  final String roomId;
  final String boardId;
  final String boardLabel;

  static const _backgroundAsset = 'assets/images/scoreboard_background.png';
  static const _logoAsset = 'assets/images/bahar_e_danish.gif';

  @override
  ConsumerState<BoardScoreScreen> createState() => _BoardScoreScreenState();
}

class _BoardScoreScreenState extends ConsumerState<BoardScoreScreen>
    with WidgetsBindingObserver {
  static const _brightnessPrefKey = 'board_brightness';
  final _screenBrightness = ScreenBrightness();
  double? _previousBrightness;
  Timer? _identifyPopupTimer;
  Timer? _countdownTicker;
  bool _completingTimer = false;
  bool _resettingEndedTimer = false;
  double? _activeBoardBrightness;
  bool? _wasBrightnessManaged;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    _activateBoardMode();
    _loadSavedBrightness();
    _renewPresence();
  }

  @override
  void dispose() {
    _identifyPopupTimer?.cancel();
    _countdownTicker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _deactivateBoardMode();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _activateBoardMode();
      _renewPresence();
    }
  }

  bool _isScoringStarted(Room room) {
    return room.status == 'started' ||
        room.status == 'paused' ||
        room.status == 'closed';
  }

  bool _isIdentifyActive(Room room) {
    return room.identifyUntilMs > DateTime.now().millisecondsSinceEpoch;
  }

  bool _isTimerVisible(BoardViewState state) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (state.timerStatus == 'running' || state.timerStatus == 'paused') {
      return true;
    }
    if (state.timerEndAtMs > nowMs) {
      return true;
    }
    if (state.timerStatus == 'ended' && state.timerEndedAtMs > 0) {
      if (nowMs - state.timerEndedAtMs < 5000) {
        return true;
      }
    }
    return state.timerRemainingMs > 0;
  }

  int _timerRemainingMs(BoardViewState state) {
    if (state.timerStatus == 'running' && state.timerEndAtMs > 0) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (state.timerStartedAtMs > 0 && state.timerRunDurationMs > 0) {
        final expectedEndAtMs =
            state.timerStartedAtMs + state.timerRunDurationMs;
        final remaining = expectedEndAtMs - nowMs;
        return remaining > 0 ? remaining : 0;
      }
      final remaining = state.timerEndAtMs - nowMs;
      return remaining > 0 ? remaining : 0;
    }
    if (state.timerStatus == 'paused') {
      return state.timerRemainingMs > 0 ? state.timerRemainingMs : 0;
    }
    return 0;
  }

  String _formatCountdown(int milliseconds) {
    final totalSeconds = (milliseconds / 1000).floor();
    final seconds = totalSeconds % 60;
    return seconds.toString().padLeft(2, '0');
  }

  void _syncIdentifyPopupTimer(Room room) {
    _identifyPopupTimer?.cancel();

    if (!_isIdentifyActive(room)) return;

    final remainingMs =
        room.identifyUntilMs - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) return;

    _identifyPopupTimer = Timer(Duration(milliseconds: remainingMs), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _renewPresence() async {
    try {
      final args = BoardRouteArgs(
        roomId: widget.roomId,
        boardId: widget.boardId,
      );
      await ref.read(boardPresenceControllerProvider(args)).renewPresence();
    } catch (_) {}
  }

  Future<void> _activateBoardMode() async {
    try {
      _previousBrightness ??= await _screenBrightness.application;
      await WakelockPlus.enable();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}
  }

  Future<void> _applyBoardBrightness(
    double brightness, {
    bool force = false,
    bool save = true,
  }) async {
    final clamped = brightness.clamp(0.05, 1.0) as double;
    if (!force &&
        _activeBoardBrightness != null &&
        (_activeBoardBrightness! - clamped).abs() < 0.01) {
      return;
    }
    _activeBoardBrightness = clamped;
    try {
      await _screenBrightness.setApplicationScreenBrightness(clamped);
    } catch (_) {}
    if (save) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_brightnessPrefKey, clamped);
      } catch (_) {}
    }
  }

  Future<void> _releaseBoardBrightness() async {
    if (_activeBoardBrightness == null) return;
    _activeBoardBrightness = null;
    try {
      await _screenBrightness.resetApplicationScreenBrightness();
    } catch (_) {}
  }

  Future<void> _loadSavedBrightness() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_brightnessPrefKey);
      if (saved == null) return;
      _activeBoardBrightness = saved;
      await _screenBrightness.setApplicationScreenBrightness(
        saved.clamp(0.05, 1.0) as double,
      );
    } catch (_) {}
  }

  Future<void> _deactivateBoardMode() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await WakelockPlus.disable();
      if (_previousBrightness != null) {
        await _screenBrightness.setApplicationScreenBrightness(
          _previousBrightness!,
        );
      }
    } catch (_) {}
  }

  Future<void> _handleBackMoveOut() async {
    final args = BoardRouteArgs(roomId: widget.roomId, boardId: widget.boardId);
    try {
      await ref.read(boardPresenceControllerProvider(args)).moveOut();
    } catch (_) {}
  }

  Future<void> _completeTimerIfElapsed() async {
    if (_completingTimer) return;
    _completingTimer = true;
    try {
      await ref
          .read(roomRepositoryProvider)
          .completeBoardTimerIfElapsed(
            roomId: widget.roomId,
            boardId: widget.boardId,
          );
    } catch (_) {
    } finally {
      _completingTimer = false;
    }
  }

  Future<void> _resetEndedTimerIfExpired(int timerEndedAtMs) async {
    if (_resettingEndedTimer) return;
    _resettingEndedTimer = true;
    try {
      final expiredBeforeMs = DateTime.now().millisecondsSinceEpoch - 5000;
      await ref
          .read(roomRepositoryProvider)
          .resetEndedBoardTimerIfExpired(
            roomId: widget.roomId,
            boardId: widget.boardId,
            expiredBeforeMs: expiredBeforeMs,
          );
    } catch (_) {
    } finally {
      _resettingEndedTimer = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = BoardRouteArgs(roomId: widget.roomId, boardId: widget.boardId);
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final boardState = ref.watch(boardViewProvider(args));

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) return;
        await _handleBackMoveOut();
      },
      child: Scaffold(
        body: roomAsync.when(
          data: (room) {
            _syncIdentifyPopupTimer(room);
            return boardState.when(
              data: (state) {
                final wasManaged =
                    _wasBrightnessManaged ?? state.brightnessManaged;
                if (state.brightnessManaged) {
                  _applyBoardBrightness(
                    room.boardBrightness,
                    force: !wasManaged,
                    save: true,
                  );
                } else {
                  _releaseBoardBrightness();
                }
                _wasBrightnessManaged = state.brightnessManaged;
                final scoringStarted = _isScoringStarted(room);
                final showIdentifyPopup = _isIdentifyActive(room);
                final showTimer = _isTimerVisible(state);
                final timerRemainingMs = _timerRemainingMs(state);
                if (state.timerStatus == 'running' && timerRemainingMs <= 0) {
                  _completeTimerIfElapsed();
                }
                if (state.timerStatus == 'ended' && state.timerEndedAtMs > 0) {
                  final nowMs = DateTime.now().millisecondsSinceEpoch;
                  if (nowMs - state.timerEndedAtMs >= 5000) {
                    _resetEndedTimerIfExpired(state.timerEndedAtMs);
                  }
                }
                final shouldShowLogo =
                    (!scoringStarted || room.hideScores) && !showTimer;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      BoardScoreScreen._backgroundAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                        );
                      },
                    ),
                    Container(color: Colors.black.withValues(alpha: 0.28)),
                    SafeArea(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                            child: Column(
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      if (shouldShowLogo) {
                                        return Center(
                                          child: Image.asset(
                                            BoardScoreScreen._logoAsset,
                                            height:
                                                MediaQuery.of(
                                                  context,
                                                ).size.height *
                                                0.7,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox.shrink(),
                                          ),
                                        );
                                      }

                                      if (showTimer) {
                                        final diameter =
                                            constraints.maxHeight <
                                                MediaQuery.of(
                                                      context,
                                                    ).size.shortestSide *
                                                    1.25
                                            ? constraints.maxHeight
                                            : MediaQuery.of(
                                                    context,
                                                  ).size.shortestSide *
                                                  1.25;
                                        return Center(
                                          child: SizedBox(
                                            height: diameter * 1.25,
                                            width: diameter * 1.25,
                                            child: Center(
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Image.asset(
                                                    'assets/images/empty.gif',
                                                    height: diameter,
                                                    width: diameter,
                                                    fit: BoxFit.contain,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          __,
                                                          ___,
                                                        ) => Container(
                                                          height: diameter,
                                                          width: diameter,
                                                          decoration: BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                    alpha: 0.6,
                                                                  ),
                                                              width: 6,
                                                            ),
                                                          ),
                                                        ),
                                                  ),
                                                  Center(
                                                    child: Text(
                                                      _formatCountdown(
                                                        timerRemainingMs,
                                                      ),
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      overflow:
                                                          TextOverflow.visible,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .displayLarge
                                                          ?.copyWith(
                                                            color: Colors.white,
                                                            fontFamily:
                                                                'Poppins',
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 250,
                                                          ),
                                                      // textAlign:
                                                      //     TextAlign.center,
                                                      // textWidthBasis:
                                                      //     TextWidthBasis
                                                      //         .parent,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      return Center(
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          switchInCurve: Curves.easeOutBack,
                                          switchOutCurve: Curves.easeIn,
                                          transitionBuilder:
                                              (child, animation) {
                                                return ScaleTransition(
                                                  scale: animation,
                                                  child: FadeTransition(
                                                    opacity: animation,
                                                    child: child,
                                                  ),
                                                );
                                              },
                                          child: Text(
                                            '${state.score}',
                                            key: ValueKey<int>(state.score),
                                            style: Theme.of(context)
                                                .textTheme
                                                .displayLarge
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontFamily: 'Poppins',
                                                  fontWeight: FontWeight.w800,
                                                  fontFeatures: const [
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                  fontSize: 500,
                                                ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (showIdentifyPopup)
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                  horizontal: 28,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  state.boardLabel,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
        ),
      ),
    );
  }
}
