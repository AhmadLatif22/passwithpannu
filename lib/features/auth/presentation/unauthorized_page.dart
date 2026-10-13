import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import 'auth_providers.dart';

/// Shown if a non-admin signs in to the admin dashboard.
class UnauthorizedPage extends ConsumerWidget {
  const UnauthorizedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Instructor access only',
          message: 'This account doesn’t have access to the admin dashboard.',
          actionLabel: 'Sign out',
          onAction: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
      );
}
