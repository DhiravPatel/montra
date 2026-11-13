#!/usr/bin/env node
/**
 * Generates the code that loads message catalogs with their routes.
 *
 * Catalogs live in src/shared/i18n/locales/<lang>/<namespace>.ts, one
 * namespace per top-level key prefix (`budgets.*` → budgets.ts); `core.ts`
 * holds the prefixes the first screen needs and is bundled with the app.
 * Everything else is loaded on demand.
 *
 * Writes:
 *   src/shared/i18n/namespaces.gen.ts   – namespace list and import() loaders
 *   src/shared/i18n/locales/en/index.ts – whole English catalog (types, tests)
 *   src/shared/i18n/locales/hi/index.ts – whole Hindi catalog (tests)
 *   src/app/router/routeModules.gen.ts  – each lazy route's import() and namespaces
 *
 * Route namespaces come from a static scan: every module a route reaches
 * through imports is searched for message-key literals ('budgets.title',
 * `budgets.pace.${x}`), and their prefixes give the namespaces. It fails
 * when a module the app imports eagerly (the first screen) uses a namespace
 * other than core.
 *
 * Usage: node scripts/i18n-messages.mjs [--check]
 */
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as prettier from 'prettier';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const src = path.join(root, 'src');
const localesDir = path.join(src, 'shared/i18n/locales');
const languages = ['en', 'hi'];
const check = process.argv.includes('--check');

const rel = (file) => path.relative(src, file).split(path.sep).join('/');

// --- Namespaces --------------------------------------------------------------

const namespaces = readdirSync(path.join(localesDir, 'en'))
  .filter((name) => name.endsWith('.ts') && name !== 'index.ts')
  .map((name) => name.slice(0, -3))
  .sort();

for (const lang of languages) {
  for (const ns of namespaces) {
    if (!existsSync(path.join(localesDir, lang, `${ns}.ts`))) {
      throw new Error(`Missing catalog ${lang}/${ns}.ts (every language has every namespace).`);
    }
  }
}

/** Prefix → namespace, read from the keys in each English catalog. */
const prefixNamespace = new Map();
for (const ns of namespaces) {
  const text = readFileSync(path.join(localesDir, 'en', `${ns}.ts`), 'utf8');
  for (const match of text.matchAll(/^ {2}'([^'.]+)\.[^']*':/gm)) {
    const prefix = match[1];
    const owner = prefixNamespace.get(prefix);
    if (owner && owner !== ns) {
      throw new Error(`Prefix '${prefix}' is split between ${owner}.ts and ${ns}.ts.`);
    }
    if (ns !== 'core' && prefix !== ns) {
      throw new Error(`${ns}.ts holds '${prefix}.*' keys; only core.ts may hold other prefixes.`);
    }
    prefixNamespace.set(prefix, ns);
  }
}

// --- Module graph ------------------------------------------------------------

const EXTENSIONS = ['.ts', '.tsx', '/index.ts', '/index.tsx'];

function resolveImport(from, spec) {
  let base;
  if (spec.startsWith('@/')) base = path.join(src, spec.slice(2));
  else if (spec.startsWith('.')) base = path.resolve(path.dirname(from), spec);
  else return null;
  if (/\.(css|svg|png|json)$/.test(base)) return null;
  if (existsSync(base) && /\.tsx?$/.test(base)) return base;
  for (const ext of EXTENSIONS) if (existsSync(base + ext)) return base + ext;
  // This script writes the generated modules; they use no messages themselves.
  if (/\.gen$|locales[\\/](en|hi)[\\/]index$/.test(base)) return null;
  throw new Error(`Cannot resolve '${spec}' from ${rel(from)}`);
}

const STATIC_IMPORT =
  /(?:^|\n)\s*(?:import|export)\s+(?:type\s+)?(?:[^'";]*?\s+from\s+)?['"]([^'"]+)['"]/g;
const DYNAMIC_IMPORT = /import\(\s*['"]([^'"]+)['"]\s*\)/g;
const KEY_LITERAL = /['"`]([a-z][A-Za-z0-9]*)\.[A-Za-z0-9_$]/g;

const routerFile = path.join(src, 'app/router/routes.tsx');
const routeModulesFile = path.join(src, 'app/router/routeModules.gen.ts');
const PAGE_CALL = /\bpage\(\s*'([^']+)'/g;
const cache = new Map();

function readModule(file) {
  let info = cache.get(file);
  if (info) return info;
  const text = readFileSync(file, 'utf8');
  const imports = [];
  for (const match of text.matchAll(STATIC_IMPORT)) {
    if (/^\s*(import|export)\s+type\s/.test(match[0].trim())) continue; // type-only: no runtime use
    const target = resolveImport(file, match[1]);
    if (target) imports.push(target);
  }
  const lazy = [];
  for (const match of text.matchAll(DYNAMIC_IMPORT)) {
    const target = resolveImport(file, match[1]);
    if (target) lazy.push({ spec: match[1], target });
  }
  const used = new Set();
  // Catalogs and generated loaders mention every namespace; they are not users.
  if (!rel(file).startsWith('shared/i18n/locales/') && !rel(file).endsWith('.gen.ts')) {
    for (const match of text.matchAll(KEY_LITERAL)) {
      const ns = prefixNamespace.get(match[1]);
      if (ns) used.add(ns);
    }
  }
  info = { imports, lazy, used };
  cache.set(file, info);
  return info;
}

/** Modules reachable from `entry` through static imports (and non-route dynamic imports). */
function closure(entry) {
  const seen = new Set();
  const stack = [entry];
  while (stack.length > 0) {
    const file = stack.pop();
    if (seen.has(file)) continue;
    seen.add(file);
    const info = readModule(file);
    stack.push(...info.imports);
    // A lazy route is its own entry; other dynamic imports belong to the importer.
    if (file !== routeModulesFile) stack.push(...info.lazy.map((item) => item.target));
  }
  return seen;
}

function namespacesOf(files) {
  const used = new Set();
  for (const file of files) for (const ns of readModule(file).used) used.add(ns);
  return used;
}

const eager = closure(path.join(src, 'main.tsx'));
const eagerNamespaces = namespacesOf(eager);
const leaked = [...eagerNamespaces].filter((ns) => ns !== 'core').sort();
if (leaked.length > 0) {
  const offenders = [...eager]
    .filter((file) => [...readModule(file).used].some((ns) => ns !== 'core'))
    .map(
      (file) =>
        `  ${rel(file)}: ${[...readModule(file).used].filter((ns) => ns !== 'core').join(', ')}`,
    );
  console.error(
    `The first screen's modules use namespaces outside core.ts: ${leaked.join(', ')}\n` +
      `${offenders.join('\n')}\n` +
      'Move those keys into core.ts, or load the module lazily.',
  );
  process.exit(1);
}

const routes = new Map();
for (const match of readFileSync(routerFile, 'utf8').matchAll(PAGE_CALL)) {
  const spec = match[1];
  if (routes.has(spec)) continue;
  const target = resolveImport(routerFile, spec);
  if (!target) throw new Error(`page('${spec}') must name a module under src/ (@/...).`);
  const needed = [...namespacesOf(closure(target))].filter((ns) => ns !== 'core').sort();
  routes.set(spec, needed);
}

// --- Output ------------------------------------------------------------------

const header = '// Generated by scripts/i18n-messages.mjs: do not edit. Run `pnpm i18n:gen`.\n';
const id = (ns) => (/^[a-z][A-Za-z0-9]*$/.test(ns) ? ns : JSON.stringify(ns));

const outputs = new Map();

outputs.set(
  path.join(src, 'shared/i18n/namespaces.gen.ts'),
  `${header}
/** Message namespaces: one per top-level key prefix, plus core. */
export const namespaces = [${namespaces.map((ns) => `'${ns}'`).join(', ')}] as const;

export type Namespace = (typeof namespaces)[number];

/** Namespaces loaded on demand (core ships with the app). */
export type LazyNamespace = Exclude<Namespace, 'core'>;

/** Loads one language's catalog for a namespace (each is its own chunk). */
export const catalogLoaders = {
${languages
  .map(
    (lang) =>
      `  ${lang}: {\n${namespaces
        .filter((ns) => !(lang === 'en' && ns === 'core'))
        .map((ns) => `    ${id(ns)}: () => import('./locales/${lang}/${ns}'),`)
        .join('\n')}\n  },`,
  )
  .join('\n')}
} as const;
`,
);

for (const lang of languages) {
  const imports = namespaces.map((ns) => `import ${ns}Messages from './${ns}';`).join('\n');
  const spread = namespaces.map((ns) => `  ...${ns}Messages,`).join('\n');
  outputs.set(
    path.join(localesDir, lang, 'index.ts'),
    `${header}
/**
 * The whole ${lang === 'en' ? 'English' : 'Hindi'} catalog in one object, for types and tests only.
 * The app never imports this file: it loads namespaces with their routes.
 */
${imports}

export const ${lang} = {
${spread}
} as const;
`,
  );
}

outputs.set(
  routeModulesFile,
  `${header}
import type { LazyNamespace } from '@/shared/i18n/namespaces.gen';

/**
 * Lazy route modules (from the \`page()\` calls in routes.tsx) and the
 * message namespaces each one uses, found by scanning the modules it
 * imports. Core is always loaded.
 */
export const routeModules = {
${[...routes]
  .map(
    ([spec, list]) =>
      `  '${spec}': {\n    load: () => import('${spec}'),\n    messages: [${list.map((ns) => `'${ns}'`).join(', ')}],\n  },`,
  )
  .join('\n')}
} as const satisfies Record<string, { load: () => Promise<unknown>; messages: readonly LazyNamespace[] }>;
`,
);

let stale = false;
for (const [file, raw] of outputs) {
  const options = (await prettier.resolveConfig(file)) ?? {};
  const content = await prettier.format(raw, { ...options, filepath: file });
  const current = existsSync(file) ? readFileSync(file, 'utf8') : '';
  if (current === content) continue;
  if (check) {
    console.error(`${rel(file)} is out of date. Run \`pnpm i18n:gen\`.`);
    stale = true;
  } else {
    writeFileSync(file, content);
    console.log(`wrote ${rel(file)}`);
  }
}
if (stale) process.exit(1);
if (check)
  console.log(`i18n loaders up to date (${namespaces.length} namespaces, ${routes.size} routes).`);
