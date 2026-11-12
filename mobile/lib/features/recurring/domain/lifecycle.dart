import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// Whether [error] says a lifecycle action no longer fits the record's
/// status (`DOMAIN_RULE_VIOLATION` with `invalid_status_transition`, params
/// `from` / `to`). The record changed somewhere else, so screens reload it
/// and show the localized explanation (`describeError`).
bool isStaleStatus(Object error) =>
    error is ApiException &&
    error.code == ErrorObjectCode.domainRuleViolation &&
    error.details.any((Detail d) => d.code == 'invalid_status_transition');

/// Whether [error] answers a stale `version` (`VERSION_CONFLICT`).
bool isVersionConflict(Object error) =>
    error is ApiException && error.code == ErrorObjectCode.versionConflict;
