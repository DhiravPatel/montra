import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/formatting/dates.dart';

/// "just now", "5 minutes ago", "yesterday", or a date for older moments.
/// Future instants (clock skew) read as "just now".
String formatRelativeTime(
  AppLocalizations l10n,
  DateTime when, {
  required DateTime now,
  required String locale,
}) {
  final Duration age = now.difference(when);
  if (age.inMinutes < 1) {
    return l10n.relativeJustNow;
  }
  if (age.inHours < 1) {
    return l10n.relativeMinutesAgo(age.inMinutes);
  }
  if (age.inDays < 1) {
    return l10n.relativeHoursAgo(age.inHours);
  }
  if (age.inDays < 7) {
    return l10n.relativeDaysAgo(age.inDays);
  }
  return formatShortDate(when, locale: locale);
}

/// Medium date in the user's local time zone and date format, e.g.
/// `4 Nov 2026`.
String formatShortDate(DateTime when, {required String locale}) =>
    LocalDates.displayDay(when.toLocal(), locale: locale);

/// A wait for messages: "30 seconds", "15 minutes" (rounded up, minimum one
/// second). Servers can ask for long waits (e.g. the sign-in throttle window).
String formatWait(AppLocalizations l10n, Duration wait) {
  final int seconds = (wait.inMilliseconds / 1000).ceil();
  if (seconds < 60) {
    return l10n.durationSeconds(seconds < 1 ? 1 : seconds);
  }
  return l10n.durationMinutes((seconds / 60).ceil());
}

/// A compact wait for button labels: "30s", "15 min".
String formatWaitShort(AppLocalizations l10n, int seconds) {
  if (seconds < 60) {
    return l10n.shortSeconds(seconds < 1 ? 1 : seconds);
  }
  return l10n.shortMinutes((seconds / 60).ceil());
}
