import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:montra_mobile/core/files/file_export.dart';

/// A goal's contribution history as CSV text (`GET /goals/{id}/export`,
/// `text/csv`; every contribution, voided ones included).
@immutable
class GoalExport {
  /// Creates the export.
  const GoalExport({required this.csv, this.fileName});

  /// The CSV text exactly as the server produced it.
  final String csv;

  /// Suggested file name from `Content-Disposition`, if any.
  final String? fileName;

  /// The export as a file to share or save: the server's name (by default
  /// `goal-contributions-YYYY-MM-DD.csv`), UTF-8 encoded.
  DownloadedFile toFile({String fallbackName = 'goal-contributions.csv'}) =>
      DownloadedFile(
        name: fileName ?? fallbackName,
        bytes: Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
      );

  /// The records of [csv], header first.
  List<List<String>> get records => parseCsv(csv);

  /// Number of data rows (the header is not counted).
  int get rowCount {
    final int count = records.length;
    return count == 0 ? 0 : count - 1;
  }
}

/// Error bodies of the CSV export arrive as text; decode the JSON error
/// envelope so `ApiException.fromDio` can read its code.
DioException withJsonErrorBody(DioException error) {
  final Response<Object?>? response = error.response;
  final Object? data = response?.data;
  if (response == null || data is! String) {
    return error;
  }
  try {
    return error.copyWith(
      response: Response<Object?>(
        requestOptions: response.requestOptions,
        data: jsonDecode(data),
        statusCode: response.statusCode,
        headers: response.headers,
      ),
    );
  } on FormatException {
    return error;
  }
}

/// The file name in a `Content-Disposition` header
/// (`attachment; filename="goal.csv"`), or null.
String? exportFileName(String? contentDisposition) {
  if (contentDisposition == null) {
    return null;
  }
  final RegExpMatch? encoded = RegExp(
    r"filename\*\s*=\s*UTF-8''([^;]+)",
    caseSensitive: false,
  ).firstMatch(contentDisposition);
  if (encoded != null) {
    try {
      return Uri.decodeComponent(encoded.group(1)!.trim());
    } on ArgumentError {
      // Fall back to the plain parameter.
    }
  }
  final RegExpMatch? plain = RegExp(
    r'filename\s*=\s*"?([^";]+)"?',
    caseSensitive: false,
  ).firstMatch(contentDisposition);
  final String? name = plain?.group(1)?.trim();
  return name == null || name.isEmpty ? null : name;
}

/// Splits CSV [text] (RFC 4180: commas, double-quoted fields with `""`
/// escapes and line breaks inside quotes) into records. A trailing line
/// break does not add an empty record.
List<List<String>> parseCsv(String text) {
  final List<List<String>> records = <List<String>>[];
  List<String> record = <String>[];
  final StringBuffer field = StringBuffer();
  bool quoted = false;
  bool fieldStarted = false;

  void endField() {
    record.add(field.toString());
    field.clear();
    fieldStarted = false;
  }

  void endRecord() {
    endField();
    records.add(record);
    record = <String>[];
  }

  for (int i = 0; i < text.length; i++) {
    final String c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
      continue;
    }
    switch (c) {
      case '"' when !fieldStarted && field.isEmpty:
        quoted = true;
        fieldStarted = true;
      case ',':
        endField();
      case '\r':
        if (i + 1 < text.length && text[i + 1] == '\n') {
          i++;
        }
        endRecord();
      case '\n':
        endRecord();
      default:
        field.write(c);
        fieldStarted = true;
    }
  }
  if (field.isNotEmpty || fieldStarted || record.isNotEmpty) {
    endRecord();
  }
  return records;
}
