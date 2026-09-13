import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'local_notifier.dart';

/// Handles FCM messages for synced-event changes (e.g. a provider adapter,
/// in a later step, updates or removes an event that already had local
/// reminders scheduled) by surfacing them as a local notification.
///
/// Only messages carrying `data['type'] == 'event_change'` are surfaced;
/// anything else is ignored so this doesn't turn into a catch-all push
/// handler for features that don't exist yet.
class PushNotificationService {
  factory PushNotificationService({required LocalNotifier notifier, Stream<RemoteMessage>? onMessage}) {
    return PushNotificationService._(notifier, onMessage ?? FirebaseMessaging.onMessage);
  }

  PushNotificationService._(this._notifier, this._onMessage);

  static const _eventChangeType = 'event_change';

  final LocalNotifier _notifier;
  final Stream<RemoteMessage> _onMessage;
  StreamSubscription<RemoteMessage>? _subscription;

  void start() {
    _subscription ??= _onMessage.listen(handleMessage);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Exposed directly (not just via [start]) so the background message
  /// handler can reuse the same logic in its own isolate.
  Future<void> handleMessage(RemoteMessage message) async {
    if (message.data['type'] != _eventChangeType) return;

    final eventId = message.data['eventId'] as String? ?? message.messageId ?? 'unknown';
    final title = message.notification?.title ?? (message.data['title'] as String?) ?? 'Calendar updated';
    final body =
        message.notification?.body ??
        (message.data['body'] as String?) ??
        'One of your synced events changed.';

    await _notifier.showNow(
      id: stableNotificationId(eventId, 'sync'),
      title: title,
      body: body,
    );
  }
}
