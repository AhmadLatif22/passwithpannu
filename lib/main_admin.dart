import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app_mode.dart';
import 'app/bootstrap.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await bootstrap(mode: AppMode.admin);
}