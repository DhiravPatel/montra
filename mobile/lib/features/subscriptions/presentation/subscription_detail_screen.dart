import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/frequency.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/charts.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';
import 'package:montra_mobile/features/recurring/domain/lifecycle.dart';
import 'package:montra_mobile/features/subscriptions/application/subscriptions_providers.dart';
import 'package:montra_mobile/features/subscriptions/data/subscriptions_api.dart';
import 'package:montra_mobile/features/subscriptions/domain/subscription_display.dart';
import 'package:montra_mobile/features/subscriptions/presentation/subscription_payment_sheet.dart';
import 'package:montra_mobile/features/subscriptions/presentation/subscription_widgets.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_display.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_picker.dart';
import 'package:url_launcher/url_launcher.dart';

/// How many history entries are shown before "Show all".
const int _historyPreview = 8;

/// One subscription: price and normalized cost (from the server), possible
/// duplicates, dates, payments, reminders, the cancellation guide and the
/// history. The owner can record payments and move it through its
/// lifecycle; Montra never cancels anything with the provider.
class SubscriptionDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [subscriptionId].
  const SubscriptionDetailScreen({required this.subscriptionId, super.key});

  /// The subscription.
  final String subscriptionId;

  @override
  ConsumerState<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState
    extends ConsumerState<SubscriptionDetailScreen> {
  final IdempotentSubmission _payment = IdempotentSubmission();
  bool _busy = false;
  bool _allHistory = false;

  String get _id => widget.subscriptionId;

  void _reload() => ref.invalidate(subscriptionDetailProvider(_id));

  void _showError(ApiException error) {
    if (error.code == ErrorObjectCode.versionConflict ||
        error.code == ErrorObjectCode.conflict ||
        error.code == ErrorObjectCode.notFound ||
        isStaleStatus(error)) {
      // Something changed elsewhere: show the current state.
      _reload();
    }
    if (!mounted) {
      return;
    }
    showSnack(
      context,
      error.code == ErrorObjectCode.versionConflict
          ? context.l10n.versionConflictReloaded
          : subscriptionErrorText(context.l10n, error),
    );
  }

  Future<void> _act(SubscriptionDetail s, SubscriptionAction action) async {
    if (_busy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    SubscriptionActionInput input = const SubscriptionActionInput();
    if (action == SubscriptionAction.cancelled) {
      // Montra never cancels: the user confirms the provider did, and when.
      final String? cancelledOn = await showDialog<String>(
        context: context,
        builder: (BuildContext context) => _CancelledDialog(subscription: s),
      );
      if (cancelledOn == null || !mounted) {
        return;
      }
      input = SubscriptionActionInput(confirm: true, cancelledOn: cancelledOn);
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(subscriptionsApiProvider)
          .act(s.id, action, input: input, version: s.version);
      finance.bump();
      if (mounted) {
        showSnack(context, subscriptionActionDone(l10n, action));
      }
    } on ApiException catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _recordPayment(SubscriptionDetail s) async {
    if (_busy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final PaymentSheetResult? choice = await showSubscriptionPaymentSheet(
      context,
      subscription: s,
    );
    if (choice == null || !mounted) {
      return;
    }
    final ChargeChoice charge;
    switch (choice) {
      case PickedCharge(charge: final ChargeChoice picked):
        charge = picked;
      case PickOtherCharge():
        final TransactionDto? t = await showTransactionPicker(
          context,
          filter: const TransactionFilter(types: <String>{'expense'}),
          title: l10n.subscriptionPaymentPickerTitle,
        );
        if (t == null || !mounted) {
          return;
        }
        if (t.amount.currency != s.amount.currency) {
          showSnack(
            context,
            l10n.subscriptionPaymentCurrencyMismatch(s.amount.currency),
          );
          return;
        }
        charge = ChargeChoice(
          transactionId: t.id,
          title: transactionTitle(l10n, t),
          date: t.localDate,
          amount: t.amount,
        );
    }
    // A price update only matters when the charge differs from the price.
    final bool differs = charge.amount.amountMinor != s.amount.amountMinor;
    final bool? updatePrice = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => _RecordPaymentDialog(
        subscription: s,
        charge: charge,
        offerPriceUpdate: differs,
      ),
    );
    if (updatePrice == null || !mounted) {
      return;
    }
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final SubscriptionPaymentInput input = SubscriptionPaymentInput(
      transactionId: charge.transactionId,
      updatePrice: differs ? updatePrice : null,
    );
    setState(() => _busy = true);
    try {
      await ref
          .read(subscriptionsApiProvider)
          .recordPayment(
            s.id,
            input,
            key: _payment.keyFor(<String, Object?>{
              'subscription_id': s.id,
              ...input.toJson(),
            }),
          );
      _payment.reset();
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.subscriptionPaymentRecorded);
      }
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _payment.reset();
      }
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _unlink(SubscriptionDetail s, LinkedPayment payment) async {
    final String transactionId = payment.transactionId;
    if (_busy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool ok = await showConfirmDialog(
      context,
      title: l10n.subscriptionUnlinkConfirmTitle,
      body: l10n.subscriptionUnlinkConfirmBody(s.name),
      confirmLabel: l10n.subscriptionUnlinkPayment,
      destructive: true,
    );
    if (!ok || !mounted) {
      return;
    }
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    setState(() => _busy = true);
    try {
      await ref
          .read(subscriptionsApiProvider)
          .unlinkPayment(s.id, transactionId);
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.subscriptionPaymentUnlinked);
      }
    } on ApiException catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setStep(SubscriptionDetail s, int index, bool done) async {
    if (_busy) {
      return;
    }
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    setState(() => _busy = true);
    try {
      // One step changes; the rest of the subscription is left alone.
      await ref
          .read(subscriptionsApiProvider)
          .updateChecklistItem(
            s.id,
            index,
            ChecklistItemPatch(done: done, version: s.version),
          );
      finance.bump();
    } on ApiException catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openPage(String url) async {
    final AppLocalizations l10n = context.l10n;
    final Uri? uri = Uri.tryParse(url);
    bool opened = false;
    if (uri != null && uri.scheme == 'https') {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on PlatformException {
        opened = false;
      }
    }
    if (!opened && mounted) {
      showSnack(context, l10n.subscriptionOpenPageFailed);
    }
  }

  Future<void> _copyPage(String url) async {
    final AppLocalizations l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      showSnack(context, l10n.subscriptionLinkCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<SubscriptionDetail> detail = ref.watch(
      subscriptionDetailProvider(_id),
    );
    final SubscriptionDetail? loaded = detail.value;
    final bool owned = loaded?.owned ?? false;
    final List<SubscriptionAction> actions = loaded == null || !owned
        ? const <SubscriptionAction>[]
        : subscriptionActionsFor(loaded.status.json);
    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.name ?? l10n.subscriptionDetailTitle),
        bottom: _busy || (detail.isLoading && detail.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          if (loaded != null && owned)
            IconButton(
              tooltip: l10n.actionEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy
                  ? null
                  : () => context.push(AppRoutes.editSubscription(loaded.id)),
            ),
          if (loaded != null && actions.isNotEmpty)
            PopupMenuButton<SubscriptionAction>(
              tooltip: l10n.actionMore,
              enabled: !_busy,
              onSelected: (SubscriptionAction a) => _act(loaded, a),
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<SubscriptionAction>>[
                    for (final SubscriptionAction a in actions)
                      PopupMenuItem<SubscriptionAction>(
                        value: a,
                        child: Text(subscriptionActionText(l10n, a)),
                      ),
                  ],
            ),
        ],
      ),
      body: AsyncValueView<SubscriptionDetail>(
        value: detail,
        onRetry: _reload,
        data: (SubscriptionDetail s) => RefreshIndicator(
          onRefresh: () async {
            _reload();
            try {
              await ref.read(subscriptionDetailProvider(_id).future);
            } on Object {
              // Shown by the screen state.
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(Insets.md),
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              _HeaderCard(subscription: s),
              for (final DuplicateWarning w in s.duplicateWarnings)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.md),
                  child: NoticeBanner(
                    tone: NoticeTone.warning,
                    title: l10n.subscriptionDuplicateTitle,
                    message: l10n.subscriptionDuplicateBody(
                      w.name,
                      duplicateWarningReason(l10n, w),
                    ),
                    action: TextButton(
                      onPressed: () => context.push(
                        AppRoutes.subscriptionDetail(w.subscriptionId),
                      ),
                      child: Text(
                        l10n.subscriptionDuplicateOpen,
                        semanticsLabel: l10n.subscriptionDuplicateOpenLabel(
                          w.name,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!s.owned) ...<Widget>[
                const SizedBox(height: Insets.md),
                NoticeBanner(message: l10n.subscriptionSharedNotice),
              ],
              const SizedBox(height: Insets.md),
              _CostCard(subscription: s),
              const SizedBox(height: Insets.md),
              _PaymentsCard(
                subscription: s,
                onRecord:
                    s.owned &&
                        s.status != SubscriptionDetailStatus.cancelled &&
                        !_busy
                    ? () => _recordPayment(s)
                    : null,
                onUnlink: s.owned && !_busy
                    ? (LinkedPayment p) => _unlink(s, p)
                    : null,
              ),
              if (_showCancellation(s)) ...<Widget>[
                const SizedBox(height: Insets.md),
                _CancellationCard(
                  subscription: s,
                  onStep:
                      s.owned &&
                          !_busy &&
                          s.status != SubscriptionDetailStatus.cancelled
                      ? (int i, bool done) => _setStep(s, i, done)
                      : null,
                  onOpenPage: _openPage,
                  onCopyPage: _copyPage,
                ),
              ],
              const SizedBox(height: Insets.md),
              _DatesCard(subscription: s),
              const SizedBox(height: Insets.md),
              _DetailsCard(subscription: s),
              const SizedBox(height: Insets.md),
              _HistoryCard(
                subscription: s,
                showAll: _allHistory,
                onShowAll: () => setState(() => _allHistory = true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _showCancellation(SubscriptionDetail s) =>
      s.status == SubscriptionDetailStatus.cancellationPending ||
      (s.cancellationUrl?.isNotEmpty ?? false) ||
      (s.cancellationInstructions?.isNotEmpty ?? false) ||
      s.cancellationChecklist.isNotEmpty;
}

class _MoneyRow extends ConsumerWidget {
  const _MoneyRow({required this.label, required this.money});

  final String label;
  final Money money;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DetailRow(
    label: label,
    semanticsValue: formatMoney(context, ref, money),
    child: MoneyText(money),
  );
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.subscription});

  final SubscriptionDetail subscription;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final SubscriptionDetail s = subscription;
    final String? plan = s.planName;
    final String? when = subscriptionWhenText(
      l10n,
      status: s.status.json,
      nextRenewalDate: s.nextRenewalDate,
      trialEndsOn: s.trialEndsOn,
      locale: locale,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (plan != null && plan.isNotEmpty)
              Text(plan, style: theme.textTheme.bodyMedium),
            Wrap(
              spacing: Insets.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                MoneyText(
                  s.amount,
                  label: l10n.subscriptionPriceLabel,
                  style: theme.textTheme.headlineMedium,
                ),
                Text(
                  billingCycleText(
                    l10n,
                    s.billingFrequency.json,
                    s.intervalCount,
                    s.intervalUnit?.json,
                  ),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            if (when != null) ...<Widget>[
              const SizedBox(height: Insets.xs),
              Text(when, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                SubscriptionStatusLabel(status: s.status.json),
                if (s.source == SubscriptionDetailSource.detected)
                  StatusLabel(
                    text: l10n.subscriptionSourceDetected,
                    icon: Icons.manage_search,
                  ),
                if (!s.owned)
                  StatusLabel(
                    text: l10n.subscriptionSharedLabel,
                    icon: Icons.group_outlined,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CostCard extends StatelessWidget {
  const _CostCard({required this.subscription});

  final SubscriptionDetail subscription;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SectionCard(
      title: l10n.subscriptionCostTitle,
      children: <Widget>[
        _MoneyRow(
          label: l10n.subscriptionMonthlyCost,
          money: subscription.monthlyCost,
        ),
        _MoneyRow(
          label: l10n.subscriptionAnnualCost,
          money: subscription.annualCost,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.xs,
            Insets.md,
            Insets.sm,
          ),
          child: Text(
            l10n.subscriptionCostNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _PaymentsCard extends ConsumerWidget {
  const _PaymentsCard({
    required this.subscription,
    required this.onRecord,
    required this.onUnlink,
  });

  final SubscriptionDetail subscription;
  final VoidCallback? onRecord;
  final ValueChanged<LinkedPayment>? onUnlink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final SubscriptionPayment? last = subscription.lastPayment;
    final Money? lastAmount = last?.amount;
    final String? transactionId = last?.transactionId;
    final List<LinkedPayment> linked = subscription.payments;
    final ValueChanged<LinkedPayment>? onUnlink = this.onUnlink;
    return SectionCard(
      title: l10n.subscriptionPaymentsTitle,
      children: <Widget>[
        if (last == null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.sm,
            ),
            child: Text(l10n.subscriptionNoPayments),
          )
        else ...<Widget>[
          DetailRow(
            label: l10n.subscriptionLastPayment,
            value: LocalDates.display(last.occurredOn, locale: locale),
          ),
          if (lastAmount != null)
            _MoneyRow(label: l10n.subscriptionPaidAmount, money: lastAmount),
          if (transactionId != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () =>
                    context.push(AppRoutes.transactionDetail(transactionId)),
                child: Text(l10n.subscriptionViewTransaction),
              ),
            ),
        ],
        if (linked.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              0,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.subscriptionLinkedPaymentsTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          for (final LinkedPayment p in linked)
            ListTile(
              title: Text(LocalDates.display(p.localDate, locale: locale)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  MoneyText(p.amount, flow: MoneyFlow.outflow),
                  if ((p.accountName ?? '').trim().isNotEmpty)
                    Text(p.accountName!.trim()),
                ],
              ),
              onTap: () =>
                  context.push(AppRoutes.transactionDetail(p.transactionId)),
              trailing: onUnlink == null
                  ? null
                  : IconButton(
                      tooltip: l10n.subscriptionUnlinkPaymentLabel(
                        LocalDates.display(p.localDate, locale: locale),
                      ),
                      icon: const Icon(Icons.link_off),
                      onPressed: () => onUnlink(p),
                    ),
            ),
        ],
        if (onRecord != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.xs,
              Insets.md,
              Insets.sm,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: onRecord,
                icon: const Icon(Icons.link),
                label: Text(l10n.subscriptionRecordPayment),
              ),
            ),
          ),
      ],
    );
  }
}

class _CancellationCard extends StatelessWidget {
  const _CancellationCard({
    required this.subscription,
    required this.onStep,
    required this.onOpenPage,
    required this.onCopyPage,
  });

  final SubscriptionDetail subscription;
  final void Function(int index, bool done)? onStep;
  final ValueChanged<String> onOpenPage;
  final ValueChanged<String> onCopyPage;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final SubscriptionDetail s = subscription;
    final String? url = s.cancellationUrl;
    final String? how = s.cancellationInstructions;
    final List<CancellationChecklistItem> steps = s.cancellationChecklist;
    final void Function(int index, bool done)? onStep = this.onStep;
    return SectionCard(
      title: l10n.subscriptionCancellationSection,
      children: <Widget>[
        if (s.status == SubscriptionDetailStatus.cancellationPending)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.xs,
            ),
            child: NoticeBanner(message: l10n.subscriptionCancellingNotice),
          ),
        if (how != null && how.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.xs,
            ),
            child: Text(how),
          ),
        if (url != null && url.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SelectableText(url, style: text.bodySmall),
                Wrap(
                  spacing: Insets.sm,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: () => onOpenPage(url),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.subscriptionOpenPage),
                    ),
                    TextButton.icon(
                      onPressed: () => onCopyPage(url),
                      icon: const Icon(Icons.copy),
                      label: Text(l10n.subscriptionCopyLink),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (steps.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              0,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.subscriptionChecklistTitle,
                style: text.titleSmall,
              ),
            ),
          ),
          for (int i = 0; i < steps.length; i++)
            CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              value: steps[i].done,
              onChanged: onStep == null
                  ? null
                  : (bool? v) => onStep(i, v ?? false),
              title: Text(steps[i].item),
            ),
        ] else if (s.status == SubscriptionDetailStatus.cancellationPending)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.sm,
            ),
            child: Text(l10n.subscriptionChecklistEmpty, style: text.bodySmall),
          ),
      ],
    );
  }
}

class _DatesCard extends StatelessWidget {
  const _DatesCard({required this.subscription});

  final SubscriptionDetail subscription;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final SubscriptionDetail s = subscription;
    final List<int> reminders = s.reminderDaysBefore;
    return SectionCard(
      title: l10n.subscriptionDatesSection,
      children: <Widget>[
        DetailRow(
          label: l10n.subscriptionStartLabel,
          value: LocalDates.display(s.startDate, locale: locale),
        ),
        if (s.nextRenewalDate case final String next)
          DetailRow(
            label: l10n.subscriptionNextRenewalLabel,
            value: LocalDates.display(next, locale: locale),
          ),
        if (s.trialEndsOn case final String trial)
          DetailRow(
            label: l10n.subscriptionTrialLabel,
            value: LocalDates.display(trial, locale: locale),
          ),
        if (s.cancelledOn case final String on)
          DetailRow(
            label: l10n.subscriptionCancelledOn,
            value: LocalDates.display(on, locale: locale),
          ),
        DetailRow(
          label: l10n.subscriptionLastChecked,
          value: switch (s.lastVerifiedAt) {
            final DateTime at => formatDateTime(at, locale: locale),
            null => l10n.subscriptionNeverChecked,
          },
        ),
        DetailRow(
          label: l10n.subscriptionRemindersLabel,
          value: reminders.isEmpty
              ? l10n.reminderNone
              : <String>[
                  for (final int d in reminders) reminderOffsetLabel(l10n, d),
                ].join(', '),
        ),
      ],
    );
  }
}

class _DetailsCard extends ConsumerWidget {
  const _DetailsCard({required this.subscription});

  final SubscriptionDetail subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final SubscriptionDetail s = subscription;
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final Map<String, GroupDto> groups = ref.watch(groupIndexProvider);
    return SectionCard(
      title: l10n.subscriptionDetailsSection,
      children: <Widget>[
        if (s.merchant case final MerchantRef m)
          DetailRow(label: l10n.merchantFieldLabel, value: m.name),
        if (s.categoryId case final String id)
          DetailRow(
            label: l10n.categoryFieldLabel,
            value: switch (categories[id]) {
              final CategoryDto c => categoryName(l10n, c),
              null => l10n.subscriptionCategoryUnavailable,
            },
          ),
        if (s.paymentAccountId case final String id)
          DetailRow(
            label: l10n.subscriptionPaymentAccountLabel,
            value: accounts[id]?.name ?? l10n.paymentAccountUnknown,
          ),
        if (s.groupId case final String id)
          DetailRow(
            label: l10n.subscriptionGroupLabel,
            value: groups[id]?.name ?? l10n.subscriptionGroupUnavailable,
          ),
        DetailRow(
          label: l10n.subscriptionSourceLabel,
          value: s.source == SubscriptionDetailSource.detected
              ? l10n.subscriptionSourceDetected
              : l10n.subscriptionSourceManual,
        ),
        if (s.notes case final String notes when notes.isNotEmpty)
          DetailRow(label: l10n.notesLabel, value: notes),
      ],
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({
    required this.subscription,
    required this.showAll,
    required this.onShowAll,
  });

  final SubscriptionDetail subscription;
  final bool showAll;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    // Newest first, as the server sends them.
    final List<SubscriptionEvent> events = subscription.events;
    final List<SubscriptionEvent> shown = showAll
        ? events
        : events.take(_historyPreview).toList();
    // Prices over time, oldest first: the starting price and every change.
    final List<SubscriptionEvent> prices = <SubscriptionEvent>[
      for (final SubscriptionEvent e in events.reversed)
        if ((e.kind == SubscriptionEventKind.created ||
                e.kind == SubscriptionEventKind.priceChanged) &&
            e.newAmount != null)
          e,
    ];
    return SectionCard(
      title: l10n.subscriptionHistoryTitle,
      children: <Widget>[
        if (prices.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: AccessibleChart(
              summary: l10n.subscriptionPriceHistorySummary(
                formatMoney(context, ref, prices.first.newAmount!),
                LocalDates.display(prices.first.occurredOn, locale: locale),
                formatMoney(context, ref, prices.last.newAmount!),
                LocalDates.display(prices.last.occurredOn, locale: locale),
              ),
              chart: Sparkline(
                values: <int>[
                  for (final SubscriptionEvent e in prices)
                    e.newAmount!.amountMinor,
                ],
              ),
              table: Column(
                children: <Widget>[
                  for (final SubscriptionEvent e in prices.reversed)
                    _MoneyRow(
                      label: LocalDates.display(e.occurredOn, locale: locale),
                      money: e.newAmount!,
                    ),
                ],
              ),
            ),
          ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Text(l10n.subscriptionHistoryEmpty),
          ),
        for (final SubscriptionEvent e in shown) _EventRow(event: e),
        if (!showAll && events.length > shown.length)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              child: TextButton(
                onPressed: onShowAll,
                child: Text(l10n.subscriptionHistoryShowAll(events.length)),
              ),
            ),
          ),
      ],
    );
  }
}

class _EventRow extends ConsumerWidget {
  const _EventRow({required this.event});

  final SubscriptionEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final SubscriptionEvent e = event;
    final Money? oldAmount = e.oldAmount;
    final Money? newAmount = e.newAmount;
    final String? note = subscriptionEventNote(l10n, e);
    final String? transactionId = e.transactionId;
    final String? amountText = switch ((oldAmount, newAmount)) {
      (final Money from, final Money to) => l10n.subscriptionPriceChange(
        formatMoney(context, ref, from),
        formatMoney(context, ref, to),
      ),
      (null, final Money to) => formatMoney(context, ref, to),
      _ => null,
    };
    return ListTile(
      title: Text(subscriptionEventText(l10n, e.kind)),
      subtitle: Text(
        <String>[
          LocalDates.display(e.occurredOn, locale: locale),
          ?amountText,
          if (note != null && note.isNotEmpty) note,
        ].join(' · '),
      ),
      trailing: transactionId == null
          ? null
          : const ExcludeSemantics(child: Icon(Icons.chevron_right)),
      onTap: transactionId == null
          ? null
          : () => context.push(AppRoutes.transactionDetail(transactionId)),
    );
  }
}

/// Confirms linking [charge] as a payment; returns whether the price should
/// follow the charge (always false when [offerPriceUpdate] is false), or
/// null when cancelled.
class _RecordPaymentDialog extends ConsumerStatefulWidget {
  const _RecordPaymentDialog({
    required this.subscription,
    required this.charge,
    required this.offerPriceUpdate,
  });

  final SubscriptionDetail subscription;
  final ChargeChoice charge;
  final bool offerPriceUpdate;

  @override
  ConsumerState<_RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  bool _updatePrice = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final ChargeChoice c = widget.charge;
    final String charged = formatMoney(context, ref, c.amount);
    return AlertDialog(
      title: Text(l10n.subscriptionRecordPaymentTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.subscriptionRecordPaymentBody(
                c.title,
                LocalDates.display(c.date, locale: locale),
                charged,
              ),
            ),
            if (widget.offerPriceUpdate) ...<Widget>[
              const SizedBox(height: Insets.md),
              Text(
                l10n.subscriptionPriceDiffers(
                  formatMoney(context, ref, widget.subscription.amount),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _updatePrice,
                onChanged: (bool v) => setState(() => _updatePrice = v),
                title: Text(l10n.subscriptionUpdatePrice(charged)),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_updatePrice),
          child: Text(l10n.subscriptionRecordPaymentConfirm),
        ),
      ],
    );
  }
}

/// Asks the user to confirm the provider cancelled [subscription] and when
/// (`cancelled_on`, today by default). Returns the date, or null when the
/// user backs out.
class _CancelledDialog extends StatefulWidget {
  const _CancelledDialog({required this.subscription});

  final SubscriptionDetail subscription;

  @override
  State<_CancelledDialog> createState() => _CancelledDialogState();
}

class _CancelledDialogState extends State<_CancelledDialog> {
  String _date = LocalDates.format(LocalDates.today());

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.subscriptionCancelledConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.subscriptionCancelledConfirmBody(widget.subscription.name),
            ),
            const SizedBox(height: Insets.md),
            DateSelectorField(
              label: l10n.subscriptionCancelledOn,
              value: _date,
              helperText: l10n.subscriptionCancelledOnPickHelp,
              lastDate: LocalDates.today(),
              onChanged: (String? d) {
                if (d != null) {
                  setState(() => _date = d);
                }
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(_date),
          child: Text(l10n.subscriptionCancelledConfirm),
        ),
      ],
    );
  }
}
