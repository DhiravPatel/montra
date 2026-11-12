import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/support/data/support_api.dart';

/// The user's support requests, newest first.
final FutureProvider<List<RequestDto>> supportRequestsProvider =
    FutureProvider.autoDispose<List<RequestDto>>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(supportApiProvider).list();
    });

/// One request.
final FutureProviderFamily<RequestDto, String> supportRequestProvider =
    FutureProvider.autoDispose.family<RequestDto, String>((Ref ref, String id) {
      ref.watch(currentUserIdProvider);
      return ref.read(supportApiProvider).get(id);
    });

/// The message thread of a request, oldest first.
final FutureProviderFamily<List<MessageDto>, String> supportMessagesProvider =
    FutureProvider.autoDispose.family<List<MessageDto>, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(currentUserIdProvider);
      return ref.read(supportApiProvider).messages(id);
    });
