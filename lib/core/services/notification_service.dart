import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../../firebase_options.dart';
import '../config/app_router.dart';
import '../providers/navigation_provider.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase already initialized or failed in background: $e');
  }
}

final notificationServiceProvider = Provider((ref) {
  final service = NotificationService(ref);
  service.init();
  return service;
});

class NotificationService {
  final Ref _ref;
  bool _initialized = false;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Notification that launched the app from a terminated state. We can't act on
  // it immediately because the app still has to boot through the splash and
  // restore auth/shop state. It's stashed here and replayed by
  // [consumePendingNotification] once the home screen is actually mounted.
  // The intent survives login/onboarding (it isn't cleared until the home
  // screen consumes it), so a logged-out tap still lands on the right screen
  // after the vendor signs in.
  RemoteMessage? _pendingMessage;
  DateTime? _pendingMessageAt;

  // How long a stashed launch notification stays actionable. Long enough to
  // cover a phone-OTP login + onboarding, short enough that re-opening the app
  // much later doesn't yank the vendor into a stale chat.
  static const Duration _pendingMessageTtl = Duration(minutes: 10);

  NotificationService(this._ref);

  void init() {
    if (_initialized) return;
    _initialized = true;

    _initLocalNotifications();
    _initFirebaseMessaging();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _syncDeviceRegistration();
      }
    });
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          try {
            final payload = response.payload;
            if (payload != null && payload.isNotEmpty) {
              final data = json.decode(payload) as Map<String, dynamic>;
              _routeNotification(data);
            }
          } catch (e) {
            debugPrint('Error handling local notification click: $e');
          }
        },
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await _createNotificationChannels(androidImplementation);
      }
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  /// Registers the notification channels up front so FCM messages that arrive
  /// while the app is terminated render with the right importance/sound. The
  /// backend targets `chat_messages` by channelId; on Android 8+ a message
  /// pointing at a non-existent channel falls back to a low-importance default
  /// (no heads-up, no sound). Channel settings are immutable once created, so
  /// these must match the AndroidNotificationDetails used in
  /// [_showNativeNotification].
  Future<void> _createNotificationChannels(
    AndroidFlutterLocalNotificationsPlugin android,
  ) async {
    const chatChannel = AndroidNotificationChannel(
      'chat_messages',
      'Customer Messages',
      description: 'Notifications for new customer chat messages',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const vendorChannel = AndroidNotificationChannel(
      'vendor_channel_id',
      'Vendor Alerts',
      description: 'Notifications for orders and store activity',
      importance: Importance.max,
      playSound: true,
    );

    await android.createNotificationChannel(chatChannel);
    await android.createNotificationChannel(vendorChannel);
  }

  Future<void> _showNativeNotification(
    String title,
    String body, {
    String? payload,
    bool isChatMessage = false,
  }) async {
    final AndroidNotificationDetails androidDetails = isChatMessage
        ? const AndroidNotificationDetails(
            'chat_messages',
            'Customer Messages',
            channelDescription: 'Notifications for new customer chat messages',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
          )
        : const AndroidNotificationDetails(
            'vendor_channel_id',
            'Vendor Alerts',
            channelDescription: 'Notifications for orders and store activity',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            playSound: true,
          );

    final platformDetails = NotificationDetails(android: androidDetails);
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error displaying native notification: $e');
    }
  }

  Future<void> _initFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        final title = notification.title ?? 'New Alert';
        final body = notification.body ?? 'Check the app for details';
        final isChatMessage = message.data['type'] == 'chat';
        final payload = json.encode(message.data);
        _showNativeNotification(title, body,
            payload: payload, isChatMessage: isChatMessage);
      }
    });

    // Handle message opened when app is in background (but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM message opened from background: ${message.messageId}');
      _handleNotificationClick(message);
    });

    // Check if the app was opened from a terminated state via a notification.
    // Don't navigate now: the app is still booting through the splash screen,
    // and the splash does its own `go('/')` after ~2s which would wipe any
    // route we push here. Stash it and let the home screen replay it once it's
    // mounted (see consumePendingNotification).
    messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint(
            'FCM message opened from terminated state: ${message.messageId}');
        _pendingMessage = message;
        _pendingMessageAt = DateTime.now();
      }
    });

    messaging.onTokenRefresh.listen((token) {
      _syncDeviceRegistration();
    });
  }

  /// Replays a notification that launched the app from a terminated state.
  /// Called by the home screen once it's mounted, so navigation lands on a
  /// settled, authenticated app instead of racing the splash screen. If the
  /// vendor had to log in / onboard first, the intent waited here for them;
  /// stale intents (older than [_pendingMessageTtl]) are dropped quietly.
  void consumePendingNotification() {
    final message = _pendingMessage;
    final at = _pendingMessageAt;
    _pendingMessage = null;
    _pendingMessageAt = null;
    if (message == null) return;
    if (at != null && DateTime.now().difference(at) > _pendingMessageTtl) {
      debugPrint('Dropping stale launch notification: ${message.messageId}');
      return;
    }
    _handleNotificationClick(message);
  }

  void _handleNotificationClick(RemoteMessage message) {
    try {
      _routeNotification(
        Map<String, dynamic>.from(message.data),
        fallbackUserName: message.notification?.title,
      );
    } catch (e) {
      debugPrint('Error handling FCM notification click: $e');
    }
  }

  /// Central deep-link router for a notification's data payload. Every entry
  /// point — foreground tap, background tap, and cold-start replay — funnels
  /// through here so navigation behaves identically regardless of how the app
  /// was opened. The backend always stamps a string `type` discriminator (and
  /// any IDs the client needs) on the data payload; see functions/src/index.ts.
  void _routeNotification(Map<String, dynamic> data,
      {String? fallbackUserName}) {
    switch (data['type']?.toString()) {
      case 'chat':
        _navigateToChat(
          userId:
              data['userId']?.toString() ?? data['senderId']?.toString() ?? '',
          userName:
              data['userName']?.toString() ?? fallbackUserName ?? 'Customer',
        );
        break;
      case 'security_new_device':
        // "New sign-in detected" alert (recordDeviceAndMaybeAlert in the
        // backend). Take the vendor straight to the security screen where they
        // can review devices and sign out everywhere.
        _navigateToSecurity();
        break;
    }
  }

  void _navigateToSecurity() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).push('/security');
  }

  void _navigateToChat({required String userId, required String userName}) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    // First land on main nav with the Chats tab selected.
    _ref.read(navigationIndexProvider.notifier).setIndex(3);
    GoRouter.of(context).go('/');

    // Then push the specific chat after the navigation settles.
    if (userId.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 350), () {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          // ignore: use_build_context_synchronously
          GoRouter.of(ctx)
              .push('/chat', extra: {'userId': userId, 'userName': userName});
        }
      });
    }
  }

  Future<void> _syncDeviceRegistration() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final dbRef =
          FirebaseDatabase.instance.ref('users_devices/${user.uid}/merchant');

      final Map<String, dynamic> data = {
        'fcmToken': token,
        'updatedAt': ServerValue.timestamp,
      };

      await dbRef.update(data);
      debugPrint(
          'Device registration synced to RTDB for user: ${user.uid} (merchant)');
    } catch (e) {
      debugPrint('Error syncing device registration: $e');
    }
  }
}
