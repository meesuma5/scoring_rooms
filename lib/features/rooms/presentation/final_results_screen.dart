import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_rooms/features/rooms/presentation/creator_scoring_screen.dart';
import 'package:scoring_rooms/features/rooms/providers/room_providers.dart';

class FinalResultsScreen extends ConsumerWidget {
  const FinalResultsScreen({super.key, required this.roomId});

  final String roomId;
  static const _backgroundAsset = 'assets/images/scoreboard_background.png';

  String _formatElapsed(int elapsedMs) {
    if (elapsedMs <= 0) {
      return '00:00';
    }
    final totalSeconds = elapsedMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final minutesText = minutes.toString().padLeft(2, '0');
    final secondsText = seconds.toString().padLeft(2, '0');
    return '$minutesText:$secondsText';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final boardsAsync = ref.watch(roomBoardsProvider(roomId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Final Results'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _backgroundAsset,
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
                ref.invalidate(roomStreamProvider(roomId));
                ref.invalidate(roomBoardsProvider(roomId));
                await Future<void>.delayed(const Duration(milliseconds: 250));
              },
              child: roomAsync.when(
                data: (room) {
                  return boardsAsync.when(
                    data: (boards) {
                      final sortedBoards = [...boards]
                        ..sort((a, b) => b.score.compareTo(a.score));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Elapsed: ${_formatElapsed(room.elapsedMs)}'),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: sortedBoards.length,
                              itemBuilder: (context, index) {
                                final board = sortedBoards[index];
                                final rank = index + 1;
                                return ListTile(
                                  leading: Text('#$rank'),
                                  title: Text('Board ${board.boardLabel}'),
                                  trailing: Text(
                                    '${board.score}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (room.status == 'closed')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await ref
                                      .read(lobbyControllerProvider(roomId))
                                      .continueSession();
                                  if (!context.mounted) return;
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CreatorScoringScreen(roomId: roomId),
                                    ),
                                  );
                                },
                                child: const Text('Continue Session'),
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 180),
                        Center(child: CircularProgressIndicator()),
                      ],
                    ),
                    error: (error, _) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 180),
                        Center(child: Text(error.toString())),
                      ],
                    ),
                  );
                },
                loading: () => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
                error: (error, _) => ListView(
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
