import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// Notification categories as the server defines them
/// (`notifications.Categories`), in the order the settings screen shows
/// them. Unknown categories from a newer server are shown by their wire
/// value, after these.
const List<String> notificationCategories = <String>[
  'security',
  'account',
  'budget',
  'bill',
  'subscription',
  'recurring',
  'goal',
  'group',
  'settlement',
  'trip',
  'community',
  'challenge',
  'social',
  'import',
  'receipt',
  'export',
  'insight',
  'system',
];

/// Name of a notification category.
String notificationCategoryLabel(AppLocalizations l10n, String category) =>
    switch (category) {
      'budget' => l10n.notifCategoryBudget,
      'bill' => l10n.notifCategoryBill,
      'subscription' => l10n.notifCategorySubscription,
      'recurring' => l10n.notifCategoryRecurring,
      'goal' => l10n.notifCategoryGoal,
      'group' => l10n.notifCategoryGroup,
      'settlement' => l10n.notifCategorySettlement,
      'trip' => l10n.notifCategoryTrip,
      'community' => l10n.notifCategoryCommunity,
      'challenge' => l10n.notifCategoryChallenge,
      'security' => l10n.notifCategorySecurity,
      'import' => l10n.notifCategoryImport,
      'receipt' => l10n.notifCategoryReceipt,
      'export' => l10n.notifCategoryExport,
      'account' => l10n.notifCategoryAccount,
      'insight' => l10n.notifCategoryInsight,
      'system' => l10n.notifCategorySystem,
      'social' => l10n.notifCategorySocial,
      _ => category.replaceAll('_', ' '),
    };

/// Decorative icon of a category (the label carries the meaning).
IconData notificationCategoryIcon(String category) => switch (category) {
  'budget' => Icons.pie_chart_outline,
  'bill' => Icons.receipt_long_outlined,
  'subscription' => Icons.autorenew,
  'recurring' => Icons.event_repeat,
  'goal' => Icons.flag_outlined,
  'group' => Icons.group_outlined,
  'settlement' => Icons.handshake_outlined,
  'trip' => Icons.luggage_outlined,
  'community' => Icons.forum_outlined,
  'challenge' => Icons.emoji_events_outlined,
  'security' => Icons.shield_outlined,
  'import' => Icons.upload_file_outlined,
  'receipt' => Icons.receipt_outlined,
  'export' => Icons.download_outlined,
  'account' => Icons.manage_accounts_outlined,
  'insight' => Icons.lightbulb_outline,
  'system' => Icons.info_outline,
  'social' => Icons.person_add_alt_outlined,
  _ => Icons.notifications_outlined,
};

/// Name of a delivery channel.
String notificationChannelLabel(
  AppLocalizations l10n,
  PreferenceDtoChannel channel,
) => switch (channel) {
  PreferenceDtoChannel.inApp => l10n.notifChannelInApp,
  PreferenceDtoChannel.email => l10n.notifChannelEmail,
  PreferenceDtoChannel.push => l10n.notifChannelPush,
  PreferenceDtoChannel.webPush => l10n.notifChannelWebPush,
  PreferenceDtoChannel.unrecognized => channel.json,
};

/// Channels in the order the settings screen shows them.
const List<PreferenceDtoChannel> notificationChannels = <PreferenceDtoChannel>[
  PreferenceDtoChannel.inApp,
  PreferenceDtoChannel.email,
  PreferenceDtoChannel.push,
  PreferenceDtoChannel.webPush,
];

/// Name of a per-category email digest choice (`immediate` follows the
/// account's email digest).
String notificationDigestLabel(
  AppLocalizations l10n,
  PreferenceDtoDigest digest,
) => switch (digest) {
  PreferenceDtoDigest.immediate => l10n.notifDigestFollowAccount,
  PreferenceDtoDigest.daily => l10n.notifDigestDaily,
  PreferenceDtoDigest.weekly => l10n.notifDigestWeekly,
  PreferenceDtoDigest.unrecognized => digest.json,
};

/// Name of the account-wide email digest.
String emailDigestLabel(
  AppLocalizations l10n,
  PreferencesDtoEmailDigest digest,
) => switch (digest) {
  PreferencesDtoEmailDigest.off => l10n.notifDigestOff,
  PreferencesDtoEmailDigest.daily => l10n.notifDigestDaily,
  PreferencesDtoEmailDigest.weekly => l10n.notifDigestWeekly,
  PreferencesDtoEmailDigest.unrecognized => digest.json,
};

/// A visible word for priorities above normal; null for `low` / `normal`.
String? notificationPriorityLabel(AppLocalizations l10n, String priority) =>
    switch (priority) {
      'high' => l10n.notifPriorityHigh,
      'critical' => l10n.notifPriorityCritical,
      _ => null,
    };

/// `HH:MM` → the time of day, or null when the value is not a clock time.
TimeOfDay? parseClockTime(String value) {
  final Match? m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value.trim());
  if (m == null) {
    return null;
  }
  final int hour = int.parse(m.group(1)!);
  final int minute = int.parse(m.group(2)!);
  if (hour > 23 || minute > 59) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

/// A time of day as the contract's `HH:MM`.
String clockTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
