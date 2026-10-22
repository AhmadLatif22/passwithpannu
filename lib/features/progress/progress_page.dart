import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// The student's public progress summary. Private instructor notes are never
/// stored in this document and must be protected by server-side Firestore rules.
class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My Driving Progress')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('progress')
            .doc('summary')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Progress is currently unavailable'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snapshot.data!.data() ?? {};
          final hours = (d['completedHours'] as num?)?.toDouble() ?? 0;
          final readiness =
              ((d['testReadinessPercent'] as num?)?.toDouble() ?? 0).clamp(
                0,
                100,
              );
          Widget section(String title, String key) {
            final value = d[key];
            final text = value is List
                ? value.join('\n• ')
                : (value?.toString() ?? 'Not added yet');
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(text),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${hours.toStringAsFixed(1)} hours completed',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Instructor-assessed test readiness: ${readiness.toStringAsFixed(0)}%',
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: readiness / 100),
                    ],
                  ),
                ),
              ),
              section('Covered in previous lessons', 'covered'),
              section('Doing well', 'strengths'),
              section('Areas to improve', 'improvements'),
              section('Working on next', 'nextSteps'),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Progress reflects your instructor’s assessment, not an official test result.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
