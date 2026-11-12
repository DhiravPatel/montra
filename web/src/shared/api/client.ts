import { sessionRecoveryMiddleware } from './session-recovery';
import { createMontraClient, type MontraClient } from './transport';

/**
 * The typed Montra API client (types generated from the OpenAPI contract
 * with `pnpm gen:api`). Every request carries `X-Montra-Client: web`,
 * `X-Client-Version`, cookies, and `X-CSRF-Token` on unsafe methods, and
 * recovers expired sessions transparently. Use with apiData()/apiEnvelope().
 */
export const api: MontraClient = createMontraClient(sessionRecoveryMiddleware);
