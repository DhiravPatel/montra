// Generates typed Dart models from the Montra OpenAPI contract.
//
// Usage (from the mobile/ directory):
//   dart run tool/gen_api.dart          # (re)write lib/core/api/generated/models.dart
//   dart run tool/gen_api.dart --check  # exit 1 if the committed file is stale
//   dart run tool/gen_api.dart --spec <spec.json> --out <file.dart> [--check]
//                                       # same for another spec (test fixtures)
//
// The generator is pure Dart (dart:io + dart:convert only). It supports the
// subset of OpenAPI 3.1 / JSON Schema that the Go backend (Huma) emits today:
// objects with `properties`/`required`, string/integer/number/boolean/array,
// `$ref`, string `enum`, `format: date-time`, nullable unions such as
// `type: [array, null]`, and free-form objects. Anything else fails loudly so a
// contract change can never silently produce wrong models.
//
// Only `components.schemas` is read. Paths, operation parameters, response
// headers and their `$ref`s (`components.parameters`, `components.headers`)
// are ignored here: the app's HTTP client sends the declared headers, and
// test/core/api/endpoints_contract_test.dart checks them.

import 'dart:convert';
import 'dart:io';

/// Contract location relative to the mobile/ package root.
const String contractPath = '../contracts/openapi/montra.v1.json';

/// Generated file location relative to the mobile/ package root.
const String outputPath = 'lib/core/api/generated/models.dart';

Future<void> main(List<String> args) async {
  final bool check = args.contains('--check');
  final String specPath = _option(args, '--spec') ?? contractPath;
  final String outPath = _option(args, '--out') ?? outputPath;
  final String? enforcedBy = _option(args, '--enforced-by');
  if (!File(specPath).existsSync()) {
    stderr.writeln('Spec not found at $specPath (run from mobile/).');
    exitCode = 2;
    return;
  }
  final String generated;
  try {
    generated = generateFromFile(
      specPath: specPath,
      outPath: outPath,
      enforcedBy: enforcedBy,
    );
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
    return;
  }
  final File out = File(outPath);

  if (check) {
    final bool fresh =
        out.existsSync() &&
        normalizeGenerated(out.readAsStringSync()) ==
            normalizeGenerated(generated);
    if (fresh) {
      stdout.writeln('$outPath is up to date with $specPath.');
    } else {
      stderr.writeln(
        '$outPath is stale. Run: ${_command(specPath, outPath, enforcedBy)}',
      );
      exitCode = 1;
    }
    return;
  }

  await out.parent.create(recursive: true);
  await out.writeAsString(generated);
  final ProcessResult format = await Process.run(
    Platform.resolvedExecutable,
    <String>['format', outPath],
  );
  if (format.exitCode != 0) {
    stderr.writeln('dart format failed: ${format.stderr}');
    exitCode = format.exitCode;
    return;
  }
  stdout.writeln('Wrote $outPath from $specPath.');
}

String? _option(List<String> args, String name) {
  final int i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

String _command(String specPath, String outPath, [String? enforcedBy]) =>
    specPath == contractPath && outPath == outputPath && enforcedBy == null
    ? 'dart run tool/gen_api.dart'
    : 'dart run tool/gen_api.dart --spec $specPath --out $outPath'
          '${enforcedBy == null ? '' : ' --enforced-by $enforcedBy'}';

/// Generates models from the JSON spec at [specPath] with exactly the header
/// the CLI writes for [outPath] (used by the CLI and by fixture tests).
String generateFromFile({
  required String specPath,
  required String outPath,
  String? enforcedBy,
}) {
  final Object? decoded = jsonDecode(File(specPath).readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException('$specPath is not a JSON object.');
  }
  final bool isContract = specPath == contractPath && outPath == outputPath;
  return generateModels(
    decoded,
    source: isContract ? 'contracts/openapi/montra.v1.json' : specPath,
    regenerate: _command(specPath, outPath, enforcedBy),
    enforcedBy:
        enforcedBy ??
        (isContract
            ? 'test/core/api/generated_models_test.dart'
            : 'the test that reads $outPath'),
  );
}

/// Normalizes generated source so that formatting differences (whitespace and
/// trailing commas added or removed by `dart format`) do not count as drift.
String normalizeGenerated(String source) {
  final String noSpace = source.replaceAll(RegExp(r'\s+'), '');
  return noSpace.replaceAll(RegExp(r',(?=[\)\]\}])'), '');
}

/// Produces the Dart source for every schema in `components.schemas`.
///
/// [source], [regenerate] and [enforcedBy] only change the header comment
/// (fixture tests generate code from synthetic specs).
String generateModels(
  Map<String, Object?> spec, {
  String source = 'contracts/openapi/montra.v1.json',
  String regenerate = 'dart run tool/gen_api.dart',
  String enforcedBy = 'test/core/api/generated_models_test.dart',
}) {
  final Map<String, Object?> components = _obj(
    spec['components'],
    'components',
  );
  final Map<String, Object?> rawSchemas = _obj(
    components['schemas'],
    'components.schemas',
  );
  final Map<String, Map<String, Object?>> schemas =
      <String, Map<String, Object?>>{
        for (final MapEntry<String, Object?> e in rawSchemas.entries)
          e.key: _obj(e.value, 'components.schemas.${e.key}'),
      };
  final Map<String, Object?> info = spec['info'] is Map<String, Object?>
      ? spec['info']! as Map<String, Object?>
      : const <String, Object?>{};
  return _Generator(
    schemas: schemas,
    apiTitle: '${info['title'] ?? 'API'}',
    apiVersion: '${info['version'] ?? '?'}',
    openApiVersion: '${spec['openapi'] ?? '?'}',
    source: source,
    regenerate: regenerate,
    enforcedBy: enforcedBy,
  ).run();
}

// ---------------------------------------------------------------------------
// Type model
// ---------------------------------------------------------------------------

sealed class _Type {
  const _Type();
}

final class _Primitive extends _Type {
  const _Primitive(this.dart);
  final String dart; // String, int, num, bool
}

final class _DateTimeType extends _Type {
  const _DateTimeType();
}

final class _RefType extends _Type {
  const _RefType(this.className, this.schemaName);
  final String className;
  final String schemaName;
}

final class _EnumType extends _Type {
  const _EnumType(this.enumName);
  final String enumName;
}

final class _ListType extends _Type {
  const _ListType(this.item);
  final _Type item;
}

/// `type: object` without `properties`: a map with string keys.
/// [value] is the `additionalProperties` schema ([_AnyType] when free-form).
final class _MapType extends _Type {
  const _MapType([this.value = const _AnyType()]);
  final _Type value;
}

final class _AnyType extends _Type {
  const _AnyType();
}

final class _Property {
  _Property({
    required this.jsonName,
    required this.dartName,
    required this.type,
    required this.required,
    required this.nullable,
    required this.schema,
  });

  final String jsonName;
  final String dartName;
  final _Type type;
  final bool required;
  final bool nullable;
  final Map<String, Object?> schema;
}

final class _EnumSpec {
  _EnumSpec(this.name, this.ownerSchema, this.jsonName, this.values);
  final String name;
  final String ownerSchema;
  final String jsonName;
  final List<String> values;
}

// ---------------------------------------------------------------------------
// Generator
// ---------------------------------------------------------------------------

final class _Generator {
  _Generator({
    required this.schemas,
    required this.apiTitle,
    required this.apiVersion,
    required this.openApiVersion,
    required this.source,
    required this.regenerate,
    required this.enforcedBy,
  });

  final Map<String, Map<String, Object?>> schemas;
  final String apiTitle;
  final String apiVersion;
  final String openApiVersion;
  final String source;
  final String regenerate;
  final String enforcedBy;

  final StringBuffer _out = StringBuffer();
  final List<_EnumSpec> _enums = <_EnumSpec>[];
  int _lambdaDepth = 0;

  String run() {
    final List<String> names = schemas.keys.toList()..sort();
    _writeHeader();
    final String? metaType = _envelopeMetaType(names);
    if (metaType != null) {
      _writeEnvelope(metaType);
    }
    for (final String name in names) {
      final Map<String, Object?> schema = schemas[name]!;
      if (_isEnvelope(name, schema)) {
        _writeEnvelopeAlias(name, schema);
      } else {
        _writeClass(name, schema);
      }
    }
    for (final _EnumSpec spec in _enums) {
      _writeEnum(spec);
    }
    _writeHelpers();
    return _out.toString();
  }

  // -- naming ---------------------------------------------------------------

  static final RegExp _wordPattern = RegExp(
    r'[A-Z]+(?=[A-Z][a-z]|[0-9]|$)|[A-Z]?[a-z]+|[0-9]+',
  );

  /// Every Dart keyword: reserved words, built-in identifiers and
  /// contextual keywords. Generated identifiers never use one, even where
  /// the language would allow it, so generated code stays unambiguous.
  static const Set<String> _dartKeywords = <String>{
    // Reserved words.
    'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
    'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
    'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
    'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
    // Built-in identifiers.
    'abstract', 'as', 'covariant', 'deferred', 'dynamic', 'export',
    'extension', 'external', 'factory', 'function', 'get', 'implements',
    'import', 'interface', 'late', 'library', 'mixin', 'operator', 'part',
    'required', 'set', 'static', 'typedef',
    // Contextual keywords.
    'async', 'await', 'base', 'hide', 'of', 'on', 'sealed', 'show', 'sync',
    'type', 'when', 'yield',
  };

  /// Members every Dart object has.
  static const Set<String> _objectMembers = <String>{
    'hashCode',
    'noSuchMethod',
    'runtimeType',
    'toString',
  };

  /// Members the generator emits on model classes.
  static const Set<String> _modelMembers = <String>{'fromJson', 'toJson'};

  /// Members the generator emits on enums (`json`, `fromJson`, the
  /// `unrecognized` fallback and the `value` parameter), plus the members of
  /// Dart's `Enum` (`index`, `values`, and `name` from `EnumName`).
  static const Set<String> _enumMembers = <String>{
    'fromJson',
    'index',
    'json',
    'name',
    'toJson',
    'unrecognized',
    'value',
    'values',
  };

  /// Top-level names the generated library must not shadow: `dart:core`
  /// types it uses or that readers expect, and the generic [Envelope].
  static const Set<String> _reservedTypeNames = <String>{
    'BigInt',
    'Comparable',
    'DateTime',
    'Duration',
    'Enum',
    'Envelope',
    'Error',
    'Exception',
    'FormatException',
    'Function',
    'Future',
    'Iterable',
    'Iterator',
    'List',
    'Map',
    'MapEntry',
    'Never',
    'Null',
    'Object',
    'Pattern',
    'Record',
    'RegExp',
    'Set',
    'Sink',
    'Stream',
    'String',
    'StringBuffer',
    'Symbol',
    'Type',
    'Uri',
    'bool',
    'double',
    'int',
    'num',
  };

  /// Dart class name of every schema, decided once before writing.
  late final Map<String, String> _typeNames = _assignTypeNames();

  /// Enum type names already handed out.
  final Set<String> _enumNames = <String>{};

  /// Appends `Value` until [name] is not in [taken]. Deterministic: the
  /// same contract always yields the same names.
  static String _free(String name, Set<String> taken) {
    String result = name;
    while (taken.contains(result)) {
      result = '${result}Value';
    }
    return result;
  }

  Map<String, String> _assignTypeNames() {
    final Map<String, String> names = <String, String>{};
    final Map<String, String> owners = <String, String>{};
    for (final String schema in schemas.keys.toList()..sort()) {
      String name = className(schema);
      if (_reservedTypeNames.contains(name)) {
        name = '${name}Model';
      }
      final String? clash = owners[name];
      if (clash != null) {
        throw UnsupportedError(
          'Schemas "$clash" and "$schema" both map to the Dart class $name',
        );
      }
      owners[name] = schema;
      names[schema] = name;
    }
    return names;
  }

  /// The Dart class name of [schemaName].
  String _typeName(String schemaName) => _typeNames[schemaName]!;

  /// A top-level enum name that collides with no class, `dart:core` type or
  /// other enum (`Enum` is appended until it is free).
  String _uniqueEnumName(String name) {
    final Set<String> taken = <String>{
      ..._typeNames.values,
      ..._reservedTypeNames,
      ..._enumNames,
    };
    String result = name;
    while (taken.contains(result)) {
      result = '${result}Enum';
    }
    _enumNames.add(result);
    return result;
  }

  /// A model field name for [jsonName], unique within its class ([used]).
  String _fieldName(String jsonName, int position, Set<String> used) {
    final String name = _free(_identifier(jsonName, position), <String>{
      ..._dartKeywords,
      ..._objectMembers,
      ..._modelMembers,
      ...used,
    });
    used.add(name);
    return name;
  }

  /// An enum constant name for wire value [wire], unique within its enum
  /// ([used]) and never one of the enum's own members.
  String _enumMemberName(String wire, int position, Set<String> used) {
    final String name = _free(_identifier(wire, position), <String>{
      ..._dartKeywords,
      ..._objectMembers,
      ..._enumMembers,
      ...used,
    });
    used.add(name);
    return name;
  }

  /// `access_expires_at` -> `accessExpiresAt`, `25k_50k` -> `v25k50k`.
  /// Values without letters or digits become `value<position>`.
  static String _identifier(String raw, int position) {
    final List<String> parts = raw
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'value${position + 1}';
    }
    final StringBuffer b = StringBuffer(parts.first.toLowerCase());
    for (final String p in parts.skip(1)) {
      b.write(p[0].toUpperCase() + p.substring(1).toLowerCase());
    }
    final String name = b.toString();
    return RegExp(r'^[0-9]').hasMatch(name) ? 'v$name' : name;
  }

  /// `SessionDTO` -> `SessionDto`, `DisableMFABody` -> `DisableMfaBody`.
  /// Acronyms longer than two letters are capitalized like words
  /// (Effective Dart); two-letter acronyms keep their capitals.
  String className(String schemaName) {
    final Iterable<String> words = _wordPattern
        .allMatches(schemaName)
        .map((Match m) => m.group(0)!);
    final StringBuffer b = StringBuffer();
    for (final String w in words) {
      final bool acronym = w.length > 2 && w == w.toUpperCase();
      final String word = acronym ? w[0] + w.substring(1).toLowerCase() : w;
      // Capitalize every word so hyphenated names such as
      // `Category-rules-applyRequest` become `CategoryRulesApplyRequest`.
      b.write(word[0].toUpperCase() + word.substring(1));
    }
    final String result = b.toString();
    if (result.isEmpty) {
      throw UnsupportedError('Cannot derive a class name from "$schemaName"');
    }
    return result;
  }

  // -- schema helpers -------------------------------------------------------

  bool _isEnvelope(String name, Map<String, Object?> schema) {
    if (!name.startsWith('Envelope')) {
      return false;
    }
    final Map<String, Object?> props = _obj(
      schema['properties'] ?? const <String, Object?>{},
      '$name.properties',
    );
    return props.length == 2 &&
        props.containsKey('data') &&
        props.containsKey('meta');
  }

  ({List<String> types, bool nullable}) _typesOf(Map<String, Object?> s) {
    final Object? t = s['type'];
    if (t is String) {
      return (types: <String>[t], nullable: false);
    }
    if (t is List<Object?>) {
      final List<String> types = t.whereType<String>().toList();
      final bool nullable = types.remove('null');
      return (types: types, nullable: nullable);
    }
    return (types: const <String>[], nullable: false);
  }

  _Type _resolve(
    Map<String, Object?> s,
    String owner,
    String jsonName,
    String path,
  ) {
    final Object? ref = s[r'$ref'];
    if (ref is String) {
      const String prefix = '#/components/schemas/';
      if (!ref.startsWith(prefix)) {
        throw UnsupportedError('$path: unsupported \$ref "$ref"');
      }
      final String target = ref.substring(prefix.length);
      if (!schemas.containsKey(target)) {
        throw UnsupportedError('$path: \$ref to unknown schema "$target"');
      }
      return _RefType(_typeName(target), target);
    }
    for (final String unsupported in <String>['oneOf', 'anyOf', 'allOf']) {
      if (s.containsKey(unsupported)) {
        throw UnsupportedError('$path: "$unsupported" is not supported yet');
      }
    }
    final List<String> types = _typesOf(s).types;
    if (types.length > 1) {
      throw UnsupportedError('$path: union types $types are not supported');
    }
    final String type = types.isEmpty ? 'any' : types.single;
    switch (type) {
      case 'string':
        final Object? values = s['enum'];
        if (values is List<Object?>) {
          final String enumName = _uniqueEnumName(
            _typeName(owner) + className(_pascal(jsonName)),
          );
          _enums.add(
            _EnumSpec(
              enumName,
              owner,
              jsonName,
              values.map((Object? v) => '$v').toList(),
            ),
          );
          return _EnumType(enumName);
        }
        if (s['format'] == 'date-time') {
          return const _DateTimeType();
        }
        return const _Primitive('String');
      case 'integer':
        return const _Primitive('int');
      case 'number':
        return const _Primitive('num');
      case 'boolean':
        return const _Primitive('bool');
      case 'array':
        final Map<String, Object?> items = _obj(
          s['items'] ?? const <String, Object?>{},
          '$path.items',
        );
        return _ListType(_resolve(items, owner, '${jsonName}_item', '$path[]'));
      case 'object':
        if (s.containsKey('properties')) {
          throw UnsupportedError(
            '$path: inline object schemas are not supported; use \$ref',
          );
        }
        final Object? additional = s['additionalProperties'];
        if (additional is Map<String, Object?> && additional.isNotEmpty) {
          return _MapType(
            _resolve(additional, owner, '${jsonName}_value', '$path{}'),
          );
        }
        return const _MapType();
      case 'any':
        return const _AnyType();
      default:
        throw UnsupportedError('$path: unsupported type "$type"');
    }
  }

  String _pascal(String snake) => snake
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((String p) => p.isNotEmpty)
      .map((String p) => p[0].toUpperCase() + p.substring(1))
      .join();

  List<_Property> _properties(String name, Map<String, Object?> schema) {
    final String type = _typesOf(schema).types.isEmpty
        ? 'object'
        : _typesOf(schema).types.single;
    if (type != 'object') {
      throw UnsupportedError('$name: top-level type "$type" is not supported');
    }
    final Map<String, Object?> props = _obj(
      schema['properties'] ?? const <String, Object?>{},
      '$name.properties',
    );
    final Set<String> required = <String>{
      ...((schema['required'] as List<Object?>?) ?? const <Object?>[])
          .whereType<String>(),
    };
    final Set<String> usedNames = <String>{};
    final List<MapEntry<String, Object?>> entries = props.entries.toList();
    return <_Property>[
      for (int i = 0; i < entries.length; i++)
        () {
          final MapEntry<String, Object?> e = entries[i];
          final Map<String, Object?> ps = _obj(e.value, '$name.${e.key}');
          final bool isRequired = required.contains(e.key);
          return _Property(
            jsonName: e.key,
            dartName: _fieldName(e.key, i, usedNames),
            type: _resolve(ps, name, e.key, '$name.${e.key}'),
            required: isRequired,
            nullable: !isRequired || _typesOf(ps).nullable,
            schema: ps,
          );
        }(),
    ];
  }

  // -- Dart rendering ---------------------------------------------------------

  String _dartType(_Type t) => switch (t) {
    _Primitive(:final String dart) => dart,
    _DateTimeType() => 'DateTime',
    _RefType(:final String className) => className,
    _EnumType(:final String enumName) => enumName,
    _ListType(:final _Type item) => 'List<${_dartType(item)}>',
    _MapType(:final _Type value) => 'Map<String, ${_dartType(value)}>',
    _AnyType() => 'Object?',
  };

  String _fieldType(_Property p) {
    final String base = _dartType(p.type);
    if (p.type is _AnyType || !p.nullable) {
      return base;
    }
    return '$base?';
  }

  /// Expression decoding [value] (an `Object?`) at JSON [path] into type [t].
  String _decodeValue(_Type t, String value, String path) {
    switch (t) {
      case _Primitive(:final String dart):
        return '_cast<$dart>($value, $path)';
      case _DateTimeType():
        return '_parseDateTime(_cast<String>($value, $path), $path)';
      case _EnumType(:final String enumName):
        return '$enumName.fromJson(_cast<String>($value, $path))';
      case _RefType(:final String className):
        return '$className.fromJson(_cast<Map<String, Object?>>($value, $path))';
      case _ListType(:final _Type item):
        _lambdaDepth++;
        final String e = 'e$_lambdaDepth';
        final String p = 'p$_lambdaDepth';
        final String inner = _decodeValue(item, e, p);
        _lambdaDepth--;
        return '_castList($value, $path, (Object? $e, String $p) => $inner)';
      case _MapType(value: final _Type mapValue):
        if (mapValue is _AnyType) {
          return '_cast<Map<String, Object?>>($value, $path)';
        }
        _lambdaDepth++;
        final String e = 'e$_lambdaDepth';
        final String p = 'p$_lambdaDepth';
        final String inner = _decodeValue(mapValue, e, p);
        _lambdaDepth--;
        return '_castMap($value, $path, (Object? $e, String $p) => $inner)';
      case _AnyType():
        return value;
    }
  }

  String _decodeProperty(_Property p, String schemaName) {
    final String value = "json['${p.jsonName}']";
    final String path = "'$schemaName.${p.jsonName}'";
    if (p.type is _AnyType) {
      return value;
    }
    final String decoded = _decodeValue(p.type, value, path);
    if (!p.nullable) {
      return decoded;
    }
    // Optional or nullable: absent and null both decode to null.
    return '$value == null ? null : $decoded';
  }

  bool _isPlain(_Type t) =>
      t is _Primitive ||
      t is _AnyType ||
      (t is _MapType && _isPlain(t.value)) ||
      (t is _ListType && _isPlain(t.item));

  int _depthOf(_Type t) => switch (t) {
    _ListType(:final _Type item) => 1 + _depthOf(item),
    _MapType(:final _Type value) => 1 + _depthOf(value),
    _ => 0,
  };

  /// Expression encoding the Dart value [v] of type [t] to JSON. With
  /// [nullAware] the expression short-circuits to null when [v] is null.
  String _encodeValue(_Type t, String v, {bool nullAware = false}) {
    final String dot = nullAware ? '?.' : '.';
    if (_isPlain(t)) {
      return v;
    }
    switch (t) {
      case _DateTimeType():
        return '$v${dot}toUtc().toIso8601String()';
      case _EnumType():
        return '$v${dot}json';
      case _RefType():
        return '$v${dot}toJson()';
      case _ListType(:final _Type item):
        final String x = 'item${_depthOf(t)}';
        return '$v${dot}map((${_dartType(item)} $x) => '
            '${_encodeValue(item, x)}).toList()';
      case _MapType(:final _Type value):
        final String k = 'key${_depthOf(t)}';
        final String x = 'value${_depthOf(t)}';
        return '$v${dot}map((String $k, ${_dartType(value)} $x) => '
            'MapEntry<String, Object?>($k, ${_encodeValue(value, x)}))';
      case _Primitive() || _AnyType():
        return v;
    }
  }

  String _encodeProperty(_Property p) {
    if (p.type is _AnyType) {
      return "'${p.jsonName}': ${p.dartName}";
    }
    if (!p.nullable) {
      return "'${p.jsonName}': ${_encodeValue(p.type, p.dartName)}";
    }
    // Null-aware map entries omit absent optional fields from request bodies.
    return "'${p.jsonName}': "
        '?${_encodeValue(p.type, p.dartName, nullAware: true)}';
  }

  // -- writers ----------------------------------------------------------------

  void _w([String line = '']) => _out.writeln(line);

  void _doc(String text, {String indent = ''}) {
    for (final String line in const LineSplitter().convert(text.trim())) {
      _w(line.isEmpty ? '$indent///' : '$indent/// $line');
    }
  }

  void _writeHeader() {
    _w('// GENERATED CODE - DO NOT EDIT BY HAND.');
    _w('//');
    _w('// Source: $source ($apiTitle $apiVersion, OpenAPI $openApiVersion).');
    _w('// Regenerate with: $regenerate');
    _w('// Staleness is enforced by $enforcedBy.');
    _w();
    _w('/// Typed models for every schema in the Montra API contract.');
    _w('///');
    _w(
      '/// Models are immutable. `toString()` deliberately omits field values',
    );
    _w('/// so tokens and personal data never end up in logs.');
    _w('library;');
    _w();
    _w("import 'package:meta/meta.dart';");
    _w();
  }

  /// The class used for `meta` by every `Envelope*` schema, or null when the
  /// spec has no envelopes (then no [Envelope] class is emitted).
  String? _envelopeMetaType(List<String> names) {
    final Set<String> metaTypes = <String>{};
    for (final String name in names) {
      final Map<String, Object?> schema = schemas[name]!;
      if (!_isEnvelope(name, schema)) {
        continue;
      }
      final Map<String, Object?> props = _obj(
        schema['properties'],
        '$name.properties',
      );
      final _Type meta = _resolve(
        _obj(props['meta'], '$name.meta'),
        name,
        'meta',
        '$name.meta',
      );
      if (meta is! _RefType) {
        throw UnsupportedError('$name.meta must be a \$ref to a schema');
      }
      metaTypes.add(meta.className);
    }
    if (metaTypes.length > 1) {
      throw UnsupportedError('Envelopes use different meta types: $metaTypes');
    }
    return metaTypes.isEmpty ? null : metaTypes.single;
  }

  void _writeEnvelope(String metaType) {
    _doc(
      'Success envelope `{"data": ..., "meta": {...}}` shared by every\n'
      '`Envelope*` schema in the contract.',
    );
    _w('@immutable');
    _w('final class Envelope<T> {');
    _w('  /// Creates an envelope.');
    _w('  const Envelope({required this.data, required this.meta});');
    _w();
    _w('  /// Decodes an envelope, using [decodeData] for the `data` member.');
    _w('  factory Envelope.fromJson(');
    _w('    Map<String, Object?> json,');
    _w('    T Function(Object? data, String path) decodeData,');
    _w('  ) => Envelope<T>(');
    _w("    data: decodeData(json['data'], 'Envelope.data'),");
    _w(
      "    meta: $metaType.fromJson(_cast<Map<String, Object?>>(json['meta'], "
      "'Envelope.meta')),",
    );
    _w('  );');
    _w();
    _w('  /// The response payload.');
    _w('  final T data;');
    _w();
    _w('  /// Response metadata (request ID, timestamp, pagination).');
    _w('  final $metaType meta;');
    _w();
    _w('  @override');
    _w("  String toString() => 'Envelope(...)';");
    _w('}');
    _w();
  }

  void _writeEnvelopeAlias(String name, Map<String, Object?> schema) {
    final Map<String, Object?> props = _obj(
      schema['properties'],
      '$name.properties',
    );
    final Map<String, Object?> dataSchema = _obj(props['data'], '$name.data');
    final _Type dataType = _resolve(dataSchema, name, 'data', '$name.data');
    final bool nullable = _typesOf(dataSchema).nullable;
    final String dartData = _dartType(dataType) + (nullable ? '?' : '');
    final String alias = _typeName(name);
    _doc('Schema `$name`: an [Envelope] whose `data` is `$dartData`.');
    _w('typedef $alias = Envelope<$dartData>;');
    _w();
    final String decode = _decodeValue(dataType, 'data', 'path');
    final String body = nullable ? 'data == null ? null : $decode' : decode;
    _doc('Decodes a `$name` response body.');
    _w('$alias decode$alias(Map<String, Object?> json) =>');
    _w('    Envelope<$dartData>.fromJson(');
    _w('      json,');
    _w('      (Object? data, String path) => $body,');
    _w('    );');
    _w();
  }

  void _writeClass(String name, Map<String, Object?> schema) {
    final String cls = _typeName(name);
    final List<_Property> props = _properties(name, schema);
    final Object? description = schema['description'];
    _doc(
      '${description is String ? '$description\n\n' : ''}'
      'Schema `$name`.',
    );
    _w('@immutable');
    _w('final class $cls {');

    // Constructor.
    final String article = 'AEIOU'.contains(cls[0]) ? 'an' : 'a';
    _w('  /// Creates $article [$cls].');
    if (props.isEmpty) {
      _w('  const $cls();');
    } else {
      _w('  const $cls({');
      for (final _Property p in props) {
        final bool mustPass = p.required || !p.nullable;
        _w('    ${mustPass ? 'required ' : ''}this.${p.dartName},');
      }
      _w('  });');
    }
    _w();

    // fromJson.
    _w('  /// Decodes $article `$name` JSON object.');
    _w('  factory $cls.fromJson(Map<String, Object?> json) => $cls(');
    for (final _Property p in props) {
      _w('    ${p.dartName}: ${_decodeProperty(p, name)},');
    }
    _w('  );');
    _w();

    // Constraint constants. Their names must not collide with a field (a
    // property literally named `name_max_length`, say) or with each other.
    final Set<String> taken = <String>{
      ..._objectMembers,
      ..._modelMembers,
      for (final _Property p in props) p.dartName,
    };
    String constant(String name) {
      final String free = _free(name, taken);
      taken.add(free);
      return free;
    }

    for (final _Property p in props) {
      final Object? maxLength = p.schema['maxLength'];
      final Object? minLength = p.schema['minLength'];
      final Object? pattern = p.schema['pattern'];
      if (minLength is int) {
        _w('  /// Contract `minLength` of `${p.jsonName}`.');
        _w(
          '  static const int ${constant('${p.dartName}MinLength')} = '
          '$minLength;',
        );
        _w();
      }
      if (maxLength is int) {
        _w('  /// Contract `maxLength` of `${p.jsonName}`.');
        _w(
          '  static const int ${constant('${p.dartName}MaxLength')} = '
          '$maxLength;',
        );
        _w();
      }
      if (pattern is String) {
        _w('  /// Contract `pattern` of `${p.jsonName}`.');
        _w(
          '  static const String ${constant('${p.dartName}Pattern')} = '
          '${_literal(pattern)};',
        );
        _w();
      }
    }

    // Fields.
    for (final _Property p in props) {
      final List<String> notes = <String>[];
      final Object? d = p.schema['description'];
      if (d is String && d.isNotEmpty) {
        notes.add(d.endsWith('.') ? d : '$d.');
      }
      notes.add(
        'JSON `${p.jsonName}`'
        '${p.required ? '' : ' (optional)'}'
        '${p.required && p.nullable ? ' (nullable)' : ''}.',
      );
      final Object? format = p.schema['format'];
      if (format is String && format != 'date-time') {
        notes.add('Format: `$format`.');
      }
      final Object? examples = p.schema['examples'];
      if (examples is List<Object?> && examples.isNotEmpty) {
        notes.add('Example: `${examples.first}`.');
      }
      _doc(notes.join('\n\n'), indent: '  ');
      _w('  final ${_fieldType(p)} ${p.dartName};');
      _w();
    }

    // toJson.
    _w(
      '  /// Encodes this object as JSON. Absent optional fields are omitted.',
    );
    _w('  Map<String, Object?> toJson() => <String, Object?>{');
    for (final _Property p in props) {
      _w('    ${_encodeProperty(p)},');
    }
    _w('  };');
    _w();

    // Equality.
    _w('  @override');
    _w('  bool operator ==(Object other) =>');
    if (props.isEmpty) {
      _w('      other is $cls;');
    } else {
      _w('      identical(this, other) ||');
      _w('      other is $cls');
      for (final _Property p in props) {
        if (p.type is _ListType) {
          _w('          && _listEquals(other.${p.dartName}, ${p.dartName})');
        } else if (p.type is _MapType) {
          _w('          && _mapEquals(other.${p.dartName}, ${p.dartName})');
        } else {
          _w('          && other.${p.dartName} == ${p.dartName}');
        }
      }
      _w('      ;');
    }
    _w();
    _w('  @override');
    if (props.isEmpty) {
      _w('  int get hashCode => ($cls).hashCode;');
    } else {
      final String parts = props
          .map(
            (_Property p) => switch (p.type) {
              _ListType() => '_listHash(${p.dartName})',
              _MapType() => '_mapHash(${p.dartName})',
              _ => p.dartName,
            },
          )
          .join(', ');
      _w('  int get hashCode => Object.hashAll(<Object?>[$parts]);');
    }
    _w();
    _w('  @override');
    _w("  String toString() => '$cls(...)';");
    _w('}');
    _w();
  }

  void _writeEnum(_EnumSpec spec) {
    final Set<String> used = <String>{};
    final List<(String, String)> members = <(String, String)>[];
    for (int i = 0; i < spec.values.length; i++) {
      final String value = spec.values[i];
      members.add((_enumMemberName(value, i, used), value));
    }
    // Always `unrecognized`: wire values are escaped away from it above.
    const String fallback = 'unrecognized';
    _doc(
      'Allowed values of `${spec.ownerSchema}.${spec.jsonName}`: '
      '${spec.values.map((String v) => '`$v`').join(', ')}.\n\n'
      'Unknown values (for example from a newer server) decode to '
      '[$fallback] instead of failing.',
    );
    _w('enum ${spec.name} {');
    for (final (String name, String value) in members) {
      _w('  /// Wire value `$value`.');
      _w('  $name(${_literal(value)}),');
    }
    _w(
      '  /// A value this client version does not know. Never sent to the server.',
    );
    _w("  $fallback('');");
    _w();
    _w('  const ${spec.name}(this.json);');
    _w();
    _w('  /// The wire value.');
    _w('  final String json;');
    _w();
    _w('  /// Decodes a wire value, falling back to [$fallback].');
    _w('  static ${spec.name} fromJson(String value) {');
    _w('    for (final ${spec.name} candidate in values) {');
    _w('      if (candidate != $fallback && candidate.json == value) {');
    _w('        return candidate;');
    _w('      }');
    _w('    }');
    _w('    return $fallback;');
    _w('  }');
    _w('}');
    _w();
  }

  void _writeHelpers() {
    // Only emit helpers the models reference, so `unused_element` stays clean.
    final String body = _out.toString();
    _w(
      '// ---------------------------------------------------------------------------',
    );
    _w(
      '// Decoding helpers. Error messages name the JSON path, never the value,',
    );
    _w('// so a malformed response cannot leak personal data into logs.');
    _w(
      '// ---------------------------------------------------------------------------',
    );
    _w();
    _w('T _cast<T extends Object>(Object? value, String path) {');
    _w('  if (value is T) {');
    _w('    return value;');
    _w('  }');
    _w(
      "  throw FormatException(value == null ? '\$path is missing' : '\$path has an unexpected type');",
    );
    _w('}');
    if (body.contains('_castList(')) {
      _w();
      _w(
        'List<T> _castList<T>(Object? value, String path, T Function(Object? item, String itemPath) decode) {',
      );
      _w('  final List<Object?> list = _cast<List<Object?>>(value, path);');
      _w('  return List<T>.unmodifiable(<T>[');
      _w(
        "    for (int i = 0; i < list.length; i++) decode(list[i], '\$path[\$i]'),",
      );
      _w('  ]);');
      _w('}');
    }
    if (body.contains('_castMap(')) {
      _w();
      _w(
        'Map<String, T> _castMap<T>(Object? value, String path, T Function(Object? item, String itemPath) decode) {',
      );
      _w(
        '  final Map<String, Object?> map = _cast<Map<String, Object?>>(value, path);',
      );
      _w('  return Map<String, T>.unmodifiable(<String, T>{');
      _w(
        "    for (final MapEntry<String, Object?> e in map.entries) e.key: decode(e.value, '\$path.\${e.key}'),",
      );
      _w('  });');
      _w('}');
    }
    if (body.contains('_parseDateTime(')) {
      _w();
      _w('DateTime _parseDateTime(String value, String path) {');
      _w('  final DateTime? parsed = DateTime.tryParse(value);');
      _w('  if (parsed == null) {');
      _w("    throw FormatException('\$path is not an RFC 3339 date-time');");
      _w('  }');
      _w('  return parsed;');
      _w('}');
    }
    if (body.contains('_listEquals(')) {
      _w();
      _w('bool _listEquals<T>(List<T>? a, List<T>? b) {');
      _w('  if (identical(a, b)) {');
      _w('    return true;');
      _w('  }');
      _w('  if (a == null || b == null || a.length != b.length) {');
      _w('    return false;');
      _w('  }');
      _w('  for (int i = 0; i < a.length; i++) {');
      _w('    if (a[i] != b[i]) {');
      _w('      return false;');
      _w('    }');
      _w('  }');
      _w('  return true;');
      _w('}');
    }
    if (body.contains('_listHash(')) {
      _w();
      _w(
        'int _listHash<T>(List<T>? list) => list == null ? 0 : Object.hashAll(list);',
      );
    }
    if (body.contains('_mapEquals(')) {
      _w();
      _w('bool _mapEquals<T>(Map<String, T>? a, Map<String, T>? b) {');
      _w('  if (identical(a, b)) {');
      _w('    return true;');
      _w('  }');
      _w('  if (a == null || b == null || a.length != b.length) {');
      _w('    return false;');
      _w('  }');
      _w('  for (final MapEntry<String, T> e in a.entries) {');
      _w('    if (!b.containsKey(e.key) || b[e.key] != e.value) {');
      _w('      return false;');
      _w('    }');
      _w('  }');
      _w('  return true;');
      _w('}');
    }
    if (body.contains('_mapHash(')) {
      _w();
      _w('int _mapHash<T>(Map<String, T>? map) => map == null');
      _w('    ? 0');
      _w('    : Object.hashAllUnordered(<int>[');
      _w(
        '        for (final MapEntry<String, T> e in map.entries) Object.hash(e.key, e.value),',
      );
      _w('      ]);');
    }
  }

  /// A Dart string literal for [value]: plain when possible, raw when it
  /// contains `$` or backslashes, escaped otherwise.
  String _literal(String value) {
    final bool hasQuote = value.contains("'") || value.contains('\n');
    if (!hasQuote && !value.contains(r'$') && !value.contains(r'\')) {
      return "'$value'";
    }
    if (!hasQuote) {
      return "r'$value'";
    }
    return jsonEncode(value).replaceAll(r'$', r'\$');
  }
}

Map<String, Object?> _obj(Object? value, String path) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw FormatException('$path must be a JSON object');
}
