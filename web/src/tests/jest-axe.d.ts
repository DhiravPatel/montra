// jest-axe ships no types (and @types/jest-axe pulls in Jest's globals), so
// declare the small surface the tests use. This file must stay a script (no
// top-level import/export) so the block below declares the module rather than
// augmenting it; the Vitest matcher typing lives in ./axe.ts.
declare module 'jest-axe' {
  import type { AxeResults, RunOptions, Spec } from 'axe-core';

  type JestAxe = (html: Element | string, options?: RunOptions) => Promise<AxeResults>;

  export function configureAxe(options?: RunOptions & { globalOptions?: Spec }): JestAxe;
  export const axe: JestAxe;
  export const toHaveNoViolations: {
    toHaveNoViolations(results: AxeResults): { pass: boolean; message: () => string };
  };
}
