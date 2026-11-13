import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/help/help_guide_button.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';

/// Settings → Security: two-step verification, sessions, password and
/// "sign out everywhere". Pull down to refresh the account summary.
class SecurityScreen extends ConsumerWidget {
  /// Creates the screen.
  const SecurityScreen({super.key});

  Future<void> _signOutEverywhere(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.signOutEverywhereConfirmTitle,
      body: l10n.signOutEverywhereConfirmBody,
      confirmLabel: l10n.signOutEverywhereConfirm,
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).signOutEverywhere();
    } on ApiException catch (error) {
      if (context.mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AuthState auth = ref.watch(authControllerProvider);
    final UserDto? user = auth is SignedIn ? auth.user : null;
    final bool mfaOn = user?.mfaEnabled ?? false;
    final String status = mfaOn ? l10n.statusOn : l10n.statusOff;
    return Scaffold(
      appBar: AppBar(
        actions: const <Widget>[HelpGuideButton(HelpGuide.twoStep)],
        title: Text(l10n.securityTitle),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await ref.read(authControllerProvider.notifier).refreshAccount();
          } on ApiException catch (error) {
            if (context.mounted) {
              showSnack(context, describeError(l10n, error));
            }
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            ContentFrame(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: Text(l10n.twoStepTitle),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: Insets.xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l10n.twoStepSubtitle),
                          const SizedBox(height: Insets.xs),
                          StatusLabel(
                            text: status,
                            tone: mfaOn
                                ? StatusTone.positive
                                : StatusTone.neutral,
                            semanticsLabel: l10n.twoStepStatus(status),
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.twoStep),
                  ),
                  ListTile(
                    leading: const Icon(Icons.devices_outlined),
                    title: Text(l10n.sessionsTitle),
                    subtitle: Text(l10n.sessionsSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.sessions),
                  ),
                  ListTile(
                    leading: const Icon(Icons.password_outlined),
                    title: Text(l10n.changePasswordTitle),
                    subtitle: Text(l10n.changePasswordSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.changePassword),
                  ),
                ],
              ),
            ),
            const Divider(),
            ContentFrame(
              child: SubmitButton(
                kind: SubmitButtonKind.destructive,
                icon: Icons.logout,
                label: l10n.signOutEverywhereButton,
                onPressed: () => _signOutEverywhere(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
