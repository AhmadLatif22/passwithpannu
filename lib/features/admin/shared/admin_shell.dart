import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../app/app_mode.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/push_bootstrap.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../lesson_requests/presentation/request_providers.dart';
import '../../notifications/presentation/notification_providers.dart';

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon, this.path);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

const _dests = [
  _Dest('Dashboard', Icons.dashboard_outlined, Icons.dashboard, '/admin'),
  _Dest(
    'Diary',
    Icons.calendar_month_outlined,
    Icons.calendar_month,
    '/admin/diary',
  ),
  _Dest(
    'Bookings',
    Icons.event_note_outlined,
    Icons.event_note,
    '/admin/bookings',
  ),
  _Dest('Students', Icons.groups_outlined, Icons.groups, '/admin/students'),
  _Dest(
    'Requests',
    Icons.mark_email_unread_outlined,
    Icons.mark_email_unread,
    '/admin/requests',
  ),
  _Dest(
    'Availability',
    Icons.event_busy_outlined,
    Icons.event_busy,
    '/admin/availability',
  ),
  _Dest('Settings', Icons.settings_outlined, Icons.settings, '/admin/settings'),
];

/// Responsive admin chrome: navigation rail on desktop/tablet, bottom bar + "More" on phones.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  int get _index {
    var best = -1;
    for (var i = 0; i < _dests.length; i++) {
      final p = _dests[i].path;
      final match = p == '/admin'
          ? location == '/admin'
          : location.startsWith(p);
      if (match) best = i;
    }
    return best;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending =
        ref.watch(adminPendingRequestsProvider).valueOrNull?.length ?? 0;
    final unread = ref.watch(unreadNotificationsProvider);
    final width = MediaQuery.of(context).size.width;
    final idx = _index;

    Widget icon(_Dest d, {bool selected = false}) {
      final i = Icon(selected ? d.selectedIcon : d.icon);
      return d.label == 'Requests'
          ? Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: i,
            )
          : i;
    }

    IconButton(
      tooltip: 'Switch to student view',
      onPressed: () =>
          ref.read(adminViewAsStudentProvider.notifier).state = true,
      icon: const Icon(Icons.swap_horiz),
    );

    Future<void> signOut() async {
      final ok = await confirmDialog(
        context,
        title: 'Sign out?',
        message: 'You’ll need to sign in again.',
        confirmLabel: 'Sign out',
        cancelLabel: 'Stay signed in',
      );
      if (ok) await ref.read(authControllerProvider.notifier).signOut();
    }

    if (width >= AppBreakpoints.tablet) {
      return PushBootstrap(
        child: Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: width >= AppBreakpoints.desktop,
                selectedIndex: idx < 0 ? null : idx,
                onDestinationSelected: (i) => context.go(_dests[i].path),
                labelType: width >= AppBreakpoints.desktop
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: BrandLogo(
                    height: width >= AppBreakpoints.desktop ? 56 : 36,
                  ),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Notifications',
                            onPressed: () => context.go('/admin/notifications'),
                            icon: Badge(
                              isLabelVisible: unread > 0,
                              label: Text('$unread'),
                              child: const Icon(Icons.notifications_outlined),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sign out',
                            onPressed: signOut,
                            icon: const Icon(Icons.logout),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                destinations: [
                  for (final d in _dests)
                    NavigationRailDestination(
                      icon: icon(d),
                      selectedIcon: icon(d, selected: true),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }

    // Phone layout: first four sections + a More sheet for the rest.
    final barIndex = idx < 0
        ? null
        : (idx == 0
              ? 0
              : idx == 1
              ? 1
              : idx == 2
              ? 2
              : idx == 4
              ? 3
              : 4);
    const barItems = [0, 1, 2, 4];
    return PushBootstrap(
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: barIndex ?? 0,
          onDestinationSelected: (i) {
            if (i < barItems.length) {
              context.go(_dests[barItems[i]].path);
            } else {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: AppColors.surface,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final k in [3, 5, 6])
                        ListTile(
                          leading: Icon(_dests[k].icon),
                          title: Text(_dests[k].label),
                          onTap: () {
                            Navigator.pop(ctx);
                            context.go(_dests[k].path);
                          },
                        ),
                      ListTile(
                        leading: Badge(
                          isLabelVisible: unread > 0,
                          label: Text('$unread'),
                          child: const Icon(Icons.notifications_outlined),
                        ),
                        title: const Text('Notifications'),
                        onTap: () {
                          Navigator.pop(ctx);
                          context.go('/admin/notifications');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Sign out'),
                        onTap: () {
                          Navigator.pop(ctx);
                          signOut();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.swap_horiz),
                        title: const Text('Switch to student view'),
                        onTap: () {
                          Navigator.pop(ctx);
                          ref.read(adminViewAsStudentProvider.notifier).state =
                              true;
                        },
                      ),
                    ],
                  ),
                ),
              );
            }
          },
          destinations: [
            for (final k in barItems)
              NavigationDestination(
                icon: icon(_dests[k]),
                selectedIcon: icon(_dests[k], selected: true),
                label: _dests[k].label,
              ),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
