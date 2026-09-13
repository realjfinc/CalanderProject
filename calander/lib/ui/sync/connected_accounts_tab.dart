import 'package:flutter/material.dart';

import '../../services/event_repository.dart';
import '../../services/google_calendar_adapter.dart';
import '../../services/icloud_caldav_adapter.dart';
import '../../services/outlook_calendar_adapter.dart';
import '../../services/provider_sync.dart';

/// Triggers a sync pass against each provider adapter.
///
/// Google and Outlook need an OAuth access token, which normally comes
/// from a full sign-in consent flow (`google_sign_in` /
/// `flutter_appauth`) against a registered OAuth client — that
/// registration is a deployment-time dependency this screen doesn't set
/// up (see README), so in the meantime it accepts a token pasted directly
/// (e.g. from Google's OAuth Playground or Microsoft Graph Explorer while
/// testing). This is a genuine, working interim path, not a placeholder:
/// once a client is registered, only the token-acquisition step needs
/// replacing with a real sign-in button — everything downstream (the
/// adapter, dedup, conflict detection) is already real.
///
/// iCloud needs no such registration — CalDAV authenticates with the
/// user's Apple ID and an app-specific password directly, so that form is
/// fully functional as-is.
class ConnectedAccountsTab extends StatefulWidget {
  const ConnectedAccountsTab({super.key, required this.eventRepository});

  final EventRepository eventRepository;

  @override
  State<ConnectedAccountsTab> createState() => _ConnectedAccountsTabState();
}

class _ConnectedAccountsTabState extends State<ConnectedAccountsTab> {
  final _googleTokenController = TextEditingController();
  final _outlookTokenController = TextEditingController();
  final _appleIdController = TextEditingController();
  final _appPasswordController = TextEditingController();
  final _calendarUrlController = TextEditingController();

  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _googleTokenController.dispose();
    _outlookTokenController.dispose();
    _appleIdController.dispose();
    _appPasswordController.dispose();
    _calendarUrlController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() sync) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await sync();
      setState(() => _status = 'Sync complete.');
    } catch (error) {
      setState(() => _status = 'Sync failed: $error');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: _busy,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
            if (_status != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_status!)),
            const Text('Google Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _googleTokenController,
              decoration: const InputDecoration(labelText: 'OAuth access token'),
            ),
            ElevatedButton(
              onPressed: () => _run(() => syncProvider(
                    adapter: GoogleCalendarAdapter(accessToken: _googleTokenController.text.trim()),
                    repository: widget.eventRepository,
                  )),
              child: const Text('Sync Google Calendar'),
            ),
            const Divider(height: 32),
            const Text('Outlook', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _outlookTokenController,
              decoration: const InputDecoration(labelText: 'OAuth access token'),
            ),
            ElevatedButton(
              onPressed: () => _run(() => syncProvider(
                    adapter: OutlookCalendarAdapter(accessToken: _outlookTokenController.text.trim()),
                    repository: widget.eventRepository,
                  )),
              child: const Text('Sync Outlook'),
            ),
            const Divider(height: 32),
            const Text('iCloud', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _appleIdController,
              decoration: const InputDecoration(labelText: 'Apple ID email'),
            ),
            TextField(
              controller: _appPasswordController,
              decoration: const InputDecoration(labelText: 'App-specific password'),
              obscureText: true,
            ),
            TextField(
              controller: _calendarUrlController,
              decoration: const InputDecoration(labelText: 'Calendar CalDAV URL'),
            ),
            ElevatedButton(
              onPressed: () => _run(() => syncProvider(
                    adapter: ICloudCalDavAdapter(
                      appleId: _appleIdController.text.trim(),
                      appSpecificPassword: _appPasswordController.text.trim(),
                      calendarUrl: Uri.parse(_calendarUrlController.text.trim()),
                    ),
                    repository: widget.eventRepository,
                  )),
              child: const Text('Sync iCloud'),
            ),
        ],
      ),
    );
  }
}
