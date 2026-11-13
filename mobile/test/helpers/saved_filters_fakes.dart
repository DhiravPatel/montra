import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/saved_filters/saved_filters.dart';

class MockSavedFiltersApi extends Mock implements SavedFiltersApi {}

/// A saved filter as the API returns it.
SavedFilterDto savedFilter(
  String name,
  Object? filter, {
  String id = 's1',
  String scope = 'transactions',
}) => SavedFilterDto.fromJson(<String, Object?>{
  'id': id,
  'scope': scope,
  'name': name,
  'filter': filter,
  'created_at': '2026-11-13T07:00:00Z',
});
