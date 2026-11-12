/**
 * Double-submit CSRF token for cookie-authenticated unsafe requests
 * (ADR-002). Source of truth is the readable `montra_csrf` cookie; when the
 * API is on another origin the cookie is not readable, so the token from the
 * latest login/refresh/session response is kept in memory (never in storage).
 */
export const CSRF_COOKIE = 'montra_csrf';

let memoryToken: string | null = null;

export function readCsrfCookie(): string | null {
  if (typeof document === 'undefined') return null;
  for (const part of document.cookie.split(';')) {
    const separator = part.indexOf('=');
    if (separator === -1) continue;
    if (part.slice(0, separator).trim() !== CSRF_COOKIE) continue;
    let value = part.slice(separator + 1).trim();
    if (value.startsWith('"') && value.endsWith('"')) value = value.slice(1, -1);
    if (!value) return null;
    try {
      return decodeURIComponent(value);
    } catch {
      return value;
    }
  }
  return null;
}

export function getCsrfToken(): string | null {
  return readCsrfCookie() ?? memoryToken;
}

export function rememberCsrfToken(token: string | null | undefined): void {
  if (token) memoryToken = token;
}

export function forgetCsrfToken(): void {
  memoryToken = null;
}
