import 'package:flutter/material.dart';

/// Shown for a route the app doesn't recognize -- a stale deep link, a
/// bookmarked web URL to a page that no longer exists, or any other
/// navigation to somewhere that isn't there. Wired as [MaterialApp]'s
/// `onUnknownRoute` in `app.dart`, so this is the fallback for every
/// unrecognized route, not just one specific screen's dead links.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.explore_off_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  '404',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'We couldn’t find that page.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'The link might be old, or the page may have moved.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Back to Calander'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
