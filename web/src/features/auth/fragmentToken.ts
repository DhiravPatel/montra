/**
 * Email links carry single-use tokens in the URL fragment
 * (`/verify-email#token=...`). Fragments are never sent to servers or in
 * Referer headers; the page still removes it from the address bar and the
 * history entry as soon as it has been read.
 */
const TOKEN_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;

export function readFragmentToken(hash: string): string | null {
  const params = new URLSearchParams(hash.startsWith('#') ? hash.slice(1) : hash);
  const token = params.get('token');
  return token && TOKEN_PATTERN.test(token) ? token : null;
}

/** Replaces the current history entry with the same URL minus the fragment. */
export function clearUrlFragment(): void {
  const { pathname, search, hash } = window.location;
  if (!hash) return;
  window.history.replaceState(window.history.state as unknown, '', pathname + search);
}
