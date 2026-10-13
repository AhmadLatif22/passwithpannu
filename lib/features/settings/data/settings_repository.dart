import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this._db);
  final FirebaseFirestore _db;
  DocumentReference<Map<String, dynamic>> get _doc => _db.collection('app_settings').doc('main');

  Stream<AppSettings> watch() => _doc.snapshots().map((d) => AppSettings.fromMap(d.data()));
  Future<void> save(AppSettings s) => _doc.set(s.toMap(), SetOptions(merge: true));
}

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepository(ref.watch(firestoreProvider)));

/// Live app settings (defaults until the admin saves any).
final settingsProvider = StreamProvider<AppSettings>((ref) {
  final uid = ref.watch(currentUidProvider); // re-subscribes when someone signs in
  if (uid == null) return Stream.value(const AppSettings());
  return ref.watch(settingsRepositoryProvider).watch();
});
