import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../availability/domain/slot.dart';
import '../../../availability/presentation/pickup_field.dart';
import '../booking_providers.dart';
import 'booking_flow_controller.dart';

class StepPickup extends ConsumerWidget {
  const StepPickup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final draft = ref.watch(bookingFlowProvider);

    final past = ref.watch(studentBookingsProvider).valueOrNull ?? const [];

    final seen = <String>{};

    final recent = <PickupLocation>[
      for (final b in past.reversed)
        if (b.pickupLat != 0 && seen.add(b.pickupAddress))
          PickupLocation(
            address: b.pickupAddress,
            lat: b.pickupLat,
            lng: b.pickupLng,
          ),
    ].take(3).toList();

    final pickup = draft.pickup;

    // Default map location (London, UK).
    const defaultLocation = LatLng(51.5074, -0.1278);

    final selectedPosition = pickup == null
        ? defaultLocation
        : LatLng(pickup.lat, pickup.lng);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Where should we pick you up?', style: t.headlineMedium),

        const SizedBox(height: 8),

        Text(
          'Search for your pickup address and confirm '
          'the location on the map.',
          style: t.bodyMedium,
        ),

        const SizedBox(height: AppSpacing.lg),

        PickupAutocompleteField(
          initial: pickup,
          recent: recent,
          onSelected: (location) {
            ref.read(bookingFlowProvider.notifier).setPickup(location);
          },
        ),

        const SizedBox(height: 20),

        // GOOGLE MAP
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 300,
            child: GoogleMap(
              key: ValueKey(
                '${selectedPosition.latitude}_'
                '${selectedPosition.longitude}',
              ),
              initialCameraPosition: CameraPosition(
                target: selectedPosition,
                zoom: pickup == null ? 11 : 16,
              ),
              markers: pickup == null
                  ? {}
                  : {
                      Marker(
                        markerId: const MarkerId('pickup_location'),
                        position: selectedPosition,
                        infoWindow: InfoWindow(
                          title: 'Pickup Location',
                          snippet: pickup.address,
                        ),
                      ),
                    },
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              buildingsEnabled: true,
              onMapCreated: (controller) {
                debugPrint('GOOGLE MAP CREATED SUCCESSFULLY');
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (pickup != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text(pickup.address, style: t.bodyMedium)),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Pickup coordinates: '
            '${pickup.lat}, ${pickup.lng}',
            style: t.bodySmall,
          ),
        ] else
          Text(
            'Search and select an address to place '
            'your pickup marker.',
            style: t.bodySmall,
          ),
      ],
    );
  }
}
