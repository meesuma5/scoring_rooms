import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scoring_rooms/features/auth/providers/auth_providers.dart';
import 'package:scoring_rooms/features/rooms/models/room.dart';
import 'package:scoring_rooms/features/rooms/presentation/creator_scoring_screen.dart';
import 'package:scoring_rooms/features/rooms/presentation/create_room_screen.dart';
import 'package:scoring_rooms/features/rooms/presentation/final_results_screen.dart';
import 'package:scoring_rooms/features/rooms/presentation/lobby_screen.dart';
import 'package:scoring_rooms/features/rooms/providers/room_providers.dart';

class CreatorHomeScreen extends ConsumerWidget {
  const CreatorHomeScreen({super.key});

  Widget _destinationForRoom(Room room) {
    if (room.status == 'closed') {
      return FinalResultsScreen(roomId: room.roomId);
    }
    if (room.status == 'started' || room.status == 'paused') {
      return CreatorScoringScreen(roomId: room.roomId);
    }
    return LobbyScreen(roomId: room.roomId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final creatorUid = user?.uid;
    final AsyncValue<List<Room>> roomsAsync = creatorUid == null
        ? const AsyncData<List<Room>>([])
        : ref.watch(creatorRoomsProvider(creatorUid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator Home'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              user?.email ?? user?.displayName ?? 'Signed in creator',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
                );
              },
              child: const Text('Create Room'),
            ),
            const SizedBox(height: 12),
            Text('Your Rooms', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (creatorUid != null) {
                    ref.invalidate(creatorRoomsProvider(creatorUid));
                  }
                  await Future<void>.delayed(const Duration(milliseconds: 250));
                },
                child: roomsAsync.when(
                  data: (rooms) {
                    if (rooms.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 180),
                          Center(child: Text('No rooms created yet.')),
                        ],
                      );
                    }
                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return Card(
                          child: ListTile(
                            title: Text(
                              room.roomCode.isEmpty
                                  ? 'Code unavailable'
                                  : 'Code: ${room.roomCode}',
                            ),
                            subtitle: Text('Status: ${room.status}'),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _destinationForRoom(room),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 160),
                      Center(child: CircularProgressIndicator()),
                    ],
                  ),
                  error: (error, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 160),
                      Center(child: Text(error.toString())),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
