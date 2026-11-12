import { readFileSync } from 'node:fs';
import { fileURLToPath, URL } from 'node:url';
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { loadEnv } from 'vite';
import { defineConfig } from 'vitest/config';
import { vercelCspGuard } from './build/vercel-csp-guard.ts';

function readPackageVersion(): string {
  const pkg: unknown = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8'));
  if (
    typeof pkg === 'object' &&
    pkg !== null &&
    'version' in pkg &&
    typeof pkg.version === 'string'
  ) {
    return pkg.version;
  }
  return '0.0.0';
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const proxyTarget = env.MONTRA_API_PROXY_TARGET || 'http://localhost:8080';
  // The browser always calls same-origin /api/...; the dev/preview server
  // forwards to the Go API so HttpOnly session cookies stay first-party.
  const apiProxy = { '/api': { target: proxyTarget, changeOrigin: false } };

  return {
    plugins: [
      react(),
      tailwindcss(),
      vercelCspGuard(
        env.VITE_API_BASE_URL,
        fileURLToPath(new URL('./vercel.json', import.meta.url)),
      ),
    ],
    resolve: {
      alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
    },
    define: {
      __APP_VERSION__: JSON.stringify(readPackageVersion()),
    },
    server: { port: 5173, strictPort: true, proxy: apiProxy },
    preview: { port: 4173, strictPort: true, proxy: apiProxy },
    build: {
      target: 'es2022',
      sourcemap: false,
      rolldownOptions: {
        output: {
          // Stable vendor chunks cache well across app releases.
          codeSplitting: {
            groups: [
              {
                name: 'vendor-react',
                test: /[\\/]node_modules[\\/](react|react-dom|scheduler|react-router|cookie|set-cookie-parser)[\\/]/,
              },
              { name: 'vendor-query', test: /[\\/]node_modules[\\/]@tanstack[\\/]/ },
              {
                name: 'vendor-forms',
                test: /[\\/]node_modules[\\/](zod|react-hook-form|@hookform)[\\/]/,
              },
              // Message catalogs change with features, not with vendor upgrades.
              { name: 'i18n-en', test: /[\\/]src[\\/]shared[\\/]i18n[\\/]locales[\\/]en\.ts$/ },
              { name: 'i18n-hi', test: /[\\/]src[\\/]shared[\\/]i18n[\\/]locales[\\/]hi\.ts$/ },
              {
                name: 'vendor-ui',
                test: /[\\/]node_modules[\\/](@radix-ui|@floating-ui|react-remove-scroll|react-remove-scroll-bar|react-style-singleton|use-callback-ref|use-sidecar|aria-hidden|get-nonce|detect-node-es|tslib)[\\/]/,
              },
            ],
          },
        },
      },
    },
    test: {
      environment: 'jsdom',
      environmentOptions: { jsdom: { url: 'http://localhost:5173/' } },
      setupFiles: ['./src/tests/setup.ts'],
      include: ['src/**/*.test.{ts,tsx}'],
      css: false,
      clearMocks: true,
      restoreMocks: true,
      // Whole-form journeys (typing every field with user-event) take 2-4 s
      // alone and can pass 5 s when the machine is busy; a real hang still fails.
      testTimeout: 20_000,
    },
  };
});
