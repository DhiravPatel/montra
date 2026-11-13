/// <reference types="node" />
import { execFileSync } from 'node:child_process';
import { describe, expect, it } from 'vitest';
import { hasNamespaces } from '@/shared/i18n/catalogs';
import { namespaces } from '@/shared/i18n/namespaces.gen';
import { routeModules } from './routeModules.gen';

describe('lazy routes and their messages', () => {
  it('declares only known namespaces for every lazy route', () => {
    for (const [spec, entry] of Object.entries(routeModules)) {
      for (const ns of entry.messages) expect(namespaces, spec).toContain(ns);
      expect(hasNamespaces('hi', entry.messages), spec).toBe(true);
    }
    expect(routeModules['@/features/support/pages/GuidePage'].messages).toContain('helpContent');
    expect(routeModules['@/features/support/pages/HelpPage'].messages).not.toContain('helpContent');
  });

  it('has generated loaders that match the catalogs and routes (pnpm i18n:gen)', () => {
    // Vitest runs from the web package root.
    const output = execFileSync(process.execPath, ['scripts/i18n-messages.mjs', '--check'], {
      cwd: process.cwd(),
      encoding: 'utf8',
    });
    expect(output).toContain('up to date');
  });
});
