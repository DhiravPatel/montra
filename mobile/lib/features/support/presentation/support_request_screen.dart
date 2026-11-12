import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/support/application/support_providers.dart';
import 'package:montra_mobile/features/support/data/support_api.dart';
import 'package:montra_mobile/features/support/domain/support_display.dart';
import 'package:montra_mobile/features/support/presentation/support_form_screen.dart';

/// One support request: what was asked, its status and the conversation
/// with Montra support (`GET/POST /support/requests/{id}/messages`).
/// Replies are plain text; a closed request takes no more replies.
class SupportRequestScreen extends ConsumerWidget {
  /// Creates the screen.
  const SupportRequestScreen({required this.requestId, super.key});

  /// The request.
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<RequestDto> request = ref.watch(
      supportRequestProvider(requestId),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpRequestTitle)),
      body: AsyncValueView<RequestDto>(
        value: request,
        onRetry: () => ref.invalidate(supportRequestProvider(requestId)),
        data: (RequestDto r) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(supportMessagesProvider(requestId));
            final RequestDto _ = await ref.refresh(
              supportRequestProvider(requestId).future,
            );
          },
          child: _RequestBody(request: r),
        ),
      ),
    );
  }
}

class _RequestBody extends ConsumerWidget {
  const _RequestBody({required this.request});

  final RequestDto request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final (String status, StatusTone tone) = supportStatus(
      l10n,
      request.status,
    );
    final AsyncValue<List<MessageDto>> messages = ref.watch(
      supportMessagesProvider(request.id),
    );
    final List<MessageDto>? thread = messages.value;
    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      children: <Widget>[
        ContentFrame(
          child: SectionCard(
            title: request.subject,
            children: <Widget>[
              DetailRow(
                label: l10n.helpReferenceLabel,
                value: request.reference,
              ),
              DetailRow(
                label: l10n.helpKindLabel,
                value: supportKindLabel(l10n, request.kind.json),
              ),
              DetailRow(
                label: l10n.statusLabel,
                semanticsValue: status,
                child: StatusLabel(text: status, tone: tone),
              ),
              DetailRow(
                label: l10n.helpSentOn,
                value: formatDateTime(request.createdAt, locale: locale),
              ),
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Text(request.body),
              ),
            ],
          ),
        ),
        ContentFrame(
          child: SectionCard(
            title: l10n.helpConversation,
            children: <Widget>[
              if (thread == null && messages.hasError && !messages.isLoading)
                SizedBox(
                  height: 320,
                  child: ErrorStateView(
                    error: messages.error!,
                    onRetry: () =>
                        ref.invalidate(supportMessagesProvider(request.id)),
                  ),
                )
              else if (thread == null)
                const Padding(
                  padding: EdgeInsets.all(Insets.lg),
                  child: LoadingStateView(),
                )
              else if (thread.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Text(l10n.helpNoMessages),
                )
              else
                for (final MessageDto m in thread) _MessageTile(m),
            ],
          ),
        ),
        ContentFrame(
          child: acceptsReplies(request)
              ? _ReplyBox(requestId: request.id)
              : NoticeBanner(message: l10n.helpRequestClosedNote),
        ),
      ],
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile(this.message);

  final MessageDto message;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final bool staff = message.authorRole == MessageDtoAuthorRole.staff;
    final String who = staff
        ? l10n.helpFromSupport
        : (message.mine ? l10n.helpFromYou : l10n.helpFromRequester);
    return Semantics(
      container: true,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.xs,
        ),
        padding: const EdgeInsets.all(Insets.sm + Insets.xs),
        decoration: BoxDecoration(
          color: staff
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(
                    staff ? Icons.support_agent : Icons.person_outline,
                    size: 18,
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: Text(
                    '$who · ${formatDateTime(message.createdAt, locale: locale)}',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(message.body),
          ],
        ),
      ),
    );
  }
}

class _ReplyBox extends ConsumerStatefulWidget {
  const _ReplyBox({required this.requestId});

  final String requestId;

  @override
  ConsumerState<_ReplyBox> createState() => _ReplyBoxState();
}

class _ReplyBoxState extends ConsumerState<_ReplyBox> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _body = TextEditingController();
  ServerFormErrors _errors = ServerFormErrors.none;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    try {
      await ref
          .read(supportApiProvider)
          .reply(widget.requestId, _body.text.trim());
      _body.clear();
      ref
        ..invalidate(supportMessagesProvider(widget.requestId))
        ..invalidate(supportRequestProvider(widget.requestId))
        ..invalidate(supportRequestsProvider);
      if (mounted) {
        showSnack(context, l10n.helpReplySent);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(
            l10n,
            error,
            fieldMap: const <String, String>{'body': 'body'},
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? general = _errors.general;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (general != null) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.error,
              message: general,
              requestId: _errors.requestId,
            ),
            const SizedBox(height: Insets.sm),
          ],
          TextFormField(
            controller: _body,
            maxLength: MessageInput.bodyMaxLength,
            minLines: 3,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: l10n.helpReplyLabel,
              helperText: l10n.helpNoSecretsShort,
              helperMaxLines: 3,
              alignLabelWithHint: true,
              errorText: _errors['body'],
              errorMaxLines: 3,
            ),
            validator: (String? v) => validateSupportText(
              l10n,
              v,
              min: MessageInput.bodyMinLength,
              max: MessageInput.bodyMaxLength,
            ),
          ),
          const SizedBox(height: Insets.sm),
          SubmitButton(
            icon: Icons.send_outlined,
            label: l10n.helpSendReply,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
