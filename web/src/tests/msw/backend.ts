import type { Session, User } from '@/shared/api/types';
import type {
  Account,
  AccountsReport,
  Category,
  Group,
  GroupDetail,
  Merchant,
  PaymentMethod,
  Preferences,
  PublicProfile,
  Tag,
  Widget,
} from '@/shared/finance/types';
import { makeSession } from '../fixtures';
import { defaultWidgets, makeAccountsReport, makePreferences } from '../financeFixtures';

interface TestBackend {
  user: User | null;
  sessions: Session[];
  accounts: Account[];
  categories: Category[];
  tags: Tag[];
  merchants: Merchant[];
  paymentMethods: PaymentMethod[];
  preferences: Preferences;
  widgets: Widget[];
  accountTotals: AccountsReport;
  onboarding: { completed_steps: string[]; skipped_steps: string[]; completed_at?: string };
  /** GET /connections (any connection state; pickers keep friends). */
  people: PublicProfile[];
  groups: Group[];
  /** GET /groups/{id}, by group ID. */
  groupDetails: Record<string, GroupDetail>;
}

function initialState(): TestBackend {
  return {
    user: null,
    sessions: [],
    accounts: [],
    categories: [],
    tags: [],
    merchants: [],
    paymentMethods: [],
    preferences: makePreferences(),
    widgets: defaultWidgets(),
    accountTotals: makeAccountsReport(),
    onboarding: { completed_steps: [], skipped_steps: [] },
    people: [],
    groups: [],
    groupDetails: {},
  };
}

/**
 * Minimal state behind the default MSW handlers (tests only). Tests set
 * `user` to simulate a signed-in browser and fill the finance lists that
 * pickers read; handlers read them. Writes are never handled by default, so
 * a test must declare every write it expects.
 */
export const testBackend: TestBackend = initialState();

export function resetTestBackend(): void {
  Object.assign(testBackend, initialState());
}
export const CURRENT_SESSION_ID = 'a4b2c1d0-1111-4222-8333-944455556666';

export function currentSession(): Session {
  return makeSession({ id: CURRENT_SESSION_ID, current: true, device_name: 'Chrome on macOS' });
}
