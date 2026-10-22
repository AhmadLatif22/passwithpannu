/// A bookable start time returned by the availability engine (UTC instants).
class Slot {
  const Slot({required this.start, required this.end});
  final DateTime start;
  final DateTime end;

  factory Slot.fromMap(Map<String, dynamic> m) => Slot(
    start: DateTime.parse(m['start'] as String).toUtc(),
    end: DateTime.parse(m['end'] as String).toUtc(),
  );

  @override
  bool operator ==(Object other) =>
      other is Slot && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
}

/// A geocoded pickup point (address + coordinates), needed for travel-time checks.
class PickupLocation {
  const PickupLocation({
    required this.address,
    required this.lat,
    required this.lng,
  });
  final String address;
  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is PickupLocation &&
      other.address == address &&
      other.lat == lat &&
      other.lng == lng;
  @override
  int get hashCode => Object.hash(address, lat, lng);
}
