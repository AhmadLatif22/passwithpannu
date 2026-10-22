import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

/// Calls an admin-authorised Firebase callable; never creates Auth users in the app.
class InviteStudentPage extends StatefulWidget {
  const InviteStudentPage({super.key});
  @override
  State<InviteStudentPage> createState() => _InviteStudentPageState();
}

class _InviteStudentPageState extends State<InviteStudentPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  String lessonType = 'manual';
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> invite() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west2',
      ).httpsCallable('inviteStudent').call({
        'fullName': name.text.trim(),
        'email': email.text.trim().toLowerCase(),
        'phone': phone.text.trim(),
        'lessonType': lessonType,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation email sent.')));
      Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invitation failed: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invite student')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Only invited students can activate an account.'),
              const SizedBox(height: 20),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Enter full name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: (v) =>
                    !RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch((v ?? '').trim())
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: lessonType,
                decoration: const InputDecoration(labelText: 'Lesson type'),
                items: const [
                  DropdownMenuItem(value: 'manual', child: Text('Manual')),
                  DropdownMenuItem(
                    value: 'automatic',
                    child: Text('Automatic'),
                  ),
                ],
                onChanged: (v) => setState(() => lessonType = v ?? 'manual'),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy ? null : invite,
                icon: const Icon(Icons.forward_to_inbox_outlined),
                label: Text(busy ? 'Sending invitation…' : 'Send invitation'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
