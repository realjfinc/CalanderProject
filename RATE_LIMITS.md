# Account rate limits

The Flutter client, Chrome extension, and `firestore.rules` enforce **100 Firestore document
changes per account per one-hour window**, shared by all devices using that
Firebase Authentication UID. Each create, update, or delete counts once.
Default tag initialization changes four documents and consumes four slots.
Automatic tagging and push-token writes share the same quota. Reads and live
listeners remain available; this is not a limit on total Firebase requests or
billed reads. Storage uploads and Authentication have their existing controls
and are not counted by this Firestore quota.

`FirestoreWriteLimiter` commits the change and `clientWriteLimits/{uid}` in one
transaction. The rules use server time and `getAfter()` to verify the counter
increment and each affected path. Direct writes without a matching quota update,
early resets, counter deletion, and undercounted batches are rejected. The first
change starts the hour; unused capacity does not carry forward. Rejected writes
do not consume a slot. Transactions require a connection, so edits no longer
queue for offline writes. The device clock is used only to propose window resets;
Firebase server time decides whether a reset is valid.

AI extraction has a separate **10 attempts per hour per account** counter at
`serviceRateLimits/{uid}`, updated only by the Cloud Function before calling the
LLM. Failed extraction attempts still consume a slot because the upstream call
may have incurred a cost. `resource-exhausted` includes a retry timestamp which
the app turns into a readable message. Scheduled Admin SDK sports imports bypass
client quotas, so automatic game imports do not exhaust the user's allowance.

## Deployment

The account write limiter was published to `calander-1025b` through Firebase
Console during this change. That deployment preserves the live event
email-verification check and restricts settings access to `tagRouting`; the
repository's pre-existing broader ownership/settings policy is unchanged.
Future full-file deployments should deliberately reconcile those policies.
The AI extraction limiter is implemented and tested but not deployed: the
project is currently on Spark, and Cloud Functions deployment requires Blaze.

Ship the updated Flutter app together with the Firestore rules. Old clients do
not attach a quota update and will be denied after these rules are published.
From the repository root:

```sh
firebase deploy --only firestore:rules --project calander-1025b
firebase deploy --only functions:extractEvent --project calander-1025b
```

Cloud Functions deployment requires the project's billing setup and the existing
`ANTHROPIC_API_KEY` secret. Do not deploy unrelated functions to enable this limit.

## Verification

The Flutter tests cover the boundary, expiry, account isolation, batch rejection,
the user-facing message, and Sports bottom navigation. The dedicated emulator
suite checks server enforcement, including concurrent writers and bypass attempts:

```sh
cd tests/firestore-rules
pnpm install
pnpm test
```

The emulator uses `demo-calander`; it never writes test data to the live project.
Backend extraction boundary tests are in `functions/test/rateLimiter.test.ts`.
