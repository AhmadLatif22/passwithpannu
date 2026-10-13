import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/availability/availability_page.dart';
import '../../features/admin/bookings/admin_booking_detail_page.dart';
import '../../features/admin/bookings/admin_bookings_page.dart';
import '../../features/admin/dashboard/dashboard_page.dart';
import '../../features/admin/diary/diary_page.dart';
import '../../features/admin/requests/requests_page.dart';
import '../../features/admin/settings/settings_page.dart';
import '../../features/admin/shared/admin_shell.dart';
import '../../features/admin/students/student_detail_page.dart';
import '../../features/admin/students/students_page.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/auth/presentation/unauthorized_page.dart';
import '../../features/bookings/presentation/booking_confirmation_page.dart';
import '../../features/bookings/presentation/booking_detail_page.dart';
import '../../features/bookings/presentation/flow/booking_flow_page.dart';
import '../../features/bookings/presentation/lessons_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/home/presentation/student_shell.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../app_mode.dart';

const _authPages = {'/login', '/register', '/forgot'};

/// Auth + role guard:
///  * session loading  -> /splash (no flash of the wrong screen)
///  * signed out       -> /login
///  * admin build + non-admin -> /unauthorized
///  * admins -> /admin/*, students -> student shell. Admin routes are unreachable
///    for students (the real protection is still the server: rules + callables).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authSessionProvider, (_, __) => refresh.value++);
  ref.listen(adminViewAsStudentProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String? redirect(BuildContext context, GoRouterState state) {
    final session = ref.read(authSessionProvider);
    final mode = ref.read(appModeProvider);
    final loc = state.matchedLocation;

    if (session.isLoading) return loc == '/splash' ? null : '/splash';
    final s = session.valueOrNull;
    if (s == null) return _authPages.contains(loc) ? null : '/login';

    if (mode == AppMode.admin && !s.isAdmin) return loc == '/unauthorized' ? null : '/unauthorized';

    final asStudent = s.isAdmin && ref.read(adminViewAsStudentProvider);
    final inAdminArea = s.isAdmin && !asStudent;
    final home = inAdminArea ? '/admin' : '/home';
    if (loc == '/splash' || _authPages.contains(loc)) return home;
    if (inAdminArea && !loc.startsWith('/admin')) return '/admin';
    if (!inAdminArea && loc.startsWith('/admin')) return '/home';
    return null;
  }

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(path: '/unauthorized', builder: (_, __) => const UnauthorizedPage()),

      // ---- student ----
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => StudentShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomePage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/book', builder: (_, __) => const BookingFlowPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/lessons', builder: (_, __) => const LessonsPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, __) => const ProfilePage())]),
        ],
      ),
      GoRoute(
        path: '/lesson/:id',
        builder: (_, s) => BookingDetailPage(bookingId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/book/confirmation/:id',
        builder: (_, s) => BookingConfirmationPage(bookingId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),

      // ---- admin ----
      ShellRoute(
        builder: (_, state, child) => AdminShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/admin/diary', builder: (_, __) => const DiaryPage()),
          GoRoute(path: '/admin/bookings', builder: (_, __) => const AdminBookingsPage()),
          GoRoute(
            path: '/admin/bookings/:id',
            builder: (_, s) => AdminBookingDetailPage(bookingId: s.pathParameters['id']!),
          ),
          GoRoute(path: '/admin/students', builder: (_, __) => const StudentsPage()),
          GoRoute(
            path: '/admin/students/:id',
            builder: (_, s) => StudentDetailPage(studentId: s.pathParameters['id']!),
          ),
          GoRoute(path: '/admin/requests', builder: (_, __) => const RequestsPage()),
          GoRoute(path: '/admin/availability', builder: (_, __) => const AvailabilityPage()),
          GoRoute(path: '/admin/settings', builder: (_, __) => const SettingsPage()),
          GoRoute(path: '/admin/notifications', builder: (_, __) => const NotificationsPage()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
