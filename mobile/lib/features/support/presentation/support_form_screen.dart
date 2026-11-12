import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/support/application/support_providers.dart';
import 'package:montra_mobile/features/support/data/support_api.dart';
import 'package:montra_mobile/features/support/domain/support_display.dart';

/// Validates a support text field: required, within the contract's
/// lengths, and free of card numbers, PINs, OTPs and passwords.
String? validateSupportText(
  AppLocalizations l10n,
  String? value, {
  required int min,
  required int max,
}) {
  final String text = value?.trim() ?? '';
  if (text.isEmpty) {
    return l10n.fieldRequired;
  }
  if (text.length < min) {
    return l10n.fieldTooShort('$min');
  }
  if (text.length > max) {
    return l10n.fieldTooLong('$max');
  }
  if (containsSecret(text)) {
    return l10n.fieldContainsSecret;
  }
  return null;
}

/// A new support request (`POST /support/requests`): kind, subject and
/// message. Text that looks like a card number, PIN, OTP or password is
/// refused before sending (the API refuses it too: `contains_secret`); the
/// daily limit answers with the time it opens again (`daily_cap`).
class SupportFormScreen extends ConsumerStatefulWidget {
  /// Creates the form.
  const SupportFormScreen({super.key});

  @override
  ConsumerState<SupportFormScreen> createState() => _SupportFormScreenState();
}

class _SupportFormScreenState extends ConsumerState<SupportFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _body = TextEditingController();
  RequestInputKind _kind = RequestInputKind.support;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'kind': 'kind',
    'subject': 'subject',
    'body': 'body',
  };

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    try {
      final RequestDto created = await ref
          .read(supportApiProvider)
          .create(
            RequestInput(
              kind: _kind,
              subject: _subject.text.trim(),
              body: _body.text.trim(),
            ),
          );
      ref.invalidate(supportRequestsProvider);
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.helpRequestSent(created.reference));
      context.pushReplacement(AppRoutes.supportRequestDetail(created.id));
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpNewRequest)),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            if (general != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: general,
                requestId: _errors.requestId,
              ),
              const SizedBox(height: Insets.md),
            ],
            NoticeBanner(message: l10n.helpNoSecretsNote),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<RequestInputKind>(
              initialValue: _kind,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.helpKindLabel,
                errorText: _errors['kind'],
              ),
              items: <DropdownMenuItem<RequestInputKind>>[
                for (final RequestInputKind k in supportKinds)
                  DropdownMenuItem<RequestInputKind>(
                    value: k,
                    child: Text(supportKindLabel(l10n, k.json)),
                  ),
              ],
              onChanged: (RequestInputKind? k) =>
                  setState(() => _kind = k ?? _kind),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _subject,
              maxLength: RequestInput.subjectMaxLength,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.helpSubjectLabel,
                errorText: _errors['subject'],
              ),
              validator: (String? v) => validateSupportText(
                l10n,
                v,
                min: RequestInput.subjectMinLength,
                max: RequestInput.subjectMaxLength,
              ),
            ),
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _body,
              maxLength: RequestInput.bodyMaxLength,
              minLines: 5,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                labelText: l10n.helpBodyLabel,
                helperText: l10n.helpBodyHelp,
                helperMaxLines: 3,
                alignLabelWithHint: true,
                errorText: _errors['body'],
                errorMaxLines: 3,
              ),
              validator: (String? v) => validateSupportText(
                l10n,
                v,
                min: RequestInput.bodyMinLength,
                max: RequestInput.bodyMaxLength,
              ),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              icon: Icons.send_outlined,
              label: l10n.helpSend,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
