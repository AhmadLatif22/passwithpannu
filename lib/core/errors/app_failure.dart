import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// User-presentable failure. Raw Firebase exceptions never reach the UI.
class AppFailure implements Exception {
  const AppFailure(this.code, this.message, {this.reason});

  /// Stable machine code, e.g. `slot_unavailable`, `too_late_to_change`, `network`.
  final String code;
  final String message;

  /// Extra detail from the server, e.g. `travel_before` for a slot conflict.
  final String? reason;

  bool get isSlotUnavailable => code == 'slot_unavailable';

  /// Conflicts an admin may knowingly override (never overlap with another lesson).
  bool get isOverridable =>
      isSlotUnavailable &&
      const {'travel_before', 'travel_after', 'blocked', 'outside_hours', 'too_soon', 'misaligned'}.contains(reason);

  @override
  String toString() => message;

  static const _generic = 'Something went wrong. Please try again.';
  static const _network = 'No connection. Check your internet and try again.';

  static const _serverMessages = <String, String>{
    'slot_unavailable': 'That time was just taken. Please choose another slot.',
    'too_late_to_change':
        'Changes or cancellations must normally be requested at least 48 hours before your lesson.',
    'request_already_open': 'You already have an open request for this lesson.',
    'not_confirmed': 'Only confirmed lessons can be changed.',
    'reason_required': 'Please tell us why you need to cancel.',
    'booking_not_found': 'We could not find that lesson.',
    'request_not_found': 'We could not find that request.',
    'already_resolved': 'This request has already been handled.',
    'resolve_request_first': 'Resolve the student’s open request first.',
    'invalid_status': 'That is no longer possible for this lesson.',
    'not_started': 'This lesson has not started yet.',
    'profile_missing': 'Your account is not active. Please contact Pass With Pannu.',
    'maps_not_configured': 'Address search is unavailable right now. Please try again later.',
    'places_failed': 'Address search is unavailable right now. Please try again later.',
    'not_admin': 'You do not have permission to do that.',
    'invalid_input': 'Please check the details you entered.',
  };

  static const _slotReasons = <String, String>{
    'travel_before': 'That time doesn’t leave enough travel time after the previous lesson.',
    'travel_after': 'That time doesn’t leave enough travel time before the next lesson.',
    'blocked': 'The instructor isn’t available at that time.',
    'overlap': 'That time was just taken. Please choose another slot.',
    'in_past': 'That time has already passed.',
    'too_soon': 'That time is too soon. Please choose a later slot.',
    'too_far_ahead': 'That date is too far ahead to book yet.',
    'outside_hours': 'That time is outside working hours.',
    'misaligned': 'Please pick one of the listed start times.',
  };

  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;

    if (error is FirebaseFunctionsException) {
      final details = error.details;
      final code = details is Map ? details['code'] as String? : null;
      final reason = details is Map ? details['reason'] as String? : null;
      if (code != null) {
        final msg = code == 'slot_unavailable' && reason != null
            ? (_slotReasons[reason] ?? _serverMessages[code]!)
            : (_serverMessages[code] ?? _generic);
        return AppFailure(code, msg, reason: reason);
      }
      switch (error.code) {
        case 'unavailable':
        case 'deadline-exceeded':
          return const AppFailure('network', _network);
        case 'unauthenticated':
          return const AppFailure('unauthenticated', 'Please sign in again.');
        case 'permission-denied':
          return const AppFailure('permission', 'You do not have permission to do that.');
      }
      return const AppFailure('unknown', _generic);
    }

    if (error is FirebaseAuthException) {
      return AppFailure(error.code, switch (error.code) {
        'invalid-email' => 'That email address does not look right.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Incorrect email or password.',
        'email-already-in-use' => 'An account with this email already exists.',
        'weak-password' => 'Please choose a stronger password.',
        'too-many-requests' => 'Too many attempts. Please wait a moment and try again.',
        'network-request-failed' => _network,
        _ => _generic,
      });
    }

    if (error is FirebaseException) {
      if (error.code == 'unavailable') return const AppFailure('network', _network);
      if (error.code == 'permission-denied') {
        return const AppFailure('permission', 'You do not have permission to do that.');
      }
      return const AppFailure('unknown', _generic);
    }

    final text = error.toString();
    if (text.contains('SocketException') || text.contains('ClientException') || text.contains('network')) {
      return const AppFailure('network', _network);
    }
    return const AppFailure('unknown', _generic);
  }
}
