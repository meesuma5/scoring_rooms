# Scoring Rooms — One-Page Architecture Map

## Purpose
Mobile-first real-time scoring app where a **creator** manages a room and **boards** join by code to display live scores.

## Stack
- Flutter
- Riverpod (single state-management layer)
- Firebase Auth (Google sign-in for creator)
- Cloud Firestore (room, boards, links, live updates)

## Runtime Entry + Routing
- App entry: `lib/main.dart`
- Bootstrap:
  1. Initialize Firebase
  2. Mount `ProviderScope`
  3. Route by auth state:
     - signed out -> `StartupScreen`
     - signed in -> `CreatorHomeScreen`

## Feature Modules
- `lib/features/startup/`
  - Startup options: Google login or Join Room
  - Internet guard before opening join flow
- `lib/features/auth/`
  - Firebase + Google auth providers/controller
- `lib/features/rooms/`
  - Room lifecycle, lobby, scoring, final results
  - Board join and full-screen score display
  - Firestore repository + stream providers

## Screen Flows
### Creator
1. `StartupScreen` -> Google sign-in
2. `CreatorHomeScreen` (list creator rooms, create room)
3. `CreateRoomScreen` -> room document created
4. `LobbyScreen` (board list, rename/remove, start scoring)
5. `CreatorScoringScreen` (pause/resume, +/- score, identify, close)
6. `FinalResultsScreen`

### Board
1. `StartupScreen` -> Join Room
2. `BoardJoinScreen` (room code)
3. `BoardScoreScreen` (full-screen, live score)
4. Back navigation marks board as moved out (`inRoom=false`)

## Firestore Model
### `rooms/{roomId}`
- Identity/config: `roomId`, `roomCode`, `creatorUid`, `maxBoards`, `scoreStep`
- Lifecycle: `status` (`open|started|paused|closed`), `roomLocked`
- Timing/state: `identifyUntilMs`, `elapsedMs`, timestamps (`createdAt`, `startedAt`, `closedAt`, `lastActivityAt`)

### `rooms/{roomId}/boards/{boardId}`
- `boardId`, `boardLabel`, `score`
- Presence: `inRoom`
- Identity/linking: `deviceKey`
- Timestamps: `updatedAt`, `joinedAt`

### `rooms/{roomId}/boardLinks/{deviceKey}`
- `boardId`, `boardLabel`, `updatedAt`
- Enables same-device rejoin to map to existing board identity

## State + Provider Topology
- `authStateProvider` (Firebase auth stream)
- `authControllerProvider` (Google sign-in/sign-out)
- `roomRepositoryProvider` (Firestore write operations)
- `roomStreamProvider(roomId)` (single room stream)
- `creatorRoomsProvider(creatorUid)` (creator room list)
- `roomBoardsProvider(roomId)` (board list)
- `boardJoinControllerProvider` (join by code + device key)
- `deviceKeyProvider` (persistent local identity)
- `boardViewProvider(roomId, boardId)` (single board stream)
- `boardPresenceControllerProvider(roomId, boardId)` (renew/move-out)

## Critical Behavior Invariants
- Riverpod is the only state-management layer.
- Rejoin from same device restores same board identity via `deviceKey -> boardLinks`.
- If board was moved out, rejoin renews it back to in-room.
- Join is allowed only when room is joinable (`status=open` and not locked).
- Scoring adjustments are allowed only while room status is `started`.
- Board UI mode:
  - pre-start: logo-focused
  - post-start: score-focused with animation
  - identify: temporary overlay when `identifyUntilMs` is active

## Operational Notes
- "Room not found" can mean invalid code or non-joinable room.
- Pull-to-refresh is intentionally enabled on creator-facing lists/screens.
- If UI feels stale on device, prefer a full restart over hot reload.

## Fast Navigation
- Entrypoint: `lib/main.dart`
- Startup: `lib/features/startup/startup_screen.dart`
- Auth providers: `lib/features/auth/providers/auth_providers.dart`
- Room providers/repository: `lib/features/rooms/providers/room_providers.dart`
- Board providers: `lib/features/rooms/providers/scoreboard_providers.dart`
- Creator screens: `lib/features/rooms/presentation/creator_home_screen.dart`, `lobby_screen.dart`, `creator_scoring_screen.dart`, `final_results_screen.dart`
- Board screens: `lib/features/rooms/presentation/board_join_screen.dart`, `board_score_screen.dart`
- Tests: `test/features/...`

## Keep This Document Fresh (when changing code)
Update this file whenever you change:
- Firestore fields/collections
- room/board lifecycle rules
- provider ownership/responsibilities
- screen transitions or role boundaries
- board identity/presence behavior
