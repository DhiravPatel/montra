import { isNotificationCategory } from './categories';

/**
 * One-click unsubscribe links carry a signed token in the URL fragment
 * (`/unsubscribe#token=<payload>.<signature>`). Fragments never reach
 * servers or Referer headers; the page still removes it from the address
 * bar and history as soon as it is read, keeps it in memory only and
 * sends it only in the request body.
 */
const TOKEN = /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/;

export function readUnsubscribeToken(hash: string): string | null {
  const params = new URLSearchParams(hash.startsWith('#') ? hash.slice(1) : hash);
  const token = params.get('token');
  if (!token || token.length < 20 || token.length > 500 || !TOKEN.test(token)) return null;
  return token;
}

/** Replaces the current history entry with the same URL minus the fragment. */
export function clearUrlFragment(): void {
  const { pathname, search, hash } = window.location;
  if (!hash) return;
  window.history.replaceState(window.history.state as unknown, '', pathname + search);
}

/**
 * The category the link is for, read from the token's signed payload so
 * the page can say what it will turn off before the user confirms. It is
 * a preview only: the server verifies the signature and answers with the
 * category it actually changed. Returns null when it cannot be read.
 */
export function previewCategory(token: string): string | null {
  const payload = token.split('.')[0] ?? '';
  const base64 = payload.replace(/-/g, '+').replace(/_/g, '/');
  let text: string;
  try {
    text = atob(base64 + '='.repeat((4 - (base64.length % 4)) % 4));
  } catch {
    return null;
  }
  const parts = text.split('|');
  const category = parts.length === 3 ? (parts[1] ?? '') : '';
  return isNotificationCategory(category) ? category : null;
}
