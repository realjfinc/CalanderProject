# Calander

Mobile-first Flutter account screens based on `../design/CalanderProject.png`.
Light and dark themes follow the device setting. Inter is bundled locally with its license.

## Included

- Welcome, email/password signup, login, password reset, and email verification.
- Signup stores the full name in the Firebase Authentication user profile.
- Unverified accounts stay on the verification screen, including restored sessions.
- Verification refreshes manually or when the app returns to the foreground.
- Password-reset links open Firebase's hosted reset page; return to the app to log in.
- Verified accounts see a home screen with "Manage Tags", "Tag Routing", and a logout button.
- Google and Apple buttons are placeholders only.

## Firebase

Project: `calander-1025b` (Calander, free Spark plan). Email/Password is enabled.
Android and iOS use `com.example.calander`; web is registered for local testing.
Public app configuration is in `lib/firebase_configuration.dart`,
`android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist`.
These files contain app identifiers, not administrator credentials.

Cloud Firestore is used for per-user data (currently: tags — see below).
Firestore security rules live at the repo root: `../firestore.rules`, deployed
with `firebase deploy --only firestore:rules` from the repo root.

## Tags (Step 1)

Per-user tags are stored at `users/{uid}/tags/{tagId}`, scoped to the signed-in
Firebase Auth user (`../firestore.rules` restricts access to the owning user).
A fresh account gets three default tags (Work/Personal/School) created once,
via a persisted `users/{uid}/meta/tagInit` marker — idempotent, so deleting a
default tag never brings it back on a later launch. Manage them from the home
screen's "Manage Tags" button: add, rename/recolor, and delete.

Relevant code: `lib/models/event_tag.dart`, `lib/services/tag_repository.dart`,
`lib/services/firestore_tag_repository.dart`, `lib/ui/tags/tag_management_screen.dart`.
Tests use `fake_cloud_firestore` instead of a live backend
(`test/firestore_tag_repository_test.dart`, `test/tag_management_screen_test.dart`).

## Tag Routing (Step 5)

Two things live under the home screen's "Tag Routing" button:

- **Events tab**: assign a tag to any untagged event, or change/clear any
  event's current tag — direct user action always wins here, whether or
  not the tag showing was assigned automatically.
- **Auto-Tag Rules tab**: an `autoTagEnabled` toggle and a list of rules
  (`{match: {field, operator, value}, tag}`, e.g. "if title contains
  'standup', tag Work"), stored at `users/{uid}/settings/tagRouting`.

Auto-tagging only ever runs while `autoTagEnabled` is true, and only ever
touches an event whose `tag` is still `null` — once an event has a tag
(user-set or previously auto-assigned), it's never touched again, which is
what guarantees a user's override always sticks. This is bootstrapped from
`main.dart` (not the widget tree) via `TagRoutingBootstrap`, same pattern
as everything else that needs to run continuously in the background — see
`lib/services/tag_routing_reconciler.dart`.

`lib/services/event_repository.dart` deliberately exposes only
`watchEvents()` and `setEventTag()` — no general "update the whole event"
method — so this rule-matching logic and direct user action really are the
only two things in this codebase that can ever write an event's `tag`.

Relevant code: `lib/models/tag_rule.dart`, `lib/services/tag_router.dart`
(pure rule matching), `lib/services/tag_routing_reconciler.dart`,
`lib/services/firestore_tag_routing_repository.dart`,
`lib/ui/tags/tag_routing_screen.dart` (and its two tabs).

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
per-user scoping. The tag-routing tests cover: pure rule matching
(`test/tag_router_test.dart`), the reconciler's stream-driven behavior with
in-memory fakes — including that it never re-tags an event that already has
one and does nothing while auto-tagging is off
(`test/tag_routing_reconciler_test.dart`), the Firestore repositories via
`fake_cloud_firestore` (`test/firestore_event_repository_test.dart`,
`test/firestore_tag_routing_repository_test.dart`), and the manual
tagging/override UI (`test/event_tags_tab_test.dart`).

Before testing was stopped at the user's request, analysis and widget tests passed,
and the web build succeeded. Android compilation was blocked while downloading
Gradle by the local Java certificate configuration. iOS has not been built.
A complete signup, verification-email, reset-email, and login cycle remains for manual testing.
Use an email address you control and check its spam folder if needed.
