// GENERATED CODE - DO NOT EDIT BY HAND.
//
// Source: test/fixtures/gen_api_collisions.json (Generator collision fixture 1, OpenAPI 3.1.0).
// Regenerate with: dart run tool/gen_api.dart --spec test/fixtures/gen_api_collisions.json --out test/fixtures/gen_api_collisions.g.dart --enforced-by test/core/api/gen_api_collisions_test.dart
// Staleness is enforced by test/core/api/gen_api_collisions_test.dart.

/// Typed models for every schema in the Montra API contract.
///
/// Models are immutable. `toString()` deliberately omits field values
/// so tokens and personal data never end up in logs.
library;

import 'package:meta/meta.dart';

/// Schema `Duration`.
@immutable
final class DurationModel {
  /// Creates a [DurationModel].
  const DurationModel({this.seconds});

  /// Decodes a `Duration` JSON object.
  factory DurationModel.fromJson(Map<String, Object?> json) => DurationModel(
    seconds: json['seconds'] == null
        ? null
        : _cast<int>(json['seconds'], 'Duration.seconds'),
  );

  /// JSON `seconds` (optional).
  final int? seconds;

  /// Encodes this object as JSON. Absent optional fields are omitted.
  Map<String, Object?> toJson() => <String, Object?>{'seconds': ?seconds};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DurationModel && other.seconds == seconds;

  @override
  int get hashCode => Object.hashAll(<Object?>[seconds]);

  @override
  String toString() => 'DurationModel(...)';
}

/// Schema `Holder`.
@immutable
final class Holder {
  /// Creates a [Holder].
  const Holder({this.span});

  /// Decodes a `Holder` JSON object.
  factory Holder.fromJson(Map<String, Object?> json) => Holder(
    span: json['span'] == null
        ? null
        : DurationModel.fromJson(
            _cast<Map<String, Object?>>(json['span'], 'Holder.span'),
          ),
  );

  /// JSON `span` (optional).
  final DurationModel? span;

  /// Encodes this object as JSON. Absent optional fields are omitted.
  Map<String, Object?> toJson() => <String, Object?>{'span': ?span?.toJson()};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Holder && other.span == span;

  @override
  int get hashCode => Object.hashAll(<Object?>[span]);

  @override
  String toString() => 'Holder(...)';
}

/// Schema `Report`.
@immutable
final class Report {
  /// Creates a [Report].
  const Report({
    required this.format,
    this.typeValue,
    required this.name,
    this.nameMaxLength,
    this.hashCodeValue,
    this.toJsonValue,
    this.inValue,
    this.userId,
    this.userIdValue,
    this.tags,
  });

  /// Decodes a `Report` JSON object.
  factory Report.fromJson(Map<String, Object?> json) => Report(
    format: ReportFormatEnum.fromJson(
      _cast<String>(json['format'], 'Report.format'),
    ),
    typeValue: json['type'] == null
        ? null
        : _cast<String>(json['type'], 'Report.type'),
    name: _cast<String>(json['name'], 'Report.name'),
    nameMaxLength: json['name_max_length'] == null
        ? null
        : _cast<int>(json['name_max_length'], 'Report.name_max_length'),
    hashCodeValue: json['hash_code'] == null
        ? null
        : _cast<String>(json['hash_code'], 'Report.hash_code'),
    toJsonValue: json['to_json'] == null
        ? null
        : _cast<String>(json['to_json'], 'Report.to_json'),
    inValue: json['in'] == null ? null : _cast<bool>(json['in'], 'Report.in'),
    userId: json['user_id'] == null
        ? null
        : _cast<String>(json['user_id'], 'Report.user_id'),
    userIdValue: json['user-id'] == null
        ? null
        : _cast<String>(json['user-id'], 'Report.user-id'),
    tags: json['tags'] == null
        ? null
        : _castList(
            json['tags'],
            'Report.tags',
            (Object? e1, String p1) =>
                ReportTagsItem.fromJson(_cast<String>(e1, p1)),
          ),
  );

  /// Contract `maxLength` of `name`.
  static const int nameMaxLengthValue = 80;

  /// JSON `format`.
  final ReportFormatEnum format;

  /// JSON `type` (optional).
  final String? typeValue;

  /// JSON `name`.
  final String name;

  /// JSON `name_max_length` (optional).
  final int? nameMaxLength;

  /// JSON `hash_code` (optional).
  final String? hashCodeValue;

  /// JSON `to_json` (optional).
  final String? toJsonValue;

  /// JSON `in` (optional).
  final bool? inValue;

  /// JSON `user_id` (optional).
  final String? userId;

  /// JSON `user-id` (optional).
  final String? userIdValue;

  /// JSON `tags` (optional).
  final List<ReportTagsItem>? tags;

  /// Encodes this object as JSON. Absent optional fields are omitted.
  Map<String, Object?> toJson() => <String, Object?>{
    'format': format.json,
    'type': ?typeValue,
    'name': name,
    'name_max_length': ?nameMaxLength,
    'hash_code': ?hashCodeValue,
    'to_json': ?toJsonValue,
    'in': ?inValue,
    'user_id': ?userId,
    'user-id': ?userIdValue,
    'tags': ?tags?.map((ReportTagsItem item1) => item1.json).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Report &&
          other.format == format &&
          other.typeValue == typeValue &&
          other.name == name &&
          other.nameMaxLength == nameMaxLength &&
          other.hashCodeValue == hashCodeValue &&
          other.toJsonValue == toJsonValue &&
          other.inValue == inValue &&
          other.userId == userId &&
          other.userIdValue == userIdValue &&
          _listEquals(other.tags, tags);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    format,
    typeValue,
    name,
    nameMaxLength,
    hashCodeValue,
    toJsonValue,
    inValue,
    userId,
    userIdValue,
    _listHash(tags),
  ]);

  @override
  String toString() => 'Report(...)';
}

/// Schema `ReportFormat`.
@immutable
final class ReportFormat {
  /// Creates a [ReportFormat].
  const ReportFormat({this.label});

  /// Decodes a `ReportFormat` JSON object.
  factory ReportFormat.fromJson(Map<String, Object?> json) => ReportFormat(
    label: json['label'] == null
        ? null
        : _cast<String>(json['label'], 'ReportFormat.label'),
  );

  /// JSON `label` (optional).
  final String? label;

  /// Encodes this object as JSON. Absent optional fields are omitted.
  Map<String, Object?> toJson() => <String, Object?>{'label': ?label};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ReportFormat && other.label == label;

  @override
  int get hashCode => Object.hashAll(<Object?>[label]);

  @override
  String toString() => 'ReportFormat(...)';
}

/// Allowed values of `Report.format`: `csv`, `json`, `value`, `values`, `name`, `index`, `unrecognized`, `toJson`, `in`, `is`, `default`, `import`, `type`, `25k_50k`, `JSON`, `--`.
///
/// Unknown values (for example from a newer server) decode to [unrecognized] instead of failing.
enum ReportFormatEnum {
  /// Wire value `csv`.
  csv('csv'),

  /// Wire value `json`.
  jsonValue('json'),

  /// Wire value `value`.
  valueValue('value'),

  /// Wire value `values`.
  valuesValue('values'),

  /// Wire value `name`.
  nameValue('name'),

  /// Wire value `index`.
  indexValue('index'),

  /// Wire value `unrecognized`.
  unrecognizedValue('unrecognized'),

  /// Wire value `toJson`.
  tojson('toJson'),

  /// Wire value `in`.
  inValue('in'),

  /// Wire value `is`.
  isValue('is'),

  /// Wire value `default`.
  defaultValue('default'),

  /// Wire value `import`.
  importValue('import'),

  /// Wire value `type`.
  typeValue('type'),

  /// Wire value `25k_50k`.
  v25k50k('25k_50k'),

  /// Wire value `JSON`.
  jsonValueValue('JSON'),

  /// Wire value `--`.
  value16('--'),

  /// A value this client version does not know. Never sent to the server.
  unrecognized('');

  const ReportFormatEnum(this.json);

  /// The wire value.
  final String json;

  /// Decodes a wire value, falling back to [unrecognized].
  static ReportFormatEnum fromJson(String value) {
    for (final ReportFormatEnum candidate in values) {
      if (candidate != unrecognized && candidate.json == value) {
        return candidate;
      }
    }
    return unrecognized;
  }
}

/// Allowed values of `Report.tags_item`: `json`, `other`.
///
/// Unknown values (for example from a newer server) decode to [unrecognized] instead of failing.
enum ReportTagsItem {
  /// Wire value `json`.
  jsonValue('json'),

  /// Wire value `other`.
  other('other'),

  /// A value this client version does not know. Never sent to the server.
  unrecognized('');

  const ReportTagsItem(this.json);

  /// The wire value.
  final String json;

  /// Decodes a wire value, falling back to [unrecognized].
  static ReportTagsItem fromJson(String value) {
    for (final ReportTagsItem candidate in values) {
      if (candidate != unrecognized && candidate.json == value) {
        return candidate;
      }
    }
    return unrecognized;
  }
}

// ---------------------------------------------------------------------------
// Decoding helpers. Error messages name the JSON path, never the value,
// so a malformed response cannot leak personal data into logs.
// ---------------------------------------------------------------------------

T _cast<T extends Object>(Object? value, String path) {
  if (value is T) {
    return value;
  }
  throw FormatException(
    value == null ? '$path is missing' : '$path has an unexpected type',
  );
}

List<T> _castList<T>(
  Object? value,
  String path,
  T Function(Object? item, String itemPath) decode,
) {
  final List<Object?> list = _cast<List<Object?>>(value, path);
  return List<T>.unmodifiable(<T>[
    for (int i = 0; i < list.length; i++) decode(list[i], '$path[$i]'),
  ]);
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null || a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

int _listHash<T>(List<T>? list) => list == null ? 0 : Object.hashAll(list);
