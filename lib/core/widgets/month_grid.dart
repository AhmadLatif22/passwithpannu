import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Monday-first month calendar. The caller decides how each day looks, so the same
/// grid serves student date picking and the admin month diary.
class MonthGrid extends StatelessWidget {
  const MonthGrid({super.key, required this.month, required this.dayBuilder, this.cellHeight = 56});
  final DateTime month; // any date inside the month to show
  final Widget Function(DateTime day) dayBuilder;
  final double cellHeight;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = ((lead + days) / 7).ceil();
    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(w, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < rows; r++)
          SizedBox(
            height: cellHeight,
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: () {
                      final dayNum = r * 7 + c - lead + 1;
                      if (dayNum < 1 || dayNum > days) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.all(2),
                        child: dayBuilder(DateTime(month.year, month.month, dayNum)),
                      );
                    }(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
