import { COMMON_PASSWORDS } from './commonPasswords';

/** Server password policy (docs/SECURITY.md, backend auth.ValidatePassword). */
export const PASSWORD_MIN_LENGTH = 10;
export const PASSWORD_MAX_LENGTH = 128;
const MIN_DISTINCT_CHARACTERS = 4;

export type PasswordRuleId = 'length' | 'notCommon' | 'notEmail' | 'variety';

export interface PasswordRuleResult {
  id: PasswordRuleId;
  met: boolean;
}

function characterCount(value: string): number {
  return Array.from(value).length;
}

function emailLocalPart(email: string | undefined): string | null {
  if (!email) return null;
  const at = email.indexOf('@');
  if (at < 0) return null;
  const local = email.slice(0, at).trim().toLowerCase();
  return local.length >= 4 ? local : null;
}

/** Evaluates each rule the server enforces, for live hints. */
export function evaluatePassword(password: string, email?: string): PasswordRuleResult[] {
  const lower = password.toLowerCase();
  const local = emailLocalPart(email);
  const length = characterCount(password);
  return [
    { id: 'length', met: length >= PASSWORD_MIN_LENGTH && length <= PASSWORD_MAX_LENGTH },
    { id: 'notCommon', met: password.length > 0 && !COMMON_PASSWORDS.has(lower) },
    { id: 'notEmail', met: password.length > 0 && (local === null || !lower.includes(local)) },
    {
      id: 'variety',
      met: new Set(password).size >= MIN_DISTINCT_CHARACTERS && password.trim() !== '',
    },
  ];
}

/** The first unmet rule, or null when the password satisfies the policy. */
export function firstUnmetPasswordRule(
  password: string,
  email?: string,
): PasswordRuleId | 'tooLong' | null {
  if (characterCount(password) > PASSWORD_MAX_LENGTH) return 'tooLong';
  return evaluatePassword(password, email).find((rule) => !rule.met)?.id ?? null;
}
