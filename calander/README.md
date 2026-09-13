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
repository include the previously published calendar rules plus the provider
fields reconciled in this merge. The updated rules still need deployment.
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

## Notifications (Step 2)

Local reminders use `flutter_local_notifications`. Each event's `reminders`
field (a list of offsets — 5/10/15/30 min, 1 hour, 1 day before start) is
turned into a scheduled notification by `services/reminder_planner.dart`
(pure scheduling decision) and `services/notification_scheduler.dart`
(reconciles the plugin's scheduled set against the current event list).
`services/notification_reconciler.dart` wires that to a live
`users/{uid}/events` Firestore stream. This step only *consumes* the
`reminders` field — the UI for picking a reminder offset is Jonathan's.

FCM handles synced-event-change pushes: `services/push_notification_service.dart`
shows a local notification for any message with `data.type == "event_change"`
(foreground and background/terminated, via a top-level handler registered in
`main.dart`). `services/fcm_token_registrar.dart` stores the device's token at
`users/{uid}/meta/fcmToken` so a future backend has somewhere to send to —
no such backend exists yet in this repo.

All of this is bootstrapped from `main.dart` (not the widget tree), so it
only runs against the real, initialized Firebase app and never activates
during `test/widget_test.dart`'s fake-auth widget tests.

## Provider Sync (Step 6)

Settings > Provider Sync opens two tabs:

- **Connected Accounts**: sync from Google Calendar, Outlook, or iCloud.
  iCloud is fully functional as-is (CalDAV over HTTP Basic auth with an
  Apple ID + app-specific password — no OAuth client needed). Google and
  Outlook need an OAuth access token, which normally comes from a full
  sign-in flow against a *registered* OAuth client (Google Cloud /
  Azure AD) — that registration hasn't been done (see Dependencies below),
  so in the meantime the screen accepts a token pasted directly (e.g. from
  Google's OAuth Playground or Microsoft Graph Explorer). This is a real,
  working interim path: everything downstream of getting a token — the
  adapter, dedup, conflict detection — is fully implemented and tested;
  only the token-acquisition UI needs swapping for a real sign-in button
  once a client exists.
- **Conflicts**: resolves any cross-source conflict sync detected, with
  the roadmap's exact three choices — Keep original, Keep new, Keep both.
  Never auto-merges.

Each provider adapter (`lib/services/google_calendar_adapter.dart`,
`outlook_calendar_adapter.dart`, `icloud_caldav_adapter.dart`) maps that
provider's raw event format to the canonical schema, using the provider's
own event id as `sourceId` and normalizing every timestamp to UTC at
ingestion (Outlook via Graph's `Prefer: outlook.timezone="UTC"` header;
iCloud via real IANA timezone conversion in `ics_parser.dart`, using the
`timezone` package's zone database). No adapter ever sets `tag`.

`lib/services/event_sync.dart`'s `ingestProviderEvent` is the one shared
place dedup and conflict detection happen — no adapter reimplements
either. It keys dedup on `(source, sourceId)`, and flags a cross-source
conflict when an active event from a *different* source has a similar
title and a start time within 15 minutes; both sides become
`pendingConflict`, linked by an additive `conflictGroupId`/`conflictRole`
pair (not part of the roadmap's baseline schema, but needed to implement
"Keep original / Keep new / Keep both" without a separate conflicts
collection — see the doc comment on `CalendarEvent.conflictGroupId`).

### Dependencies / known limitations

- **Google Calendar and Outlook need real OAuth client registrations**
  (a Google Cloud OAuth client, an Azure AD app registration) that haven't
  been done — same category of dependency as Step 3's Blaze plan
  requirement. Until then, the "paste a token" interim path above is what
  actually runs.
- **iCloud calendar discovery is simplified**: the adapter needs the
  specific calendar's CalDAV URL entered directly rather than discovering
  it automatically from just an Apple ID (full CalDAV service discovery —
  a `PROPFIND` against `https://caldav.icloud.com/` to resolve the
  account's principal and enumerate its calendars — isn't implemented).
- **iCloud ICS parsing** handles the common cases (UTC via `Z` suffix,
  `TZID`-qualified times via the real timezone database, all-day
  `VALUE=DATE`) but not recurrence rules (`RRULE`) — a recurring event's
  future instances aren't expanded, only whatever a single VEVENT block
  states directly.

Relevant code: `lib/models/calendar_event.dart`, `lib/services/provider_adapter.dart`,
`lib/services/event_sync.dart`, `lib/services/provider_sync.dart`,
`lib/services/conflict_resolver.dart`, `lib/services/ics_parser.dart`,
`lib/ui/sync/`.

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
guests/sharing, sports, friends, and file imports are not part of the calendar UI.
Native provider sync is available separately through Settings.
No sample events are inserted into users' accounts.

The current calendar changes have been reviewed with static analysis only.
No builds or tests were run, at the user's request. Existing auth test fixtures
were updated for the new calendar destination and Settings logout. For manual
verification, add an event, sign in to the same account on a second device,
then edit and delete it. A different account should have its own empty calendar.

## Provider sync / calendar merge

Calendar views and provider sync share one event repository. Reads accept both
`startAt`/`endAt` calendar documents and `start`/`end` provider documents; new
writes keep both field pairs consistent. Tags, importance, all-day dates,
provider identity, and conflict metadata survive calendar edits. Timed events
stay UTC in the model and are converted to local time only in the calendar UI.
The repository retains both stream contracts (event lists for provider sync,
metadata snapshots for calendar sync status) without filtering out older docs.
Provider Sync is available in Settings, within the signed-in session navigator.

The merged Firestore rules add validated provider fields while keeping the
owner/verified-user restriction. Deploy these updated rules before using this
merged client with the live database; this merge does not deploy cloud changes:

```sh
firebase deploy --only firestore:rules --project calander-1025b
```

Legacy provider documents without a creation timestamp remain editable;
updates preserve existing creation timestamps and never recreate deleted events.
Merge validation uses static analysis only; builds and tests were not run.
