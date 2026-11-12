import 'package:meta/meta.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// A remark about a receipt's values: the server's English [text] with its
/// stable [code] and [params] (`ReceiptExtractionDTO.warnings`,
/// `warning_codes` and `warning_params`, aligned by position).
@immutable
class ReceiptWarning {
  /// Creates the warning.
  const ReceiptWarning({
    required this.text,
    this.code,
    this.params = const <String, String>{},
  });

  /// English text, shown only for codes the app does not know.
  final String text;

  /// The stable code; null when the server sent none for this remark.
  final ReceiptExtractionDtoWarningCodesItem? code;

  /// Values for the code (amounts are decimal strings with a `currency`).
  final Map<String, String> params;

  @override
  String toString() => 'ReceiptWarning(${code?.json ?? '-'})';
}

/// A receipt with its coded warnings.
@immutable
class ReceiptView {
  /// Creates the view from [detail]; the warnings come from its current
  /// values.
  ReceiptView(this.detail) : warnings = receiptWarningsOf(detail.current);

  /// The receipt.
  final ReceiptDetail detail;

  /// Remarks about the current values, in the server's order.
  final List<ReceiptWarning> warnings;

  @override
  String toString() => 'ReceiptView(${detail.id})';
}

/// The coded warnings of a receipt's values: `warnings`, `warning_codes`
/// and `warning_params` are parallel lists (a code the app does not know
/// decodes as `unrecognized` and keeps its English text).
List<ReceiptWarning> receiptWarningsOf(ReceiptExtractionDto? current) {
  if (current == null) {
    return const <ReceiptWarning>[];
  }
  final List<String> texts = current.warnings;
  final List<ReceiptExtractionDtoWarningCodesItem> codes = current.warningCodes;
  final List<Map<String, String>> params = current.warningParams;
  return <ReceiptWarning>[
    for (int i = 0; i < texts.length; i++)
      ReceiptWarning(
        text: texts[i],
        code:
            i < codes.length &&
                codes[i] != ReceiptExtractionDtoWarningCodesItem.unrecognized
            ? codes[i]
            : null,
        params: i < params.length ? params[i] : const <String, String>{},
      ),
  ];
}
