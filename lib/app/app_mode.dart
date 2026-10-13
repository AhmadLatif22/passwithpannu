import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which entry point launched the app. The admin build only lets admins in.
enum AppMode { student, admin }

final appModeProvider = Provider<AppMode>((_) => AppMode.student);
final adminViewAsStudentProvider = StateProvider<bool>((_) => false);