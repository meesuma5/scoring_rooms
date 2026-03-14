# Scoring Rooms — Chat Context

## Stack
- Flutter + Riverpod
- Firebase Auth + Firestore
- Targets: iOS + Android (mobile-first)

## App flow
1. Startup:
   - Creator: Google sign-in
   - Board: Join room by code
2. Creator:
   - Create room
   - Lobby (manage boards)
   - Scoring controls (pause/resume, +/- score, close)
   - Final results
3. Board:
   - Join room
   - Full-screen board display

## Key behavior decisions (current)
- State management: Riverpod only
- Board identity: same device rejoin should map to same board identity
- Board move-out: triggered via back navigation on board screen
- Rejoin behavior: moved-out state is renewed (board set back in-room)
- Board visuals:
  - Pre-start: logo-focused display
  - Post-start: score-focused display with score animation
  - Identify mode: temporary board-name overlay triggered by creator
- Creator home: shows all rooms for the signed-in creator, and room cards are tappable
- Lobby: board rename supported (tap/edit on board row)
- Creator screens: pull-to-refresh enabled
- Join guard: internet check before opening Join Room screen

## Firestore shape (important collections)
- rooms/{roomId}
  - roomCode, creatorUid, status, roomLocked, maxBoards, scoreStep, identifyUntilMs, elapsedMs
- rooms/{roomId}/boards/{boardId}
  - boardLabel, score, inRoom, deviceKey, updatedAt, joinedAt
- rooms/{roomId}/boardLinks/{deviceKey}
  - boardId, boardLabel, updatedAt

## Frequent troubleshooting notes
- "Room not found" can mean invalid code or room not open for joining.
- If UI looks stale on device, use full restart (clean run), not only hot reload.
- iOS release Google auth requires proper URL scheme and client id in Info.plist.

## Good prompts for next chats
- "Implement X in creator flow only."
- "Update board screen behavior before/after scoring."
- "Adjust Firestore room/board fields and migrate reads safely."
- "Add/update tests for the changed module only."
