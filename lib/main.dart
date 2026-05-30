import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

import 'core/network/api_client.dart';
import 'core/config/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/providers/theme_provider.dart';
import 'ui/common/connectivity_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check: attests that requests come from a genuine, untampered build.
  // Debug provider in debug builds; Play Integrity / DeviceCheck in release.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode
        ? AndroidAppCheckProvider.playIntegrity
        : AndroidAppCheckProvider.debug,
    providerApple:
        kReleaseMode ? AppleAppCheckProvider.deviceCheck : AppleAppCheckProvider.debug,
  );

  // Crashlytics: collect only in release builds (keeps debug noise out of the console).
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  // Route uncaught Flutter framework errors (widget build failures, etc.) to Crashlytics.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('[FlutterError] ${details.exception}\n${details.stack}');
    } else {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };

  // Route uncaught async errors that escape the Flutter framework zone to Crashlytics.
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('[Unhandled] $error\n$stack');
    } else {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  // Initialize API client
  ApiClient.initialize();

  // Firestore: cap offline cache at 50 MB (default is 100 MB, grows unbounded)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 50 * 1024 * 1024,
  );

  // RTDB: enable persistence with a 5 MB cap (stores structure, not images)
  FirebaseDatabase.instance.setPersistenceCacheSizeBytes(5 * 1024 * 1024);
  FirebaseDatabase.instance.setPersistenceEnabled(true);

  runApp(
    const ProviderScope(
      child: LocalVyapariVendorApp(),
    ),
  );
}

class LocalVyapariVendorApp extends ConsumerWidget {
  const LocalVyapariVendorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize notification service
    ref.watch(notificationServiceProvider);

    final router = ref.watch(appRouter);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Local Vyapari Vendor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
          child: ConnectivityBanner(child: child!),
        );
      },
    );
  }
}
