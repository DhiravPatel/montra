// @ts-check
import js from '@eslint/js';
import prettier from 'eslint-config-prettier/flat';
import jsxA11y from 'eslint-plugin-jsx-a11y';
import reactHooks from 'eslint-plugin-react-hooks';
import reactRefresh from 'eslint-plugin-react-refresh';
import { defineConfig, globalIgnores } from 'eslint/config';
import globals from 'globals';
import tseslint from 'typescript-eslint';

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
    rules: {
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
