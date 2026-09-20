`icon.png` and `icon_foreground.png` are a placeholder brand mark — a
simple calendar glyph in the app's real theme color (`#285BE0`, see
`lib/theme.dart`), generated to replace the default Flutter logo that
was shipping in every store listing and home-screen icon before this.
It is **not** final branding. Swap these two files for real artwork
whenever you have it, then regenerate every platform's icons with:

```
dart run flutter_launcher_icons
```

- `icon.png` — the full 1024×1024 icon (background + mark), used as-is
  for iOS/web and as the flat fallback everywhere `flutter_launcher_icons`
  needs one image.
- `icon_foreground.png` — the mark alone, transparent background, used as
  the foreground layer of Android's adaptive icon (the background is the
  solid `adaptive_icon_background` color in `pubspec.yaml` instead, since
  Android crops/masks the foreground independently of it).
