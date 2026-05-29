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
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

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

    const InitializationSettings initializationSettings = InitializationSettings(
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
              if (data['type'] == 'chat') {
                _navigateToChat(
                  userId: data['userId']?.toString() ?? data['senderId']?.toString() ?? '',
                  userName: data['userName']?.toString() ?? 'Customer',
                );
              }
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
      }
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
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
        _showNativeNotification(title, body, payload: payload, isChatMessage: isChatMessage);
      }
    });

    // Handle message opened when app is in background (but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM message opened from background: ${message.messageId}');
      _handleNotificationClick(message);
    });

    // Check if the app was opened from a terminated state via a notification
    messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('FCM message opened from terminated state: ${message.messageId}');
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleNotificationClick(message);
        });
      }
    });

    messaging.onTokenRefresh.listen((token) {
      _syncDeviceRegistration();
    });
  }

  void _handleNotificationClick(RemoteMessage message) {
    try {
      if (message.data['type'] == 'chat') {
        _navigateToChat(
          userId: message.data['userId']?.toString() ?? message.data['senderId']?.toString() ?? '',
          userName: message.data['userName']?.toString() ?? message.notification?.title ?? 'Customer',
        );
      }
    } catch (e) {
      debugPrint('Error handling FCM notification click: $e');
    }
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
          GoRouter.of(ctx).push('/chat', extra: {'userId': userId, 'userName': userName});
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

      final dbRef = FirebaseDatabase.instance.ref('users_devices/${user.uid}/merchant');

      final Map<String, dynamic> data = {
        'fcmToken': token,
        'updatedAt': ServerValue.timestamp,
      };

      await dbRef.update(data);
      debugPrint('Device registration synced to RTDB for user: ${user.uid} (merchant)');
    } catch (e) {
      debugPrint('Error syncing device registration: $e');
    }
  }
}
