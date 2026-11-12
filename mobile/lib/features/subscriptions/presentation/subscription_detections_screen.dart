import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/frequency.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/presentation/label_pickers.dart';
import 'package:montra_mobile/features/subscriptions/application/subscriptions_providers.dart';
import 'package:montra_mobile/features/subscriptions/data/subscriptions_api.dart';
import 'package:montra_mobile/features/subscriptions/domain/subscription_display.dart';
import 'package:montra_mobile/features/subscriptions/presentation/subscription_widgets.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

/// Possible subscriptions found in the user's transactions: charges that
/// repeat at a regular interval with a similar amount. Each shows its
/// evidence in plain words; nothing is added until the user confirms.
class SubscriptionDetectionsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SubscriptionDetectionsScreen({super.key});

  @override
  ConsumerState<SubscriptionDetectionsScreen> createState() =>
      _SubscriptionDetectionsScreenState();
}

class _SubscriptionDetectionsScreenState
    extends ConsumerState<SubscriptionDetectionsScreen> {
  String? _busyId;
  bool _refreshing = false;

  Future<void> _lookAgain() async {
    if (_refreshing) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    setState(() => _refreshing = true);
    try {
      await ref.read(subscriptionsApiProvider).refreshDetections();
      ref.invalidate(pendingDetectionsProvider);
      if (mounted) {
        showSnack(context, l10n.detectionsRefreshStarted);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _dismiss(DetectionCandidateDto c) async {
    if (_busyId != null) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.detectionDismissTitle,
      body: l10n.detectionDismissBody(c.merchantLabel),
      confirmLabel: l10n.detectionDismiss,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    setState(() => _busyId = c.id);
    try {
      await ref.read(subscriptionsApiProvider).dismissDetection(c.id);
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.detectionDismissed);
      }
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.conflict ||
          error.code == ErrorObjectCode.notFound) {
        ref.invalidate(pendingDetectionsProvider);
      }
      if (mounted) {
        showSnack(context, subscriptionErrorText(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<void> _confirm(DetectionCandidateDto c) async {
    if (_busyId != null) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final SubscriptionDetail? created =
        await showModalBottomSheet<SubscriptionDetail>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (BuildContext context) =>
              ConfirmDetectionSheet(candidate: c),
        );
    if (created != null && mounted) {
      showSnack(context, l10n.detectionConfirmed);
      await context.push(AppRoutes.subscriptionDetail(created.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<DetectionCandidateDto>> detections = ref.watch(
      pendingDetectionsProvider,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.detectionsTitle),
        bottom: _refreshing || (detections.isLoading && detections.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          IconButton(
            tooltip: l10n.detectionsRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _refreshing ? null : _lookAgain,
          ),
        ],
      ),
      body: AsyncValueView<List<DetectionCandidateDto>>(
        value: detections,
        onRetry: () => ref.invalidate(pendingDetectionsProvider),
        isEmpty: (List<DetectionCandidateDto> d) => d.isEmpty,
        empty: MessageStateView(
          icon: Icons.manage_search,
          title: l10n.detectionsEmptyTitle,
          body: l10n.detectionsEmptyBody,
          action: OutlinedButton.icon(
            onPressed: _refreshing ? null : _lookAgain,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.detectionsRefresh),
          ),
        ),
        data: (List<DetectionCandidateDto> list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pendingDetectionsProvider);
            try {
              await ref.read(pendingDetectionsProvider.future);
            } on Object {
              // Shown by the screen state.
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(Insets.md),
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              Text(l10n.detectionsIntro),
              const SizedBox(height: Insets.md),
              for (final DetectionCandidateDto c in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.md),
                  child: _DetectionCard(
                    candidate: c,
                    busy: _busyId != null,
                    onConfirm: () => _confirm(c),
                    onDismiss: () => _dismiss(c),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetectionCard extends ConsumerWidget {
  const _DetectionCard({
    required this.candidate,
    required this.busy,
    required this.onConfirm,
    required this.onDismiss,
  });

  final DetectionCandidateDto candidate;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final DetectionCandidateDto c = candidate;
    final DetectionEvidence evidence = c.evidence;
    final ({DetectionStrength strength, int percent}) confidence =
        detectionConfidence(c.confidenceBp);
    final String? next = c.nextExpectedDate;
    final String? merchantId = c.merchantId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(c.merchantLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: Insets.xs),
            Wrap(
              spacing: Insets.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                MoneyText(c.amount, label: l10n.detectionTypicalAmount),
                Text('· ${frequencyLabel(l10n, c.cadence.json)}'),
              ],
            ),
            if (c.amountTolerance.amountMinor > 0)
              Text(
                l10n.detectionTolerance(
                  formatMoney(context, ref, c.amountTolerance),
                ),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: Insets.sm),
            StatusLabel(
              text: detectionStrengthText(
                l10n,
                confidence.strength,
                confidence.percent,
              ),
              icon: Icons.insights_outlined,
            ),
            const SizedBox(height: Insets.xs),
            Text(
              l10n.detectionConfidenceHelp,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Insets.sm),
            _Evidence(
              lines: <String>[
                ...detectionEvidenceLines(l10n, evidence),
                l10n.detectionEvidenceLast(
                  LocalDates.display(evidence.lastChargeDate, locale: locale),
                ),
                if (next != null)
                  l10n.detectionEvidenceNext(
                    LocalDates.display(next, locale: locale),
                  ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                FilledButton(
                  onPressed: busy ? null : onConfirm,
                  child: Text(
                    l10n.detectionConfirm,
                    semanticsLabel: l10n.detectionConfirmLabel(c.merchantLabel),
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : onDismiss,
                  child: Text(
                    l10n.detectionDismiss,
                    semanticsLabel: l10n.detectionDismissLabel(c.merchantLabel),
                  ),
                ),
                if (merchantId != null)
                  TextButton(
                    onPressed: () => context.go(
                      TransactionFilter(merchantId: merchantId).toLocation(),
                    ),
                    child: Text(
                      l10n.detectionSeeCharges,
                      semanticsLabel: l10n.detectionSeeChargesLabel(
                        c.merchantLabel,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Evidence extends StatelessWidget {
  const _Evidence({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const ExcludeSemantics(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(end: Insets.sm),
                    child: Icon(Icons.check, size: 18),
                  ),
                ),
                Expanded(child: Text(line, style: text.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Confirms a possible subscription, optionally changing the name, price,
/// next renewal, account or category first (unchanged values use what was
/// detected). Pops with the created subscription.
class ConfirmDetectionSheet extends ConsumerStatefulWidget {
  /// Creates the sheet for [candidate].
  const ConfirmDetectionSheet({required this.candidate, super.key});

  /// The possible subscription.
  final DetectionCandidateDto candidate;

  @override
  ConsumerState<ConfirmDetectionSheet> createState() =>
      _ConfirmDetectionSheetState();
}

class _ConfirmDetectionSheetState extends ConsumerState<ConfirmDetectionSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.candidate.merchantLabel,
  );
  late final TextEditingController _amount = TextEditingController(
    text: widget.candidate.amount.amount,
  );
  late String? _next = widget.candidate.nextExpectedDate;
  String? _accountId;
  String? _categoryId;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'amount': 'amount',
    'next_renewal_date': 'next',
    'payment_account_id': 'account',
    'category_id': 'category',
  };

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickAccount() async {
    final AccountDto? account = await showAccountPicker(
      context,
      selectedId: _accountId,
      currency: widget.candidate.amount.currency,
      title: context.l10n.subscriptionPaymentAccountLabel,
    );
    if (account != null && mounted) {
      setState(() => _accountId = account.id);
    }
  }

  Future<void> _pickCategory() async {
    final Picked<CategoryDto>? picked = await showCategoryPicker(
      context,
      kind: CategoryKindFilter.spending,
      selectedId: _categoryId,
    );
    if (picked != null && mounted) {
      setState(() => _categoryId = picked.value?.id);
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final DetectionCandidateDto c = widget.candidate;
    final String? amount = readAmount(
      context,
      ref,
      _amount.text,
      currency: c.amount.currency,
    ).value;
    if (amount == null) {
      return;
    }
    final String name = _name.text.trim();
    // Only what the user changed is sent; the rest uses the detected values.
    final DetectionConfirmInput input = DetectionConfirmInput(
      name: name == c.merchantLabel ? null : name,
      amount: amount == c.amount.amount ? null : amount,
      nextRenewalDate: _next == c.nextExpectedDate ? null : _next,
      paymentAccountId: _accountId,
      categoryId: _categoryId,
    );
    try {
      final SubscriptionDetail created = await ref
          .read(subscriptionsApiProvider)
          .confirmDetection(c.id, input);
      finance.bump();
      if (mounted) {
        Navigator.of(context).pop(created);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(
            l10n,
            error,
            fieldMap: _fields,
            generalMessage: (ApiException e) => subscriptionErrorText(l10n, e),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DetectionCandidateDto c = widget.candidate;
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final String? accountId = _accountId;
    final String? categoryId = _categoryId;
    final String? general = _errors.general;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            0,
            Insets.md,
            Insets.lg,
          ),
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.detectionConfirmTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(l10n.detectionConfirmBody),
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
              maxLength: DetectionConfirmInput.nameMaxLength,
              decoration: InputDecoration(
                labelText: l10n.subscriptionNameLabel,
                errorText: _errors['name'],
                counterText: '',
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
            ),
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _amount,
              label: l10n.subscriptionAmountLabel,
              currency: c.amount.currency,
              errorText: _errors['amount'],
            ),
            const SizedBox(height: Insets.md),
            DateSelectorField(
              label: l10n.subscriptionNextRenewalLabel,
              value: _next,
              emptyLabel: l10n.subscriptionNextRenewalAuto,
              clearable: true,
              errorText: _errors['next'],
              onChanged: (String? d) => setState(() => _next = d),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.subscriptionPaymentAccountLabel,
              icon: Icons.account_balance_wallet_outlined,
              value: accountId == null
                  ? null
                  : (accounts[accountId]?.name ?? l10n.paymentAccountUnknown),
              placeholder: l10n.detectionAccountDefault,
              errorText: _errors['account'],
              onTap: _pickAccount,
              onClear: () => setState(() => _accountId = null),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.categoryFieldLabel,
              icon: Icons.category_outlined,
              value: categoryId == null
                  ? null
                  : switch (categories[categoryId]) {
                      final CategoryDto cat => categoryName(l10n, cat),
                      null => l10n.subscriptionCategoryUnavailable,
                    },
              placeholder: l10n.categoryNone,
              errorText: _errors['category'],
              onTap: _pickCategory,
              onClear: () => setState(() => _categoryId = null),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(label: l10n.detectionConfirm, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
