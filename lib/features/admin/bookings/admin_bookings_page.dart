import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/lesson_card.dart';
import '../../bookings/domain/booking.dart';
import '../../bookings/domain/booking_status.dart';
import '../shared/admin_providers.dart';
import 'create_lesson_dialog.dart';

enum _Filter { upcoming, requests, completed, cancelled, all }

class AdminBookingsPage extends ConsumerStatefulWidget {
  const AdminBookingsPage({super.key});
  @override
  ConsumerState<AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends ConsumerState<AdminBookingsPage> {
  _Filter _filter = _Filter.upcoming;
  String _query = '';

  static const _labels = {
    _Filter.upcoming: 'Upcoming',
    _Filter.requests: 'Requests',
    _Filter.completed: 'Completed',
    _Filter.cancelled: 'Cancelled',
    _Filter.all: 'All',
  };

  List<Booking> _apply(List<Booking> all) {
    final now = DateTime.now();
    var list = all.where(
      (b) => switch (_filter) {
        _Filter.upcoming => b.isUpcoming(now),
        _Filter.requests =>
          b.status == BookingStatus.changeRequested ||
              b.status == BookingStatus.cancellationRequested,
        _Filter.completed => b.status == BookingStatus.completed,
        _Filter.cancelled =>
          b.status == BookingStatus.cancelled ||
              b.status == BookingStatus.rejected,
        _Filter.all => true,
      },
    );
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where(
        (b) =>
            b.studentName.toLowerCase().contains(q) ||
            b.studentEmail.toLowerCase().contains(q) ||
            b.reference.toLowerCase().contains(q) ||
            b.pickupAddress.toLowerCase().contains(q),
      );
    }
    final out = list.toList();
    out.sort(
      (a, b) => _filter == _Filter.upcoming || _filter == _Filter.requests
          ? a.start.compareTo(b.start)
          : b.start.compareTo(a.start),
    );
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateLessonDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add lesson'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search name, email, reference or address',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _Filter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_labels[f]!),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Booking>>(
              value: ref.watch(adminBookingsProvider).whenData(_apply),
              onRetry: () => ref.invalidate(adminBookingsProvider),
              isEmpty: (l) => l.isEmpty,
              empty: const EmptyState(
                icon: Icons.event_note_outlined,
                title: 'No bookings found',
                message: 'Try another filter or search.',
              ),
              data: (items) => ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: LessonCard(
                      booking: items[i],
                      showStudent: true,
                      onTap: () => context.go('/admin/bookings/${items[i].id}'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
