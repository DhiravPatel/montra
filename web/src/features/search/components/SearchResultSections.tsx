import type { ReactNode } from 'react';
import { Link } from 'react-router';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Icon, type IconName } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextLink } from '@/shared/components/TextLink';
import {
  accountPath,
  billPath,
  budgetPath,
  goalPath,
  groupPath,
  merchantPath,
  paths,
  postPath,
  recurringPath,
  subscriptionPath,
  transactionPath,
  withQuery,
} from '@/shared/config/paths';
import {
  accountTypeIcon,
  isAccountType,
  TRANSACTION_TYPES,
  transactionTypeLabel,
} from '@/shared/finance/labels';
import { transactionIcon } from '@/shared/finance/transactionDisplay';
import type { TransactionType } from '@/shared/finance/types';
import { formatDate, formatLocalDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { sectionHeadingId } from '../ids';
import { hitKindLabel, scopeLabel, sectionIcon } from '../labels';
import { ALL_SECTIONS_LIMIT, ONE_SECTION_LIMIT, SEARCH_SECTIONS } from '../query';
import type {
  NamedHit,
  NamedSection,
  PostHit,
  SearchResults,
  SearchScope,
  SearchSection,
  TransactionHit,
  UserHit,
} from '../types';
import { Highlight } from './Highlight';

const rowClasses = 'flex min-h-11 items-center gap-3 rounded-md px-2 py-2.5 hover:bg-surface-muted';

function isTransactionType(value: string): value is TransactionType {
  return (TRANSACTION_TYPES as readonly string[]).includes(value);
}

function RowIcon({ name }: { name: IconName }) {
  return (
    <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
      <Icon name={name} className="size-4" />
    </span>
  );
}

function RowText({ title, details }: { title: ReactNode; details?: ReactNode }) {
  return (
    <span className="min-w-0 flex-1">
      <span className="block truncate font-medium text-fg">{title}</span>
      {details ? <span className="block text-sm text-fg-muted">{details}</span> : null}
    </span>
  );
}

function TransactionRow({ hit, query }: { hit: TransactionHit; query: string }) {
  const { t, formatLocale } = useI18n();
  const type = isTransactionType(hit.type) ? hit.type : null;
  const typeLabel = type ? t(transactionTypeLabel[type]) : null;
  const title = hit.merchant || hit.description || typeLabel || t('search.tx.untitled');
  const details = [
    hit.merchant && hit.description ? hit.description : null,
    typeLabel,
    formatLocalDate(hit.local_date, formatLocale),
  ].filter(Boolean);
  return (
    <Link to={transactionPath(hit.id)} className={rowClasses}>
      <RowIcon name={type ? transactionIcon(type) : 'list'} />
      <RowText
        title={<Highlight text={title} query={query} />}
        details={
          <>
            {details.join(' · ')}
            {hit.shared ? (
              <span className="mt-1 block">
                <StatusBadge tone="info" icon="users">
                  {t('search.tx.shared')}
                </StatusBadge>
              </span>
            ) : null}
          </>
        }
      />
      <MoneyText money={hit.amount} className="shrink-0 font-medium text-fg" />
    </Link>
  );
}

/**
 * Where a named hit opens (IDs only). Categories have no page of their
 * own, so a category opens the transactions recorded in it.
 */
const namedPath: Readonly<Record<NamedSection, (id: string) => string>> = {
  accounts: accountPath,
  merchants: merchantPath,
  categories: (id) => withQuery(paths.transactions, { category_id: id }),
  budgets: budgetPath,
  bills: billPath,
  subscriptions: subscriptionPath,
  recurring_rules: recurringPath,
  goals: goalPath,
  groups: groupPath,
};

function NamedRow({
  hit,
  section,
  query,
}: {
  hit: NamedHit;
  section: NamedSection;
  query: string;
}) {
  const { t } = useI18n();
  const kind = hitKindLabel(section, hit.kind);
  const icon =
    section === 'accounts' && hit.kind && isAccountType(hit.kind)
      ? accountTypeIcon[hit.kind]
      : sectionIcon[section];
  return (
    <Link to={namedPath[section](hit.id)} className={rowClasses}>
      <RowIcon name={icon} />
      <RowText
        title={<Highlight text={hit.name} query={query} />}
        details={kind ? t(kind) : null}
      />
      <Icon name="chevron-right" className="text-fg-muted" />
    </Link>
  );
}

function PostRow({ hit, query }: { hit: PostHit; query: string }) {
  const { formatLocale } = useI18n();
  const user = useCurrentUser();
  const created = parseTimestamp(hit.created_at);
  const details = [
    hit.community_name,
    created ? formatDate(created, formatLocale, user.timezone) : null,
  ]
    .filter(Boolean)
    .join(' · ');
  return (
    <Link to={postPath(hit.id)} className={rowClasses}>
      <RowIcon name={sectionIcon.posts} />
      <RowText title={<Highlight text={hit.title} query={query} />} details={details} />
      <Icon name="chevron-right" className="text-fg-muted" />
    </Link>
  );
}

function UserRow({ hit, query }: { hit: UserHit; query: string }) {
  const { t } = useI18n();
  return (
    <div className={rowClasses}>
      <RowIcon name={sectionIcon.users} />
      <RowText
        title={<Highlight text={hit.display_name} query={query} />}
        details={
          hit.username ? (
            <Highlight text={t('search.user.username', { username: hit.username })} query={query} />
          ) : null
        }
      />
    </div>
  );
}

function sectionRows(section: SearchSection, results: SearchResults, query: string): ReactNode[] {
  switch (section) {
    case 'transactions':
      return results.transactions.map((hit) => (
        <li key={hit.id}>
          <TransactionRow hit={hit} query={query} />
        </li>
      ));
    case 'posts':
      return results.posts.map((hit) => (
        <li key={hit.id}>
          <PostRow hit={hit} query={query} />
        </li>
      ));
    case 'users':
      return results.users.map((hit) => (
        <li key={hit.user_id}>
          <UserRow hit={hit} query={query} />
        </li>
      ));
    default:
      return results[section].map((hit) => (
        <li key={hit.id}>
          <NamedRow hit={hit} section={section} query={query} />
        </li>
      ));
  }
}

interface SearchResultSectionsProps {
  results: SearchResults;
  scope: SearchScope;
  onShowMore: (section: SearchSection) => void;
}

/** Results grouped by type, in a fixed order; empty sections are left out. */
export function SearchResultSections({ results, scope, onShowMore }: SearchResultSectionsProps) {
  const { t } = useI18n();
  return (
    <div className="space-y-6">
      {SEARCH_SECTIONS.filter((section) => results[section].length > 0).map((section) => {
        const count = results[section].length;
        const label = t(scopeLabel[section]);
        const headingId = sectionHeadingId(section);
        const mayHaveMore = scope === 'all' && count >= ALL_SECTIONS_LIMIT;
        return (
          <section
            key={section}
            aria-labelledby={headingId}
            className="rounded-xl border border-line bg-surface p-5 shadow-card sm:p-6"
          >
            <div className="mb-3 flex flex-wrap items-start justify-between gap-3">
              <div className="min-w-0 space-y-1">
                <h2
                  id={headingId}
                  tabIndex={-1}
                  className="flex items-center gap-2 text-lg font-semibold text-fg outline-none"
                >
                  <Icon name={sectionIcon[section]} className="text-fg-muted" />
                  {label}
                </h2>
                <p className="text-sm text-fg-muted">{t('search.results.count', { count })}</p>
              </div>
              {mayHaveMore ? (
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={() => {
                    onShowMore(section);
                  }}
                >
                  {t('search.section.more', { section: label })}
                </Button>
              ) : null}
            </div>
            <ul className="divide-y divide-line">{sectionRows(section, results, results.query)}</ul>
            {scope === section && count >= ONE_SECTION_LIMIT ? (
              <p className="mt-3 text-sm text-fg-muted">
                {t('search.section.limitReached', { count })}
              </p>
            ) : null}
            {section === 'users' ? (
              <p className="mt-3 text-sm text-fg-muted">
                {t('search.users.connectHint')}{' '}
                <TextLink to={withQuery(paths.friends, { tab: 'find' })}>
                  {t('search.users.findLink')}
                </TextLink>
              </p>
            ) : null}
          </section>
        );
      })}
    </div>
  );
}
