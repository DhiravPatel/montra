/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Base URL of the Montra API (path or absolute URL). Defaults to `/api/v1`. */
  readonly VITE_API_BASE_URL?: string;
  readonly VITE_SUPPORT_EMAIL?: string;
  readonly VITE_SECURITY_EMAIL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

/** Web portal version from package.json (sent as X-Client-Version). */
declare const __APP_VERSION__: string;
