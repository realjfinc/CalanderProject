# Privacy Policy

_Last updated September 2026_

This is also available inside the app itself: **Settings → Privacy Policy**
(and from the welcome screen, before you create an account). Both copies
describe the same policy; this file is the source most convenient to read
or link to outside the app.

## Overview

Calander ("we", "our", "the app") helps you manage your calendar, extract
events from photos, PDFs, and links, sync with other calendar providers,
and follow sports teams' schedules. This policy explains what information
we collect, how we use it — including where we use AI — and the choices
you have.

## Information We Collect

- **Account information**: your name, email address, and a securely
  hashed password, created when you sign up through Firebase
  Authentication.
- **Calendar data**: the events you create or import — titles, locations,
  start/end times, notes, tags, and attachments.
- **Uploads and links you submit for event extraction**: photos, PDF
  files, and link URLs you choose to extract event details from.
- **Connected calendar accounts**: if you connect Google Calendar,
  Outlook, or iCloud, we access and sync events from those accounts using
  the permissions you grant.
- **Followed sports teams**: teams you choose to follow in Sports Mode,
  and the game schedules synced for them.
- **Device and notification data**: a push-notification token so we can
  send you event reminders, and your device's timezone so events display
  correctly.

## How We Use AI

When you use "Add Event from Upload," the photo, PDF, or link content you
submit is sent to **Anthropic's Claude API** — a third-party AI service —
to extract a proposed event's title, location, start time, end time, and
notes.

- Only the specific file or link you submit is sent — never your other
  calendar data, account details, or contacts.
- Your device's timezone label is included only so the AI can correctly
  interpret a time that has no explicit UTC offset.
- The AI never saves anything to your calendar on its own. It returns a
  proposed, editable draft that you must review and confirm before it's
  added — you're always in control of what actually gets saved.
- Per Anthropic's API terms, content submitted through this feature is
  not used to train Anthropic's underlying models, and is retained only
  briefly for abuse and safety monitoring — not for any other purpose.
- If you keep the original photo or PDF as an attachment on the saved
  event, it's stored securely in your account's private cloud storage.
  Extraction itself doesn't otherwise retain your file.

## FTC AI Disclosure

In line with FTC guidance on disclosing the use of artificial intelligence:

- Calander uses a third-party AI model (**Anthropic's Claude**) to read a
  photo, PDF, or link you submit and propose calendar event details. This is
  an AI-assisted extraction feature, not a human reviewing your content.
- **AI output can be wrong.** The model can misread dates, times, locations,
  or other details, especially from low-quality images, ambiguous text, or
  unusual formats. Always check an extracted event before saving it.
- **No event is ever saved automatically.** Every AI-generated draft is
  shown to you for review, and you must explicitly confirm — and may edit —
  it before it's added to your calendar. AI never makes the final decision;
  you do.
- We do not use AI to profile you, score you, or make any automated
  decision that has a legal or similarly significant effect on you.

## Other Third-Party Services

- **Firebase (Google)**: powers authentication, calendar data storage,
  file storage, push notifications, and the extraction and sports-sync
  functions described above. Google processes this data on our behalf as
  our infrastructure provider.
- **TheSportsDB**: when you follow a team, we send only that team's name
  to TheSportsDB's public schedule API to fetch upcoming games — no
  personal or account information is shared with them.
- **Google Calendar, Microsoft Outlook, Apple iCloud**: if you connect
  one of these, we access your calendar through the permissions you
  explicitly grant, solely to sync events into Calander. You can
  disconnect at any time from Provider Sync in Settings.

## Data Storage & Security

Your data is stored using Firebase's cloud infrastructure with encryption
in transit and at rest. Access to your calendar is restricted to your own
signed-in, verified account through Firestore security rules — no other
user can read or write your events.

## Data Retention & Deletion

We keep your account and calendar data for as long as your account stays
active. You can delete individual events, tags, or followed teams at any
time from within the app. You can also permanently delete your entire
account and all associated data — your calendar, tags, followed teams,
and uploaded attachments — yourself, in-app, from **Settings → Delete
Account**. This is immediate and can't be undone. If you'd rather we do
it for you, contact us using the details below.

## Your Choices

- Review every AI-extracted event before it's saved — nothing is added
  automatically.
- Disconnect a connected calendar provider at any time.
- Unfollow a sports team to stop syncing its games.
- Turn off notifications from your device settings.

## Privacy Nutrition Label

A quick-reference summary of what we collect and why, similar to an app
store "privacy nutrition label." The sections above are the full policy;
this table is a shortcut, not a replacement.

| Data category | Collected? | Used for | Shared with a third party? | Linked to your identity? |
|---|---|---|---|---|
| Name, email, password | Yes | Account creation & sign-in | Firebase (infrastructure only) | Yes |
| Calendar events, notes, tags | Yes | Core app functionality | Firebase (storage only) | Yes |
| Photos/PDFs/links you submit for extraction | Yes, only what you submit | AI event extraction | Anthropic (processed, not used for training) | Yes |
| Connected calendar data (Google/Outlook/iCloud) | Only if you connect a provider | Sync events into Calander | The provider itself, via the permissions you grant | Yes |
| Followed sports teams | Only if you use Sports Mode | Show game schedules | TheSportsDB (team name only, no account data) | No |
| Push notification token & device timezone | Yes | Event reminders, correct local times | Firebase Cloud Messaging | Yes |
| Precise/background location | No | — | — | — |
| Health, financial, or browsing-history data | No | — | — | — |
| Advertising or cross-app tracking identifiers | No | — | — | — |

We do not sell your data, and we do not use your data for advertising.

## Children's Privacy

Calander is not directed at children under 13, and we do not knowingly
collect information from them.

## Changes to This Policy

We may update this policy as the app changes. We'll update the date at
the top when we do, in both this file and the in-app copy.

## Contact Us

Questions about this policy or your data? Contact us at
**privacy@calanderapp.com**.

<!-- TODO: replace with the project's real support/legal contact before shipping. -->
