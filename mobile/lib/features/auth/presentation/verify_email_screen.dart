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
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/core/widgets/text_fields.dart';
import 'package:montra_mobile/features/auth/domain/auth_link.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/link_input_field.dart';
import 'package:montra_mobile/features/auth/presentation/widgets/resend_verification_button.dart';

enum _Phase { needLink, verifying, verified, expired, failed }

/// Confirms an email address from `/verify-email#token=...` (deep link) or a
/// pasted link. Verification starts automatically when a token is present.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [initialToken] comes from the deep link.
  const VerifyEmailScreen({this.initialToken, super.key});

  /// Token from the opened link, if any.
  final String? initialToken;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final GlobalKey<FormState> _linkForm = GlobalKey<FormState>();
  final GlobalKey<FormState> _resendForm = GlobalKey<FormState>();
  final TextEditingController _link = TextEditingController();
  final TextEditingController _email = TextEditingController();

  _Phase _phase = _Phase.needLink;
  String? _token;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    final String? token = widget.initialToken;
    if (token != null && AuthLinks.isPlausibleToken(token)) {
      _token = token;
      _phase = _Phase.verifying;
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify(token));
    }
  }

  @override
  void dispose() {
    _link.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _verify(String token) async {
    setState(() {
      _token = token;
      _phase = _Phase.verifying;
      _failure = null;
    });
    try {
      await ref.read(authApiProvider).verifyEmail(token);
      if (!mounted) {
        return;
      }
      setState(() => _phase = _Phase.verified);
      if (ref.read(authControllerProvider) is SignedIn) {
        // Best effort: refresh `email_verified` on the profile.
        try {
          await ref.read(authControllerProvider.notifier).refreshAccount();
        } on ApiException {
          // The verification itself succeeded.
        }
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final bool invalidLink =
          error.code == ErrorObjectCode.gone ||
          (error.code == ErrorObjectCode.validationError &&
              error.bodyFieldErrors.containsKey('token'));
      setState(() {
        _phase = invalidLink ? _Phase.expired : _Phase.failed;
        _failure = error;
      });
    }
  }

  Future<void> _submitLink() async {
    if (!(_linkForm.currentState?.validate() ?? false)) {
      return;
    }
    final AuthLink? link = AuthLinks.parse(_link.text);
    if (link != null) {
      await _verify(link.token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool signedIn = ref.watch(authControllerProvider) is SignedIn;
    final List<Widget> children = switch (_phase) {
      _Phase.verifying => <Widget>[
        LoadingStateView(label: l10n.verifyingEmail),
      ],
      _Phase.verified => <Widget>[
        NoticeBanner(
          tone: NoticeTone.success,
          title: l10n.verifyEmailSuccessTitle,
          message: signedIn
              ? l10n.verifyEmailSuccessSignedInBody
              : l10n.verifyEmailSuccessBody,
        ),
        const SizedBox(height: Insets.lg),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () =>
              context.go(signedIn ? AppRoutes.signedInHome : AppRoutes.signIn),
          child: Text(signedIn ? l10n.actionContinue : l10n.signInButton),
        ),
      ],
      _Phase.failed => <Widget>[
        NoticeBanner(
          tone: NoticeTone.error,
          title: l10n.errorGenericTitle,
          message: describeError(l10n, _failure ?? Object()),
          requestId: _failure == null ? null : requestIdOf(_failure!),
        ),
        const SizedBox(height: Insets.lg),
        SubmitButton(
          label: l10n.actionRetry,
          icon: Icons.refresh,
          onPressed: _token == null ? null : () => _verify(_token!),
        ),
      ],
      _Phase.expired => <Widget>[
        NoticeBanner(
          tone: NoticeTone.warning,
          message: l10n.verifyEmailExpired,
        ),
        const SizedBox(height: Insets.lg),
        ..._resendSection(l10n),
        const SizedBox(height: Insets.lg),
        ..._linkSection(l10n),
      ],
      _Phase.needLink => <Widget>[
        Text(
          l10n.verifyEmailPasteBody,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: Insets.md),
        ..._linkSection(l10n),
        const SizedBox(height: Insets.xl),
        ..._resendSection(l10n),
      ],
    };
    return AuthScaffold(title: l10n.verifyEmailTitle, children: children);
  }

  List<Widget> _linkSection(AppLocalizations l10n) => <Widget>[
    Form(
      key: _linkForm,
      child: LinkInputField(
        controller: _link,
        expected: AuthLinkKind.verifyEmail,
        onSubmitted: (_) => _submitLink(),
      ),
    ),
    const SizedBox(height: Insets.md),
    SubmitButton(label: l10n.verifyEmailButton, onPressed: _submitLink),
  ];

  List<Widget> _resendSection(AppLocalizations l10n) => <Widget>[
    Semantics(
      header: true,
      child: Text(
        l10n.resendSectionTitle,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
    const SizedBox(height: Insets.xs),
    Text(l10n.resendSectionBody),
    const SizedBox(height: Insets.md),
    Form(
      key: _resendForm,
      child: EmailField(
        controller: _email,
        maxLength: EmailBody.emailMaxLength,
        textInputAction: TextInputAction.done,
      ),
    ),
    const SizedBox(height: Insets.md),
    ResendVerificationButton(
      email: () => (_resendForm.currentState?.validate() ?? false)
          ? _email.text.trim()
          : null,
    ),
  ];
}
