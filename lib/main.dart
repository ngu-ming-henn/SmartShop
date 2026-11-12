import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

/// `flutter run --dart-define=USE_FIREBASE_EMULATOR=true` talks to the
/// Firebase Local Emulator Suite (`firebase emulators:start`) instead of the
/// real database: test data stays on this computer.
///
/// Android already starts the default Firebase app from google-services.json,
/// so emulator mode uses the same app and only points Auth and Firestore at
/// the emulators (a second, different default app is not allowed).
const useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (useFirebaseEmulator) {
      // 10.0.2.2 is the computer running the emulators, seen from an
      // Android emulator.
      final host = defaultTargetPlatform == TargetPlatform.android && !kIsWeb
          ? '10.0.2.2'
          : 'localhost';
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    }
  } catch (e) {
    runApp(FirebaseSetupErrorApp(error: e));
    return;
  }

  // Local cache on the phone: browse offline, stock-in queued until online.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final prefs = await SharedPreferences.getInstance();
  await initializeDateFormatting('ms'); // Malay month names
  await NotificationService.instance.init();

  runApp(SmartShopApp(prefs: prefs));
}

/// Shown instead of crashing when `flutterfire configure` has not been run.
class FirebaseSetupErrorApp extends StatelessWidget {
  const FirebaseSetupErrorApp({super.key, required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(useGoogleFonts: false),
      home: Scaffold(
        appBar: AppBar(title: const Text('SmartShop setup')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Firebase could not start',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text('$error'),
              const SizedBox(height: 16),
              const Text(
                'In the project folder run:\n\n'
                '  dart pub global activate flutterfire_cli\n'
                '  flutterfire configure\n\n'
                'Then stop and run the app again.',
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
