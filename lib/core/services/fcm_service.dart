import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

/// Registers this device's FCM token under users/{uid}/devices/{token} and
/// exposes foreground messages. Skipped on web (admin web uses live Firestore
/// streams for its badges; web push needs a VAPID key + service worker).
class FcmService {
  FcmService(this._messaging, this._db);
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  String? _registeredUid;
  String? _token;

  /// Asks for permission, then stores the token. Returns the authorization status.
  Future<AuthorizationStatus> register(String uid) async {
    if (kIsWeb) return AuthorizationStatus.notDetermined;
    final settings = await _messaging.requestPermission();
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) return settings.authorizationStatus;

    _registeredUid = uid;
    final token = await _messaging.getToken();
    if (token != null) await _save(uid, token);
    _messaging.onTokenRefresh.listen((t) {
      final u = _registeredUid;
      if (u != null) _save(u, t);
    });
    return settings.authorizationStatus;
  }

  Future<void> _save(String uid, String token) async {
    _token = token;
    await _db.collection('users').doc(uid).collection('devices').doc(token).set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Call BEFORE signing out so a signed-out phone stops receiving someone's reminders.
  Future<void> unregister(String uid) async {
    final token = _token ?? await _messaging.getToken();
    _registeredUid = null;
    if (token == null || kIsWeb) return;
    try {
      await _db.collection('users').doc(uid).collection('devices').doc(token).delete();
    } catch (_) {}
  }

  Stream<RemoteMessage> get foregroundMessages =>
      kIsWeb ? const Stream.empty() : FirebaseMessaging.onMessage;
}

final fcmServiceProvider = Provider<FcmService>(
  (ref) => FcmService(ref.watch(firebaseMessagingProvider), ref.watch(firestoreProvider)),
);

/// Result of the permission prompt, so the profile page can explain a denial.
final notificationPermissionProvider = StateProvider<AuthorizationStatus?>((_) => null);
