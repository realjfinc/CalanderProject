# Sports Poller (Python)

A standalone alternative to deploying `../../functions/src/index.ts`'s
`pollSportsEvents` as a paid, 2nd-generation Firebase Cloud Function.
Firebase requires the Blaze (pay-as-you-go) plan to deploy ANY 2nd-gen
Cloud Function at all — regardless of whether it calls a paid API — so
until the project is upgraded off the free Spark plan, that scheduled
function can't be deployed. This script does the identical job without
needing Cloud Functions or Blaze: it runs anywhere Python does, on
whatever schedule you point at it. `.github/workflows/poll-sports-events.yml`
runs it once an hour via GitHub Actions' free scheduled-workflow minutes —
no Firebase billing change needed.

## What it does

For every user document under `users/{uid}`, reads their `followedTeams`
subcollection; for every followed team, fetches upcoming games from
[TheSportsDB](https://www.thesportsdb.com/api.php) (using their public
test key `"3"` — no account or credential of its own needed) and ingests
each one through the same shared dedup/conflict logic every other source
in this project uses:

- `source: "sports"`, `sourceId` = TheSportsDB's own event id.
- Dedup and cross-source conflict detection key off `(source, sourceId)`.
- `tag: null` always — only direct user action or Step 5's routing logic
  ever assigns a tag.
- A user with no followed teams costs one empty subcollection read and
  nothing else.

This is a field-for-field Python port of the same logic already reviewed
and shipped twice: `calander/lib/services/event_sync.dart` (the Flutter
client) and `functions/src/shared/ingestProviderEvent.ts` (the Cloud
Function). All three stay in sync by construction — same dedup key, same
conflict fields, same "no source adapter writes tag" rule — so a game this
script ingests is indistinguishable from one either of the others wrote.

Writes go through the Firebase Admin SDK, which — like the TypeScript
Cloud Function — bypasses `../../firestore.rules`' client-side schema
validation entirely, so this script only ever writes the canonical
fields. The Flutter client's `CalendarEvent.fromMap()` already tolerates
that (falling back from `startAt`/`endAt`/`tagId` to `start`/`end`/`tag`
when the dashboard's mirror fields are absent), and the first time a user
edits a sports-sourced event from the app, that edit "upgrades" the
document with the full field set on save.

## Setup

```sh
cd scripts/sports_poller
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt   # includes pytest, for local test runs
```

You'll need a Firebase service account key for the `calander-1025b`
project: **Firebase Console → Project Settings → Service Accounts →
Generate new private key**. Never commit that file — `.gitignore` here
already excludes the conventional names, but double-check before
committing regardless.

Run it locally:

```sh
python poll_sports_events.py --credentials /path/to/service-account.json
```

or with the key contents in an environment variable instead of a file
(this is what the GitHub Actions workflow does, from a repo secret):

```sh
FIREBASE_SERVICE_ACCOUNT_JSON="$(cat /path/to/service-account.json)" python poll_sports_events.py
```

## Running it hourly via GitHub Actions

`.github/workflows/poll-sports-events.yml` runs this script on an hourly
cron (`0 * * * *`) plus a manual `workflow_dispatch` trigger. It needs one
repository secret:

1. **Settings → Secrets and variables → Actions → New repository secret**
2. Name: `FIREBASE_SERVICE_ACCOUNT_JSON`
3. Value: the full contents of the service account key JSON file above.

That's it — no Firebase project changes, no billing plan upgrade. GitHub
Actions' free tier includes enough scheduled-workflow minutes for an
hourly job like this on a typical repo.

## Local development / tests

```sh
python -m pytest -v
```

All tests run against fakes (an in-memory `EventRepository`, a stubbed
`fetch_upcoming_events_raw_fn`) — none of them call TheSportsDB or
Firestore, so they need no deployed project, no service account, and no
network access. Covers: TheSportsDB response mapping (UTC timestamp
parsing, fallbacks, defaults, matching
`test/thesportsdb_client_test.dart`'s cases), the dedup/conflict utility
including a repeated-resync regression test (matching
`functions/test/ingestProviderEvent.test.ts`), and the polling
orchestrator (matching `functions/test/pollUpcomingGames.test.ts`).

## Known limitations

- This script and the TypeScript Cloud Function do the same job by
  design — if you later upgrade to Blaze and deploy `pollSportsEvents`,
  running both would double-poll (harmlessly, since the shared dedup
  logic makes a resync idempotent, but wastefully). Pick one.
- No retry/backoff on TheSportsDB request failures within a run — a
  failed request for one team is logged and skipped, and the rest of the
  poll (that user's other teams, every other user) continues. Fine for an
  hourly cron, since the next run retries the skipped team anyway, but
  worth knowing before assuming every run covers every followed team.
