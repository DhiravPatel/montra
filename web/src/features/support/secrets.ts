/**
 * Mirrors the API's payment-secret check (backend textsafe.Secret), so text
 * with a card number, PIN, OTP, CVV or password is caught before it ever
 * leaves the browser. The API still decides and refuses such text itself.
 */

/** 13 to 19 digits, optionally separated by single spaces or dashes. */
const DIGIT_RUN = /(?:\d[ -]?){13,19}/g;

/** "OTP 482913", "PIN: 1234", "CVV=123", "password: hunter22"… */
const SECRET_WORDS = new RegExp(
  String.raw`\b(?:cvv2?|cvc|upi\s*pin|atm\s*pin|mpin|pin|otp|one[- ]time\s+(?:password|code))\b\s*(?:is|:|=|-)?\s*\d{3,8}\b` +
    String.raw`|\b(?:net\s*banking\s+)?password\s*[:=]\s*\S{4,}`,
  'i',
);

/** The Luhn checksum used by payment card numbers (13 to 19 digits). */
export function passesLuhn(digits: string): boolean {
  if (!/^\d{13,19}$/.test(digits)) return false;
  let sum = 0;
  let double = false;
  for (let index = digits.length - 1; index >= 0; index -= 1) {
    let value = digits.charCodeAt(index) - 48;
    if (double) {
      value *= 2;
      if (value > 9) value -= 9;
    }
    sum += value;
    double = !double;
  }
  return sum % 10 === 0;
}

/** True when the text looks like it contains a card number, PIN, OTP, CVV or password. */
export function containsSecret(text: string): boolean {
  if (SECRET_WORDS.test(text)) return true;
  for (const match of text.matchAll(DIGIT_RUN)) {
    if (passesLuhn(match[0].trim().replace(/[ -]/g, ''))) return true;
  }
  return false;
}
