import 'package:firebase_core/firebase_core.dart';
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

  // Catch uncaught Flutter framework errors (widget build failures, etc.)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) debugPrint('[FlutterError] ${details.exception}\n${details.stack}');
  };

  // Catch uncaught async errors that escape the Flutter framework zone
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) debugPrint('[Unhandled] $error\n$stack');
    return true;
  };

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize API client
  ApiClient.initialize();

  // Enable local caching / offline persistence
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
