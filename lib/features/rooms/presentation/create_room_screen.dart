import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_rooms/features/rooms/presentation/lobby_screen.dart';
import 'package:scoring_rooms/features/rooms/providers/room_providers.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _maxBoardsController = TextEditingController(text: '4');
  final _scoreStepController = TextEditingController(text: '1');

  @override
  void dispose() {
    _maxBoardsController.dispose();
    _scoreStepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createRoomControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Room')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(createRoomControllerProvider);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _maxBoardsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Max boards'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _scoreStepController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Score step'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        try {
                          final maxBoards = int.parse(
                            _maxBoardsController.text,
                          );
                          final scoreStep = int.parse(
                            _scoreStepController.text,
                          );

                          final roomId = await ref
                              .read(createRoomControllerProvider.notifier)
                              .createRoom(
                                maxBoards: maxBoards,
                                scoreStep: scoreStep,
                              );
                          if (!context.mounted) return;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => LobbyScreen(roomId: roomId),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      },
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Room'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
