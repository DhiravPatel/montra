import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/integrations/data/integrations_api.dart';

/// Providers and connections (`GET /integrations`).
final FutureProvider<Overview> integrationsOverviewProvider =
    FutureProvider.autoDispose<Overview>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(integrationsApiProvider).overview();
    });

/// One connection with its recent syncs.
final FutureProviderFamily<ConnectionStatus, String> connectionStatusProvider =
    FutureProvider.autoDispose.family<ConnectionStatus, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(currentUserIdProvider);
      return ref.read(integrationsApiProvider).status(id);
    });
