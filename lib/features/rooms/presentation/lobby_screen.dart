import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_rooms/features/rooms/presentation/creator_scoring_screen.dart';
import 'package:scoring_rooms/features/rooms/presentation/final_results_screen.dart';
import 'package:scoring_rooms/features/rooms/providers/room_providers.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final boardsAsync = ref.watch(roomBoardsProvider(roomId));

    return Scaffold(
      appBar: AppBar(title: const Text('Room Lobby')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(roomStreamProvider(roomId));
          ref.invalidate(roomBoardsProvider(roomId));
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: roomAsync.when(
            data: (room) {
              return boardsAsync.when(
                data: (boards) {
                  final canStart = boards.length >= 2 && room.status == 'open';
                  final hasStarted =
                      room.status == 'started' || room.status == 'paused';
                  final isClosed = room.status == 'closed';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Room Code: ${room.roomCode.isEmpty ? '-' : room.roomCode}',
                      ),
                      const SizedBox(height: 8),
                      Text('Status: ${room.status.toUpperCase()}'),
                      const SizedBox(height: 8),
                      Text('Joined Boards: ${boards.length}/${room.maxBoards}'),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: boards.length,
                          itemBuilder: (context, index) {
                            final board = boards[index];
                            return ListTile(
                              title: Text('Board ${board.boardLabel}'),
                              subtitle: Text('Score: ${board.score}'),
                              onTap: () async {
                                final controller = TextEditingController(
                                  text: board.boardLabel,
                                );
                                final nextLabel = await showDialog<String>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Rename Board'),
                                      content: TextField(
                                        controller: controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Board name',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(
                                            context,
                                          ).pop(controller.text),
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (nextLabel == null ||
                                    nextLabel.trim().isEmpty ||
                                    nextLabel.trim() == board.boardLabel) {
                                  return;
                                }

                                try {
                                  await ref
                                      .read(lobbyControllerProvider(roomId))
                                      .renameBoard(
                                        boardId: board.boardId,
                                        boardLabel: nextLabel,
                                      );
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      final controller = TextEditingController(
                                        text: board.boardLabel,
                                      );
                                      final nextLabel =
                                          await showDialog<String>(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: const Text(
                                                  'Rename Board',
                                                ),
                                                content: TextField(
                                                  controller: controller,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Board name',
                                                      ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(controller.text),
                                                    child: const Text('Save'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );

                                      if (nextLabel == null ||
                                          nextLabel.trim().isEmpty ||
                                          nextLabel.trim() ==
                                              board.boardLabel) {
                                        return;
                                      }

                                      try {
                                        await ref
                                            .read(
                                              lobbyControllerProvider(roomId),
                                            )
                                            .renameBoard(
                                              boardId: board.boardId,
                                              boardLabel: nextLabel,
                                            );
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(error.toString()),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  if (room.status == 'open')
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        ref
                                            .read(
                                              lobbyControllerProvider(roomId),
                                            )
                                            .removeBoard(board.boardId);
                                      },
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await ref
                                .read(lobbyControllerProvider(roomId))
                                .identifyBoards();
                          },
                          child: const Text('Identify Boards'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canStart
                              ? () async {
                                  await ref
                                      .read(lobbyControllerProvider(roomId))
                                      .startScoring();
                                  if (!context.mounted) return;
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CreatorScoringScreen(roomId: roomId),
                                    ),
                                  );
                                }
                              : null,
                          child: const Text('Start Scoring'),
                        ),
                      ),
                      if (hasStarted || isClosed) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => isClosed
                                      ? FinalResultsScreen(roomId: roomId)
                                      : CreatorScoringScreen(roomId: roomId),
                                ),
                              );
                            },
                            child: Text(
                              isClosed ? 'Open Results' : 'Open Scoring',
                            ),
                          ),
                        ),
                      ],
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
    );
  }
}
