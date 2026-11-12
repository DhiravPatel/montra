import { readFileSync } from 'node:fs';
import type { Plugin } from 'vite';

interface VercelHeader {
  key: string;
  value: string;
}

interface VercelHeaderRule {
  source: string;
  headers: VercelHeader[];
}

function isHeaderRule(value: unknown): value is VercelHeaderRule {
  if (typeof value !== 'object' || value === null) return false;
  const rule = value as Record<string, unknown>;
  return typeof rule.source === 'string' && Array.isArray(rule.headers);
}

/** Returns the `connect-src` sources declared by the CSP in vercel.json. */
export function readConnectSources(vercelJsonPath: string): string[] {
  const parsed: unknown = JSON.parse(readFileSync(vercelJsonPath, 'utf8'));
  const headers =
    typeof parsed === 'object' && parsed !== null
      ? (parsed as Record<string, unknown>).headers
      : undefined;
  const rules = Array.isArray(headers) ? headers.filter(isHeaderRule) : [];
  for (const rule of rules) {
    for (const header of rule.headers) {
      if (header.key.toLowerCase() !== 'content-security-policy') continue;
      const directive = header.value
        .split(';')
        .map((part) => part.trim())
        .find((part) => part.startsWith('connect-src'));
      return directive ? directive.split(/\s+/).slice(1) : [];
    }
  }
  return [];
}

/**
 * Fails `vite build` when VITE_API_BASE_URL points at an origin that the
 * production CSP (vercel.json) would block, so a misconfigured deployment
 * cannot ship a portal that is unable to reach its API.
 */
export function vercelCspGuard(apiBaseUrl: string | undefined, vercelJsonPath: string): Plugin {
  return {
    name: 'montra:vercel-csp-guard',
    apply: 'build',
    buildStart() {
      const base = apiBaseUrl?.trim() ?? '';
      if (base === '' || base.startsWith('/')) return; // same-origin: covered by 'self'
      let origin: string;
      try {
        origin = new URL(base).origin;
      } catch {
        this.error(
          `VITE_API_BASE_URL must be a path (e.g. /api/v1) or an absolute URL, got "${base}".`,
        );
      }
      const sources = readConnectSources(vercelJsonPath);
      if (!sources.includes(origin)) {
        this.error(
          `vercel.json Content-Security-Policy connect-src does not allow ${origin}. ` +
            `Add it to connect-src or use a same-origin VITE_API_BASE_URL.`,
        );
      }
    },
  };
}
