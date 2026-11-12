import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/recurring/data/recurring_api.dart';

/// Filters of the recurring list: `kind` and `status` wire values, or null
/// for any.
typedef RecurringQuery = ({String? kind, String? status});

/// Recurring rules matching a [RecurringQuery]. Re-read after every finance
/// write (confirming an occurrence records a transaction).
final FutureProviderFamily<List<RecurringRuleDto>, RecurringQuery>
recurringRulesProvider = FutureProvider.autoDispose
    .family<List<RecurringRuleDto>, RecurringQuery>((
      Ref ref,
      RecurringQuery query,
    ) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(recurringApiProvider)
          .list(kind: query.kind, status: query.status);
    });

/// One rule with its occurrences.
final FutureProviderFamily<RecurringRuleDetail, String> recurringRuleProvider =
    FutureProvider.autoDispose.family<RecurringRuleDetail, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(financeRevisionProvider);
      return ref.read(recurringApiProvider).get(id);
    });
