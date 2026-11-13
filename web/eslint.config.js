// @ts-check
import path from 'node:path';

import js from '@eslint/js';
import prettier from 'eslint-config-prettier/flat';
import jsxA11y from 'eslint-plugin-jsx-a11y';
import reactHooks from 'eslint-plugin-react-hooks';
import reactRefresh from 'eslint-plugin-react-refresh';
import { defineConfig, globalIgnores } from 'eslint/config';
import globals from 'globals';
import tseslint from 'typescript-eslint';

// ------------------------------------------------------------------
// Module boundaries (ARCH-004, docs/ARCHITECTURE.md)
//
// - src/shared/** must not import src/features/** or src/app/**.
// - src/features/<f>/** must not import src/app/** (tests may, for the
//   app providers and routes) nor another feature, except the modules
//   listed below. Everything else a feature needs from another feature
//   belongs in src/shared.
//
// The rule resolves `@/` and relative specifiers alike (so `../../other/x`
// cannot bypass it), and counts type-only imports too. The allowlist is
// the set of deliberate cross-feature imports on 2026-11-13; a new entry
// is a design decision made in review, not a lint fix.
const SRC_DIR = path.join(import.meta.dirname, 'src');

/** @type {Record<string, string[]>} importing feature -> modules (features/<module>) it may import */
const allowedFeatureImports = {
  admin: ['privacy/format'],
  analytics: ['fx/components/DisclosedRate'],
  challenges: ['communities/fieldCodes'],
  communities: ['auth/fragmentToken', 'auth/hooks/useFragmentToken'],
  dashboard: [
    'budgets/alertActions',
    'budgets/components/BudgetAlertButtons',
    'budgets/components/BudgetMeter',
    'budgets/components/PaceBadge',
    'goals/components/GoalProgressSummary',
    'groups/labels',
    'planning/calendarMonth',
    'planning/components/CommitmentList',
    'planning/labels',
  ],
  fx: ['analytics/components/Blocks'],
  'group-money': [
    'fx/rate',
    'groups/components/GroupSubNav',
    'planning/components/RecurrenceFields',
    'planning/components/StatusBadges',
    'planning/labels',
    'planning/schedule',
    'receipts/uploads',
  ],
  groups: ['auth/fragmentToken', 'auth/hooks/useFragmentToken'],
  imports: ['reconciliation/reasons'],
  moderation: ['communities/fieldCodes'],
  onboarding: [
    'accounts/components/AccountBalance',
    'accounts/components/AccountForm',
    'accounts/formValues',
    'accounts/useCreateAccount',
    'goals/api',
    'goals/errors',
    'goals/labels',
  ],
  'payment-methods': ['accounts/components/AccountsSubNav'],
  receipts: ['transactions/api'],
  reconciliation: ['imports/api', 'imports/reasons', 'imports/types'],
  reports: ['analytics/components/Blocks'],
  settings: [
    'onboarding/countries',
    'onboarding/regionOptions',
    'social/api',
    'social/errors',
    'social/hooks',
    'social/keys',
    'social/people',
    'social/types',
  ],
};

/** @param {string} spec @param {string} filename @returns {string | null} path under src/ */
function srcPath(spec, filename) {
  if (spec.startsWith('@/')) return spec.slice(2);
  if (spec.startsWith('.')) {
    return path
      .relative(SRC_DIR, path.resolve(path.dirname(filename), spec))
      .split(path.sep)
      .join('/');
  }
  return null;
}

/** @type {import('eslint').Rule.RuleModule} */
const moduleBoundaries = {
  meta: {
    type: 'problem',
    schema: [],
    messages: {
      sharedUp:
        'src/shared must not import {{target}}: shared code cannot depend on features or the app shell.',
      featureApp:
        'Features must not import {{target}} (the app shell); only tests may import app providers and routes.',
      crossFeature:
        "Feature '{{from}}' must not import '{{target}}'. Move the code to src/shared, or add it to allowedFeatureImports in web/eslint.config.js if the dependency is deliberate.",
    },
  },
  create(context) {
    const file = path.relative(SRC_DIR, context.filename).split(path.sep).join('/');
    if (file.startsWith('..')) return {};
    const [area, name] = file.split('/');
    const isTest = /\.test\.tsx?$/.test(file);
    /** @param {import('estree').Node} node @param {unknown} spec */
    const check = (node, spec) => {
      if (typeof spec !== 'string') return;
      const target = srcPath(spec, context.filename);
      if (!target || target.startsWith('..')) return;
      const [tArea, tName, ...rest] = target.split('/');
      if (area === 'shared' && (tArea === 'features' || tArea === 'app')) {
        context.report({ node, messageId: 'sharedUp', data: { target: spec } });
      } else if (area === 'features' && tArea === 'app' && !isTest) {
        context.report({ node, messageId: 'featureApp', data: { target: spec } });
      } else if (area === 'features' && tArea === 'features' && tName !== name && name) {
        const mod = [tName, ...rest]
          .join('/')
          .replace(/\.(tsx?|js)$/, '')
          .replace(/\/index$/, '');
        if (!(allowedFeatureImports[name] ?? []).includes(mod)) {
          context.report({ node, messageId: 'crossFeature', data: { from: name, target: spec } });
        }
      }
    };
    return {
      ImportDeclaration: (n) => {
        check(n.source, n.source.value);
      },
      ExportNamedDeclaration: (n) => {
        if (n.source) check(n.source, n.source.value);
      },
      ExportAllDeclaration: (n) => {
        check(n.source, n.source.value);
      },
      ImportExpression: (n) => {
        if (n.source.type === 'Literal') check(n.source, n.source.value);
      },
    };
  },
};

const moneyFloatMessage =
  'Never parse money with floating point. Money arrives as an exact decimal string; format it with formatMoney().';

export default defineConfig([
  globalIgnores([
    'dist',
    'coverage',
    'playwright-report',
    'test-results',
    'blob-report',
    'src/shared/api/schema.d.ts',
  ]),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      js.configs.recommended,
      tseslint.configs.strictTypeChecked,
      tseslint.configs.stylisticTypeChecked,
      reactHooks.configs.flat['recommended-latest'],
      jsxA11y.flatConfigs.strict,
      reactRefresh.configs.vite,
    ],
    languageOptions: {
      ecmaVersion: 2023,
      globals: globals.browser,
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: { montra: { rules: { 'module-boundaries': moduleBoundaries } } },
    rules: {
      'montra/module-boundaries': 'error',
      'no-console': 'error',
      eqeqeq: ['error', 'always'],
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/consistent-type-imports': ['error', { fixStyle: 'inline-type-imports' }],
      '@typescript-eslint/no-import-type-side-effects': 'error',
      '@typescript-eslint/restrict-template-expressions': ['error', { allowNumber: true }],
      '@typescript-eslint/prefer-nullish-coalescing': [
        'error',
        { ignorePrimitives: { string: true } },
      ],
      // Allow `onSubmit={form.handleSubmit(...)}` style JSX handlers.
      '@typescript-eslint/no-misused-promises': [
        'error',
        { checksVoidReturn: { attributes: false } },
      ],
      'no-restricted-globals': [
        'error',
        { name: 'parseFloat', message: moneyFloatMessage },
        {
          name: 'localStorage',
          message:
            'Use shared/utils/preferences (UI preferences only). Never store tokens or personal data in browser storage.',
        },
        {
          name: 'sessionStorage',
          message:
            'Do not use sessionStorage. Never store tokens or personal data in browser storage.',
        },
      ],
      'no-restricted-properties': [
        'error',
        { object: 'Number', property: 'parseFloat', message: moneyFloatMessage },
        {
          object: 'window',
          property: 'sessionStorage',
          message:
            'Do not use sessionStorage. Never store tokens or personal data in browser storage.',
        },
      ],
    },
  },
  {
    files: ['vite.config.ts', 'playwright.config.ts', 'build/**/*.ts', 'e2e/**/*.ts'],
    languageOptions: { globals: globals.node },
    rules: { 'react-refresh/only-export-components': 'off' },
  },
  {
    files: ['src/**/*.test.{ts,tsx}', 'src/tests/**/*.{ts,tsx}'],
    rules: {
      'react-refresh/only-export-components': 'off',
      '@typescript-eslint/no-non-null-assertion': 'off',
    },
  },
  {
    files: ['**/*.{js,mjs}'],
    extends: [js.configs.recommended],
    languageOptions: { globals: globals.node },
  },
  {
    files: ['public/**/*.js'],
    languageOptions: { globals: globals.browser, sourceType: 'script' },
  },
  prettier,
]);
