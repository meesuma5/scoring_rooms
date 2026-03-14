# scoring_rooms
A FlutterFire application for live scoring + viewing

## Firebase setup

1. Install FlutterFire CLI:
	- `dart pub global activate flutterfire_cli`
2. Configure Firebase for this app from project root:
	- `flutterfire configure`
3. Enable Authentication provider in Firebase Console:
	- Authentication -> Sign-in method -> enable **Google**
4. Create Firestore database in Firebase Console:
	- Firestore Database -> Create database
5. Run the app:
	- `flutter run`

## State management

- Uses `flutter_riverpod` as the single state layer.
- `ProviderScope` is mounted at app root.
- UI reads with `ref.watch`, and side effects flow through provider controllers.

## Screen plan and ownership

Total planned screens: **8**

- Startup (everyone): **Login / Sign-up with Google**, **Join a Room**
- Creator Auth/Home (creator only)
- Create Room (creator only)
- Lobby (creator only)
- Creator Scoring (creator only)
- Join Room (score-board only)
- Board Full-Screen Score (score-board only, live-updating until Move out)
- Final Results (creator + board read-only variants)

## Current implementation status

- Implemented startup screen with exactly two options.
- Implemented Google login action (creator path) and sign-out.
- Implemented room join screen and board full-screen score screen shell.
- Implemented same-device identity persistence foundation via local `deviceKey`.
- Implemented creator lobby -> scoring -> final results flow with room-status based transitions.
