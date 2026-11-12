// Fails when src/shared/api/schema.d.ts no longer matches the OpenAPI
// contract (contracts/openapi/montra.v1.json). Fix with `pnpm gen:api`.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const committed = 'src/shared/api/schema.d.ts';
const dir = mkdtempSync(join(tmpdir(), 'montra-api-types-'));
try {
  const generated = join(dir, 'schema.d.ts');
  execFileSync(
    'pnpm',
    ['exec', 'openapi-typescript', '../contracts/openapi/montra.v1.json', '--output', generated],
    { stdio: ['ignore', 'ignore', 'inherit'] },
  );
  if (readFileSync(generated, 'utf8') !== readFileSync(committed, 'utf8')) {
    console.error(`${committed} is out of date with the API contract. Run: pnpm gen:api`);
    process.exitCode = 1;
  } else {
    console.log('API types match the contract.');
  }
} finally {
  rmSync(dir, { recursive: true, force: true });
}
