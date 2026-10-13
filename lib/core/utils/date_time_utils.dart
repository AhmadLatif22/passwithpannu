import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../constants/app_constants.dart';

/// Every date shown in the app goes through here. Storage is UTC; display and
/// day boundaries use the instructor's business time zone (Europe/London).
abstract final class DateTimeUtils {
  static tz.Location? _location;
  static tz.Location get _loc =>
      _location ?? (throw StateError('Call DateTimeUtils.init() at startup.'));

  static void init() {
    tzdata.initializeTimeZones();
    _location = tz.getLocation(AppConstants.businessTimeZone);
  }

  static final _dateKey = DateFormat('yyyy-MM-dd');
  static final _fullDate = DateFormat('EEE d MMM yyyy');
  static final _longDate = DateFormat('EEEE d MMMM');
  static final _dayMonth = DateFormat('d MMMM');
  static final _shortDate = DateFormat('EEE d MMM');
  static final _time = DateFormat('h:mm a');
  static final _monthYear = DateFormat('MMMM yyyy');

  static tz.TZDateTime toBusiness(DateTime d) => tz.TZDateTime.from(d.toUtc(), _loc);

  /// Business wall-clock time -> UTC instant (what gets sent to / stored by the backend).
  static DateTime fromBusinessParts(int y, int m, int d, int hour, int minute) =>
      tz.TZDateTime(_loc, y, m, d, hour, minute).toUtc();

  static DateTime startOfBusinessDay(int y, int m, int d) => fromBusinessParts(y, m, d, 0, 0);

  /// "2026-10-12" in business time: groups a day's lessons.
  static String dateKey(DateTime instant) => _dateKey.format(toBusiness(instant));

  /// Key for a plain calendar date the user picked (no time zone conversion).
  static String keyOfDate(DateTime plain) => _dateKey.format(DateTime(plain.year, plain.month, plain.day));

  static DateTime parseKey(String key) {
    final p = key.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static DateTime todayBusiness() {
    final n = toBusiness(DateTime.now());
    return DateTime(n.year, n.month, n.day);
  }

  static String formatDate(DateTime d) => _fullDate.format(toBusiness(d));
  static String formatLongDate(DateTime d) => _longDate.format(toBusiness(d));
  static String formatDayMonth(DateTime d) => _dayMonth.format(toBusiness(d));
  static String formatShortDate(DateTime d) => _shortDate.format(toBusiness(d));
  static String formatTime(DateTime d) => _time.format(toBusiness(d));
  static String formatPlainShort(DateTime plain) => _shortDate.format(plain);
  static String formatMonthYear(DateTime plain) => _monthYear.format(plain);

  /// "10:00 AM – 12:00 PM"
  static String formatRange(DateTime start, DateTime end) => '${formatTime(start)} – ${formatTime(end)}';

  /// "Tue 14 Oct, 2:00 PM"
  static String formatDateTime(DateTime d) => '${formatShortDate(d)}, ${formatTime(d)}';

  /// Whole days/hours until [start], phrased for humans.
  static String untilLabel(DateTime start, DateTime now) {
    final diff = start.difference(now);
    if (diff.isNegative) return 'Started';
    if (diff.inHours < 1) return 'In ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'In ${diff.inHours} h';
    final days = diff.inDays;
    return 'In $days day${days == 1 ? '' : 's'}';
  }
}
