import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../errors/app_failure.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (_) => FirebaseMessaging.instance,
);

final functionsClientProvider = Provider<FunctionsClient>(
  (_) => FunctionsClient(
    FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion),
  ),
);

/// Thin wrapper over Firebase callable functions.
///
/// Before every callable request, this checks that the user is authenticated
/// and refreshes the Firebase ID token so Cloud Functions receives a valid
/// `request.auth`.
///
/// Every exception is converted to [AppFailure].
class FunctionsClient {
  FunctionsClient(this._functions);

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic>? data,
  ]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint(
          '[FunctionsClient] $name failed: FirebaseAuth.currentUser is null',
        );

        throw const AppFailure('unauthenticated', 'Please sign in again.');
      }

      debugPrint(
        '[FunctionsClient] Calling $name as '
        '${user.email ?? user.uid}',
      );

      // Force-refresh Firebase ID token.
      //
      // Callable Cloud Functions automatically attach the Firebase Auth token
      // when one is available. Refreshing here helps prevent calls from being
      // made with an expired/stale token.
      final token = await user.getIdToken(true);

      debugPrint('[FunctionsClient] UID: ${user.uid}');

      debugPrint(
        '[FunctionsClient] Token available: '
        '${token != null && token.isNotEmpty}',
      );

      final callable = _functions.httpsCallable(name);

      final response = await callable.call<Object?>(
        data ?? <String, dynamic>{},
      );

      final result = response.data;

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      return <String, dynamic>{};
    } on FirebaseFunctionsException catch (e, stackTrace) {
      debugPrint('[FunctionsClient] Function "$name" failed');

      debugPrint('[FunctionsClient] Code: ${e.code}');

      debugPrint('[FunctionsClient] Message: ${e.message}');

      debugPrint('[FunctionsClient] Details: ${e.details}');

      debugPrintStack(stackTrace: stackTrace);

      throw AppFailure.from(e);
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('[FunctionsClient] Auth error while calling "$name"');

      debugPrint('[FunctionsClient] Code: ${e.code}');

      debugPrint('[FunctionsClient] Message: ${e.message}');

      debugPrintStack(stackTrace: stackTrace);

      throw AppFailure.from(e);
    } on AppFailure {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[FunctionsClient] Unexpected error calling "$name": $e');

      debugPrintStack(stackTrace: stackTrace);

      throw AppFailure.from(e);
    }
  }
}
