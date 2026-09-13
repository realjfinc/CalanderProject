# Calander Screenshot Capture (Chrome Extension)

Manifest V3 extension: capture the current tab, run it through the same
`extractEvent` Cloud Function pipeline as Step 3 (no duplicated extraction
logic), and save the result to the signed-in user's Calander account.
Events created here always use `source: "screenshot"`, `sourceId: null`,
`tag: null`.

## Setup

```sh
npm install
npm run build   # bundles src/popup.js -> dist/popup.bundle.js (esbuild)
```

Then in Chrome: `chrome://extensions` → enable Developer mode → "Load
unpacked" → select this `chrome-extension/` directory. The build step is
required first — Manifest V3 forbids remote/unbundled ES module resolution
for extension pages, so `dist/popup.bundle.js` (gitignored, built locally)
is what `src/popup.html` actually loads.

## Auth

Uses the same Firebase project and web app registration as the mobile/iOS
app (`calander/lib/firebase_configuration.dart`'s `web` config, duplicated
in `src/firebaseConfig.js` — same public identifiers, not new credentials).
Signing in here with an existing Calander email/password account is the
same account, not a separate one — this integrates with Jonathan's existing
`FirebaseAuthService`-backed accounts rather than building a new auth
system. The extension only supports email/password sign-in (matching what
the mobile app currently supports); Google/Apple sign-in are placeholders
there too.

## Flow

1. Sign in (popup shows a login form until `onAuthStateChanged` reports a user).
2. "Capture This Tab" → `chrome.tabs.captureVisibleTab()` → the same
   `extractEvent` callable Step 3 uses, with `type: "image"`.
3. Review/edit the extracted fields.
4. "Save Event" uploads the screenshot to Cloud Storage
   (`users/{uid}/uploads/`) and writes the event to Firestore
   (`users/{uid}/events`) with `source: "screenshot"`, `sourceId: null`,
   `tag: null`. Nothing is saved before this step.

The write goes through the client SDK (not a Cloud Function), so it's
subject to the live `firestore.rules` schema validation the calendar
dashboard's own event writes share. That schema requires both the
dashboard's own field names (`startAt`/`endAt`/`allDay`/`flexible`/`tagId`)
and the canonical ones (`start`/`end`/`tag`) on every event document, kept
consistent — `buildScreenshotEvent` mirrors both pairs, and `popup.js` adds
`createdAt`/`updatedAt` as Firestore server timestamps at write time (the
one thing the framework-agnostic `eventPayload.js` can't produce itself).

## Code layout

- `src/eventPayload.js` — pure: builds the extraction request and the final
  event fields (hard-codes `source`/`sourceId`/`tag`, ignoring any override).
- `src/dataUrl.js` — pure: splits a `captureVisibleTab` data URL into mime
  type + base64.
- `src/timezoneOffset.js` — pure: same fixed-UTC-offset approach as
  `calander/lib/services/timezone_offset.dart`, for disambiguating a
  timestamp the LLM extracts without its own offset.
- `src/popup.js` — the only file that touches `chrome.*`/Firebase/DOM APIs;
  everything else is pure and unit-tested without a browser.

## Testing

```sh
npm test    # node's built-in test runner, no browser/network needed
```

Covers the pure modules above — in particular, that `buildScreenshotEvent`
always produces `source: "screenshot"`, `sourceId: null`, `tag: null`
regardless of what's passed in.

### What was and wasn't verified end-to-end

The manifest, bundle, and popup UI were verified against a real unpacked
load in this sandbox's pre-installed Chromium (via Playwright): the
extension loads, the popup renders with the expected title and login form,
and the sign-in button's click handler correctly invokes
`signInWithEmailAndPassword` with the entered credentials — no console or
page errors at any point.

What could **not** be verified here: an actual network round-trip to
Firebase. Even a plain `fetch()` to `googleapis.com` from the loaded
extension's popup page never resolved or rejected in this sandbox's
headless-Chromium test harness — this reproduces for *any* outbound
request from that context, not just Firebase calls, so it's a sandbox
network limitation (this environment's outbound traffic goes through an
agent proxy that a manually-launched, `--headless=new` Chromium subprocess
isn't transparently bridged through), not a bug in this code. A real,
non-headless Chrome profile loading this extension does not have that
restriction.

Also not deployed: the `extractEvent` function itself has the same Blaze
plan + `ANTHROPIC_API_KEY` secret dependency documented in
`../functions/README.md` — this extension calls the same function, so
nothing here can complete a live extraction until that's done either.
