import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase already initialized or failed in background: $e");
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

  Future<void> _showNativeNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'vendor_channel_id',
      'Vendor Alerts',
      channelDescription: 'Notifications for new orders and store activity',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
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
        _showNativeNotification(title, body);
      }
    });

    messaging.onTokenRefresh.listen((token) {
      _syncDeviceRegistration();
    });
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
