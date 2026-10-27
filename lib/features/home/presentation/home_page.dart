import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pass_with_pannu/core/widgets/app_card.dart';

import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/lesson_card.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../bookings/domain/booking.dart';
import '../../bookings/presentation/booking_providers.dart';
import '../../notifications/presentation/notification_providers.dart';
import 'widgets/home_video_banner.dart';

// Screen-only styling: no global theme changes.
const _ink = Color(0xFF080B10);
const _paper = Color(0xFFF5F7FA);
const _panel = Color(0xFF101823);
const _muted = Color(0xFF9AA8B7);
const _line = Color(0xFF283241);
const _blue = Color(0xFF3979F6);
const _green = Color(0xFF16C784);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProvider).valueOrNull;
    final name = profile?.firstName.trim();
    final unread = ref.watch(unreadNotificationsProvider);
    final upcoming = ref.watch(upcomingBookingsProvider);
    final hour = DateTimeUtils.toBusiness(DateTime.now()).hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'PASS WITH PANNU',
          style: TextStyle(
            color: _paper,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: _paper,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncValueView<List<Booking>>(
        value: upcoming,
        onRetry: () => ref.invalidate(studentBookingsProvider),
        data: (bookings) {
          final next = bookings.isEmpty ? null : bookings.first;
          final later = bookings.skip(1).take(2).toList();
          return RefreshIndicator(
            color: _blue,
            onRefresh: () async {
              ref.invalidate(currentUserProvider);
              ref.invalidate(notificationsProvider);
              ref.invalidate(studentBookingsProvider);
              await ref.read(studentBookingsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        name == null || name.isEmpty
                            ? greeting
                            : '$greeting, $name',
                        style: const TextStyle(
                          color: _paper,
                          fontSize: 29,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Make every mile count.',
                        style: TextStyle(color: _muted, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      // The provided video banner is kept exactly as it is.
                      const HomeVideoBanner(),
                      const SizedBox(height: 27),
                      _FeaturedLesson(booking: next),
                      const SizedBox(height: 18),
                      _BookingAction(onTap: () => context.go('/book')),
                      const SizedBox(height: 30),
                      const _SmallHeading('YOUR SPACE'),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Expanded(
                            child: _Shortcut(
                              title: 'My progress',
                              detail: 'Skills & test readiness',
                              icon: Icons.speed_rounded,
                              color: _green,
                              onTap: () => context.push('/progress'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Shortcut(
                              title: 'My bookings',
                              detail: 'Your lesson diary',
                              icon: Icons.calendar_today_rounded,
                              color: _blue,
                              onTap: () => context.go('/lessons'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 29),
                      const _SmallHeading('THE ROAD AHEAD'),
                      const SizedBox(height: 14),
                      const _ProgressStrip(),
                      if (later.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            const Expanded(child: _SmallHeading('COMING UP')),
                            TextButton(
                              onPressed: () => context.go('/lessons'),
                              child: const Text('View all'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        for (final lesson in later)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: LessonCard(
                              booking: lesson,
                              onTap: () => context.push('/lesson/${lesson.id}'),
                            ),
                          ),
                      ],
                      const SizedBox(height: 27),
                      const Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: _green,
                            size: 17,
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Bring your provisional driving licence to each lesson.',
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeaturedLesson extends StatelessWidget {
  const _FeaturedLesson({required this.booking});
  final Booking? booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final lessonDate = b == null ? null : DateTimeUtils.toBusiness(b.start);
    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            b == null ? context.go('/book') : context.push('/lesson/${b.id}'),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: _blue, width: 3)),
          ),
          padding: const EdgeInsets.fromLTRB(19, 21, 17, 21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'YOUR NEXT LESSON',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.north_east_rounded, color: _muted, size: 18),
                ],
              ),
              const SizedBox(height: 17),
              if (b == null) ...[
                const Text(
                  'The road is yours.',
                  style: TextStyle(
                    color: _paper,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'No upcoming lessons. Book your next drive.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 75,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2839),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${lessonDate!.day}',
                            style: const TextStyle(
                              color: _paper,
                              fontSize: 34,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _month(lessonDate.month),
                            style: const TextStyle(
                              color: _green,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.lessonType.label} lesson',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _paper,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            DateTimeUtils.formatRange(b.start, b.end),
                            style: const TextStyle(
                              color: _green,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: _line, height: 1),
                const SizedBox(height: 13),
                Row(
                  children: [
                    const Icon(Icons.near_me_outlined, color: _muted, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b.pickupAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _month(int month) => const [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ][month - 1];
}

class _BookingAction extends StatelessWidget {
  const _BookingAction({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 55,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      child: const Row(
        children: [
          Icon(Icons.add_rounded, size: 23),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Request a Lesson',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          Icon(Icons.arrow_forward_rounded, size: 19),
        ],
      ),
    ),
  );
}

class _SmallHeading extends StatelessWidget {
  const _SmallHeading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: _muted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.8,
    ),
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF141D28),
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 12, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 23),
            Text(
              title,
              style: const TextStyle(
                color: _paper,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip();
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('progress')
          .doc('summary')
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final hours = (data?['completedHours'] as num?)?.toDouble() ?? 0.0;
        final readiness =
            ((data?['testReadinessPercent'] as num?)?.toDouble() ?? 0.0)
                .clamp(0.0, 100.0)
                .toDouble();
        return InkWell(
          onTap: () => context.push('/progress'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Road to your test',
                        style: TextStyle(
                          color: _paper,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: _muted, size: 19),
                  ],
                ),
                const SizedBox(height: 7),
                if (snapshot.hasError)
                  const Text(
                    'Progress is temporarily unavailable.',
                    style: TextStyle(color: _muted),
                  )
                else if (!snapshot.hasData)
                  const LinearProgressIndicator(color: _blue)
                else ...[
                  Text(
                    '${hours.toStringAsFixed(1)} hours completed · ${readiness.toStringAsFixed(0)}% test readiness',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 17),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: readiness / 100,
                      minHeight: 5,
                      backgroundColor: _line,
                      valueColor: const AlwaysStoppedAnimation<Color>(_green),
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Based on your instructor’s assessment',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
