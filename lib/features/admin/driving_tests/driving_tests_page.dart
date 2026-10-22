import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Instructor-maintained tests; backend scheduled function sends reminders.
class DrivingTestsPage extends StatefulWidget {
  const DrivingTestsPage({super.key});
  @override
  State<DrivingTestsPage> createState() => _DrivingTestsPageState();
}

class _DrivingTestsPageState extends State<DrivingTestsPage> {
  final student = TextEditingController();
  final pickup = TextEditingController();
  DateTime? testAt;
  DateTime? pickupAt;
  bool saving = false;
  @override
  void dispose() {
    student.dispose();
    pickup.dispose();
    super.dispose();
  }

  Future<void> chooseDate({required bool forTest}) async {
    final today = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: today.subtract(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 730)),
      initialDate: today,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    final local = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (forTest) {
        testAt = local;
      } else {
        pickupAt = local;
      }
    });
  }

  Future<void> save() async {
    if (student.text.trim().isEmpty || testAt == null || pickupAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter student UID, test time and pickup time'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance.collection('drivingTests').add({
        'studentId': student.text.trim(),
        'testAt': Timestamp.fromDate(testAt!.toUtc()),
        'pickupAt': Timestamp.fromDate(pickupAt!.toUtc()),
        'pickupAddress': pickup.text.trim(),
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Driving test saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save test: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Driving tests')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Instructor test reminders · Europe/London'),
        const SizedBox(height: 12),
        TextField(
          controller: student,
          decoration: const InputDecoration(labelText: 'Student UID'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: pickup,
          decoration: const InputDecoration(
            labelText: 'Agreed pickup location',
          ),
        ),
        ListTile(
          title: Text(
            testAt == null ? 'Choose test date and time' : 'Test: $testAt',
          ),
          trailing: const Icon(Icons.event),
          onTap: () => chooseDate(forTest: true),
        ),
        ListTile(
          title: Text(
            pickupAt == null
                ? 'Choose pickup date and time'
                : 'Pickup: $pickupAt',
          ),
          trailing: const Icon(Icons.access_time),
          onTap: () => chooseDate(forTest: false),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: const Text('Save driving test'),
        ),
        const SizedBox(height: 18),
        const Text(
          'Note: enter UK local times on a device set to UK timezone. A production form should select a student by name and use Europe/London timezone conversion.',
        ),
      ],
    ),
  );
}
