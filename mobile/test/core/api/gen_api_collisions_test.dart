import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/gen_api.dart' as gen;
import '../../fixtures/gen_api_collisions.g.dart' as fx;

/// Generator naming is collision-safe: enum wire values and property names
/// that clash with Dart keywords, `Object`/`Enum` members or the members the
/// generator itself emits (`json`, `value`, `values`, `unrecognized`,
/// `fromJson`, `toJson`, ...) are escaped with a deterministic `Value`
/// suffix, and type names that clash get `Enum` / `Model` suffixes.
///
/// [fixturePath] is generated from [specPath] by the real CLI, so
/// `flutter analyze` compile-checks the escaped output and the tests below
/// exercise it at runtime. Regenerate it with:
///
///     dart run tool/gen_api.dart --spec test/fixtures/gen_api_collisions.json \
///       --out test/fixtures/gen_api_collisions.g.dart \
///       --enforced-by test/core/api/gen_api_collisions_test.dart
///
/// The spec covers: plain values; `json` (the enum's wire-value field);
/// `value` (fromJson's parameter); `values`, `index`, `name` (Enum
/// members); `unrecognized` (the fallback); `toJson`; reserved words (`in`,
/// `is`, `default`); a built-in identifier (`import`); a contextual keyword
/// (`type`); a digit-leading value; a value normalizing to an escaped name
/// (`JSON`); a value without letters or digits; property names colliding
/// with `Object`/model members, keywords, each other and a contract
/// constant; an enum type name taken by a schema; and a schema named like a
/// `dart:core` type. Its operation parameters and response headers use
/// `$ref`s that the generator must ignore.
const String specPath = 'test/fixtures/gen_api_collisions.json';

/// The generated fixture checked by `flutter analyze` and used below.
const String fixturePath = 'test/fixtures/gen_api_collisions.g.dart';

const String enforcedBy = 'test/core/api/gen_api_collisions_test.dart';

void main() {
  test('the committed fixture matches the generator output', () {
    final String generated = gen.generateFromFile(
      specPath: specPath,
      outPath: fixturePath,
      enforcedBy: enforcedBy,
    );
    expect(
      gen.normalizeGenerated(File(fixturePath).readAsStringSync()) ==
          gen.normalizeGenerated(generated),
      isTrue,
      reason: '$fixturePath is stale; see the regenerate command above.',
    );
  });

  group('enum wire values', () {
    test('are escaped away from generator, Enum and keyword names', () {
      final Map<String, fx.ReportFormatEnum> expected =
          <String, fx.ReportFormatEnum>{
            'csv': fx.ReportFormatEnum.csv,
            'json': fx.ReportFormatEnum.jsonValue,
            'value': fx.ReportFormatEnum.valueValue,
            'values': fx.ReportFormatEnum.valuesValue,
            'name': fx.ReportFormatEnum.nameValue,
            'index': fx.ReportFormatEnum.indexValue,
            'unrecognized': fx.ReportFormatEnum.unrecognizedValue,
            'toJson': fx.ReportFormatEnum.tojson,
            'in': fx.ReportFormatEnum.inValue,
            'is': fx.ReportFormatEnum.isValue,
            'default': fx.ReportFormatEnum.defaultValue,
            'import': fx.ReportFormatEnum.importValue,
            'type': fx.ReportFormatEnum.typeValue,
            '25k_50k': fx.ReportFormatEnum.v25k50k,
            'JSON': fx.ReportFormatEnum.jsonValueValue,
            '--': fx.ReportFormatEnum.value16,
          };
      for (final MapEntry<String, fx.ReportFormatEnum> e in expected.entries) {
        expect(fx.ReportFormatEnum.fromJson(e.key), e.value, reason: e.key);
        expect(e.value.json, e.key, reason: 'wire value round-trips');
      }
    });

    test('keep `unrecognized` as the fallback for unknown values', () {
      expect(
        fx.ReportFormatEnum.fromJson('something-new'),
        fx.ReportFormatEnum.unrecognized,
      );
      expect(fx.ReportFormatEnum.unrecognized.json, '');
      expect(
        fx.ReportFormatEnum.unrecognized,
        isNot(fx.ReportFormatEnum.unrecognizedValue),
      );
      // Enum's own members still work.
      expect(fx.ReportFormatEnum.jsonValue.name, 'jsonValue');
      expect(fx.ReportFormatEnum.values, hasLength(17));
    });

    test('list item enums are escaped too', () {
      expect(fx.ReportTagsItem.fromJson('json'), fx.ReportTagsItem.jsonValue);
    });
  });

  group('model classes', () {
    test('escape colliding property names and keep JSON names intact', () {
      final Map<String, Object?> json = <String, Object?>{
        'format': 'json',
        'type': 'monthly',
        'name': 'March',
        'name_max_length': 3,
        'hash_code': 'h',
        'to_json': 't',
        'in': true,
        'user_id': 'u1',
        'user-id': 'u2',
        'tags': <Object?>['json', 'other'],
      };
      final fx.Report report = fx.Report.fromJson(json);
      expect(report.format, fx.ReportFormatEnum.jsonValue);
      expect(report.typeValue, 'monthly');
      expect(report.name, 'March');
      expect(report.nameMaxLength, 3);
      expect(report.hashCodeValue, 'h');
      expect(report.toJsonValue, 't');
      expect(report.inValue, isTrue);
      expect(report.userId, 'u1');
      expect(report.userIdValue, 'u2');
      expect(report.tags, <fx.ReportTagsItem>[
        fx.ReportTagsItem.jsonValue,
        fx.ReportTagsItem.other,
      ]);
      expect(report.toJson(), json);
      // The contract constant is renamed around the `name_max_length` field.
      expect(fx.Report.nameMaxLengthValue, 80);
    });

    test('type names avoid other schemas and dart:core', () {
      const fx.Holder holder = fx.Holder(span: fx.DurationModel(seconds: 5));
      expect(holder.toJson(), <String, Object?>{
        'span': <String, Object?>{'seconds': 5},
      });
      expect(const fx.ReportFormat(label: 'x').toJson(), <String, Object?>{
        'label': 'x',
      });
      // dart:core's Duration is not shadowed.
      expect(const Duration(seconds: 1).inMilliseconds, 1000);
    });
  });

  test('schemas mapping to the same class name fail loudly', () {
    expect(
      () => gen.generateModels(<String, Object?>{
        'components': <String, Object?>{
          'schemas': <String, Object?>{
            'SessionDTO': <String, Object?>{'type': 'object'},
            'SessionDto': <String, Object?>{'type': 'object'},
          },
        },
      }),
      throwsUnsupportedError,
    );
  });
}
