/**
 * The web join link the API returns once with a new invitation link
 * (`share_url`, token in the URL fragment). Used only when it is an
 * absolute http(s) URL; otherwise the caller builds the link itself from
 * the token. Never stored, logged or put in this app's own URLs.
 */
export function usableShareUrl(value: string | undefined): string | null {
  if (!value) return null;
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    return null;
  }
  return url.protocol === 'https:' || url.protocol === 'http:' ? value : null;
}
