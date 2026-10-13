/// Client view of app_settings/main. Missing fields fall back to safe defaults.
class WorkingDay {
  const WorkingDay(this.start, this.end);
  final String start; // "HH:mm"
  final String end;
  Map<String, dynamic> toMap() => {'start': start, 'end': end};
}

class AppSettings {
  const AppSettings({
    this.lessonDurationMinutes = 120,
    this.slotStepMinutes = 30,
    this.studentChangeNoticeHours = 48,
    this.minBookingNoticeHours = 12,
    this.maxAdvanceBookingDays = 90,
    this.travelBufferMinutes = 10,
    this.reminderOffsetsHours = const [24, 2],
    this.requireAdminApproval = false,
    this.workingHours = const {
      1: WorkingDay('08:00', '18:00'),
      2: WorkingDay('08:00', '18:00'),
      3: WorkingDay('08:00', '18:00'),
      4: WorkingDay('08:00', '18:00'),
      5: WorkingDay('08:00', '18:00'),
      6: WorkingDay('09:00', '16:00'),
      7: null,
    },
  });

  final int lessonDurationMinutes;
  final int slotStepMinutes;
  final int studentChangeNoticeHours;
  final int minBookingNoticeHours;
  final int maxAdvanceBookingDays;
  final int travelBufferMinutes;
  final List<int> reminderOffsetsHours;
  final bool requireAdminApproval;

  /// ISO weekday (1 = Monday .. 7 = Sunday) -> hours, null when not working.
  final Map<int, WorkingDay?> workingHours;

  factory AppSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const AppSettings();
    const d = AppSettings();
    final wh = <int, WorkingDay?>{...d.workingHours};
    final raw = m['workingHours'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final k = int.tryParse('${e.key}');
        if (k == null) continue;
        final v = e.value;
        wh[k] = v is Map ? WorkingDay('${v['start']}', '${v['end']}') : null;
      }
    }
    int i(String k, int fallback) => (m[k] as num?)?.toInt() ?? fallback;
    return AppSettings(
      lessonDurationMinutes: i('lessonDurationMinutes', d.lessonDurationMinutes),
      slotStepMinutes: i('slotStepMinutes', d.slotStepMinutes),
      studentChangeNoticeHours: i('studentChangeNoticeHours', d.studentChangeNoticeHours),
      minBookingNoticeHours: i('minBookingNoticeHours', d.minBookingNoticeHours),
      maxAdvanceBookingDays: i('maxAdvanceBookingDays', d.maxAdvanceBookingDays),
      travelBufferMinutes: i('travelBufferMinutes', d.travelBufferMinutes),
      reminderOffsetsHours: (m['reminderOffsetsHours'] as List?)?.map((e) => (e as num).toInt()).toList() ??
          d.reminderOffsetsHours,
      requireAdminApproval: (m['requireAdminApproval'] as bool?) ?? false,
      workingHours: wh,
    );
  }

  Map<String, dynamic> toMap() => {
        'lessonDurationMinutes': lessonDurationMinutes,
        'slotStepMinutes': slotStepMinutes,
        'studentChangeNoticeHours': studentChangeNoticeHours,
        'minBookingNoticeHours': minBookingNoticeHours,
        'maxAdvanceBookingDays': maxAdvanceBookingDays,
        'travelBufferMinutes': travelBufferMinutes,
        'reminderOffsetsHours': reminderOffsetsHours,
        'requireAdminApproval': requireAdminApproval,
        'workingHours': {for (final e in workingHours.entries) '${e.key}': e.value?.toMap()},
      };

  AppSettings copyWith({
    int? travelBufferMinutes,
    int? studentChangeNoticeHours,
    int? minBookingNoticeHours,
    List<int>? reminderOffsetsHours,
    bool? requireAdminApproval,
    Map<int, WorkingDay?>? workingHours,
  }) =>
      AppSettings(
        lessonDurationMinutes: lessonDurationMinutes,
        slotStepMinutes: slotStepMinutes,
        studentChangeNoticeHours: studentChangeNoticeHours ?? this.studentChangeNoticeHours,
        minBookingNoticeHours: minBookingNoticeHours ?? this.minBookingNoticeHours,
        maxAdvanceBookingDays: maxAdvanceBookingDays,
        travelBufferMinutes: travelBufferMinutes ?? this.travelBufferMinutes,
        reminderOffsetsHours: reminderOffsetsHours ?? this.reminderOffsetsHours,
        requireAdminApproval: requireAdminApproval ?? this.requireAdminApproval,
        workingHours: workingHours ?? this.workingHours,
      );
}
