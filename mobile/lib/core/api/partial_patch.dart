import 'dart:convert';

/// Builds a partial `PATCH` body (docs/API.md, "Idempotency and
/// concurrency"): the server changes only the fields sent.
///
/// [before] is the edit form as it was loaded and [after] the form now,
/// both as request JSON (`SomethingInput.toJson()`, where absent optional
/// members are left out). The body contains:
///
/// * every field of [after] whose value differs from [before];
/// * for fields set in [before] but absent from [after] (the user emptied
///   them): `""` for [textFields], `[]` for lists, and otherwise the field's
///   name in `clear` when it is in [clearable] (the schema's `clear` enum);
///   fields that can be neither are left unchanged;
/// * every key of a [together] group as soon as one of its keys changes
///   (for example a new `frequency` resets the schedule anchors to the
///   ones sent with it, so all of them are sent);
/// * [always] (normally `version`) from [after].
///
/// A value and a `clear` entry are never sent for the same field.
Map<String, Object?> partialPatch({
  required Map<String, Object?> before,
  required Map<String, Object?> after,
  Set<String> clearable = const <String>{},
  Set<String> textFields = const <String>{},
  List<Set<String>> together = const <Set<String>>[],
  Set<String> always = const <String>{'version'},
  String clearKey = 'clear',
}) {
  final Map<String, Object?> body = <String, Object?>{};
  final List<String> clear = <String>[];

  bool changed(String key) {
    final Object? a = before[key];
    final Object? b = after[key];
    if (a == null && b == null) {
      return false;
    }
    return jsonEncode(a) != jsonEncode(b);
  }

  void include(String key) {
    final Object? value = after[key];
    if (value != null) {
      body[key] = value;
      return;
    }
    final Object? old = before[key];
    if (old == null) {
      return;
    }
    if (textFields.contains(key)) {
      body[key] = '';
    } else if (old is List<Object?>) {
      body[key] = const <Object?>[];
    } else if (clearable.contains(key) && !clear.contains(key)) {
      clear.add(key);
    }
  }

  final Set<String> keys = <String>{...before.keys, ...after.keys}
    ..removeAll(always)
    ..remove(clearKey);
  final Set<String> dirty = <String>{
    for (final String key in keys)
      if (changed(key)) key,
  };
  for (final Set<String> group in together) {
    if (group.any(dirty.contains)) {
      dirty.addAll(group);
    }
  }
  for (final String key in keys.union(dirty)) {
    if (dirty.contains(key)) {
      include(key);
    }
  }
  for (final String key in always) {
    if (after[key] != null) {
      body[key] = after[key];
    }
  }
  if (clear.isNotEmpty) {
    body[clearKey] = clear;
  }
  return body;
}

/// Whether [patch] (from [partialPatch]) changes anything besides the
/// [always] fields.
bool patchHasChanges(
  Map<String, Object?> patch, {
  Set<String> always = const <String>{'version'},
}) => patch.keys.any((String key) => !always.contains(key));
