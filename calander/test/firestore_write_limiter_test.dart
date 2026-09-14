import 'package:calander/services/firestore_write_limiter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:calander/ui/calendar/calendar_widgets.dart';

void main() {
  testWidgets('blocked user action shows the limit and retry time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => runCalendarAction(
                context,
                () async => throw RateLimitException(
                  DateTime.now().add(const Duration(minutes: 5)),
                ),
              ),
              child: const Text('Save'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('100 changes this hour'), findsOneWidget);
    expect(find.textContaining('Try again in 5 minutes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    '100th change succeeds, 101st fails, and reads still work across clients',
    () async {
      final db = FakeFirebaseFirestore();
      final quota = db.doc('clientWriteLimits/user');
      await quota.set({'count': 99, 'windowStart': Timestamp.now()});
      final first = FirestoreWriteLimiter(firestore: db, uid: 'user');
      final second = FirestoreWriteLimiter(firestore: db, uid: 'user');
      final event = db.doc('users/user/events/test');
      await first.commit([
        event.path,
      ], (tx) => tx.set(event, {'title': 'Saved'}));
      await expectLater(
        second.commit([event.path], (tx) => tx.delete(event)),
        throwsA(isA<RateLimitException>()),
      );
      expect((await event.get()).data()?['title'], 'Saved');
      expect((await quota.get()).data()?['count'], 100);
    },
  );

  test(
    'expired window resets and another account has a separate quota',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('clientWriteLimits/user').set({
        'count': 100,
        'windowStart': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 1, minutes: 1)),
        ),
      });
      for (final uid in ['user', 'other']) {
        final limiter = FirestoreWriteLimiter(firestore: db, uid: uid);
        final event = db.doc('users/$uid/events/test');
        await limiter.commit([
          event.path,
        ], (tx) => tx.set(event, {'title': 'Saved'}));
        expect(
          (await db.doc('clientWriteLimits/$uid').get()).data()?['count'],
          1,
        );
      }
    },
  );

  test('multi-document changes cannot partially exceed the quota', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('clientWriteLimits/user').set({
      'count': 99,
      'windowStart': Timestamp.now(),
    });
    final limiter = FirestoreWriteLimiter(firestore: db, uid: 'user');
    final a = db.doc('users/user/tags/a');
    final b = db.doc('users/user/tags/b');
    await expectLater(
      limiter.commit([a.path, b.path], (tx) {
        tx.set(a, {'name': 'a'});
        tx.set(b, {'name': 'b'});
      }),
      throwsA(isA<RateLimitException>()),
    );
    expect((await a.get()).exists, isFalse);
    expect((await b.get()).exists, isFalse);
    expect((await db.doc('clientWriteLimits/user').get()).data()?['count'], 99);
  });
}
