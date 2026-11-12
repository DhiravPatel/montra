/**
 * Exact decimal arithmetic for form guidance only ("₹20.00 left to
 * assign"). Values are canonical decimal strings ("1234.50"), handled as
 * BigInt minor units: never binary floating point. The server computes and
 * validates every real split, share, balance and conversion.
 */

const CANONICAL = /^(-)?(\d+)(?:\.(\d+))?$/;

/** A canonical decimal string to integer minor units; null when it is not exact at `exponent`. */
export function toMinor(value: string, exponent: number): bigint | null {
  const match = CANONICAL.exec(value.trim());
  if (!match) return null;
  const [, sign, integer = '0', fraction = ''] = match;
  if (fraction.length > exponent) {
    if (/[1-9]/.test(fraction.slice(exponent))) return null;
  }
  const digits = integer + fraction.slice(0, exponent).padEnd(exponent, '0');
  const minor = BigInt(digits);
  return sign ? -minor : minor;
}

/** Integer minor units to a canonical decimal string ("-1234.50"). */
export function fromMinor(minor: bigint, exponent: number): string {
  const negative = minor < 0n;
  const digits = (negative ? -minor : minor).toString().padStart(exponent + 1, '0');
  const value = exponent > 0 ? `${digits.slice(0, -exponent)}.${digits.slice(-exponent)}` : digits;
  return negative ? `-${value}` : value;
}

export function sumMinor(values: readonly bigint[]): bigint {
  return values.reduce((total, value) => total + value, 0n);
}

/** A percentage with up to 2 decimals ("33.33") in basis points (3333); null when malformed or over 100. */
export function percentToBasisPoints(value: string): bigint | null {
  const match = /^(\d{1,3})(?:\.(\d{1,2}))?$/.exec(value.trim());
  if (!match) return null;
  const basisPoints = BigInt((match[1] ?? '0') + (match[2] ?? '').padEnd(2, '0'));
  return basisPoints > 10_000n ? null : basisPoints;
}

/** Basis points as a plain percentage number without trailing zeros (1250 → "12.5"). */
export function basisPointsToPercent(basisPoints: bigint): string {
  return fromMinor(basisPoints, 2).replace(/\.?0+$/, '') || '0';
}

/** A whole-number weight for a shares split (0 to 1,000,000), or null. */
export function parseShareWeight(value: string): bigint | null {
  const text = value.trim();
  if (!/^\d{1,7}$/.test(text)) return null;
  const weight = BigInt(text);
  return weight > 1_000_000n ? null : weight;
}
