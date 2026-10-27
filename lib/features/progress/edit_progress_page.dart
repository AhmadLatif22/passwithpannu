import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Only verified instructor admins may use this editor; enforce admin custom
/// claims in Firestore security rules, not only through app routing.
class EditProgressPage extends StatefulWidget {
  const EditProgressPage({super.key, required this.studentId});
  final String studentId;
  @override
  State<EditProgressPage> createState() => _EditProgressPageState();
}

class _EditProgressPageState extends State<EditProgressPage> {
  final fields = {
    for (final k in [
      'completedHours',
      'testReadinessPercent',
      'covered',
      'strengths',
      'improvements',
      'nextSteps',
      'privateNotes',
    ])
      k: TextEditingController(),
  };
  bool saving = false;
  double? automaticHours;
  bool manualHours = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final base = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId);
      final results = await Future.wait([
        base.collection('progress').doc('summary').get(),
        base.collection('instructorPrivate').doc('progress').get(),
        FirebaseFirestore.instance
            .collection('bookings')
            .where('studentId', isEqualTo: widget.studentId)
            .get(),
      ]);
      if (!mounted) return;
      final progressSnapshot =
          results[0] as DocumentSnapshot<Map<String, dynamic>>;

      final privateSnapshot =
          results[1] as DocumentSnapshot<Map<String, dynamic>>;

      final bookingsSnapshot =
          results[2] as QuerySnapshot<Map<String, dynamic>>;

      final d = progressSnapshot.data() ?? <String, dynamic>{};

      final double hours = bookingsSnapshot.docs.fold<double>(0.0, (sum, doc) {
        final data = doc.data();

        if (data['status'] != 'completed') {
          return sum;
        }

        final start = data['startDateTime'];
        final end = data['endDateTime'];

        if (start is! Timestamp || end is! Timestamp) {
          return sum;
        }

        final duration =
            end.toDate().difference(start.toDate()).inMinutes / 60.0;

        return sum + (duration > 0 ? duration : 0);
      });

      automaticHours = hours;

      manualHours = d['completedHoursOverride'] is num;

      final privateData = privateSnapshot.data() ?? <String, dynamic>{};

      for (final k in fields.keys) {
        final dynamic value;

        if (k == 'privateNotes') {
          value = privateData['notes'];
        } else if (k == 'completedHours') {
          value = manualHours ? d['completedHoursOverride'] : hours;
        } else {
          value = d[k];
        }

        fields[k]!.text = value?.toString() ?? '';
      }

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to load progress: $e')));
      }
    }
  }

  Future<void> _save() async {
    final hours = double.tryParse(fields['completedHours']!.text);
    final readiness = double.tryParse(fields['testReadinessPercent']!.text);
    if (hours == null ||
        hours < 0 ||
        readiness == null ||
        readiness < 0 ||
        readiness > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter valid hours and a readiness percentage from 0 to 100',
          ),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final base = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId);
      final batch = FirebaseFirestore.instance.batch();
      batch.set(base.collection('progress').doc('summary'), {
        'completedHours': manualHours ? hours : (automaticHours ?? hours),
        'completedHoursOverride': manualHours ? hours : FieldValue.delete(),
        'testReadinessPercent': readiness,
        for (final k in ['covered', 'strengths', 'improvements', 'nextSteps'])
          k: fields[k]!.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(
        base.collection('instructorPrivate').doc('progress'),
        {
          'notes': fields['privateNotes']!.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Progress updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Update Driving Progress')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (automaticHours != null) ...[
          Text(
            'Automatically calculated from completed lessons: ${automaticHours!.toStringAsFixed(1)} hours',
          ),
          SwitchListTile(
            title: const Text('Manually adjust completed hours'),
            subtitle: const Text(
              'When off, completed lessons determine the total.',
            ),
            value: manualHours,
            onChanged: (v) => setState(() {
              manualHours = v;
              if (!v) {
                fields['completedHours']!.text = automaticHours!
                    .toStringAsFixed(1);
              }
            }),
          ),
        ],
        for (final entry in fields.entries) ...[
          TextField(
            controller: entry.value,
            readOnly: entry.key == 'completedHours' && !manualHours,
            keyboardType:
                ['completedHours', 'testReadinessPercent'].contains(entry.key)
                ? TextInputType.number
                : TextInputType.multiline,
            minLines: 1,
            maxLines:
                ['completedHours', 'testReadinessPercent'].contains(entry.key)
                ? 1
                : 4,
            decoration: InputDecoration(
              labelText: const {
                'completedHours': 'Completed driving hours',
                'testReadinessPercent': 'Test readiness (%)',
                'covered': 'Covered in previous lessons',
                'strengths': 'What they are doing well',
                'improvements': 'Areas to improve',
                'nextSteps': 'Focus for next lessons',
                'privateNotes':
                    'Private instructor notes — never visible to student',
              }[entry.key],
            ),
          ),
          const SizedBox(height: 14),
        ],
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Saving…' : 'Save progress'),
        ),
      ],
    ),
  );
}
