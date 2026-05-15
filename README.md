# Project Aether

Project Aether is a single-screen Flutter prototype for a global MMORPG world event. It combines a 100ms world boss countdown, an exactly capped 15-slot raid join flow, and a bounded realtime chat surface backed by Firebase.

## Architecture

- `RaidService` is the required concurrency boundary and exposes `joinRaid({required String userId})`.
- Raid joins use a Firestore transaction against `events/dragon_raid`; the slot count is read and updated in the same transaction so the sixteenth player fails cleanly.
- BLoC isolates the timer, raid, and chat state so the 100ms timer updates only the countdown region instead of rebuilding the whole screen.
- Firestore is injected through constructors and `get_it`, which lets the same production service run against `FakeFirebaseFirestore` in tests.

## Firebase Cost Strategy

For 10,000 players, the chat UI should not listen to an unbounded messages collection because every active client would repeatedly pay for a growing read set. The app listens only to the newest 30 documents in `chat_rooms/global/messages` and uses `startAfterDocument` cursor pagination when a player explicitly loads older history. At production scale, rooms should be sharded by event/region and long histories should be bucketed by time so hot listeners stay small and archival reads remain intentional.

## Firebase Setup

The project includes the provided Firebase config for project `chatmate-4485a`:

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

Native IDs are configured as `com.yash.drovenue`, and the Dart package name remains `drovenue`.

## Verification

Run these commands from the project root:

```sh
flutter analyze
flutter test
flutter test test/raid_concurrency_test.dart
dart aether_linter.dart
```

`dart aether_linter.dart` writes `ARCHITECTURE_REPORT.md`, which records whether static analysis and the thundering-herd concurrency proof passed.
