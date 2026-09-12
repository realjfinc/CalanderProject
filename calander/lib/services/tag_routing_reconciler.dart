import 'dart:async';

import '../models/calendar_event.dart';
import '../models/tag_rule.dart';
import 'event_repository.dart';
import 'tag_router.dart';
import 'tag_routing_repository.dart';

/// Watches a user's events and tag-routing settings together, and assigns
/// `tag` to any currently-untagged `active` event that a rule matches.
///
/// Only acts on events where `tag == null` — an event that already has a
/// tag (whether the user set it directly or a previous run of this same
/// reconciler did) is never touched again, which is what guarantees the
/// user can always override an automatic assignment: once they change it,
/// there is nothing left for this reconciler to do to that event.
class TagRoutingReconciler {
  factory TagRoutingReconciler({required EventRepository events, required TagRoutingRepository routing}) {
    return TagRoutingReconciler._(events, routing);
  }

  TagRoutingReconciler._(this._events, this._routing);

  final EventRepository _events;
  final TagRoutingRepository _routing;

  StreamSubscription<List<CalendarEvent>>? _eventsSubscription;
  StreamSubscription<TagRoutingSettings>? _settingsSubscription;
  List<CalendarEvent> _latestEvents = const [];
  TagRoutingSettings _latestSettings = const TagRoutingSettings();

  void start() {
    _settingsSubscription ??= _routing.watchSettings().listen((settings) {
      _latestSettings = settings;
      _reconcile();
    });
    _eventsSubscription ??= _events.watchEvents().listen((events) {
      _latestEvents = events;
      _reconcile();
    });
  }

  Future<void> stop() async {
    await _eventsSubscription?.cancel();
    await _settingsSubscription?.cancel();
    _eventsSubscription = null;
    _settingsSubscription = null;
  }

  void _reconcile() {
    if (!_latestSettings.autoTagEnabled) return;
    for (final event in _latestEvents) {
      if (event.tag != null) continue;
      if (event.status != EventStatus.active) continue;
      final matchedTag = resolveAutoTag(event, _latestSettings);
      if (matchedTag != null) {
        unawaited(_events.setEventTag(event.id, matchedTag));
      }
    }
  }
}
