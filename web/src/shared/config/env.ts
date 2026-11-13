/**
 * Runtime configuration from build-time `VITE_*` variables. The web client
 * holds no secrets: everything here is safe to ship in the bundle.
 */
const env = import.meta.env;

function nonEmpty(value: string | undefined, fallback: string): string {
  const trimmed = value?.trim();
  return trimmed ? trimmed : fallback;
}

/** An absolute https URL, or null (unset, malformed or not https). */
export function httpsUrl(value: string | undefined): string | null {
  const trimmed = value?.trim();
  if (!trimmed) return null;
  try {
    const url = new URL(trimmed);
    return url.protocol === 'https:' ? url.toString() : null;
  } catch {
    return null;
  }
}

export const appConfig = Object.freeze({
  /** API base URL as configured (path such as `/api/v1`, or absolute URL). */
  apiBaseUrl: nonEmpty(env.VITE_API_BASE_URL, '/api/v1'),
  /** Sent as `X-Client-Version` so the API can track client compatibility. */
  clientVersion: __APP_VERSION__,
  supportEmail: nonEmpty(env.VITE_SUPPORT_EMAIL, 'support@montra.example'),
  securityEmail: nonEmpty(env.VITE_SECURITY_EMAIL, 'security@montra.example'),
  /**
   * Public service-status page. Help links to it only when configured: with
   * no status page there is no link at all (never a placeholder).
   */
  statusPageUrl: httpsUrl(env.VITE_STATUS_PAGE_URL),
  /**
   * Legal document versions the user accepts at sign-up. They must match the
   * versions the API currently requires (backend auth.TermsVersion /
   * auth.PrivacyVersion); a mismatch is rejected with `body.terms_version`.
   */
  legal: Object.freeze({ termsVersion: '2026-11-01', privacyVersion: '2026-11-01' }),
});
