import 'package:flutter/widgets.dart';
import 'app/bootstrap.dart';
import 'app/app_mode.dart';

/// Shared entry point: route by verified Firebase admin custom claim.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap(mode: AppMode.student);
}
