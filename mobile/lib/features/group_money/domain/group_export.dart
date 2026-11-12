import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/features/goals/domain/goal_export.dart'
    show parseCsv;

/// A group's expenses and settlements as CSV (`GET /groups/{id}/export`,
/// `text/csv` with a byte order mark, one row per expense, deleted ones
/// included, then one per settlement).
@immutable
class GroupExport {
  /// Creates the export.
  const GroupExport({required this.csv, this.fileName});

  /// The CSV text exactly as the server produced it.
  final String csv;

  /// The server's file name (`<group>-expenses-YYYY-MM-DD.csv`), if sent.
  final String? fileName;

  /// The export as a file to share or save: UTF-8 with a byte order mark
  /// (as the server sends it), so spreadsheets read names correctly.
  DownloadedFile toFile({String fallbackName = 'group-expenses.csv'}) =>
      DownloadedFile(
        name: fileName ?? fallbackName,
        bytes: Uint8List.fromList(
          utf8.encode(csv.startsWith('\ufeff') ? csv : '\ufeff$csv'),
        ),
        mimeType: 'text/csv',
      );

  /// Number of data rows (expenses and settlements; the header is not
  /// counted).
  int get rowCount {
    final int count = parseCsv(csv).length;
    return count == 0 ? 0 : count - 1;
  }

  @override
  String toString() => 'GroupExport(${csv.length} chars)';
}
