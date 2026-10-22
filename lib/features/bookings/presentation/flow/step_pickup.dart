import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../availability/domain/slot.dart';
import '../../../availability/presentation/availability_providers.dart';
import '../../../availability/presentation/pickup_field.dart';
import '../booking_providers.dart';
import 'booking_flow_controller.dart';

/// Search for an address or long-press the map to choose a precise pickup point.
class StepPickup extends ConsumerStatefulWidget {
  const StepPickup({super.key});

  @override
  ConsumerState<StepPickup> createState() => _StepPickupState();
}

class _StepPickupState extends ConsumerState<StepPickup> {
  // Derby is the school's operating city. The map can still be panned/zoomed.
  static const _derby = LatLng(52.9225, -1.4746);
  GoogleMapController? _mapController;
  bool _resolving = false;
  String? _mapError;
  LatLng? _pendingPoint;
  int _requestId = 0;

  @override
  void dispose() {
    _requestId++;
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _chooseOnMap(LatLng point) async {
    final id = ++_requestId;
    // Clear any previously confirmed location so Next cannot proceed on old coordinates.
    ref.read(bookingFlowProvider.notifier).clearPickup();
    setState(() {
      _pendingPoint = point;
      _resolving = true;
      _mapError = null;
    });
    try {
      final location = await ref.read(placesRepositoryProvider).reverseGeocode(
        point.latitude,
        point.longitude,
      );
      if (!mounted || id != _requestId) return;
      ref.read(bookingFlowProvider.notifier).setPickup(location);
      setState(() {
        _pendingPoint = null;
        _resolving = false;
      });
    } catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _resolving = false;
        _pendingPoint = null;
        _mapError = 'Could not identify this address. Try a nearby point or use search.';
      });
    }
  }

  void _chooseFromSearch(PickupLocation location) {
    _requestId++;
    setState(() {
      _pendingPoint = null;
      _resolving = false;
      _mapError = null;
    });
    ref.read(bookingFlowProvider.notifier).setPickup(location);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(location.lat, location.lng), 17,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pickup = ref.watch(bookingFlowProvider.select((draft) => draft.pickup));
    final past = ref.watch(studentBookingsProvider).valueOrNull ?? const [];
    final seen = <String>{};
    final recent = <PickupLocation>[
      for (final b in past.reversed)
        if (b.pickupLat != 0 && seen.add(b.pickupAddress))
          PickupLocation(address: b.pickupAddress, lat: b.pickupLat, lng: b.pickupLng),
    ].take(3).toList();
    final position = _pendingPoint ??
        (pickup == null ? _derby : LatLng(pickup.lat, pickup.lng));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Where should we pick you up?', style: t.headlineMedium),
        const SizedBox(height: 8),
        Text('Search your address or press and hold the map to drop a pin. Pinch to zoom or use the + / − controls.', style: t.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        PickupAutocompleteField(
          initial: pickup,
          recent: recent,
          onSelected: _chooseFromSearch,
          onCleared: () {
            _requestId++;
            ref.read(bookingFlowProvider.notifier).clearPickup();
          },
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 320,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: position, zoom: pickup == null ? 13 : 17),
                  onMapCreated: (controller) => _mapController = controller,
                  onLongPress: _chooseOnMap,
                  zoomControlsEnabled: true,
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  markers: {
                    if (pickup != null || _pendingPoint != null)
                      Marker(
                        markerId: const MarkerId('pickup_location'),
                        position: position,
                        infoWindow: InfoWindow(
                          title: _pendingPoint != null ? 'Finding address…' : 'Pickup location',
                          snippet: pickup?.address,
                        ),
                      ),
                  },
                ),
                if (_resolving)
                  const Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Expanded(child: Text('Finding the pinned address…')),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_mapError != null) Text(_mapError!, style: t.bodySmall?.copyWith(color: AppColors.error)),
        if (pickup != null) ...[
          Row(children: [
            const Icon(Icons.location_on_outlined, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(pickup.address, style: t.bodyMedium)),
          ]),
          const SizedBox(height: 6),
          Text('Pickup location confirmed — tap Continue to choose a date.', style: t.bodySmall),
        ] else if (!_resolving)
          Text('Long-press the map or select an address to continue.', style: t.bodySmall),
      ],
    );
  }
}
