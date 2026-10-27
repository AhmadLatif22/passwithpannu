import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'terms_v1_1.dart';

/// Displays the complete client-supplied v1.1 terms.
/// The only acceptance write is via the server-authorized callable.
class TermsPage extends StatefulWidget {
  const TermsPage({super.key, this.requiredAcceptance = false});
  final bool requiredAcceptance;
  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool checked = false;
  bool saving = false;

  Future<void> _accept() async {
    if (!checked || saving) return;
    setState(() => saving = true);
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west2',
      ).httpsCallable('acceptStudentTerms').call({'version': termsVersion});
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      debugPrint('Terms acceptance failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save your acceptance. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Terms & Conditions'),
      automaticallyImplyLeading: !widget.requiredAcceptance,
      actions: widget.requiredAcceptance
          ? [TextButton(onPressed: _signOut, child: const Text('Sign out'))]
          : null,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Pass With Pannu · Version $termsVersion',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        const SelectableText(termsText),
        if (widget.requiredAcceptance) ...[
          const SizedBox(height: 22),
          CheckboxListTile(
            value: checked,
            onChanged: saving
                ? null
                : (v) => setState(() => checked = v ?? false),
            title: const Text(
              'I have read and agree to the Terms & Conditions',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          FilledButton(
            onPressed: checked && !saving ? _accept : null,
            child: Text(
              saving ? 'Recording acceptance…' : 'Accept and continue',
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          const Text('Your saved acceptance record:'),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .collection('termsAcceptances')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .get(),
                  builder: (context, profile) {
                    if (profile.hasData &&
                        profile.data!.data()?['termsAccepted'] == true) {
                      final d = profile.data!.data()!;
                      final at = d['termsAcceptedAt'];
                      final date = at is Timestamp
                          ? at.toDate().toLocal().toString()
                          : 'Date unavailable';
                      return ListTile(
                        title: Text(
                          'Version ${d['termsVersion'] ?? termsVersion}',
                        ),
                        subtitle: Text('Accepted: $date'),
                      );
                    }
                    return const Text(
                      'Acceptance record is currently unavailable.',
                    );
                  },
                );
              }
              if (!snap.hasData) return const CircularProgressIndicator();
              final records = snap.data!.docs;
              if (records.isEmpty) {
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .get(),
                  builder: (context, profile) {
                    if (!profile.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final d = profile.data!.data() ?? {};
                    if (d['termsAccepted'] != true) {
                      return const Text('No acceptance recorded.');
                    }
                    final at = d['termsAcceptedAt'];
                    return ListTile(
                      title: Text(
                        'Version ${d['termsVersion'] ?? termsVersion}',
                      ),
                      subtitle: Text(
                        'Accepted: ${at is Timestamp ? at.toDate().toLocal() : 'Date unavailable'}',
                      ),
                    );
                  },
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: records.map((r) {
                  final at = r.data()['acceptedAt'];
                  final date = at is Timestamp
                      ? at.toDate().toLocal().toString()
                      : 'Pending';
                  return ListTile(
                    title: Text('Version ${r.id}'),
                    subtitle: Text('Accepted: $date'),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Accepted Terms ${r.id}'),
                        content: SizedBox(
                          width: 550,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              r.data()['policyText'] as String? ?? '',
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ],
    ),
  );
}
