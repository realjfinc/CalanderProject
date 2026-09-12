# calander

A new Flutter project.

## Firebase setup (required before running against a live backend)

This app uses Firebase (Cloud Firestore + Auth). `lib/firebase_options.dart`
currently contains placeholder values. Before running on a device/emulator
or against real data, run from this directory:

```
flutterfire configure
```

signed in to the project's Firebase account. Until that's done, the app
still compiles and its widget/unit tests pass — tests use `fake_cloud_firestore`
instead of a live backend (see `test/firestore_tag_repository_test.dart`).

Firestore security rules for this project live at the repo root:
`../firestore.rules` (deploy with `firebase deploy --only firestore:rules`
from the repo root once a real Firebase project is configured).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
