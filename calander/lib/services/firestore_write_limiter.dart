import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared by every device signed into the same account. Reads are not limited.
class RateLimitException implements Exception {
  const RateLimitException(
    this.retryAt, {
    this.limit = 100,
    this.action = 'changes',
  });
  final DateTime retryAt;
  final int limit;
  final String action;

  String get message {
    final minutes = retryAt.difference(DateTime.now()).inSeconds / 60;
    final wait = minutes.ceil().clamp(1, 60);
    return 'You’ve reached $limit $action this hour. Try again in '
        '$wait ${wait == 1 ? 'minute' : 'minutes'}. You can still view your calendar.';
  }

  @override
  String toString() => message;
}

/// Commits both the quota and the changed documents atomically. Security rules
/// validate the server timestamp, counter increment, and exact document paths.
/// Transactions require a connection; a rejected write never consumes quota.
class FirestoreWriteLimiter {
  FirestoreWriteLimiter({
    required this.firestore,
    required this.uid,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const hourlyLimit = 100;
  final FirebaseFirestore firestore;
  final String uid;
  final DateTime Function() _now;

  Future<void> commit(
    List<String> paths,
    void Function(Transaction) write,
  ) async {
    if (paths.isEmpty ||
        paths.length > 20 ||
        paths.toSet().length != paths.length ||
        paths.any((path) => !path.startsWith('users/$uid/'))) {
      throw ArgumentError(
        'Expected 1–20 distinct documents belonging to this user.',
      );
    }
    final quota = firestore.collection('clientWriteLimits').doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(quota);
      final data = snapshot.data();
      final startedAt = (data?['windowStart'] as Timestamp?)?.toDate();
      final expired =
          startedAt == null ||
          !_now().isBefore(startedAt.add(const Duration(hours: 1)));
      final count = expired ? 0 : (data?['count'] as int? ?? 0);
      if (count + paths.length > hourlyLimit) {
        throw RateLimitException(startedAt!.add(const Duration(hours: 1)));
      }
      write(transaction);
      transaction.set(quota, {
        'windowStart': expired
            ? FieldValue.serverTimestamp()
            : data!['windowStart'],
        'count': count + paths.length,
        'paths': paths,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
