import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_rooms/features/rooms/presentation/board_score_screen.dart';
import 'package:scoring_rooms/features/rooms/providers/room_providers.dart';

class BoardJoinScreen extends ConsumerStatefulWidget {
  const BoardJoinScreen({super.key});

  @override
  ConsumerState<BoardJoinScreen> createState() => _BoardJoinScreenState();
}

class _BoardJoinScreenState extends ConsumerState<BoardJoinScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final joinState = ref.watch(boardJoinControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Join a Room')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Room code',
                hintText: 'Enter room key',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: joinState.isLoading
                    ? null
                    : () async {
                        try {
                          final result = await ref
                              .read(boardJoinControllerProvider.notifier)
                              .joinRoom(_controller.text);
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BoardScoreScreen(
                                roomId: result.roomId,
                                boardId: result.boardId,
                                boardLabel: result.boardLabel,
                              ),
                            ),
                          );
                        } catch (error, stackTrace) {
                          developer.log(
                            'BoardJoinScreen join failed code=${_controller.text.trim()} error=${error.toString()}',
                            name: 'rooms.join',
                            error: error,
                            stackTrace: stackTrace,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      },
                child: joinState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join Room'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
