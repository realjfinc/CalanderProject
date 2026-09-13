# Calander Cloud Functions

Step 7's scheduled polling function: keeps every user's calendar up to
date with their followed sports teams' upcoming games, without requiring
them to open the app and tap "Sync Now" (the client-side equivalent, in
`lib/ui/sports/dashboard_tab.dart`).

## `pollSportsEvents` (scheduled, every 6 hours)

For every user document under `users/{uid}`, reads their
`followedTeams` subcollection; for every followed team, fetches upcoming
games from [TheSportsDB](https://www.thesportsdb.com/api.php) and ingests
each one through `shared/ingestProviderEvent.ts` — a field-for-field
TypeScript port of the Flutter client's own `event_sync.dart`, so a game
this poll adds is indistinguishable from one the client synced manually:

- `source: "sports"`, `sourceId` = TheSportsDB's own event id.
- Dedup and cross-source conflict detection key off `(source, sourceId)`,
  exactly as every other source (Step 6's Google/Outlook/iCloud adapters,
  the client's own sports sync) does — this poller does not implement its
  own copy of that logic, it reuses the same utility.
- `tag: null` always — only direct user action or Step 5's routing logic
  ever assigns a tag; no source adapter, this one included, ever does.
- A user with no followed teams costs one empty subcollection read and
  nothing else (no events read, no repository created for them).

TheSportsDB's public test key (`"3"`) needs no account or credential setup
— the reason Sports Mode, alone among Steps 6/7's provider integrations,
needs no OAuth or API-key deployment step to actually run once deployed.

## Local development

```sh
npm install
npm run build   # tsc
npm test        # node's built-in test runner via tsx, no network/Firebase needed
```

All tests run against fakes (an in-memory `EventRepository`, a stubbed
`fetchUpcomingEventsRaw`) — none of them call TheSportsDB or Firestore, so
they need no deployed project, no emulator, and no network access.

## Deployment dependencies (not done by this PR)

1. **Blaze (pay-as-you-go) plan required.** Like Step 3's `extractEvent`,
   this is a 2nd-generation Cloud Function (`firebase-functions/v2`), which
   Firebase requires the Blaze plan to deploy at all — regardless of
   whether it uses a paid API. The project (`calander-1025b`) is currently
   on the free Spark plan (per the main README); this is a billing change
   only the project owner can make.
2. No secret or API key is needed beyond that — TheSportsDB's public test
   key (`"3"`) needs no account of its own.
3. Deploy with `firebase deploy --only functions` from the repo root, once
   the above is done.
