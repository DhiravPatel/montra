import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/app/theme/theme_mode_controller.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/formatting/file_size.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/settings/data/limits_api.dart';
import 'package:montra_mobile/features/settings/presentation/edit_profile_screen.dart';

/// Profile tab: who is signed in, accounts, payment methods, the Home
/// layout, security settings, appearance and sign-out.
class ProfileScreen extends ConsumerWidget {
  /// Creates the screen.
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AuthState auth = ref.watch(authControllerProvider);
    final UserDto? user = auth is SignedIn ? auth.user : null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        children: <Widget>[
          if (user != null)
            ContentFrame(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          ProfileAvatar(
                            fileId: user.avatarFileId?.isEmpty ?? true
                                ? null
                                : user.avatarFileId,
                            name: user.displayName,
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                l10n.profileSignedInAs(user.displayName),
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(user.email, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: Insets.sm),
                      StatusLabel(
                        text: user.emailVerified
                            ? l10n.emailVerifiedStatus
                            : l10n.emailNotVerifiedStatus,
                        tone: user.emailVerified
                            ? StatusTone.positive
                            : StatusTone.caution,
                      ),
                      const SizedBox(height: Insets.sm),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.editProfile),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(l10n.profileEditEntry),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ContentFrame(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(l10n.profileAccountsTitle),
                  subtitle: Text(l10n.profileAccountsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.accounts),
                ),
                ListTile(
                  leading: const Icon(Icons.credit_card_outlined),
                  title: Text(l10n.profilePaymentMethodsTitle),
                  subtitle: Text(l10n.profilePaymentMethodsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.paymentMethods),
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: Text(l10n.prefsTitle),
                  subtitle: Text(l10n.prefsEntrySubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.preferences),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: Text(l10n.profileHomeLayout),
                  subtitle: Text(l10n.profileHomeLayoutSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.dashboardWidgets),
                ),
              ],
            ),
          ),
          const Divider(),
          ContentFrame(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.md,
                    Insets.sm,
                    Insets.md,
                    0,
                  ),
                  child: SectionHeading(l10n.profileOrganizeTitle),
                ),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(l10n.categoriesTitle),
                  subtitle: Text(l10n.profileCategoriesSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.categories),
                ),
                ListTile(
                  leading: const Icon(Icons.rule),
                  title: Text(l10n.categoryRulesTitle),
                  subtitle: Text(l10n.profileRulesSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.categoryRules),
                ),
                ListTile(
                  leading: const Icon(Icons.sell_outlined),
                  title: Text(l10n.tagsTitle),
                  subtitle: Text(l10n.profileTagsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.tags),
                ),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(l10n.merchantsTitle),
                  subtitle: Text(l10n.profileMerchantsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.merchants),
                ),
              ],
            ),
          ),
          const Divider(),
          ContentFrame(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.md,
                    Insets.sm,
                    Insets.md,
                    0,
                  ),
                  child: SectionHeading(l10n.profileDataTitle),
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_outlined),
                  title: Text(l10n.entryReceipts),
                  subtitle: Text(l10n.entryReceiptsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.receipts),
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: Text(l10n.entryImports),
                  subtitle: Text(l10n.entryImportsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.imports),
                ),
                ListTile(
                  leading: const Icon(Icons.insights_outlined),
                  title: Text(l10n.entryAnalytics),
                  subtitle: Text(l10n.entryAnalyticsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.analytics),
                ),
                ListTile(
                  leading: const Icon(Icons.summarize_outlined),
                  title: Text(l10n.entryReports),
                  subtitle: Text(l10n.entryReportsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.reports),
                ),
                ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: Text(l10n.entryExchangeRates),
                  subtitle: Text(l10n.entryExchangeRatesSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.exchangeRates),
                ),
                const _StorageTile(),
              ],
            ),
          ),
          const Divider(),
          ContentFrame(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.md,
                    Insets.sm,
                    Insets.md,
                    0,
                  ),
                  child: SectionHeading(l10n.profileYouTitle),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(l10n.notificationsTitle),
                  subtitle: Text(l10n.profileNotificationsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.notifications),
                ),
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: Text(l10n.profileFriendsTitle),
                  subtitle: Text(l10n.profileFriendsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.friends),
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(l10n.profileIntegrationsTitle),
                  subtitle: Text(l10n.profileIntegrationsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.integrations),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(l10n.privacyTitle),
                  subtitle: Text(l10n.profilePrivacySubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.privacy),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: Text(l10n.profileModerationTitle),
                  subtitle: Text(l10n.profileModerationSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.myModeration),
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(l10n.helpTitle),
                  subtitle: Text(l10n.profileHelpSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.help),
                ),
              ],
            ),
          ),
          const Divider(),
          ContentFrame(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(l10n.securityTitle),
              subtitle: Text(l10n.securitySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.security),
            ),
          ),
          const Divider(),
          const ContentFrame(child: _AppearanceSection()),
          const Divider(),
          ContentFrame(
            child: SubmitButton(
              kind: SubmitButtonKind.outlined,
              icon: Icons.logout,
              label: l10n.signOutButton,
              onPressed: () async {
                final bool confirmed = await ref
                    .read(authControllerProvider.notifier)
                    .signOut();
                if (!confirmed && context.mounted) {
                  showSnack(context, l10n.signedOutOffline);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// File storage use from `GET /limits`; opens the fair-use limits. Hidden
/// when the limits cannot be read (nothing depends on them).
class _StorageTile extends ConsumerWidget {
  const _StorageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Limits> limits = ref.watch(limitsProvider);
    final Limits? data = limits.value;
    if (data == null && limits.hasError) {
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: const Icon(Icons.cloud_outlined),
      title: Text(l10n.limitsStorageTitle),
      subtitle: Text(
        data == null
            ? l10n.loadingLabel
            : l10n.limitsStorageUsed(
                formatFileSize(l10n, data.storageUsedBytes),
                formatFileSize(l10n, data.storageQuotaBytes),
              ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.limits),
    );
  }
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeMode mode = ref.watch(themeModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeading(l10n.appearanceTitle),
        const SizedBox(height: Insets.sm),
        SegmentedButton<ThemeMode>(
          segments: <ButtonSegment<ThemeMode>>[
            ButtonSegment<ThemeMode>(
              value: ThemeMode.system,
              icon: const Icon(Icons.brightness_auto_outlined),
              label: Text(l10n.themeSystem),
            ),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.light,
              icon: const Icon(Icons.light_mode_outlined),
              label: Text(l10n.themeLight),
            ),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.dark,
              icon: const Icon(Icons.dark_mode_outlined),
              label: Text(l10n.themeDark),
            ),
          ],
          selected: <ThemeMode>{mode},
          onSelectionChanged: (Set<ThemeMode> selection) =>
              ref.read(themeModeProvider.notifier).select(selection.first),
        ),
      ],
    );
  }
}
