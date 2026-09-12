# Calander

Mobile-first Flutter account screens based on `../design/CalanderProject.png`.
Light and dark themes follow the device setting. Inter is bundled locally with its license.

## Included

- Welcome, email/password signup, login, password reset, and email verification.
- Signup stores the full name in the Firebase Authentication user profile.
- Unverified accounts stay on the verification screen, including restored sessions.
- Verification refreshes manually or when the app returns to the foreground.
- Password-reset links open Firebase's hosted reset page; return to the app to log in.
- Verified accounts see a blank page with a logout button.
- Google and Apple buttons are placeholders only.

## Firebase

Project: `calander-1025b` (Calander, free Spark plan). Email/Password is enabled.
Android and iOS use `com.example.calander`; web is registered for local testing.
Public app configuration is in `lib/firebase_configuration.dart`,
`android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist`.
These files contain app identifiers, not administrator credentials.
Native desktop targets are not configured. No calendar features or database were added.

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

The eight widget tests use a fake authentication service and do not send email.
They cover account validation, verification gating, resend cooldown, password reset,
logout, and narrow layouts with enlarged text. Preview renders are saved under
`build/auth-previews/`.

Before testing was stopped at the user's request, analysis and widget tests passed,
and the web build succeeded. Android compilation was blocked while downloading
Gradle by the local Java certificate configuration. iOS has not been built.
A complete signup, verification-email, reset-email, and login cycle remains for manual testing.
Use an email address you control and check its spam folder if needed.
