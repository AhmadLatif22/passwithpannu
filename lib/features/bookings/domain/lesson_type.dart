/// Gearbox type chosen by the student. Persisted as [name] in Firestore.
enum LessonType {
  automatic,
  manual;

  String get label => switch (this) {
        LessonType.automatic => 'Automatic',
        LessonType.manual => 'Manual',
      };

  static LessonType fromName(String value) => LessonType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => throw ArgumentError('Unknown LessonType: $value'),
      );
}
