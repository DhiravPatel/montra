import 'package:montra_mobile/app/l10n/l10n.dart';

/// A file size for people: "512 B", "48 KB", "2.4 MB" ('' when unknown).
/// Sizes use 1024-byte units, like the server's limits (15 MB = 15 × 2²⁰).
String formatFileSize(AppLocalizations l10n, int? size) {
  if (size == null || size < 0) {
    return '';
  }
  if (size < 1024) {
    return l10n.sizeBytes(size);
  }
  if (size < 1024 * 1024) {
    return l10n.sizeKilobytes((size / 1024).ceil());
  }
  final double mb = size / (1024 * 1024);
  // Whole megabytes read better for limits ("15 MB", not "15.0 MB").
  final String text = mb == mb.roundToDouble()
      ? mb.toStringAsFixed(0)
      : mb.toStringAsFixed(1);
  return l10n.sizeMegabytes(text);
}
