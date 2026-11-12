import 'dart:async';

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
import 'package:montra_mobile/features/communities/application/communities_providers.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/communities/domain/community_display.dart';
import 'package:montra_mobile/features/communities/presentation/community_form_errors.dart';

/// Starts a community: name, URL name, description, rules, topics and who
/// can join. The creator becomes its owner.
class CommunityFormScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const CommunityFormScreen({super.key});

  @override
  ConsumerState<CommunityFormScreen> createState() =>
      _CommunityFormScreenState();
}

class _CommunityFormScreenState extends ConsumerState<CommunityFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _slug = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _rules = TextEditingController();
  final TextEditingController _topics = TextEditingController();
  String _visibility = 'public';
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'slug': 'slug',
    'description': 'description',
    'rules': 'rules',
    'topics': 'topics',
    'visibility': 'visibility',
  };

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    _rules.dispose();
    _topics.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final List<String> topics = parseTopics(_topics.text);
    try {
      final CommunityDto created = await ref
          .read(communitiesApiProvider)
          .create(
            CommunityInput(
              name: _name.text.trim(),
              slug: text(_slug)?.toLowerCase(),
              description: text(_description),
              rules: text(_rules),
              topics: topics.isEmpty ? null : topics,
              visibility: CommunityInputVisibility.fromJson(_visibility),
            ),
          );
      ref.read(communityRevisionProvider.notifier).bump();
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.communityCreated);
      unawaited(router.pushReplacement(AppRoutes.communityPage(created.id)));
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errors = formErrorsOf(l10n, error, _fields));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityCreateTitle)),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            Text(l10n.communityCreateIntro),
            const SizedBox(height: Insets.md),
            if (general != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: general,
                requestId: _errors.requestId,
              ),
              const SizedBox(height: Insets.md),
            ],
            TextFormField(
              controller: _name,
              maxLength: CommunityInput.nameMaxLength,
              decoration: InputDecoration(
                labelText: l10n.communityNameLabel,
                errorText: _errors['name'],
              ),
              validator: (String? v) =>
                  (v ?? '').trim().length < CommunityInput.nameMinLength
                  ? l10n.fieldTooShort('${CommunityInput.nameMinLength}')
                  : null,
            ),
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _slug,
              maxLength: 60,
              autocorrect: false,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.communitySlugLabel,
                helperText: l10n.communitySlugHelp,
                helperMaxLines: 3,
                errorText: _errors['slug'],
              ),
              validator: (String? v) {
                final String slug = (v ?? '').trim().toLowerCase();
                return slug.isEmpty || communitySlugPattern.hasMatch(slug)
                    ? null
                    : l10n.communitySlugInvalid;
              },
            ),
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _description,
              maxLength: CommunityInput.descriptionMaxLength,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.communityDescriptionLabel,
                errorText: _errors['description'],
              ),
            ),
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _rules,
              maxLength: CommunityInput.rulesMaxLength,
              minLines: 2,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: l10n.communityRulesLabel,
                helperText: l10n.communityRulesHelp,
                helperMaxLines: 3,
                errorText: _errors['rules'],
              ),
            ),
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _topics,
              decoration: InputDecoration(
                labelText: l10n.communityTopicsLabel,
                helperText: l10n.communityTopicsHelp,
                helperMaxLines: 2,
                errorText: _errors['topics'],
              ),
            ),
            const SizedBox(height: Insets.md),
            VisibilityChooser(
              value: _visibility,
              errorText: _errors['visibility'],
              onChanged: (String v) => setState(() => _visibility = v),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(label: l10n.communityCreate, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

/// Radio choices for who can join, each with its meaning.
class VisibilityChooser extends StatelessWidget {
  /// Creates the chooser.
  const VisibilityChooser({
    required this.value,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  /// The chosen wire value.
  final String value;

  /// Called with the new wire value.
  final ValueChanged<String> onChanged;

  /// Server error for the field.
  final String? errorText;

  /// Whether the choice can change (only the owner may change it).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeading(l10n.communityVisibilityLabel),
        RadioGroup<String>(
          groupValue: value,
          onChanged: (String? v) {
            if (v != null && enabled) {
              onChanged(v);
            }
          },
          child: Column(
            children: <Widget>[
              for (final String v in communityVisibilities)
                RadioListTile<String>(
                  value: v,
                  enabled: enabled,
                  contentPadding: EdgeInsets.zero,
                  title: Text(communityVisibilityLabel(l10n, v)),
                  subtitle: Text(communityVisibilityHelp(l10n, v)),
                ),
            ],
          ),
        ),
        if (errorText != null)
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}
