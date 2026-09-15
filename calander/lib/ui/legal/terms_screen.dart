import 'package:flutter/material.dart';

import '../calendar/calendar_widgets.dart';

/// Static Terms and Conditions, reachable from Settings (signed in) and
/// from the welcome screen (signed out) so it's visible before account
/// creation too. Mirrors TERMS.md at the repo root.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => CalendarPage(
    title: 'Terms and Conditions',
    subtitle: 'Last updated September 2026',
    onBack: () => Navigator.pop(context),
    children: const [
      _Section(
        heading: 'Notice',
        paragraphs: [
          'This document is provided as a starting point, not a '
              'substitute for legal advice. The Arbitration and Class '
              'Action Waiver section has state- and country-specific '
              'enforceability requirements, and the DMCA section’s '
              'Designated Agent must be registered with the U.S. '
              'Copyright Office to receive full safe-harbor protection. '
              'Have a qualified attorney review this document before '
              'relying on it.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '1. Acceptance of Terms',
        paragraphs: [
          'By creating an account or using Calander (“we”, “our”, “the '
              'app”), you agree to these Terms and Conditions and to our '
              'Privacy Policy. If you don’t agree, don’t use the app.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '2. The Service',
        paragraphs: [
          'Calander helps you manage your calendar, extract events from '
              'photos, PDFs, and links using AI, sync with other calendar '
              'providers, and follow sports teams’ schedules. Features may '
              'change, and we may add, modify, or remove features at any '
              'time.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '3. Your Account',
        paragraphs: [
          'You’re responsible for keeping your login credentials secure '
              'and for all activity under your account. Tell us right '
              'away if you suspect unauthorized access to your account.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '4. User Content',
        paragraphs: [
          '“User Content” means anything you upload, submit, or create '
              'through Calander — calendar events, notes, photos, PDFs, '
              'and links you submit for extraction.',
        ],
        bullets: [
          'You own your User Content. We don’t claim ownership of it. '
              'You grant us a limited license to store, process, and '
              'display it solely to provide the app’s functionality to '
              'you.',
          'You’re responsible for your User Content. Don’t upload '
              'anything you don’t have the right to share, anything that '
              'infringes someone else’s rights, or anything illegal, '
              'abusive, or harmful.',
          'No fake testimonials or reviews. You may not post, submit, or '
              'ask anyone else to post fabricated, paid-for-and-'
              'undisclosed, or otherwise deceptive testimonials, reviews, '
              'or endorsements about Calander. We do not create, edit, or '
              'publish fake user testimonials ourselves, and we do not '
              'misrepresent AI-generated content as a real user’s '
              'independent review.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '5. User Content Liability and DMCA Takedown Policy',
        paragraphs: [
          'Calander is a platform that stores and displays content you '
              'and other users submit (“user-generated content” or UGC). '
              'We do not pre-screen UGC before it’s saved to your '
              'account, and — consistent with the safe harbor under 17 '
              'U.S.C. § 512 (the DMCA) — we are not liable for UGC we did '
              'not create, provided we respond appropriately to valid '
              'takedown notices.',
          'If you believe content accessible through Calander infringes '
              'your copyright, send a written notice to our Designated '
              'Agent that includes your signature, identification of the '
              'copyrighted work and the infringing material, your contact '
              'information, a good-faith statement, and a statement made '
              'under penalty of perjury that you’re authorized to act on '
              'the copyright owner’s behalf.',
          'Designated Agent for Copyright Notices: dmca@calanderapp.com '
              '(placeholder — action required: this contact must be '
              'registered with the U.S. Copyright Office’s DMCA agent '
              'directory to provide real safe-harbor protection).',
          'If your content was removed and you believe that was a '
              'mistake, you may submit a counter-notice. We may terminate '
              'the accounts of users determined to be repeat infringers.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '6. How We Use AI',
        paragraphs: [
          'Our AI-assisted event extraction feature is described in '
              'detail in the Privacy Policy, including the FTC AI '
              'Disclosure section. In short: AI output is a draft only, '
              'can be inaccurate, and is never saved to your calendar '
              'without your explicit review and confirmation.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '7. Prohibited Conduct',
        bullets: [
          'Use the app for any unlawful purpose or in violation of these '
              'Terms.',
          'Attempt to gain unauthorized access to another user’s account '
              'or data.',
          'Interfere with or disrupt the app’s infrastructure, including '
              'circumventing rate limits or security controls.',
          'Reverse-engineer, scrape, or use automated means to access the '
              'app beyond normal, individual use.',
          'Upload malicious code or content that infringes another '
              'person’s intellectual property or privacy rights.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '8. Disclaimers',
        paragraphs: [
          'The app is provided “as is” and “as available,” without '
              'warranties of any kind, express or implied. AI-extracted '
              'event details may be inaccurate — you’re responsible for '
              'reviewing them before relying on them.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '9. Limitation of Liability',
        paragraphs: [
          'To the maximum extent permitted by law, Calander and its '
              'operators are not liable for any indirect, incidental, '
              'special, consequential, or punitive damages, or any loss '
              'of data, arising from your use of the app. Our total '
              'liability for any claim is limited to the amount you paid '
              'us, if any, in the twelve months before the claim arose.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '10. Arbitration and Class Action Waiver',
        paragraphs: [
          'Read this section carefully — it affects your legal rights, '
              'including your right to file a lawsuit in court.',
        ],
        bullets: [
          'Agreement to arbitrate: you and Calander agree that any '
              'dispute arising out of or relating to these Terms or your '
              'use of the app will be resolved by binding, individual '
              'arbitration rather than in court, except that either party '
              'may bring an individual claim in small-claims court if it '
              'qualifies.',
          'Class action waiver: arbitration or any proceeding will be '
              'conducted only on an individual basis, not as a class, '
              'consolidated, or representative action.',
          'Arbitration will be administered by a recognized arbitration '
              'organization under its consumer arbitration rules, before '
              'a single arbitrator, with a final and binding decision.',
          'Opt-out: you may opt out of this arbitration agreement by '
              'sending written notice within 30 days of first accepting '
              'these Terms.',
          'Severability: if the class action waiver is found '
              'unenforceable as to a particular claim, that claim '
              'proceeds in court instead; the rest of this section '
              'remains in effect.',
          'This clause is a template — enforceability varies by '
              'jurisdiction. Have an attorney confirm it before relying '
              'on it.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '11. Termination',
        paragraphs: [
          'You may stop using the app and permanently delete your account '
              'at any time from Settings → Delete Account — this '
              'immediately and permanently removes your account and all '
              'associated data and can’t be undone. We may suspend or '
              'terminate your access if you violate these Terms.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '12. Changes to These Terms',
        paragraphs: [
          'We may update these Terms as the app changes. We’ll update the '
              'date at the top when we do, in both this file and the '
              'in-app copy.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: '13. Governing Law',
        paragraphs: [
          'These Terms are governed by the laws of the jurisdiction in '
              'which Calander operates, without regard to conflict-of-law '
              'principles, except where the Federal Arbitration Act '
              'governs Section 10 above.',
        ],
      ),
      SizedBox(height: 16),
      _Section(
        heading: 'Contact Us',
        paragraphs: [
          'Questions about these Terms? Contact us at '
              'legal@calanderapp.com.',
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
