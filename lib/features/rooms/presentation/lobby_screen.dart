import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_rooms/features/rooms/presentation/creator_scoring_screen.dart';
import 'package:scoring_rooms/features/rooms/presentation/final_results_screen.dart';
import 'package:scoring_rooms/features/rooms/models/board_participant.dart';
import 'package:scoring_rooms/features/rooms/providers/room_providers.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final List<String> _pendingBoardOrder = [];

  List<BoardParticipant> _orderedBoards(List<BoardParticipant> boards) {
    if (_pendingBoardOrder.isEmpty) {
      return boards;
    }

    final byId = {for (final board in boards) board.boardId: board};

    final ordered = <BoardParticipant>[];
    for (final boardId in _pendingBoardOrder) {
      final board = byId.remove(boardId);
      if (board != null) {
        ordered.add(board);
      }
    }
    ordered.addAll(byId.values);
    return ordered;
  }

  void _onReorder(
    List<BoardParticipant> displayBoards,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final reorderedIds = displayBoards.map((board) => board.boardId).toList();
    final moved = reorderedIds.removeAt(oldIndex);
    reorderedIds.insert(newIndex, moved);

    setState(() {
      _pendingBoardOrder
        ..clear()
        ..addAll(reorderedIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final boardsAsync = ref.watch(roomBoardsProvider(widget.roomId));

    return Scaffold(
      appBar: AppBar(title: const Text('Room Lobby')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(roomStreamProvider(widget.roomId));
          ref.invalidate(roomBoardsProvider(widget.roomId));
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: roomAsync.when(
            data: (room) {
              return boardsAsync.when(
                data: (boards) {
                  final displayBoards = _orderedBoards(boards);
                  final canStart =
                      displayBoards.length >= 2 && room.status == 'open';
                  final hasStarted =
                      room.status == 'started' || room.status == 'paused';
                  final isClosed = room.status == 'closed';
                  final isOpen = room.status == 'open';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Room Code: ${room.roomCode.isEmpty ? '-' : room.roomCode}',
                      ),
                      const SizedBox(height: 8),
                      Text('Status: ${room.status.toUpperCase()}'),
                      const SizedBox(height: 8),
                      Text(
                        'Joined Boards: ${displayBoards.length}/${room.maxBoards}',
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: displayBoards.length,
                          onReorder: isOpen
                              ? (oldIndex, newIndex) => _onReorder(
                                  displayBoards,
                                  oldIndex,
                                  newIndex,
                                )
                              : (_, __) {},
                          itemBuilder: (context, index) {
                            final board = displayBoards[index];
                            return ListTile(
                              key: ValueKey(board.boardId),
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
                                      .read(
                                        lobbyControllerProvider(widget.roomId),
                                      )
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
                                              lobbyControllerProvider(
                                                widget.roomId,
                                              ),
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
                                  if (isOpen)
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        ref
                                            .read(
                                              lobbyControllerProvider(
                                                widget.roomId,
                                              ),
                                            )
                                            .removeBoard(board.boardId);
                                      },
                                    ),
                                  if (isOpen)
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Icon(Icons.drag_handle),
                                      ),
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
                                .read(lobbyControllerProvider(widget.roomId))
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
                                  final orderedBoardIds = displayBoards
                                      .map((board) => board.boardId)
                                      .toList();
                                  await ref
                                      .read(
                                        lobbyControllerProvider(widget.roomId),
                                      )
                                      .setBoardOrder(orderedBoardIds);
                                  await ref
                                      .read(
                                        lobbyControllerProvider(widget.roomId),
                                      )
                                      .startScoring();
                                  if (!context.mounted) return;
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => CreatorScoringScreen(
                                        roomId: widget.roomId,
                                      ),
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
                                      ? FinalResultsScreen(
                                          roomId: widget.roomId,
                                        )
                                      : CreatorScoringScreen(
                                          roomId: widget.roomId,
                                        ),
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
