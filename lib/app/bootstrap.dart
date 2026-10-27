import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/date_time_utils.dart';
import '../firebase_options.dart';
import 'app.dart';
import '../features/home/presentation/widgets/home_video_banner.dart';
import 'app_mode.dart';

/// Shared startup for both entry points (student app and admin web).
Future<void> bootstrap({required AppMode mode}) async {
  WidgetsFlutterBinding.ensureInitialized();
  DateTimeUtils.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseAuth.instance.authStateChanges().listen((user) {
    debugPrint('AUTH STATE: ${user?.uid ?? "SIGNED OUT"}');
  });

  FirebaseAuth.instance.idTokenChanges().listen((user) {
    debugPrint('AUTH TOKEN: ${user?.uid ?? "NO USER"}');
  });

  if (Env.useEmulator) {
    final host = Env.emulatorHost;
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instanceFor(
      region: AppConstants.functionsRegion,
    ).useFunctionsEmulator(host, 5001);
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    HomeVideoPreloader.instance.prewarm();
  });

  runApp(
    ProviderScope(
      overrides: [appModeProvider.overrideWithValue(mode)],
      child: const PassWithPannuApp(),
    ),
  );
}
