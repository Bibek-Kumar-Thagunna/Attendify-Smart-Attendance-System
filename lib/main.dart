import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/firestore_init.dart';
import 'core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/offline_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'app.dart';
import 'error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Ensure session persistence
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } catch (e) {
    debugPrint('Error setting auth persistence: $e');
  }

  // Log required indexes for reference
  final firestoreInit = FirestoreInitService();
  firestoreInit.logRequiredIndexes();

  // Initialize Notifications
  await NotificationService().initialize();

  // Set edge-to-edge system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // For dark background
      systemNavigationBarColor: Color(0xFF0B1121), // Match app background
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // In release mode, show the friendly error screen
    if (!kDebugMode) {
      runApp(ErrorApp(details: details));
    }
  };

  // Run app in a zone to catch async errors
  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          overrides: [
            offlineServiceProvider.overrideWithValue(OfflineService(prefs)),
          ],
          child: const AttendifyApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Caught global error: $error');
      debugPrint(stack.toString());
      // Here you would report to Crashlytics
    },
  );
}
