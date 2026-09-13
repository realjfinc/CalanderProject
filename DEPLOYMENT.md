# Deploying Firestore rules

`.github/workflows/deploy-firestore-rules.yml` deploys `firestore.rules`
to the live `calander-1025b` Firebase project automatically, every time a
change to that file lands on `main`. This is the one-time setup it needs
to actually run.

## Why a separate credential from the sports poller

`scripts/sports_poller/`'s `FIREBASE_SERVICE_ACCOUNT_JSON` secret can read
and write Firestore *data* (events, tags, followed teams). This workflow
needs a credential that can deploy Firestore *security rules* instead —
a meaningfully more powerful permission, since it can change what every
other credential and every signed-in user is allowed to do at all. Keeping
them as two separate service accounts means a leak of either one has a
smaller, more specific blast radius than a single credential that can do
both. Don't reuse one for the other.

## One-time setup

1. **Create a dedicated service account**, scoped to only what this
   workflow needs:
   - Go to the [Google Cloud Console → IAM & Admin → Service
     Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)
     for the `calander-1025b` project.
   - **Create service account** — name it something like
     `firestore-rules-deploy` so its purpose is obvious later.
   - Grant it exactly one role: **Firebase Rules Admin**
     (`roles/firebaserules.admin`). That's enough to deploy rules; it
     cannot read or write any Firestore document, storage object, or
     Cloud Function.

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

That's it. From then on, any push to `main` that touches `firestore.rules`
deploys automatically, and you can also trigger it manually from this
repo's **Actions** tab → **Deploy Firestore rules** → **Run workflow**.

## Verifying a deploy worked

- **Actions** tab → **Deploy Firestore rules** → the latest run should be
  green.
- Firebase Console → your project → Firestore Database → **Rules** tab →
  the "last published" timestamp should match when the workflow ran, and
  the rules text should match what's in `firestore.rules` on `main`.

## If you'd rather not automate this

You don't have to use this workflow at all — deploying by hand from your
own machine works exactly the same way it always did:

```sh
cd CalanderProject   # repo root
firebase login       # your own Google account, needs Owner/Editor on the project
firebase deploy --only firestore:rules
```

`.firebaserc` already points at `calander-1025b`, so no project-selection
step is needed either way.
