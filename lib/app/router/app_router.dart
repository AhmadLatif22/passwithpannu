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
import '../../features/admin/students/invite_student_page.dart';
import '../../features/admin/driving_tests/driving_tests_page.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/login_page.dart';
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
import '../../features/progress/progress_page.dart';
import '../../features/progress/edit_progress_page.dart';
import '../../features/terms/terms_page.dart';

const _authPages = {'/login', '/forgot'};
final adminViewAsStudentProvider = StateProvider<bool>((ref) => false);

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
  ref.listen(currentUserProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String? redirect(BuildContext context, GoRouterState state) {
    final session = ref.read(authSessionProvider);
    final loc = state.matchedLocation;

    if (session.isLoading) return loc == '/splash' ? null : '/splash';
    final s = session.valueOrNull;
    if (s == null) return _authPages.contains(loc) ? null : '/login';

    // Students must accept the currently bundled policy before any app routes.
    // Do not rely on client routing alone; backend rules must also enforce this.
    if (!s.isAdmin) {
      final profile = ref.read(currentUserProvider);
      if (profile.isLoading) return loc == '/splash' ? null : '/splash';
      final p = profile.valueOrNull;
      if (p == null) return loc == '/unauthorized' ? null : '/unauthorized';
      // Before acceptance, only the terms screen can be visited.
      if (p.termsVersion != '1.1' || !p.isActive) {
        return loc == '/terms/accept' ? null : '/terms/accept';
      }
      if (loc == '/terms/accept') return '/home';
    }

    // One binary supports both roles; admin claim determines access.

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
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(
        path: '/unauthorized',
        builder: (_, __) => const UnauthorizedPage(),
      ),

      // ---- student ----
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => StudentShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, __) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/book',
                builder: (_, __) => const BookingFlowPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/lessons',
                builder: (_, __) => const LessonsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/lesson/:id',
        builder: (_, s) =>
            BookingDetailPage(bookingId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/book/confirmation/:id',
        builder: (_, s) =>
            BookingConfirmationPage(bookingId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/terms', builder: (_, __) => const TermsPage()),
      GoRoute(
        path: '/terms/accept',
        builder: (_, __) => const TermsPage(requiredAcceptance: true),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsPage(),
      ),
      GoRoute(path: '/progress', builder: (_, __) => const ProgressPage()),

      // ---- admin ----
      ShellRoute(
        builder: (_, state, child) =>
            AdminShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/admin/diary', builder: (_, __) => const DiaryPage()),
          GoRoute(
            path: '/admin/bookings',
            builder: (_, __) => const AdminBookingsPage(),
          ),
          GoRoute(
            path: '/admin/bookings/:id',
            builder: (_, s) =>
                AdminBookingDetailPage(bookingId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/admin/students',
            builder: (_, __) => const StudentsPage(),
          ),
          GoRoute(
            path: '/admin/students/invite',
            builder: (_, __) => const InviteStudentPage(),
          ),
          GoRoute(
            path: '/admin/driving-tests',
            builder: (_, __) => const DrivingTestsPage(),
          ),
          GoRoute(
            path: '/admin/students/:id/progress',
            builder: (_, s) =>
                EditProgressPage(studentId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/admin/students/:id',
            builder: (_, s) =>
                StudentDetailPage(studentId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/admin/requests',
            builder: (_, __) => const RequestsPage(),
          ),
          GoRoute(
            path: '/admin/availability',
            builder: (_, __) => const AvailabilityPage(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (_, __) => const SettingsPage(),
          ),
          GoRoute(
            path: '/admin/notifications',
            builder: (_, __) => const NotificationsPage(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
