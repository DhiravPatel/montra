import type { RunOptions } from 'axe-core';
import { configureAxe, toHaveNoViolations } from 'jest-axe';
import { expect } from 'vitest';

expect.extend(toHaveNoViolations);

declare module 'vitest' {
  // Repeats Vitest's own type parameters (required for declaration merging).
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  interface Matchers<R extends void | Promise<void> = void | Promise<void>, T = unknown> {
    toHaveNoViolations(): R;
  }
}

/**
 * Component-level axe run for rendered pages (jsdom + MSW data). jest-axe
 * already turns off the colour rules (jsdom computes no styles); contrast is
 * checked in the browser by e2e/accessibility.spec.ts. Pages are rendered in
 * the full route tree, so landmark and heading rules apply as in the app.
 */
const runAxe = configureAxe({
  rules: {
    // A memory router renders without <html lang> / <title> management.
    'html-has-lang': { enabled: false },
    'document-title': { enabled: false },
  },
});

/**
 * jsdom loads no Tailwind CSS, so both the desktop sidebar (`hidden md:flex`)
 * and the small-screen header and tab bar (`md:hidden`) would be exposed at
 * once, which no real viewport does. These rules reproduce the display
 * toggles the app uses, and each page is checked at both breakpoints.
 */
const viewports = {
  small: '.hidden { display: none !important; }',
  desktop: [
    '.hidden:not(.sm\\:block):not(.sm\\:flex):not(.md\\:block):not(.md\\:flex):not(.md\\:grid) { display: none !important; }',
    '.md\\:hidden { display: none !important; }',
  ].join('\n'),
} as const;

/** Fails the test with jest-axe's readable report when axe finds any violation. */
export async function expectNoAxeViolations(
  root: Element = document.body,
  options: RunOptions = {},
): Promise<void> {
  for (const css of Object.values(viewports)) {
    const style = document.createElement('style');
    style.dataset.axeViewport = '';
    style.textContent = css;
    document.head.append(style);
    try {
      const results = await runAxe(root, options);
      expect(results).toHaveNoViolations();
    } finally {
      style.remove();
    }
  }
}
