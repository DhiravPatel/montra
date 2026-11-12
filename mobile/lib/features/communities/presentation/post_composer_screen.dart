import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/communities/application/communities_providers.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/communities/domain/community_display.dart';
import 'package:montra_mobile/features/communities/presentation/community_form_errors.dart';

/// Most options a poll offers in this app.
const int maxPollOptions = 10;

/// Writes a post in a community (discussion, question, resource link or
/// poll), or edits the user's own post. Text is plain; resource links must
/// be `https`. Daily caps and field problems come back from the server and
/// are explained in the user's language.
class PostComposerScreen extends ConsumerWidget {
  /// A new post in community [communityRef], or an edit of [postId].
  const PostComposerScreen({this.communityRef, this.postId, super.key})
    : assert(communityRef != null || postId != null, 'community or post');

  /// Community to post in (new posts).
  final String? communityRef;

  /// Post to edit.
  final String? postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String title = postId == null ? l10n.postNew : l10n.postEditTitle;
    final String? editing = postId;
    if (editing != null) {
      final AsyncValue<CommunityPostDetail> post = ref.watch(
        postDetailProvider(editing),
      );
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: AsyncValueView<CommunityPostDetail>(
          value: post,
          onRetry: () => ref.invalidate(postDetailProvider(editing)),
          data: (CommunityPostDetail p) => _ComposerForm(
            communityId: p.communityId,
            moderator:
                ref
                    .watch(communityProvider(p.communityId))
                    .value
                    ?.canModerate ??
                false,
            original: p,
          ),
        ),
      );
    }
    final AsyncValue<CommunityDto> community = ref.watch(
      communityProvider(communityRef!),
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AsyncValueView<CommunityDto>(
        value: community,
        onRetry: () => ref.invalidate(communityProvider(communityRef!)),
        data: (CommunityDto c) =>
            _ComposerForm(communityId: c.id, moderator: c.canModerate),
      ),
    );
  }
}

class _ComposerForm extends ConsumerStatefulWidget {
  const _ComposerForm({
    required this.communityId,
    required this.moderator,
    this.original,
  });

  final String communityId;
  final bool moderator;
  final CommunityPostDetail? original;

  @override
  ConsumerState<_ComposerForm> createState() => _ComposerFormState();
}

class _ComposerFormState extends ConsumerState<_ComposerForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.original?.title ?? '',
  );
  late final TextEditingController _body = TextEditingController(
    text: widget.original?.body ?? '',
  );
  late final TextEditingController _link = TextEditingController(
    text: widget.original?.linkUrl ?? '',
  );
  final TextEditingController _question = TextEditingController();
  final List<TextEditingController> _options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  late String _kind = widget.original?.kind.json ?? 'discussion';
  late String _label = widget.original?.label.json ?? 'personal_experience';
  bool _multiple = false;
  String? _closesOn;
  ServerFormErrors _errors = ServerFormErrors.none;

  bool get _editing => widget.original != null;

  static const Map<String, String> _fields = <String, String>{
    'title': 'title',
    'body': 'body',
    'link_url': 'link',
    'poll': 'poll',
    'label': 'label',
    'kind': 'kind',
  };

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    _question.dispose();
    for (final TextEditingController c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  CommunityPostInput _input() {
    final bool poll = _kind == 'poll';
    final bool resource = _kind == 'resource';
    final String? closes = _closesOn;
    return CommunityPostInput(
      title: _title.text.trim(),
      body: _editing ? _body.text.trim() : _text(_body),
      kind: CommunityPostInputKind.fromJson(_kind),
      label: CommunityPostInputLabel.fromJson(_label),
      linkUrl: resource ? _text(_link) : null,
      poll: poll && !_editing
          ? CommunityPollInput(
              question: _question.text.trim(),
              options: <String>[
                for (final TextEditingController c in _options)
                  if (c.text.trim().isNotEmpty) c.text.trim(),
              ],
              allowMultiple: _multiple ? true : null,
              closesAt: closes == null ? null : _endOfDay(closes),
            )
          : null,
    );
  }

  /// The end of the chosen calendar day on this device, as an instant.
  static DateTime? _endOfDay(String day) {
    final DateTime? d = LocalDates.parse(day);
    return d == null ? null : DateTime(d.year, d.month, d.day, 23, 59).toUtc();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final CommunitiesApi api = ref.read(communitiesApiProvider);
    try {
      final CommunityPostInput input = _input();
      if (_editing) {
        await api.updatePost(widget.original!.id, input);
        ref.read(communityRevisionProvider.notifier).bump();
        if (mounted) {
          showSnack(context, l10n.postSaved);
          router.pop();
        }
        return;
      }
      final CommunityPostDto created = await api.createPost(
        widget.communityId,
        input,
      );
      ref.read(communityRevisionProvider.notifier).bump();
      if (mounted) {
        showSnack(context, l10n.postPublished);
        unawaited(router.pushReplacement(AppRoutes.postDetail(created.id)));
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errors = formErrorsOf(l10n, error, _fields));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? general = _errors.general;
    final List<String> labels = postLabelsFor(moderator: widget.moderator);
    if (!labels.contains(_label)) {
      labels.add(_label);
    }
    return Form(
      key: _form,
      child: ScrollableContent(
        children: <Widget>[
          Text(l10n.postComposerIntro),
          const SizedBox(height: Insets.md),
          if (general != null) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.error,
              message: general,
              requestId: _errors.requestId,
            ),
            const SizedBox(height: Insets.md),
          ],
          SectionHeading(l10n.postKindHeading),
          const SizedBox(height: Insets.xs),
          if (_editing)
            Text(postKindLabel(l10n, _kind))
          else
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final String k in postKinds)
                  ChoiceChip(
                    label: Text(postKindLabel(l10n, k)),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
          const SizedBox(height: Insets.md),
          SectionHeading(l10n.postLabelHeading),
          const SizedBox(height: Insets.xs),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              for (final String l in labels)
                ChoiceChip(
                  label: Text(postLabelText(l10n, l)),
                  selected: _label == l,
                  onSelected: (_) => setState(() => _label = l),
                ),
            ],
          ),
          if (_errors['label'] case final String e)
            Text(
              e,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _title,
            maxLength: CommunityPostInput.titleMaxLength,
            decoration: InputDecoration(
              labelText: l10n.postTitleLabel,
              errorText: _errors['title'],
            ),
            validator: (String? v) =>
                (v ?? '').trim().length < CommunityPostInput.titleMinLength
                ? l10n.fieldTooShort('${CommunityPostInput.titleMinLength}')
                : null,
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _body,
            maxLength: CommunityPostInput.bodyMaxLength,
            minLines: 4,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: l10n.postBodyLabel,
              helperText: l10n.postBodyHelp,
              helperMaxLines: 3,
              alignLabelWithHint: true,
              errorText: _errors['body'],
            ),
          ),
          if (_kind == 'resource') ...<Widget>[
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _link,
              maxLength: CommunityPostInput.linkUrlMaxLength,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.postLinkLabel,
                helperText: l10n.postLinkHelp,
                errorText: _errors['link'],
              ),
              validator: (String? v) {
                final String text = (v ?? '').trim();
                if (text.isEmpty) {
                  return l10n.fieldLinkRequired;
                }
                final Uri? uri = safeLink(text);
                return uri == null || uri.scheme != 'https'
                    ? l10n.fieldInsecureLink
                    : null;
              },
            ),
          ],
          if (_kind == 'poll' && !_editing) ..._pollFields(context),
          if (_kind == 'poll' && _editing) ...<Widget>[
            const SizedBox(height: Insets.sm),
            NoticeBanner(message: l10n.postPollFixed),
          ],
          const SizedBox(height: Insets.lg),
          SubmitButton(
            label: _editing ? l10n.actionSave : l10n.postPublish,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  List<Widget> _pollFields(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final DateTime tomorrow = LocalDates.today().add(const Duration(days: 1));
    return <Widget>[
      const SizedBox(height: Insets.md),
      SectionHeading(l10n.postPollTitle),
      const SizedBox(height: Insets.sm),
      TextFormField(
        controller: _question,
        maxLength: CommunityPollInput.questionMaxLength,
        decoration: InputDecoration(labelText: l10n.postPollQuestionLabel),
        validator: (String? v) =>
            (v ?? '').trim().length < CommunityPollInput.questionMinLength
            ? l10n.fieldTooShort('${CommunityPollInput.questionMinLength}')
            : null,
      ),
      for (int i = 0; i < _options.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: Insets.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: _options[i],
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: l10n.postPollOptionLabel(i + 1),
                  ),
                  validator: (String? v) {
                    final String text = (v ?? '').trim();
                    if (text.isEmpty) {
                      return i < 2 ? l10n.fieldRequired : null;
                    }
                    final int same = _options
                        .where(
                          (TextEditingController c) =>
                              c.text.trim().toLowerCase() == text.toLowerCase(),
                        )
                        .length;
                    return same > 1 ? l10n.fieldDuplicateOption : null;
                  },
                ),
              ),
              if (_options.length > 2)
                IconButton(
                  tooltip: l10n.postPollRemoveOption(i + 1),
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () =>
                      setState(() => _options.removeAt(i).dispose()),
                ),
            ],
          ),
        ),
      if (_options.length < maxPollOptions)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _options.add(TextEditingController())),
            icon: const Icon(Icons.add),
            label: Text(l10n.postPollAddOption),
          ),
        ),
      if (_errors['poll'] case final String e)
        Text(
          e,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _multiple,
        onChanged: (bool v) => setState(() => _multiple = v),
        title: Text(l10n.postPollAllowMultiple),
      ),
      DateSelectorField(
        label: l10n.postPollClosesLabel,
        value: _closesOn,
        emptyLabel: l10n.postPollNoEnd,
        clearable: true,
        firstDate: tomorrow,
        lastDate: DateTime(tomorrow.year + 1, tomorrow.month, tomorrow.day),
        onChanged: (String? v) => setState(() => _closesOn = v),
      ),
    ];
  }
}
