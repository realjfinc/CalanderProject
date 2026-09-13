# Calander

Mobile-first Flutter account screens based on `../design/CalanderProject.png`.
Light and dark themes follow the device setting. Inter is bundled locally with its license.

## Included

- Welcome, email/password signup, login, password reset, and email verification.
- Signup stores the full name in the Firebase Authentication user profile.
- Unverified accounts stay on the verification screen, including restored sessions.
- Verification refreshes manually or when the app returns to the foreground.
- Password-reset links open Firebase's hosted reset page; return to the app to log in.
- Verified accounts see a home screen with "Manage Tags" and "Sports Mode" entry points and a logout button.
- Google and Apple buttons are placeholders only.

## Firebase

Project: `calander-1025b` (Calander, free Spark plan). Email/Password is enabled.
Android and iOS use `com.example.calander`; web is registered for local testing.
Public app configuration is in `lib/firebase_configuration.dart`,
`android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist`.
These files contain app identifiers, not administrator credentials.

Cloud Firestore is used for per-user data (tags, events, and followed sports
teams — see below).
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

## Sports Mode (Step 7)

Follow sports teams (via [TheSportsDB](https://www.thesportsdb.com/api.php)'s
free public API — no account or API key needed) and get their upcoming games
added to your calendar automatically. Followed teams are stored at
`users/{uid}/followedTeams/{teamId}` (keyed by the team's own API id, so
following the same team twice is a no-op). Open it from the home screen's
"Sports Mode" button:

- **Follow Teams** tab: search TheSportsDB by name, follow/unfollow.
- **Dashboard** tab: see each followed team's next game, and a "Sync Upcoming
  Games to Calendar" button that pulls every followed team's upcoming games
  into your calendar on demand.

Games are ingested as `source: "sports"`, `sourceId` = TheSportsDB's own event
id, `tag: null` — same as every other source, sports games are only ever
tagged by direct user action or Step 5's routing logic, never by this
integration. Dedup and cross-source conflict detection reuse Step 6's shared
`ingestProviderEvent`/`syncProvider` utilities as-is (`SportsAdapter`
implements the same `ProviderAdapter` interface Step 6's Google/Outlook/
iCloud adapters do) — no separate sports-specific dedup logic exists.

A scheduled Cloud Function (`../functions/`, see its own README) polls every
user's followed teams every 6 hours and ingests new games the same way, so
games appear even if you never open the dashboard's sync button yourself.

Relevant code: `lib/models/followed_team.dart`,
`lib/services/followed_teams_repository.dart`,
`lib/services/firestore_followed_teams_repository.dart`,
`lib/services/thesportsdb_client.dart`, `lib/services/sports_adapter.dart`,
`lib/ui/sports/`. Recreated shared infrastructure (since Step 6's PR hasn't
merged yet): `lib/models/calendar_event.dart`, `lib/services/event_repository.dart`,
`lib/services/firestore_event_repository.dart`, `lib/services/provider_adapter.dart`,
`lib/services/event_sync.dart`, `lib/services/provider_sync.dart`.

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

Sports Mode's tests use `fake_cloud_firestore` and fakes for the sports API
client and followed-teams repository, and cover: TheSportsDB response mapping
(UTC timestamp parsing, fallbacks, defaults), the sports adapter aggregating
upcoming games across followed teams (including skipping malformed API
entries), and the followed-teams repository (add/dedupe/remove, per-user
scoping). The Cloud Function's own tests live in `../functions/test/` and run
independently via `npm test` there — see `../functions/README.md`.

Before testing was stopped at the user's request, analysis and widget tests passed,
and the web build succeeded. Android compilation was blocked while downloading
Gradle by the local Java certificate configuration. iOS has not been built.
A complete signup, verification-email, reset-email, and login cycle remains for manual testing.
Use an email address you control and check its spam folder if needed.
