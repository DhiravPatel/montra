import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/support/data/support_api.dart';
import 'package:montra_mobile/features/support/domain/support_display.dart';
import 'package:montra_mobile/features/support/presentation/support_form_screen.dart';

/// Contact form for people who are signed out (`POST /support/contact`,
/// public): for example someone who cannot sign in. Signed-in users have
/// Help & support with their request history instead.
class ContactScreen extends ConsumerStatefulWidget {
  /// Creates the form.
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _body = TextEditingController();
  ContactInputKind _kind = ContactInputKind.support;
  ServerFormErrors _errors = ServerFormErrors.none;
  String? _reference;

  static const Map<String, String> _fields = <String, String>{
    'kind': 'kind',
    'subject': 'subject',
    'body': 'body',
    'contact_email': 'email',
  };

  @override
  void dispose() {
    _email.dispose();
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
      final ContactResult result = await ref
          .read(supportApiProvider)
          .contact(
            ContactInput(
              kind: _kind,
              subject: _subject.text.trim(),
              body: _body.text.trim(),
              contactEmail: _email.text.trim(),
            ),
          );
      if (mounted) {
        setState(() => _reference = result.reference);
      }
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
    final String? reference = _reference;
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactTitle)),
      body: reference != null
          ? ScrollableContent(
              children: <Widget>[
                NoticeBanner(
                  tone: NoticeTone.success,
                  title: l10n.contactSentTitle,
                  message: l10n.contactSentBody(reference),
                ),
              ],
            )
          : Form(
              key: _form,
              child: ScrollableContent(
                children: <Widget>[
                  Text(l10n.contactIntro),
                  const SizedBox(height: Insets.md),
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
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.email],
                    maxLength: ContactInput.contactEmailMaxLength,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.contactEmailLabel,
                      helperText: l10n.contactEmailHelp,
                      helperMaxLines: 2,
                      errorText: _errors['email'],
                    ),
                    validator: (String? v) {
                      final String text = v?.trim() ?? '';
                      if (text.isEmpty) {
                        return l10n.fieldRequired;
                      }
                      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(text)
                          ? null
                          : l10n.contactEmailInvalid;
                    },
                  ),
                  const SizedBox(height: Insets.sm),
                  DropdownButtonFormField<ContactInputKind>(
                    initialValue: _kind,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.helpKindLabel,
                      errorText: _errors['kind'],
                    ),
                    items: <DropdownMenuItem<ContactInputKind>>[
                      for (final ContactInputKind k in contactKinds)
                        DropdownMenuItem<ContactInputKind>(
                          value: k,
                          child: Text(supportKindLabel(l10n, k.json)),
                        ),
                    ],
                    onChanged: (ContactInputKind? k) =>
                        setState(() => _kind = k ?? _kind),
                  ),
                  const SizedBox(height: Insets.md),
                  TextFormField(
                    controller: _subject,
                    maxLength: ContactInput.subjectMaxLength,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.helpSubjectLabel,
                      errorText: _errors['subject'],
                    ),
                    validator: (String? v) => validateSupportText(
                      l10n,
                      v,
                      min: ContactInput.subjectMinLength,
                      max: ContactInput.subjectMaxLength,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  TextFormField(
                    controller: _body,
                    maxLength: ContactInput.bodyMaxLength,
                    minLines: 5,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      labelText: l10n.helpBodyLabel,
                      alignLabelWithHint: true,
                      errorText: _errors['body'],
                      errorMaxLines: 3,
                    ),
                    validator: (String? v) => validateSupportText(
                      l10n,
                      v,
                      min: ContactInput.bodyMinLength,
                      max: ContactInput.bodyMaxLength,
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
