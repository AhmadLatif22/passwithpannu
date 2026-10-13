import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_mode.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/primary_button.dart';
import 'auth_providers.dart';
import 'auth_scaffold.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signIn(_email.text, _password.text);
    // On success the router redirects automatically when the session changes.
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isAdminApp = ref.watch(appModeProvider) == AppMode.admin;
    return AuthScaffold(
      title: isAdminApp ? 'Instructor sign in' : 'Welcome back',
      subtitle: isAdminApp ? 'Pass With Pannu admin dashboard' : 'Sign in to book and manage your lessons',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.hasError) FormError(AppFailure.from(auth.error!).message),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => Validators.required(v, 'Password'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).clearError();
                      context.push('/forgot');
                    },
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 4),
                PrimaryButton(label: 'Sign in', isLoading: auth.isLoading, onPressed: _submit),
                if (!isAdminApp) ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('New learner?', style: Theme.of(context).textTheme.bodyMedium),
                      TextButton(
                        onPressed: () {
                          ref.read(authControllerProvider.notifier).clearError();
                          context.push('/register');
                        },
                        child: const Text('Create an account'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
