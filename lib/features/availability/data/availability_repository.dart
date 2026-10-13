import 'dart:math';

import '../../../core/services/firebase_providers.dart';
import '../../bookings/domain/lesson_type.dart';
import '../domain/slot.dart';

/// Availability is computed server-side (it needs other students' pickup points for
/// travel time, which students must never read). The client just asks for results.
class AvailabilityRepository {
  AvailabilityRepository(this._fn);
  final FunctionsClient _fn;

  Future<List<Slot>> slots({
    required String dateKey,
    required LessonType lessonType,
    required PickupLocation pickup,
  }) async {
    final r = await _fn.call('getAvailableSlots', {
      'date': dateKey,
      'lessonType': lessonType.name,
      'pickupLatitude': pickup.lat,
      'pickupLongitude': pickup.lng,
    });
    return (r['slots'] as List? ?? const [])
        .map((e) => Slot.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Days of [month] (yyyy-MM) that have at least one bookable slot.
  Future<Set<String>> dates({required String month, required PickupLocation pickup}) async {
    final r = await _fn.call('getAvailableDates', {
      'month': month,
      'pickupLatitude': pickup.lat,
      'pickupLongitude': pickup.lng,
    });
    return (r['dates'] as List? ?? const []).cast<String>().toSet();
  }
}

class PlaceSuggestion {
  const PlaceSuggestion(this.placeId, this.description);
  final String placeId;
  final String description;
}

/// Address search through the Cloud Functions proxy (the Maps key never touches the device).
class PlacesRepository {
  PlacesRepository(this._fn);
  final FunctionsClient _fn;

  static String newSessionToken() {
    final r = Random.secure();
    return List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<List<PlaceSuggestion>> autocomplete(String input, String sessionToken) async {
    final r = await _fn.call('placesAutocomplete', {'input': input, 'sessionToken': sessionToken});
    return (r['suggestions'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) => PlaceSuggestion(m['placeId'] as String, m['description'] as String))
        .toList();
  }

  Future<PickupLocation> details(String placeId, String sessionToken) async {
    final r = await _fn.call('placeDetails', {'placeId': placeId, 'sessionToken': sessionToken});
    return PickupLocation(
      address: r['address'] as String,
      lat: (r['lat'] as num).toDouble(),
      lng: (r['lng'] as num).toDouble(),
    );
  }
}
