import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';

/// Kinds offered on the signed-in request form, in the order shown.
const List<RequestInputKind> supportKinds = <RequestInputKind>[
  RequestInputKind.support,
  RequestInputKind.bug,
  RequestInputKind.privacy,
  RequestInputKind.security,
  RequestInputKind.feedback,
];

/// Kinds offered on the signed-out contact form (no feedback there).
const List<ContactInputKind> contactKinds = <ContactInputKind>[
  ContactInputKind.support,
  ContactInputKind.bug,
  ContactInputKind.privacy,
  ContactInputKind.security,
];

/// The name of a request kind (wire value).
String supportKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'support' => l10n.helpKindSupport,
  'bug' => l10n.helpKindBug,
  'security' => l10n.helpKindSecurity,
  'privacy' => l10n.helpKindPrivacy,
  'feedback' => l10n.helpKindFeedback,
  _ => l10n.helpKindSupport,
};

/// A request's status in words, with a tone that never relies on color
/// alone ([StatusLabel] adds an icon).
(String, StatusTone) supportStatus(
  AppLocalizations l10n,
  RequestDtoStatus status,
) => switch (status) {
  RequestDtoStatus.open => (l10n.helpStatusOpen, StatusTone.neutral),
  RequestDtoStatus.inProgress => (
    l10n.helpStatusInProgress,
    StatusTone.neutral,
  ),
  RequestDtoStatus.resolved => (l10n.helpStatusResolved, StatusTone.positive),
  RequestDtoStatus.closed => (l10n.helpStatusClosed, StatusTone.neutral),
  RequestDtoStatus.unrecognized => (l10n.statusWordUnknown, StatusTone.neutral),
};

/// Whether replies can still be added to a request.
bool acceptsReplies(RequestDto request) =>
    request.status != RequestDtoStatus.closed;

/// Localized text for the support area's coded errors (registered in
/// `error_messages.dart`); null for other codes. `contains_secret` and
/// `daily_cap` are shared codes localized there.
String? supportDetailMessage(AppLocalizations l10n, Detail detail) =>
    switch (detail.code) {
      'request_closed' => l10n.helpRequestClosedError,
      _ => null,
    };

final RegExp _digitRun = RegExp(r'(?:\d[ -]?){13,19}');
final RegExp _secretWords = RegExp(
  r'\b(?:cvv2?|cvc|upi\s*pin|atm\s*pin|mpin|pin|otp|one[- ]time\s+(?:password|code))\b\s*(?:is|:|=|-)?\s*\d{3,8}\b'
  r'|\b(?:net\s*banking\s+)?password\s*[:=]\s*\S{4,}',
  caseSensitive: false,
);

/// Whether [digits] (13–19 digits) pass the Luhn check of card numbers.
bool passesLuhn(String digits) {
  if (!RegExp(r'^\d{13,19}$').hasMatch(digits)) {
    return false;
  }
  int sum = 0;
  bool double = false;
  for (int i = digits.length - 1; i >= 0; i--) {
    int value = digits.codeUnitAt(i) - 48;
    if (double) {
      value *= 2;
      if (value > 9) {
        value -= 9;
      }
    }
    sum += value;
    double = !double;
  }
  return sum % 10 == 0;
}

/// Whether [text] looks like it contains a card number, PIN, OTP, CVV or
/// password. Mirrors the API's check so such text never leaves the phone;
/// the API still decides (`contains_secret`).
bool containsSecret(String text) {
  if (_secretWords.hasMatch(text)) {
    return true;
  }
  for (final RegExpMatch match in _digitRun.allMatches(text)) {
    if (passesLuhn(match.group(0)!.trim().replaceAll(RegExp('[ -]'), ''))) {
      return true;
    }
  }
  return false;
}
