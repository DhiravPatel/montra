import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/help/help_guide_button.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/notifications/application/notifications_providers.dart';
import 'package:montra_mobile/features/notifications/data/notifications_api.dart';
import 'package:montra_mobile/features/notifications/domain/notification_display.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';
import 'package:montra_mobile/features/settings/application/preferences_providers.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';

/// Notification settings: which categories reach the user on which
/// channel (`GET`/`PATCH /notifications/preferences`, each change sends
/// only the field that changed), the email digest per category and for
/// the account, and quiet hours (`PATCH /me/preferences`). Security and
/// account notifications are always on in the app and by email. Push
/// notifications are not set up in this mobile build.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  /// The server's answer to the last change (newer than the provider).
  List<PreferenceDto>? _saved;

  /// Account preferences after the last change.
  PreferencesDto? _account;

  /// Rows being saved (`category|channel|group`).
  final Set<String> _busy = <String>{};
  bool _accountBusy = false;

  static String _key(String category, PreferenceDtoChannel ch, String? g) =>
      '$category|${ch.json}|${g ?? ''}';

  Future<void> _patch(PreferencePatch item, String key) async {
    if (_busy.contains(key)) {
      return;
    }
    setState(() => _busy.add(key));
    try {
      final List<PreferenceDto> result = await ref
          .read(notificationsApiProvider)
          .updatePreferences(<PreferencePatch>[item]);
      if (mounted) {
        setState(() => _saved = result);
        showSnack(context, context.l10n.notifSettingsSaved);
      }
    } on Object catch (error) {
      if (mounted) {
        showSnack(context, describeError(context.l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(key));
      }
    }
  }

  Future<void> _setEnabled(PreferenceDto p, bool enabled) => _patch(
    PreferencePatch(
      category: p.category,
      channel: PreferencePatchChannel.fromJson(p.channel.json),
      groupId: p.groupId,
      enabled: enabled,
    ),
    _key(p.category, p.channel, p.groupId),
  );

  Future<void> _pickDigest(PreferenceDto p) async {
    final AppLocalizations l10n = context.l10n;
    final PreferenceDtoDigest? digest =
        await showOptionSheet<PreferenceDtoDigest>(
          context,
          title: l10n.notifEmailTimingFor(
            notificationCategoryLabel(l10n, p.category),
          ),
          selected: p.digest,
          options: <SheetOption<PreferenceDtoDigest>>[
            for (final PreferenceDtoDigest d in <PreferenceDtoDigest>[
              PreferenceDtoDigest.immediate,
              PreferenceDtoDigest.daily,
              PreferenceDtoDigest.weekly,
            ])
              SheetOption<PreferenceDtoDigest>(
                value: d,
                label: notificationDigestLabel(l10n, d),
              ),
          ],
        );
    if (digest == null || digest == p.digest || !mounted) {
      return;
    }
    await _patch(
      PreferencePatch(
        category: p.category,
        channel: PreferencePatchChannel.fromJson(p.channel.json),
        groupId: p.groupId,
        digest: PreferencePatchDigest.fromJson(digest.json),
      ),
      _key(p.category, p.channel, p.groupId),
    );
  }

  Future<void> _saveAccount(PreferencesPatch patch) async {
    if (_accountBusy) {
      return;
    }
    setState(() => _accountBusy = true);
    try {
      final PreferencesDto updated = await ref
          .read(preferencesApiProvider)
          .updatePreferences(patch);
      if (mounted) {
        setState(() => _account = updated);
        showSnack(context, context.l10n.notifSettingsSaved);
      }
    } on Object catch (error) {
      if (mounted) {
        showSnack(context, describeError(context.l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _accountBusy = false);
      }
    }
  }

  Future<void> _pickAccountDigest(PreferencesDto account) async {
    final AppLocalizations l10n = context.l10n;
    final PreferencesDtoEmailDigest? digest =
        await showOptionSheet<PreferencesDtoEmailDigest>(
          context,
          title: l10n.notifAccountDigestTitle,
          selected: account.emailDigest,
          options: <SheetOption<PreferencesDtoEmailDigest>>[
            for (final PreferencesDtoEmailDigest d
                in <PreferencesDtoEmailDigest>[
                  PreferencesDtoEmailDigest.off,
                  PreferencesDtoEmailDigest.daily,
                  PreferencesDtoEmailDigest.weekly,
                ])
              SheetOption<PreferencesDtoEmailDigest>(
                value: d,
                label: emailDigestLabel(l10n, d),
              ),
          ],
        );
    if (digest == null || digest == account.emailDigest || !mounted) {
      return;
    }
    await _saveAccount(
      PreferencesPatch(
        emailDigest: PreferencesPatchEmailDigest.fromJson(digest.json),
      ),
    );
  }

  Future<void> _pickQuietTime(
    PreferencesDto account, {
    required bool start,
  }) async {
    final String current = start
        ? account.quietHoursStart
        : account.quietHoursEnd;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime:
          parseClockTime(current) ??
          (start
              ? const TimeOfDay(hour: 22, minute: 0)
              : const TimeOfDay(hour: 7, minute: 0)),
    );
    if (picked == null || !mounted) {
      return;
    }
    await _saveAccount(
      start
          ? PreferencesPatch(quietHoursStart: clockTime(picked))
          : PreferencesPatch(quietHoursEnd: clockTime(picked)),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _saved = null;
      _account = null;
    });
    ref
      ..invalidate(notificationPreferencesProvider)
      ..invalidate(preferencesProvider);
    try {
      await ref.read(notificationPreferencesProvider.future);
    } on Object {
      // Shown by the screen state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<PreferenceDto>> prefs = ref.watch(
      notificationPreferencesProvider,
    );
    return Scaffold(
      appBar: AppBar(
        actions: const <Widget>[HelpGuideButton(HelpGuide.troubleshooting)],
        title: Text(l10n.notifSettingsTitle),
      ),
      body: AsyncValueView<List<PreferenceDto>>(
        value: prefs,
        onRetry: () => ref.invalidate(notificationPreferencesProvider),
        data: (List<PreferenceDto> loaded) {
          final List<PreferenceDto> all = _saved ?? loaded;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.only(bottom: Insets.xl),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.md,
                    Insets.md,
                    Insets.md,
                    0,
                  ),
                  child: NoticeBanner(
                    title: l10n.notifPushTitle,
                    message: l10n.notifPushNotConfigured,
                  ),
                ),
                _accountSection(context),
                for (final String category in _categoriesOf(all))
                  _categorySection(context, category, all),
                ..._groupSection(context, all),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Known categories in their order, then any newer ones.
  List<String> _categoriesOf(List<PreferenceDto> all) {
    final Set<String> present = <String>{
      for (final PreferenceDto p in all)
        if (p.groupId == null) p.category,
    };
    return <String>[
      for (final String c in notificationCategories)
        if (present.contains(c)) c,
      for (final String c in present)
        if (!notificationCategories.contains(c)) c,
    ];
  }

  Widget _accountSection(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<PreferencesDto> loaded = ref.watch(preferencesProvider);
    final PreferencesDto? account = _account ?? loaded.value;
    if (account == null) {
      return SectionCard(
        title: l10n.notifEmailAndQuietTitle,
        children: <Widget>[
          if (loaded.hasError)
            ListTile(
              title: Text(describeError(l10n, loaded.error!)),
              trailing: TextButton(
                onPressed: () => ref.invalidate(preferencesProvider),
                child: Text(l10n.actionRetry),
              ),
            )
          else
            const LoadingStateView(),
        ],
      );
    }
    String timeText(String value) {
      final TimeOfDay? t = parseClockTime(value);
      if (t == null) {
        return value;
      }
      return MaterialLocalizations.of(context).formatTimeOfDay(t);
    }

    return SectionCard(
      title: l10n.notifEmailAndQuietTitle,
      children: <Widget>[
        ListTile(
          title: Text(l10n.notifAccountDigestTitle),
          subtitle: Text(
            '${emailDigestLabel(l10n, account.emailDigest)}\n'
            '${l10n.notifAccountDigestHelp}',
          ),
          trailing: const Icon(Icons.chevron_right),
          enabled: !_accountBusy,
          onTap: () => _pickAccountDigest(account),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: Text(l10n.notifQuietHoursTitle),
          subtitle: Text(l10n.notifQuietHoursHelp),
          value: account.quietHoursEnabled,
          onChanged: _accountBusy
              ? null
              : (bool on) =>
                    _saveAccount(PreferencesPatch(quietHoursEnabled: on)),
        ),
        if (account.quietHoursEnabled) ...<Widget>[
          ListTile(
            title: Text(l10n.notifQuietHoursFrom),
            subtitle: Text(timeText(account.quietHoursStart)),
            trailing: const Icon(Icons.schedule),
            enabled: !_accountBusy,
            onTap: () => _pickQuietTime(account, start: true),
          ),
          ListTile(
            title: Text(l10n.notifQuietHoursTo),
            subtitle: Text(timeText(account.quietHoursEnd)),
            trailing: const Icon(Icons.schedule),
            enabled: !_accountBusy,
            onTap: () => _pickQuietTime(account, start: false),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(
              l10n.notifQuietHoursZone(account.timezone),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Widget _channelRow(BuildContext context, PreferenceDto p) {
    final AppLocalizations l10n = context.l10n;
    final bool busy = _busy.contains(_key(p.category, p.channel, p.groupId));
    final String? note = p.locked
        ? l10n.notifAlwaysOn
        : switch (p.channel) {
            PreferenceDtoChannel.push => l10n.notifPushChannelNote,
            PreferenceDtoChannel.webPush => l10n.notifWebPushChannelNote,
            _ => null,
          };
    return SwitchListTile(
      title: Text(notificationChannelLabel(l10n, p.channel)),
      subtitle: note == null ? null : Text(note),
      value: p.enabled,
      onChanged: p.locked || busy ? null : (bool on) => _setEnabled(p, on),
    );
  }

  Widget _digestRow(BuildContext context, PreferenceDto p) {
    final AppLocalizations l10n = context.l10n;
    final bool busy = _busy.contains(_key(p.category, p.channel, p.groupId));
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(
        start: Insets.xl,
        end: Insets.md,
      ),
      title: Text(l10n.notifEmailTiming),
      subtitle: Text(notificationDigestLabel(l10n, p.digest)),
      trailing: const Icon(Icons.chevron_right),
      enabled: !busy,
      onTap: () => _pickDigest(p),
    );
  }

  Widget _categorySection(
    BuildContext context,
    String category,
    List<PreferenceDto> all,
  ) {
    final AppLocalizations l10n = context.l10n;
    final List<PreferenceDto> rows = <PreferenceDto>[
      for (final PreferenceDtoChannel ch in notificationChannels)
        ...all.where(
          (PreferenceDto p) =>
              p.groupId == null && p.category == category && p.channel == ch,
        ),
    ];
    final bool locked = rows.any((PreferenceDto p) => p.locked);
    return SectionCard(
      title: notificationCategoryLabel(l10n, category),
      children: <Widget>[
        if (locked)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.xs,
            ),
            child: Text(l10n.notifAlwaysOnNote),
          ),
        for (final PreferenceDto p in rows) ...<Widget>[
          _channelRow(context, p),
          if (p.channel == PreferenceDtoChannel.email && p.enabled)
            _digestRow(context, p),
        ],
      ],
    );
  }

  List<Widget> _groupSection(BuildContext context, List<PreferenceDto> all) {
    final AppLocalizations l10n = context.l10n;
    final List<PreferenceDto> rows = <PreferenceDto>[
      for (final PreferenceDto p in all)
        if (p.groupId != null) p,
    ];
    if (rows.isEmpty) {
      return const <Widget>[];
    }
    final Map<String, GroupDto> groups = ref.watch(groupIndexProvider);
    return <Widget>[
      SectionCard(
        title: l10n.notifGroupOverridesTitle,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(l10n.notifGroupOverridesHelp),
          ),
          for (final PreferenceDto p in rows)
            SwitchListTile(
              title: Text(
                '${groups[p.groupId]?.name ?? l10n.notifGroupUnknown} · '
                '${notificationCategoryLabel(l10n, p.category)}',
              ),
              subtitle: Text(notificationChannelLabel(l10n, p.channel)),
              value: p.enabled,
              onChanged:
                  p.locked ||
                      _busy.contains(_key(p.category, p.channel, p.groupId))
                  ? null
                  : (bool on) => _setEnabled(p, on),
            ),
        ],
      ),
    ];
  }
}
