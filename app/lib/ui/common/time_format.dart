import '../../l10n/l10n.dart';

/// How the app writes times. Nothing here reads the clock: `now` is passed in, so every format is testable.

String _two(int n) => n.toString().padLeft(2, '0');

/// "14:32".
String clockTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// "14:32:07", for the agent log.
String clockSeconds(DateTime t) => '${clockTime(t)}:${_two(t.second)}';

String _month(AppLocalizations l, DateTime t) => l.monthsShort.split(' ')[t.month - 1];

/// "3 ott" this year, "3 ott 2025" before.
String shortDate(AppLocalizations l, DateTime t, DateTime now) =>
    t.year == now.year ? l.dateThisYear(t.day, _month(l, t)) : l.dateOtherYear(t.day, _month(l, t), '${t.year}');

/// A message's time: "14:32" today, "ieri 14:32", "3 ott, 14:32" this year, "3 ott 2025, 14:32" before.
String shortStamp(AppLocalizations l, DateTime t, DateTime now) {
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days == 0) return clockTime(t);
  if (days == 1) return l.timeYesterdayAt(clockTime(t));
  return l.dateAt(shortDate(l, t, now), clockTime(t));
}

/// The full date and time, for a tooltip: "5 ott 2026, 14:32:07".
String fullStamp(AppLocalizations l, DateTime t) =>
    l.dateAt(l.dateOtherYear(t.day, _month(l, t), '${t.year}'), clockSeconds(t));

/// How long ago: "adesso", "5 min fa", "3 h fa", "ieri", "4 giorni fa", then the date.
String relativeTime(AppLocalizations l, DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return l.timeNow;
  if (d.inHours < 1) return l.timeMinutesAgo(d.inMinutes);
  if (d.inDays < 1) return l.timeHoursAgo(d.inHours);
  if (d.inDays < 7) return l.timeDaysAgo(d.inDays);
  return shortDate(l, t, now);
}
