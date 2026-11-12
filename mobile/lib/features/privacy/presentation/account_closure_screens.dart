import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/privacy/application/privacy_providers.dart';
import 'package:montra_mobile/features/privacy/data/privacy_api.dart';
import 'package:montra_mobile/features/privacy/domain/privacy_display.dart';
import 'package:montra_mobile/features/settings/presentation/reauth_sheet.dart';

/// Closes the account until the user signs in again (`POST /me/deactivate`,
/// after re-authentication). Every device is signed out; nothing is
/// deleted.
class DeactivateScreen extends ConsumerWidget {
  /// Creates the screen.
  const DeactivateScreen({super.key});

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.deactivateConfirmTitle,
      body: l10n.deactivateConfirmBody,
      confirmLabel: l10n.deactivateAction,
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      final bool? done = await runWithReauth<bool>(context, () async {
        await ref.read(privacyApiProvider).deactivate();
        return true;
      });
      if (done != true) {
        return;
      }
      // The server signed out every session; end this one too.
      await ref
          .read(authControllerProvider.notifier)
          .endLocalSession(SessionEndReason.signedOutEverywhere);
    } on ApiException catch (error) {
      if (context.mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deactivateTitle)),
      body: ScrollableContent(
        children: <Widget>[
          Text(l10n.deactivateIntro),
          const SizedBox(height: Insets.md),
          for (final String line in <String>[
            l10n.deactivatePointSignedOut,
            l10n.deactivatePointKept,
            l10n.deactivatePointHidden,
            l10n.deactivatePointReturn,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const ExcludeSemantics(child: Text('•  ')),
                  Expanded(child: Text(line)),
                ],
              ),
            ),
          const SizedBox(height: Insets.lg),
          SubmitButton(
            kind: SubmitButtonKind.destructive,
            icon: Icons.pause_circle_outline,
            label: l10n.deactivateAction,
            onPressed: () => _deactivate(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Deleting the account (`GET/POST/DELETE /me/deletion-request`): what
/// happens and what is kept (localized by code), how groups are affected,
/// a typed confirmation and re-authentication; a scheduled deletion can be
/// cancelled until its date.
class DeleteAccountScreen extends ConsumerWidget {
  /// Creates the screen.
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<DeletionDto> deletion = ref.watch(deletionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deletionTitle)),
      body: AsyncValueView<DeletionDto>(
        value: deletion,
        onRetry: () => ref.invalidate(deletionProvider),
        data: (DeletionDto d) => d.status == DeletionDtoStatus.scheduled
            ? _Scheduled(deletion: d)
            : _RequestDeletion(deletion: d),
      ),
    );
  }
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.deletion});

  final DeletionDto deletion;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<String> consequences = pairedTexts(
      deletion.consequenceCodes,
      deletion.consequences,
      (String code, String text) => deletionConsequence(l10n, code, text),
    );
    final List<String> retained = pairedTexts(
      deletion.retainedCodes,
      deletion.retained,
      (String code, String text) => deletionRetained(l10n, code, text),
    );
    Widget bullets(List<String> lines) => Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const ExcludeSemantics(child: Text('•  ')),
                  Expanded(child: Text(line)),
                ],
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: l10n.deletionWhatHappens,
          children: <Widget>[bullets(consequences)],
        ),
        if (retained.isNotEmpty)
          SectionCard(
            title: l10n.deletionWhatIsKept,
            children: <Widget>[bullets(retained)],
          ),
        if (deletion.groupImpactDetails.isNotEmpty)
          SectionCard(
            title: l10n.deletionGroupsTitle,
            children: <Widget>[
              bullets(<String>[
                for (final GroupImpactDto g in deletion.groupImpactDetails)
                  groupImpactText(l10n, g),
              ]),
            ],
          ),
      ],
    );
  }
}

class _RequestDeletion extends ConsumerStatefulWidget {
  const _RequestDeletion({required this.deletion});

  final DeletionDto deletion;

  @override
  ConsumerState<_RequestDeletion> createState() => _RequestDeletionState();
}

class _RequestDeletionState extends ConsumerState<_RequestDeletion> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    try {
      final DeletionDto? scheduled = await runWithReauth<DeletionDto>(
        context,
        () =>
            ref.read(privacyApiProvider).requestDeletion(reason: _reason.text),
      );
      if (scheduled == null) {
        return;
      }
      ref.invalidate(deletionProvider);
      if (mounted) {
        showSnack(context, l10n.deletionScheduledDone);
      }
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.conflict) {
        // Already scheduled elsewhere: show it.
        ref.invalidate(deletionProvider);
      }
      if (mounted) {
        setState(() => _error = describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? error = _error;
    return Form(
      key: _form,
      child: ScrollableContent(
        children: <Widget>[
          Text(l10n.deletionIntro),
          const SizedBox(height: Insets.md),
          _Disclosure(deletion: widget.deletion),
          const SizedBox(height: Insets.md),
          NoticeBanner(message: l10n.deletionExportFirst),
          const SizedBox(height: Insets.md),
          if (error != null) ...<Widget>[
            NoticeBanner(tone: NoticeTone.error, message: error),
            const SizedBox(height: Insets.md),
          ],
          TextFormField(
            controller: _reason,
            maxLength: MeDeletionRequestRequest.reasonMaxLength,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l10n.deletionReasonLabel,
              helperText: l10n.deletionReasonHelp,
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _confirm,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.deletionConfirmLabel(
                PrivacyApi.deletionConfirmWord,
              ),
            ),
            validator: (String? v) =>
                v?.trim() == PrivacyApi.deletionConfirmWord
                ? null
                : l10n.deletionConfirmMismatch(PrivacyApi.deletionConfirmWord),
          ),
          const SizedBox(height: Insets.lg),
          SubmitButton(
            kind: SubmitButtonKind.destructive,
            icon: Icons.delete_forever_outlined,
            label: l10n.deletionAction,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _Scheduled extends ConsumerWidget {
  const _Scheduled({required this.deletion});

  final DeletionDto deletion;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    try {
      await ref.read(privacyApiProvider).cancelDeletion();
      ref.invalidate(deletionProvider);
      if (context.mounted) {
        showSnack(context, l10n.deletionCancelledDone);
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final DateTime? when = deletion.scheduledFor;
    return ScrollableContent(
      children: <Widget>[
        NoticeBanner(
          tone: NoticeTone.warning,
          title: l10n.deletionScheduledTitle,
          message: when == null
              ? l10n.deletionScheduledNoDate
              : l10n.deletionScheduledFor(
                  formatShortDate(when, locale: locale),
                ),
        ),
        const SizedBox(height: Insets.md),
        _Disclosure(deletion: deletion),
        const SizedBox(height: Insets.lg),
        SubmitButton(
          icon: Icons.undo,
          label: l10n.deletionCancelAction,
          onPressed: () => _cancel(context, ref),
        ),
      ],
    );
  }
}
