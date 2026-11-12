import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/gen_api.dart' as gen;

/// Fails when lib/core/api/generated/models.dart no longer matches what
/// tool/gen_api.dart produces from contracts/openapi/montra.v1.json — i.e.
/// the contract (or the generator) changed and models were not regenerated.
void main() {
  test('generated models are up to date with the OpenAPI contract', () {
    final File contract = File(gen.contractPath);
    expect(
      contract.existsSync(),
      isTrue,
      reason: 'Run tests from mobile/; the contract lives in ../contracts.',
    );
    final Map<String, Object?> spec =
        jsonDecode(contract.readAsStringSync()) as Map<String, Object?>;
    final String expected = gen.generateModels(spec);
    final String actual = File(gen.outputPath).readAsStringSync();
    expect(
      gen.normalizeGenerated(actual) == gen.normalizeGenerated(expected),
      isTrue,
      reason:
          '${gen.outputPath} is stale. Regenerate with: dart run tool/gen_api.dart',
    );
  });

  test('every contract schema has a generated type', () {
    final Map<String, Object?> spec = jsonDecode(
      File(gen.contractPath).readAsStringSync(),
    ) as Map<String, Object?>;
    final Map<String, Object?> schemas =
        (spec['components']! as Map<String, Object?>)['schemas']!
            as Map<String, Object?>;
    final String source = File(gen.outputPath).readAsStringSync();
    for (final String name in schemas.keys) {
      expect(
        source.contains('Schema `$name`'),
        isTrue,
        reason: 'No generated type documents schema $name',
      );
    }
  });

  test('normalization ignores formatting but not content', () {
    expect(
      gen.normalizeGenerated('f(a,\n  b,\n);'),
      gen.normalizeGenerated('f(a, b);'),
    );
    expect(
      gen.normalizeGenerated('f(a, b);') == gen.normalizeGenerated('f(a, c);'),
      isFalse,
    );
  });

  group('generator tolerance', () {
    Map<String, Object?> specWith(Map<String, Object?> schemas) =>
        <String, Object?>{
          'openapi': '3.1.0',
          'info': <String, Object?>{'title': 'T', 'version': '1'},
          'paths': <String, Object?>{
            '/things': <String, Object?>{
              'get': <String, Object?>{
                'parameters': <Object?>[
                  <String, Object?>{
                    r'$ref': '#/components/parameters/MontraClient',
                  },
                ],
                'responses': <String, Object?>{
                  '200': <String, Object?>{
                    'description': 'OK',
                    'headers': <String, Object?>{
                      'X-Request-ID': <String, Object?>{
                        r'$ref': '#/components/headers/RequestID',
                      },
                    },
                  },
                },
              },
            },
          },
          'components': <String, Object?>{
            'parameters': <String, Object?>{
              'MontraClient': <String, Object?>{
                'in': 'header',
                'name': 'X-Montra-Client',
                'schema': <String, Object?>{'type': 'string'},
              },
            },
            'headers': <String, Object?>{
              'RequestID': <String, Object?>{
                'schema': <String, Object?>{'type': 'string'},
              },
            },
            'schemas': schemas,
          },
        };

    test(
      'parameter, header and response \$refs outside schemas are ignored',
      () {
        final String out = gen.generateModels(
          specWith(<String, Object?>{
            'Thing': <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'id': <String, Object?>{'type': 'string'},
                'counts': <String, Object?>{
                  'type': 'object',
                  'additionalProperties': <String, Object?>{'type': 'integer'},
                },
              },
              'required': <Object?>['id'],
            },
          }),
        );
        expect(out, contains('final class Thing'));
        expect(out, contains('final Map<String, int>? counts;'));
      },
    );

    test('a schema \$ref to a non-schema component fails loudly', () {
      expect(
        () => gen.generateModels(
          specWith(<String, Object?>{
            'Bad': <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'client': <String, Object?>{
                  r'$ref': '#/components/parameters/MontraClient',
                },
              },
            },
          }),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
