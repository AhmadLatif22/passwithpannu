import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_time_utils.dart';

enum DiaryMode { day, week, month }

class DiaryState {
  const DiaryState(this.mode, this.date);
  final DiaryMode mode;
  final DateTime date; // plain calendar date (business day)

  DateTime get weekStart => DateTime(date.year, date.month, date.day - (date.weekday - 1));
}

class DiaryController extends Notifier<DiaryState> {
  @override
  DiaryState build() => DiaryState(DiaryMode.week, DateTimeUtils.todayBusiness());

  void setMode(DiaryMode m) => state = DiaryState(m, state.date);
  void today() => state = DiaryState(state.mode, DateTimeUtils.todayBusiness());
  void goToDay(DateTime d) => state = DiaryState(DiaryMode.day, DateTime(d.year, d.month, d.day));

  void shift(int direction) {
    final d = state.date;
    final next = switch (state.mode) {
      DiaryMode.day => DateTime(d.year, d.month, d.day + direction),
      DiaryMode.week => DateTime(d.year, d.month, d.day + 7 * direction),
      DiaryMode.month => DateTime(d.year, d.month + direction, 1),
    };
    state = DiaryState(state.mode, next);
  }
}

final diaryControllerProvider = NotifierProvider<DiaryController, DiaryState>(DiaryController.new);
