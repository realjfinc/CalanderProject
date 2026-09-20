import '../auth/auth_service.dart';
import 'fcm_token_registrar.dart';
import 'firestore_event_repository.dart';
import 'flutter_local_notifier.dart';
import 'local_notifier.dart';
import 'notification_reconciler.dart';
import 'notification_scheduler.dart';
import 'push_notification_service.dart';

/// Starts/stops the notification services (reminder scheduling, FCM sync
/// notifications, token registration) as the signed-in user changes.
///
/// This is wired from `main()` rather than the widget tree so it only runs
/// against the real, initialized Firebase app — it never touches Firebase
/// during widget tests, which construct `CalanderApp` directly with a fake
/// `AuthService` and never call `main()`.
class NotificationsBootstrap {
  NotificationsBootstrap({required this.auth, LocalNotifier? notifier})
    : _notifier = notifier ?? FlutterLocalNotifier();

  final AuthService auth;
  final LocalNotifier _notifier;

  String? _activeUid;
  NotificationReconciler? _reconciler;
  PushNotificationService? _pushService;
  FcmTokenRegistrar? _tokenRegistrar;

  void onAuthChanged() {
    final account = auth.account;
    final uid = !auth.deletingAccount && account != null && account.verified ? account.uid : null;
    if (uid == _activeUid) return;
    _stopAll();
    _activeUid = uid;
    if (uid == null) return;

    _reconciler = NotificationReconciler(
      events: FirestoreEventRepository(uid: uid),
      scheduler: NotificationScheduler(_notifier),
    )..start();
    _pushService = PushNotificationService(notifier: _notifier)..start();
    _tokenRegistrar = FcmTokenRegistrar(uid: uid)..start();
  }

  void _stopAll() {
    _reconciler?.stop();
    _pushService?.stop();
    _tokenRegistrar?.stop();
    _reconciler = null;
    _pushService = null;
    _tokenRegistrar = null;
  }
}
