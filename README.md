# Project Aether

Project Aether is a Flutter prototype for a global MMORPG world event. It combines a 100ms world boss countdown, an exactly capped 15-slot raid join flow, and a bounded realtime chat surface backed by Firebase.

## What It Demonstrates

- A 100ms countdown rendered through BLoC state so only the timer region updates.
- A raid join flow that never exceeds 15 filled slots, even under concurrent requests.
- A realtime chat feed that streams only the newest messages and paginates older history on demand.
- Firebase services wired through constructor injection so production code can be tested with `FakeFirebaseFirestore`.

## Architecture

The app uses a small Clean Architecture-style split:

- UI: `lib/main.dart` renders the dashboard and dispatches user intent to BLoCs.
- State: `WorldEventBloc`, `RaidBloc`, and `ChatBloc` keep timer, raid, and chat behavior isolated.
- Data: `RaidService` owns raid writes, while `FirestoreChatRepository` owns chat reads and writes.
- Dependency injection: `lib/injection_container.dart` registers Firestore-backed implementations with `get_it`.

The main business boundary is:

```dart
RaidService({required FirebaseFirestore firestore})
```

That constructor injection keeps Firestore replaceable in tests and avoids hidden global dependencies inside the domain logic.

## Raid Concurrency Handling

Raid joins are handled by `RaidService.joinRaid({required String userId})`. The service runs a Firestore transaction against `events/dragon_raid` and reads `slots_filled` and `max_slots` inside the same atomic operation that writes the next slot count.

That matters because a normal read followed by a normal update can let many clients observe the same old slot count and all write success. The transaction forces Firestore to retry or reject conflicting writes, so once the document reaches 15 filled slots every later request returns `false` without incrementing the counter.

The proof is in `test/raid_concurrency_test.dart`: 50 simultaneous join requests are fired at the same raid document, exactly 15 return success, and the stored `slots_filled` value remains 15.

## Firebase Data Model

- Raid state: `events/dragon_raid`
  - `slots_filled`
  - `max_slots`
  - `last_joined_user_id`
- Chat messages: `chat_rooms/global/messages/{messageId}`
  - `user_id`
  - `body`
  - `created_at`

## Firebase Cost Strategy

For 10,000 players, the chat UI should not listen to an unbounded messages collection because every active client would repeatedly pay for a growing read set. The app listens only to the newest 30 documents in `chat_rooms/global/messages`, ordered by `created_at`, and uses `startAfterDocument` cursor pagination when a player explicitly loads older history.

For a production launch, chat rooms should also be sharded by event, region, or world instance so one global room does not create unnecessary read fan-out. Long histories should be bucketed by time or archived outside the hot listener path so old messages are loaded only when requested.

## Firebase Setup

The project includes Firebase config for project `chatmate-4485a`:

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

Native IDs are configured as `com.yash.drovenue`, and the Dart package name remains `drovenue`.

## Run Locally

```sh
flutter pub get
flutter run
```

The first screen is the playable event dashboard: countdown, raid slot status, join button, and chat input.

## Verification

Run these commands from the project root:

```sh
flutter analyze
flutter test
flutter test test/raid_concurrency_test.dart
dart aether_linter.dart
```

`dart aether_linter.dart` writes `ARCHITECTURE_REPORT.md`, which records whether static analysis and the thundering-herd concurrency proof passed.
