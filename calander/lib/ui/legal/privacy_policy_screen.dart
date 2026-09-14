import 'package:flutter/material.dart';

import '../calendar/calendar_widgets.dart';

/// Static privacy policy, reachable from Settings (signed in) and from the
/// welcome screen (signed out) so it's visible before account creation too.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => CalendarPage(
    title: 'Privacy Policy',
    subtitle: 'Last updated September 2026',
    onBack: () => Navigator.pop(context),
    children: const [
      _Section(
        heading: 'Overview',
        paragraphs: [
          'Calander ("we", "our", "the app") helps you manage your '
              'calendar, extract events from photos, PDFs, and links, sync '
              'with other calendar providers, and follow sports teams’ '
              'schedules. This policy explains what information we '
              'collect, how we use it — including where we use AI — '
              'and the choices you have.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: 'Information We Collect',
        bullets: [
          'Account information: your name, email address, and a securely '
              'hashed password, created when you sign up through Firebase '
              'Authentication.',
          'Calendar data: the events you create or import — titles, '
              'locations, start/end times, notes, tags, and attachments.',
          'Uploads and links you submit for event extraction: photos, PDF '
              'files, and link URLs you choose to extract event details '
              'from.',
          'Connected calendar accounts: if you connect Google Calendar, '
              'Outlook, or iCloud, we access and sync events from those '
              'accounts using the permissions you grant.',
          'Followed sports teams: teams you choose to follow in Sports '
              'Mode, and the game schedules synced for them.',
          'Device and notification data: a push-notification token so we '
              'can send you event reminders, and your device’s timezone '
              'so events display correctly.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: 'How We Use AI',
        paragraphs: [
          'When you use "Add Event from Upload," the photo, PDF, or link '
              'content you submit is sent to Anthropic’s Claude API — a '
              'third-party AI service — to extract a proposed event’s '
              'title, location, start time, end time, and notes.',
        ],
        bullets: [
          'Only the specific file or link you submit is sent — never '
              'your other calendar data, account details, or contacts.',
          'Your device’s timezone label is included only so the AI can '
              'correctly interpret a time that has no explicit UTC offset.',
          'The AI never saves anything to your calendar on its own. It '
              'returns a proposed, editable draft that you must review and '
              'confirm before it’s added — you’re always in control of '
              'what actually gets saved.',
          'Per Anthropic’s API terms, content submitted through this '
              'feature is not used to train Anthropic’s underlying '
              'models, and is retained only briefly for abuse and safety '
              'monitoring — not for any other purpose.',
          'If you keep the original photo or PDF as an attachment on the '
              'saved event, it’s stored securely in your account’s '
              'private cloud storage. Extraction itself doesn’t '
              'otherwise retain your file.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: 'Other Third-Party Services',
        bullets: [
          'Firebase (Google): powers authentication, calendar data '
              'storage, file storage, push notifications, and the '
              'extraction and sports-sync functions described above. '
              'Google processes this data on our behalf as our '
              'infrastructure provider.',
          'TheSportsDB: when you follow a team, we send only that team’s '
              'name to TheSportsDB’s public schedule API to fetch '
              'upcoming games — no personal or account information is '
              'shared with them.',
          'Google Calendar, Microsoft Outlook, Apple iCloud: if you '
              'connect one of these, we access your calendar through the '
              'permissions you explicitly grant, solely to sync events '
              'into Calander. You can disconnect at any time from '
              'Provider Sync in Settings.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: 'Data Storage & Security',
        paragraphs: [
          'Your data is stored using Firebase’s cloud infrastructure with '
              'encryption in transit and at rest. Access to your calendar '
              'is restricted to your own signed-in, verified account '
              'through Firestore security rules — no other user can read '
              'or write your events.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: 'Data Retention & Deletion',
        paragraphs: [
          'We keep your account and calendar data for as long as your '
              'account stays active. You can delete individual events, '
              'tags, or followed teams at any time from within the app. '
              'To delete your account and all associated data, contact us '
              'using the details below.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: 'Your Choices',
        bullets: [
          'Review every AI-extracted event before it’s saved — nothing '
              'is added automatically.',
          'Disconnect a connected calendar provider at any time.',
          'Unfollow a sports team to stop syncing its games.',
          'Turn off notifications from your device settings.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: 'Children’s Privacy',
        paragraphs: [
          'Calander is not directed at children under 13, and we do not '
              'knowingly collect information from them.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: 'Changes to This Policy',
        paragraphs: [
          'We may update this policy as the app changes. We’ll update '
              'the date at the top when we do.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: 'Contact Us',
        paragraphs: [
          'Questions about this policy or your data? Contact us at '
              'privacy@calanderapp.com.',
        ],
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.heading, this.paragraphs = const [], this.bullets = const []});

  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) => CalendarPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        for (final paragraph in paragraphs) ...[
          const SizedBox(height: 10),
          Text(paragraph, style: Theme.of(context).textTheme.bodyMedium),
        ],
        for (final bullet in bullets) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(bullet, style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
        ],
      ],
    ),
  );
}
