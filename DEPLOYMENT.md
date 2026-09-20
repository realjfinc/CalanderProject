# Deploying Firebase rules and Cloud Functions

Two workflows deploy to the live `calander-1025b` Firebase project
automatically, every time a relevant change lands on `main`:

- `.github/workflows/deploy-firebase-rules.yml` — `firestore.rules` and
  `storage.rules`.
- `.github/workflows/deploy-functions.yml` — everything under
  `functions/`.

Both need a one-time credential setup before they can actually run.
Until that's done, a push that touches those paths will just fail with a
missing-secret error — nothing deploys silently or unsafely.

## Why two separate credentials, not one

- `scripts/sports_poller/`'s `FIREBASE_SERVICE_ACCOUNT_JSON` secret can
  read and write Firestore *data* (events, tags, followed teams).
- `FIREBASE_RULES_DEPLOY_SERVICE_ACCOUNT` (rules workflow) can only
  rewrite *security rules* for Firestore and Storage — a meaningfully
  more powerful permission than reading/writing data, since it changes
  what every other credential and every signed-in user is allowed to do
  at all, but still can't touch a single document or run any code.
- `FIREBASE_FUNCTIONS_DEPLOY_SERVICE_ACCOUNT` (functions workflow) can
  deploy and run arbitrary code with real data access — the biggest
  blast radius of the three.

Keeping them as separate service accounts means a leak of any one has a
smaller, more specific blast radius than a single credential that can do
everything. Don't reuse one for another.

## One-time setup: rules deploy

1. **Create a dedicated service account**, scoped to only what this
   workflow needs:
   - Go to the [Google Cloud Console → IAM & Admin → Service
     Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)
     for the `calander-1025b` project.
   - **Create service account** — name it something like
     `firebase-rules-deploy` so its purpose is obvious later.
   - Grant it **two** roles:
     - **Firebase Rules Admin** (`roles/firebaserules.admin`) — this is
       what actually deploys the rules, for both Firestore and Storage;
       it cannot read or write any Firestore document, storage object,
       or Cloud Function.
     - **Service Usage Viewer** (`roles/serviceusage.serviceUsageViewer`)
       — before every deploy, the Firebase CLI checks whether the
       project's APIs (e.g. `firestore.googleapis.com`) are enabled,
       which needs `serviceusage.services.get`. Firebase Rules Admin
       alone doesn't grant that, and the deploy fails with `403
       Permission denied to get service [firestore.googleapis.com]`
       without it. Service Usage Viewer is read-only — it can't enable,
       disable, or change anything, only check status.

2. **Generate a key** for that service account:
   - On the service account's page → **Keys** tab → **Add key** → **Create
     new key** → JSON. This downloads a `.json` file — treat it like a
     password; don't commit it anywhere.

3. **Add it as a GitHub repository secret**:
   - This repo → **Settings → Secrets and variables → Actions → New
     repository secret**.
   - Name: `FIREBASE_RULES_DEPLOY_SERVICE_ACCOUNT`
   - Value: the full contents of the downloaded JSON key file.
   - Delete the local copy of the JSON file once it's saved as the secret.

From then on, any push to `main` that touches `firestore.rules` or
`storage.rules` deploys both rule sets automatically (deploying together
is harmless even when only one file changed — the other's content is
unchanged, so its redeploy is a no-op). You can also trigger it manually
from this repo's **Actions** tab → **Deploy Firebase rules** → **Run
workflow**.

## One-time setup: functions deploy

1. **Create a second, separate service account** (see "why two separate
   credentials" above) — name it something like `firebase-functions-deploy`.
2. Grant it these roles. Cloud Functions' 2nd-gen deploy path (what this
   project uses) touches more services than rules deploy does, so this
   list is longer:
   - **Cloud Functions Admin** (`roles/cloudfunctions.admin`)
   - **Cloud Run Admin** (`roles/run.admin`) — 2nd-gen functions deploy
     as Cloud Run services under the hood.
   - **Service Account User** (`roles/iam.serviceAccountUser`) — lets
     this service account act as the functions' own runtime service
     account, which the deploy step needs to attach it.
   - **Cloud Build Editor** (`roles/cloudbuild.builds.editor`) — deploy
     triggers a Cloud Build to package the code.
   - **Artifact Registry Administrator**
     (`roles/artifactregistry.admin`) — where the built container image
     is stored.
   - **Cloud Scheduler Admin** (`roles/cloudscheduler.admin`) —
     `pollSportsEvents` is a scheduled function; deploying it manages a
     Cloud Scheduler job.
   - **Firebase Admin SDK Administrator Service Agent** is usually
     already attached automatically; if deploy fails on a permission
     this list doesn't cover, the error names the exact missing one —
     add it and retry rather than guessing further roles up front.
   - If juggling this many roles is more IAM surgery than you want, a
     single **Editor** (`roles/editor`) role on the service account
     covers all of the above (and more) with far less setup — the
     tradeoff is a bigger blast radius if that credential ever leaks.
3. **Generate a key** and **add it as a GitHub repository secret** the
   same way as the rules-deploy account above, named
   `FIREBASE_FUNCTIONS_DEPLOY_SERVICE_ACCOUNT`.
4. This is separate from (and doesn't replace) the `ANTHROPIC_API_KEY`
   secret `extractEvent` needs — that one's a Cloud Functions *runtime*
   secret set directly in the Firebase console
   (`firebase functions:secrets:set ANTHROPIC_API_KEY`), not a GitHub
   Actions secret, and only needs setting once regardless of who deploys.

From then on, any push to `main` that touches `functions/` deploys
automatically, and you can also trigger it manually from this repo's
**Actions** tab → **Deploy Cloud Functions** → **Run workflow**.

## Verifying a deploy worked

- **Actions** tab → the relevant workflow → the latest run should be
  green.
- Firebase Console → your project → Firestore Database / Storage →
  **Rules** tab → the "last published" timestamp should match when the
  rules workflow ran, and the rules text should match what's on `main`.
- Firebase Console → your project → Functions → each function's "last
  deployed" timestamp should match when the functions workflow ran.

## If you'd rather not automate this

You don't have to use either workflow — deploying by hand from your own
machine works exactly the same way it always did:

```sh
cd CalanderProject   # repo root
firebase login       # your own Google account, needs Owner/Editor on the project
firebase deploy --only firestore:rules,storage
firebase deploy --only functions
```

`.firebaserc` already points at `calander-1025b`, so no project-selection
step is needed either way.
