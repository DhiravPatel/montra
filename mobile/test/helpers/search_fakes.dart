import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/search/data/search_api.dart';

class MockSearchApi extends Mock implements SearchApi {}

/// A `Results` object (live shape); sections default to empty.
Results searchResults({
  String query = 'engage',
  String sort = 'relevance',
  List<Map<String, Object?>> transactions = const <Map<String, Object?>>[],
  List<Map<String, Object?>> accounts = const <Map<String, Object?>>[],
  List<Map<String, Object?>> categories = const <Map<String, Object?>>[],
  List<Map<String, Object?>> bills = const <Map<String, Object?>>[],
  List<Map<String, Object?>> groups = const <Map<String, Object?>>[],
  List<Map<String, Object?>> posts = const <Map<String, Object?>>[],
  List<Map<String, Object?>> users = const <Map<String, Object?>>[],
}) => Results.fromJson(<String, Object?>{
  'query': query,
  'scope': 'all',
  'sort': sort,
  'transactions': transactions,
  'merchants': <Object?>[],
  'accounts': accounts,
  'groups': groups,
  'posts': posts,
  'users': users,
  'goals': <Object?>[],
  'categories': categories,
  'bills': bills,
  'subscriptions': <Object?>[],
  'recurring_rules': <Object?>[],
  'budgets': <Object?>[],
});

/// A `TransactionHit` JSON object (live shape).
Map<String, Object?> transactionHitJson({
  String id = 'tx-1',
  String description = 'Engage test 100% juice_bar',
}) => <String, Object?>{
  'id': id,
  'description': description,
  'amount': <String, Object?>{
    'amount_minor': 25000,
    'amount': '250.00',
    'currency': 'INR',
  },
  'type': 'expense',
  'local_date': '2026-11-12',
  'account_id': 'acc-1',
  'shared': false,
};

/// A `RecentDTO`.
RecentDto recentSearch({String query = 'engage', String scope = 'all'}) =>
    RecentDto.fromJson(<String, Object?>{
      'query': query,
      'scope': scope,
      'created_at': '2026-11-12T06:14:42Z',
    });
