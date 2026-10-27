import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_providers.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perm = ref.watch(notificationPermissionProvider);
    final denied = perm == AuthorizationStatus.denied;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: AsyncValueView<AppUser?>(
        value: ref.watch(currentUserProvider),
        onRetry: () => ref.invalidate(currentUserProvider),
        data: (user) => ListView(
          children: [
            ContentWidth(
              maxWidth: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (user != null) _ProfileForm(user: user),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/terms'),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Terms & Conditions'),
                  ),
                  const SizedBox(height: 12),
                  if (denied) ...[
                    const SizedBox(height: AppSpacing.md),
                    const AppCard(
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            color: AppColors.warning,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Notifications are turned off, so you won’t get lesson reminders or updates. Enable them for Pass With Pannu in your phone’s settings. You can still see updates under Notifications in the app.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SecondaryButton(
                    label: 'Sign out',
                    icon: Icons.logout,
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'Sign out?',
                        message:
                            'You’ll need to sign in again to manage your lessons.',
                        confirmLabel: 'Sign out',
                        cancelLabel: 'Stay signed in',
                      );
                      if (ok) {
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.user});
  final AppUser user;
  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phone ?? '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(fullName: _name.text, phone: _phone.text);
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    showSnack(
      context,
      ok ? 'Profile updated' : AppFailure.from(state.error ?? 'x').message,
      error: !ok,
    );
    ref.read(authControllerProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: widget.user.email,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: Validators.fullName,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: Validators.optionalPhone,
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Save changes',
            isLoading: busy,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
