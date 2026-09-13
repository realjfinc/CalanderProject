# Calander

Mobile-first Flutter calendar and account screens based on `../design/CalanderProject.png`.
Light and dark themes follow the device setting. Inter is bundled locally with its license.

## Included

- Welcome, email/password signup, login, password reset, and email verification.
- Signup stores the full name in the Firebase Authentication user profile.
- Unverified accounts stay on the verification screen, including restored sessions.
- Verification refreshes manually or when the app returns to the foreground.
- Password-reset links open Firebase's hosted reset page; return to the app to log in.
- Verified accounts open their calendar: Month, Week, Day, Search, and event details.
- Create, edit, and delete private events with all-day/multi-day support, location, notes, tags, and Fixed/Flexible importance.
- Tags and Settings are accessible from the bottom navigation; logout is in Settings.
- Google and Apple buttons are placeholders only.

## Firebase

Project: `calander-1025b` (Calander, free Spark plan). Email/Password is enabled.
Android and iOS use `com.example.calander`; web is registered for local testing.
Public app configuration is in `lib/firebase_configuration.dart`,
`android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist`.
These files contain app identifiers, not administrator credentials.

Cloud Firestore stores per-user events and tags. The default Standard database is
provisioned in `northamerica-northeast2` (Toronto). The owner-only rules in this
repository have been published to the project.
Firestore security rules live at the repo root: `../firestore.rules`, deployed
with `firebase deploy --only firestore:rules` from the repo root.

## Tags (Step 1)

Per-user tags are stored at `users/{uid}/tags/{tagId}`, scoped to the signed-in
Firebase Auth user (`../firestore.rules` restricts access to the owning user).
A fresh account gets three default tags (Work/Personal/School) created once,
via a persisted `users/{uid}/meta/tagInit` marker — idempotent, so deleting a
default tag never brings it back on a later launch. Manage them from the home
screen's Tags tab or Settings > Manage Tags: add, rename/recolor, and delete.

Relevant code: `lib/models/event_tag.dart`, `lib/services/tag_repository.dart`,
`lib/services/firestore_tag_repository.dart`, `lib/ui/tags/tag_management_screen.dart`.
Tests use `fake_cloud_firestore` instead of a live backend
(`test/firestore_tag_repository_test.dart`, `test/tag_management_screen_test.dart`).

## Run

From this folder:

```sh
flutter pub get
flutter run -d chrome
```

For Android, connect a device or start an emulator and use `flutter run`.
iOS requires macOS and Xcode; the project targets iOS 15 or later.
Windows may request Developer Mode for Flutter plugin symlink support.

## Checks

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

The auth widget tests use a fake authentication service and do not send email.
They cover account validation, verification gating, resend cooldown, password reset,
logout, and narrow layouts with enlarged text. Preview renders are saved under
`build/auth-previews/`. The tag-system tests use `fake_cloud_firestore` and an
in-memory repository fake, and cover default-tag initialization (including
idempotency and non-resurrection of deleted defaults), add/edit/delete, and
per-user scoping.

Before testing was stopped at the user's request, analysis and widget tests passed,
and the web build succeeded. Android compilation was blocked while downloading
Gradle by the local Java certificate configuration. iOS has not been built.
A complete signup, verification-email, reset-email, and login cycle remains for manual testing.
Use an email address you control and check its spam folder if needed.

## Calendar storage and behavior

Events live at `users/{uid}/events/{eventId}`. The repository always uses the
signed-in user's UID. Published rules permit only that verified user to read,
create, edit, or delete their events and validate event fields and timestamps.
The calendar listens to Firestore snapshots, so changes appear on other devices
signed in to the same account. Cached/pending changes are labeled in the UI;
an offline write is not confirmed as synced until Firebase acknowledges it.

Timed events are stored as UTC instants and displayed in each device's local
time zone. All-day dates are stored as UTC calendar dates and reconstructed
without shifting days across time zones. End dates are exclusive in storage.
Edits preserve the creation timestamp; the last saved edit wins. A deleted
remote event cannot be recreated by an editor using the update operation.

Search covers event names, locations, notes, and tag names, with a tag filter.
Month and Week select a day and show its agenda. Importance is a label only;
the app does not automatically move events. Repeating events, reminders,
guests/sharing, sports, friends, and calendar imports are not part of this step.
No sample events are inserted into users' accounts.

The current calendar changes have been reviewed with static analysis only.
No builds or tests were run, at the user's request. Existing auth test fixtures
were updated for the new calendar destination and Settings logout. For manual
verification, add an event, sign in to the same account on a second device,
then edit and delete it. A different account should have its own empty calendar.
