import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/ui/legal/privacy_policy_screen.dart';

void main() {
  testWidgets('shows the AI usage disclosure and other required sections', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PrivacyPolicyScreen()),
    );

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('How We Use AI'), findsOneWidget);
    expect(find.textContaining('Anthropic'), findsWidgets);
    expect(find.text('Information We Collect'), findsOneWidget);
    expect(find.text('Other Third-Party Services'), findsOneWidget);
    expect(find.text('Children’s Privacy'), findsOneWidget);
    expect(find.text('Contact Us'), findsOneWidget);
  });

  testWidgets('back button pops the screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsNothing);
  });
}
