import '../auth/auth_service.dart';
import 'firestore_event_repository.dart';
import 'firestore_tag_routing_repository.dart';
import 'tag_routing_reconciler.dart';

/// Starts/stops the [TagRoutingReconciler] as the signed-in user changes.
///
/// Wired from `main()` rather than the widget tree, same reasoning as
/// notifications: it should only run against the real, initialized
/// Firebase app, and must never activate during widget tests that
/// construct `CalanderApp` directly with a fake `AuthService` and never
/// call `main()`.
class TagRoutingBootstrap {
  TagRoutingBootstrap({required this.auth});

  final AuthService auth;

  String? _activeUid;
  TagRoutingReconciler? _reconciler;

  void onAuthChanged() {
    final account = auth.account;
    final uid = !auth.deletingAccount && account != null && account.verified ? account.uid : null;
    if (uid == _activeUid) return;
    _reconciler?.stop();
    _reconciler = null;
    _activeUid = uid;
    if (uid == null) return;

    _reconciler = TagRoutingReconciler(
      events: FirestoreEventRepository(uid: uid),
      routing: FirestoreTagRoutingRepository(uid: uid),
    )..start();
  }
}
