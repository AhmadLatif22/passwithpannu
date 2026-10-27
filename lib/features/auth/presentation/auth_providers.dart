import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/fcm_service.dart';
import '../../../core/services/firebase_providers.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(fcmServiceProvider),
  ),
);

/// null = signed out. Loading = still checking on startup (splash shows).
final authSessionProvider = StreamProvider<AuthSession?>(
  (ref) => ref.watch(authRepositoryProvider).watchSession(),
);

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authSessionProvider).valueOrNull?.uid,
);

final isAdminProvider = Provider<bool>(
  (ref) => ref.watch(authSessionProvider).valueOrNull?.isAdmin ?? false,
);

/// The signed-in user's profile document (users/{uid}).
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(uid);
});

/// Drives sign-in / register / reset forms: loading + error handled via AsyncValue.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }

  Future<bool> signIn(String email, String password) =>
      _run(() => _repo.signIn(email, password));

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) => _run(
    () => _repo.register(
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
    ),
  );

  Future<bool> sendReset(String email) =>
      _run(() => _repo.sendPasswordReset(email));

  Future<bool> updateProfile({required String fullName, String? phone}) {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return Future.value(false);
    return _run(
      () => _repo.updateProfile(uid, fullName: fullName, phone: phone),
    );
  }

  Future<void> signOut() async {
    await _repo.signOut(ref.read(currentUidProvider));
  }

  void clearError() => state = const AsyncData(null);
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
