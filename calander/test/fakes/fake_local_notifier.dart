import 'package:calander/services/local_notifier.dart';

class ScheduledCall {
  ScheduledCall({required this.id, required this.title, required this.body, required this.fireAt});
  final int id;
  final String title;
  final String body;
  final DateTime fireAt;
}

class ShowNowCall {
  ShowNowCall({required this.id, required this.title, required this.body});
  final int id;
  final String title;
  final String body;
}

/// Records every call instead of touching a platform channel, so scheduling
/// logic can be unit tested.
class FakeLocalNotifier implements LocalNotifier {
  final List<ScheduledCall> scheduledCalls = [];
  final List<ShowNowCall> shownCalls = [];
  final List<int> cancelledIds = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    String? payload,
  }) async {
    scheduledCalls.add(ScheduledCall(id: id, title: title, body: body, fireAt: fireAt));
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shownCalls.add(ShowNowCall(id: id, title: title, body: body));
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }
}
