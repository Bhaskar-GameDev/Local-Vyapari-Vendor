import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'ui/screens/splash/splash_screen.dart';

import 'core/config/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
    final router = ref.watch(appRouter);

    return MaterialApp.router(
      title: 'Local Vyapari Vendor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        // Protect layouts from clipping by clamping text scaler within safe boundaries
        try {
          final textScaler = mediaQueryData.textScaler.clamp(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.15,
          );
          return MediaQuery(
            data: mediaQueryData.copyWith(textScaler: textScaler),
            child: child!,
          );
        } catch (_) {
          final double clampedScale = mediaQueryData.textScaleFactor.clamp(0.85, 1.15);
          return MediaQuery(
            data: mediaQueryData.copyWith(textScaleFactor: clampedScale),
            child: child!,
          );
        }
      },
    );
  }
}
