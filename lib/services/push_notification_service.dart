import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:coffeecore/models/coffee_disease_models.dart';
import 'package:coffeecore/models/coffee_pest_models.dart';
import 'package:coffeecore/screens/Cooperative%20Section/produce_screen.dart';
import 'package:coffeecore/screens/Field%20Data/fertilization_plan_tracker_screen.dart';
import 'package:coffeecore/screens/diseases/disease_followup_checkin_page.dart';
import 'package:coffeecore/screens/pests/pest_followup_checkin_page.dart';
import 'package:coffeecore/utils/cooperative_name.dart';

final Logger _logger = Logger(printer: PrettyPrinter());

/// Web Push certificate ("VAPID key pair") public key, generated in
/// Firebase Console → Project Settings → Cloud Messaging → Web
/// configuration. This is the PUBLIC half of the pair — it identifies the
/// sender to the browser's push service and is meant to be embedded in
/// client code (the same way DefaultFirebaseOptions.web's apiKey and the
/// Google Maps key in web/index.html already are); it is not a secret and
/// grants no send capability on its own. Only used on web — FirebaseMessaging
/// ignores it on Android/iOS, where APNs/FCM registration works differently.
const String _webPushVapidKey =
    'BLqPqutQ0XaxZ_H8riEXvhLoJhWzcGYSs9DeqgnHZMqkHGyRI0Le63DpTK2jqUfS9vcOiV2c0vn62c1dSQVeTpw';

/// Must be a top-level function (not a class method/closure) — the plugin
/// invokes this in a separate background isolate when a push arrives while
/// the app is backgrounded or terminated. FCM already renders the OS
/// notification itself from the message's `notification` payload in that
/// state, so there is nothing else this needs to do; it exists so the
/// plugin has a registered background entry point at all.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally empty — see doc comment above.
}

/// Push notifications for the follow-up reminder system (see
/// functions/index.js `sendFollowUpReminders`). This is a reliability
/// backstop alongside the local `flutter_local_notifications` scheduling
/// already done at intervention-save time (Phase 2) — it does not replace
/// it, since local scheduling already covers backgrounded/closed delivery;
/// push additionally survives alarm/permission loss and is inherently
/// gated on the device actually being online.
class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _localPluginInitialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Call once, after a user is signed in (device tokens are stored per
  /// user). Every platform call here is wrapped so a missing/incomplete
  /// platform setup (e.g. no iOS GoogleService-Info.plist yet) logs and
  /// returns quietly instead of crashing the app.
  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    try {
      await _initLocalPlugin();

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      _logger.i('Push permission status: ${settings.authorizationStatus}');

      final token = await messaging.getToken(
        vapidKey: kIsWeb ? _webPushVapidKey : null,
      );
      if (token != null) await _saveToken(token);
      messaging.onTokenRefresh.listen(_saveToken);

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

      // Cold start via notification tap — the app wasn't running at all, so
      // the navigator isn't mounted yet on this call; defer to next frame.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _handleTap(initialMessage));
      }
    } catch (e, st) {
      _logger.w('Push notification initialization failed (non-critical)',
          error: e, stackTrace: st);
    }
  }

  /// Shared local-notifications plugin instance — pest/disease management
  /// pages and the soil input page schedule their own follow-up reminders
  /// through this instead of each creating a separate
  /// `FlutterLocalNotificationsPlugin()`, so there is exactly one Android
  /// notification-channel registration for the whole app.
  static FlutterLocalNotificationsPlugin get localPlugin => _localPlugin;

  /// Idempotent — safe to call from any screen's `initState()` without
  /// re-running Android channel setup on every visit.
  static Future<void> ensureLocalPluginInitialized() => _initLocalPlugin();

  static Future<void> _initLocalPlugin() async {
    if (_localPluginInitialized) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localPlugin.initialize(settings: initSettings);
    await _localPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _localPluginInitialized = true;
  }

  static Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
      _logger.i('Saved FCM token for current user');
    } catch (e, st) {
      _logger.w('Could not save FCM token', error: e, stackTrace: st);
    }
  }

  /// FCM does not auto-display a system notification while the app is in
  /// the foreground (by design, on every platform) — this shows one via
  /// the same local-notifications plugin the rest of the app already uses.
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    try {
      await _initLocalPlugin();
      const androidDetails = AndroidNotificationDetails(
        'coffee_followup_push_channel',
        'Follow-Up Reminders',
        channelDescription: 'Push reminders for scheduled crop follow-ups',
        importance: Importance.max,
        priority: Priority.high,
      );
      await _localPlugin.show(
        id: (message.messageId ?? DateTime.now().toIso8601String()).hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(android: androidDetails),
      );
    } catch (e, st) {
      _logger.w('Could not display foreground push notification',
          error: e, stackTrace: st);
    }
  }

  /// Routes a notification tap straight to the relevant follow-up check-in
  /// screen, using the app-level navigatorKey since there's no BuildContext
  /// available when a terminated app is opened by tapping a notification.
  static Future<void> _handleTap(RemoteMessage message) async {
    final type = message.data['type'];
    if (type == null) return;

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    if (type == 'produce_value_confirmation') {
      // Lands the farmer on ProduceScreen, whose pending-confirmations
      // banner (see produce_screen.dart) surfaces this exact submission's
      // Accept/Decline actions — there's no separate confirmation screen,
      // this is already the one place a farmer sees and acts on it.
      final coopId = message.data['coopId'];
      if (coopId == null) return;
      try {
        navigator.push(MaterialPageRoute(
          builder: (_) =>
              ProduceScreen(cooperativeName: coopIdToDisplayName(coopId)),
        ));
      } catch (e, st) {
        _logger.w('Could not open Produce screen from notification tap',
            error: e, stackTrace: st);
      }
      return;
    }

    final interventionId = message.data['interventionId'];
    final collectionName = message.data['collection'];
    if (interventionId == null || collectionName == null) {
      return;
    }

    try {
      if (type == 'fertilizer_followup') {
        // Opens the whole tracker, not a single-week screen — a plan is a
        // multi-week checklist, unlike the single yes/no pest/disease check.
        navigator.push(MaterialPageRoute(
          builder: (_) => const FertilizationPlanTrackerScreen(),
        ));
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(interventionId)
          .get();
      if (!doc.exists) return;

      if (type == 'pest_followup') {
        final intervention = CoffeePestIntervention.fromFirestore(doc, null);
        navigator.push(MaterialPageRoute(
          builder: (_) => PestFollowUpCheckinPage(
            intervention: intervention,
            notificationsPlugin: _localPlugin,
          ),
        ));
      } else if (type == 'disease_followup') {
        final intervention = CoffeeDiseaseIntervention.fromFirestore(doc, null);
        navigator.push(MaterialPageRoute(
          builder: (_) => DiseaseFollowUpCheckinPage(
            intervention: intervention,
            notificationsPlugin: _localPlugin,
          ),
        ));
      }
    } catch (e, st) {
      _logger.w('Could not open follow-up check-in from notification tap',
          error: e, stackTrace: st);
    }
  }
}
