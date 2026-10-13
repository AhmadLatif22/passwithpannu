import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/primary_button.dart';
import 'auth_providers.dart';
import 'auth_scaffold.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).sendReset(_email.text);
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return AuthScaffold(
      title: 'Reset your password',
      subtitle: 'We’ll email you a link to choose a new one',
      children: [
        if (_sent) ...[
          const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.accent),
          const SizedBox(height: 12),
          Text(
            'If an account exists for ${_email.text.trim()}, a reset link is on its way. Check your inbox and spam folder.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Back to sign in', onPressed: () => context.pop()),
        ] else
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.hasError) FormError(AppFailure.from(auth.error!).message),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                  validator: Validators.email,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                PrimaryButton(label: 'Send reset link', isLoading: auth.isLoading, onPressed: _submit),
                const SizedBox(height: 12),
                TextButton(onPressed: () => context.pop(), child: const Text('Back to sign in')),
              ],
            ),
          ),
      ],
    );
  }
}
