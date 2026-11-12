import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/payment_methods/application/payment_methods_providers.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';

/// Payment methods: cash, UPI, cards, transfers… with masked hints only.
/// Removing a method that transactions use archives it instead.
class PaymentMethodsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  bool _showArchived = false;
  String? _removingId;

  Future<void> _remove(PaymentMethodDto method) async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.paymentRemoveConfirmTitle,
      body: l10n.paymentRemoveConfirmBody(method.label),
      confirmLabel: l10n.paymentRemove,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _removingId = method.id);
    try {
      final PaymentMethodDeleteResult result = await ref
          .read(paymentMethodsApiProvider)
          .remove(method.id);
      finance.bump();
      if (mounted) {
        showSnack(
          context,
          result.archived ? l10n.paymentArchivedResult : l10n.paymentRemoved,
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _removingId = null);
      }
    }
  }

  Future<void> _restore(PaymentMethodDto method) async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    setState(() => _removingId = method.id);
    try {
      await ref.read(paymentMethodsApiProvider).restore(method.id);
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.paymentRestored);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _removingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<PaymentMethodDto>> methods = ref.watch(
      paymentMethodsProvider(_showArchived),
    );
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentMethodsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newPaymentMethod),
        icon: const Icon(Icons.add),
        label: Text(l10n.paymentAdd),
      ),
      body: AsyncValueView<List<PaymentMethodDto>>(
        value: methods,
        onRetry: () => ref.invalidate(paymentMethodsProvider(_showArchived)),
        data: (List<PaymentMethodDto> list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(paymentMethodsProvider(_showArchived));
            try {
              await ref.read(paymentMethodsProvider(_showArchived).future);
            } on Object {
              // Shown by the list state.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  Insets.sm,
                  Insets.md,
                  0,
                ),
                child: Text(l10n.paymentMethodsIntro),
              ),
              SwitchListTile(
                title: Text(l10n.paymentShowArchived),
                value: _showArchived,
                onChanged: (bool v) => setState(() => _showArchived = v),
              ),
              if (list.isEmpty)
                MessageStateView(
                  icon: Icons.credit_card_outlined,
                  title: l10n.paymentEmptyTitle,
                  body: l10n.paymentEmptyBody,
                  action: FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.newPaymentMethod),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.paymentAdd),
                  ),
                )
              else
                for (final PaymentMethodDto m in list)
                  _MethodTile(
                    method: m,
                    accountName: m.accountId == null
                        ? null
                        : accounts[m.accountId]?.name,
                    busy: _removingId == m.id,
                    onEdit: m.archivedAt == null
                        ? () => context.push(AppRoutes.editPaymentMethod(m.id))
                        : null,
                    onRemove: m.archivedAt == null && _removingId == null
                        ? () => _remove(m)
                        : null,
                    onRestore: m.archivedAt != null && _removingId == null
                        ? () => _restore(m)
                        : null,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.accountName,
    required this.busy,
    required this.onEdit,
    required this.onRemove,
    required this.onRestore,
  });

  final PaymentMethodDto method;
  final String? accountName;
  final bool busy;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PaymentMethodInputKind kind = kindOf(method);
    final List<String> details = <String>[
      paymentKindLabel(l10n, kind),
      if (networkOf(method) case final PaymentMethodInputNetwork n)
        networkLabel(l10n, n),
      ?method.maskedHint,
      if (accountName != null) l10n.paymentLinkedTo(accountName!),
    ];
    return ListTile(
      onTap: onEdit,
      leading: ExcludeSemantics(child: Icon(paymentKindIcon(kind))),
      title: Text(method.label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(details.join(' · ')),
          if (method.isDefault || method.archivedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Wrap(
                spacing: Insets.xs,
                children: <Widget>[
                  if (method.isDefault)
                    StatusLabel(
                      text: l10n.paymentDefault,
                      tone: StatusTone.positive,
                      icon: Icons.star_outline,
                    ),
                  if (method.archivedAt != null)
                    StatusLabel(
                      text: l10n.accountStatusArchived,
                      icon: Icons.archive_outlined,
                    ),
                ],
              ),
            ),
        ],
      ),
      trailing: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : onRestore != null
          ? IconButton(
              tooltip: l10n.paymentRestoreLabel(method.label),
              icon: const Icon(Icons.restore),
              onPressed: onRestore,
            )
          : onRemove == null
          ? null
          : IconButton(
              tooltip: l10n.paymentRemoveLabel(method.label),
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
            ),
    );
  }
}
