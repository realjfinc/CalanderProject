# Calander Cloud Functions

Step 3's extraction pipeline: turns an uploaded image, PDF, or link into
structured event data via an LLM, for the client's confirm-before-commit UI.
Never writes to Firestore — extraction only proposes data; the user's
confirmation and the actual save both happen client-side.

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

## Deployment dependencies (not done by this PR)

1. **Blaze (pay-as-you-go) plan required.** The Firebase project
   (`calander-1025b`) is currently on the free Spark plan (per the main
   README). Cloud Functions that make outbound network calls (to the LLM
   API, and to fetch link content) require Blaze. This is a billing change
   only the project owner can make.
2. **`ANTHROPIC_API_KEY` secret.** Set it with:
   ```sh
   firebase functions:secrets:set ANTHROPIC_API_KEY
   ```
   before deploying. No key is bundled with this code.
3. Deploy with `firebase deploy --only functions` from the repo root, once
   the above are done.

## Local development

```sh
npm install
npm run build   # tsc
npm test        # node's built-in test runner via tsx, no network/Firebase needed
```

All tests run against fakes (`FakeLlmClient`, a stubbed `fetch`) — none of
them call a real LLM or hit the network, so they need no API key or
deployed project.
