import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/bills/data/bills_api.dart';

/// Bills with the given `status` filter. Re-read after every finance write
/// (paying a bill records or links a transaction).
final FutureProviderFamily<List<BillDto>, String> billsProvider = FutureProvider
    .autoDispose
    .family<List<BillDto>, String>((Ref ref, String status) {
      ref.watch(financeRevisionProvider);
      return ref.read(billsApiProvider).list(status: status);
    });

/// One bill with its payment history.
final FutureProviderFamily<BillDetail, String> billProvider = FutureProvider
    .autoDispose
    .family<BillDetail, String>((Ref ref, String id) {
      ref.watch(financeRevisionProvider);
      return ref.read(billsApiProvider).get(id);
    });

/// Which bill occurrence to find payments for.
typedef BillCandidatesQuery = ({String billId, String? occurrenceId});

/// Recorded payments that look like a bill occurrence's.
final FutureProviderFamily<List<BillPaymentCandidate>, BillCandidatesQuery>
billCandidatesProvider = FutureProvider.autoDispose
    .family<List<BillPaymentCandidate>, BillCandidatesQuery>((
      Ref ref,
      BillCandidatesQuery query,
    ) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(billsApiProvider)
          .paymentCandidates(query.billId, occurrenceId: query.occurrenceId);
    });
