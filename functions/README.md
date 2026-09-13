# Calander Cloud Functions

Two independent functions live here:

- `extractEvent` (Step 3): turns an uploaded image, PDF, or link into
  structured event data via an LLM, for the client's confirm-before-commit
  UI. Never writes to Firestore — extraction only proposes data; the
  user's confirmation and the actual save both happen client-side.
- `pollSportsEvents` (Step 7): a scheduled function that keeps every
  user's calendar up to date with their followed sports teams' upcoming
  games. The client never calls TheSportsDB to sync games itself (see
  `lib/ui/sports/dashboard_tab.dart`) — this function, or its Python
  equivalent in `../scripts/sports_poller/`, is the only thing that does.

## `extractEvent` (callable)

Request:
```ts
{ type: "image", data: <base64>, mimeType: "image/png", timezone: "America/New_York" }
{ type: "pdf",   data: <base64>, timezone: "America/New_York" }
{ type: "link",  url: "https://...", timezone: "America/New_York" }
```

Response:
```ts
{ title: string, location: string | null, startUtc: string, endUtc: string, notes: string | null }
```

`timezone` (an IANA name, e.g. from the client's `DateTime.now().timeZoneName`
equivalent) is only used to disambiguate a start/end time the LLM extracts
without an explicit UTC offset — timestamps are always normalized to UTC
before being returned, per the project's ingestion contract.

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
- Writes via the Admin SDK, which bypasses `../firestore.rules`' schema
  validation, so it only ever writes the canonical fields — the client's
  `CalendarEvent.fromMap()` already tolerates a document missing the
  dashboard's `startAt`/`endAt`/etc. mirror fields, falling back to the
  canonical ones.

TheSportsDB's public test key (`"3"`) needs no account or credential setup
— the reason Sports Mode, alone among Steps 6/7's provider integrations,
needs no OAuth or API-key deployment step to actually run once deployed.

## Local development

```sh
npm install
npm run build   # tsc
npm test        # node's built-in test runner via tsx, no network/Firebase needed
```

All tests run against fakes (`FakeLlmClient` and a stubbed `fetch` for
extraction; an in-memory `EventRepository` and a stubbed
`fetchUpcomingEventsRaw` for sports polling) — none of them call a real
LLM, TheSportsDB, or Firestore, so they need no API key, no deployed
project, and no network access.

## Deployment dependencies (not done by this PR)

1. **Blaze (pay-as-you-go) plan required.** The Firebase project
   (`calander-1025b`) is currently on the free Spark plan (per the main
   README). Both functions here are 2nd-generation Cloud Functions
   (`firebase-functions/v2`), which Firebase requires the Blaze plan to
   deploy at all, regardless of whether either one uses a paid API —
   `extractEvent` additionally makes outbound network calls (to the LLM
   API, and to fetch link content), which also requires Blaze on its own.
   This is a billing change only the project owner can make.
2. **`ANTHROPIC_API_KEY` secret**, needed only by `extractEvent`. Set it
   with:
   ```sh
   firebase functions:secrets:set ANTHROPIC_API_KEY
   ```
   before deploying. No key is bundled with this code. `pollSportsEvents`
   needs no secret or API key — TheSportsDB's public test key (`"3"`)
   needs no account of its own.
3. Deploy both with `firebase deploy --only functions` from the repo root,
   once the above is done.
