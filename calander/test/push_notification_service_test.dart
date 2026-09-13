import 'package:calander/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_local_notifier.dart';

void main() {
  test('shows a notification for an event_change message', () async {
    final notifier = FakeLocalNotifier();
    final service = PushNotificationService(notifier: notifier);

    await service.handleMessage(
      const RemoteMessage(
        data: {'type': 'event_change', 'eventId': 'evt-1'},
        notification: RemoteNotification(title: 'Meeting moved', body: 'Now starts at 3pm'),
      ),
    );

    expect(notifier.shownCalls, hasLength(1));
    expect(notifier.shownCalls.single.title, 'Meeting moved');
    expect(notifier.shownCalls.single.body, 'Now starts at 3pm');
  });

  test('ignores messages that are not event_change', () async {
    final notifier = FakeLocalNotifier();
    final service = PushNotificationService(notifier: notifier);

    await service.handleMessage(const RemoteMessage(data: {'type': 'something_else'}));
    await service.handleMessage(const RemoteMessage());

    expect(notifier.shownCalls, isEmpty);
  });

  test('falls back to data title/body when there is no notification payload', () async {
    final notifier = FakeLocalNotifier();
    final service = PushNotificationService(notifier: notifier);

    await service.handleMessage(
      const RemoteMessage(
        data: {'type': 'event_change', 'eventId': 'evt-2', 'title': 'Synced update', 'body': 'Details changed'},
      ),
    );

    expect(notifier.shownCalls.single.title, 'Synced update');
    expect(notifier.shownCalls.single.body, 'Details changed');
  });

  test('the same eventId always maps to the same notification id', () async {
    final notifier = FakeLocalNotifier();
    final service = PushNotificationService(notifier: notifier);

    await service.handleMessage(const RemoteMessage(data: {'type': 'event_change', 'eventId': 'evt-3'}));
    await service.handleMessage(const RemoteMessage(data: {'type': 'event_change', 'eventId': 'evt-3'}));

    expect(notifier.shownCalls[0].id, notifier.shownCalls[1].id);
  });
}
