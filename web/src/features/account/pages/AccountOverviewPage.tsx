import type { ReactNode } from 'react';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextLink } from '@/shared/components/TextLink';
import { paths, withQuery } from '@/shared/config/paths';
import { useCurrencies } from '@/shared/currency/api';
import { currencyName } from '@/shared/currency/currencies';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { localeDisplayName } from '@/shared/formatting/names';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="grid gap-1 py-3 sm:grid-cols-3 sm:gap-4">
      <dt className="text-sm font-medium text-fg-muted">{label}</dt>
      <dd className="text-fg sm:col-span-2">{children}</dd>
    </div>
  );
}

/** Signed-in landing page: the user's own account details, no finance data. */
export function AccountOverviewPage() {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  // Title stays generic: never put names or emails in the tab title.
  useDocumentTitle(t('account.title'));
  const memberSince = parseTimestamp(user.created_at);
  const { data: currencies } = useCurrencies();
  const baseCurrency = currencies?.find((currency) => currency.code === user.base_currency);
  const retiredOn = baseCurrency?.retired_on
    ? parseTimestamp(`${baseCurrency.retired_on}T00:00:00Z`)
    : null;

  return (
    <>
      <PageHeader
        title={t('account.title')}
        description={t('account.greeting', { name: user.display_name })}
      />
      <div className="space-y-6">
        <Card
          title={t('account.profile.title')}
          actions={
            <ButtonLink to={paths.profileSettings} variant="secondary" size="sm">
              {t('account.profile.edit')}
            </ButtonLink>
          }
        >
          <dl className="divide-y divide-line">
            <Fact label={t('account.profile.name')}>{user.display_name}</Fact>
            <Fact label={t('social.username.label')}>
              <span className="flex flex-wrap items-center gap-x-3 gap-y-1">
                {user.username ? (
                  <span className="break-all">@{user.username}</span>
                ) : (
                  <span className="text-fg-muted">{t('social.username.none')}</span>
                )}
                <TextLink to={withQuery(paths.friends, { tab: 'privacy' })}>
                  {user.username ? t('social.username.change') : t('social.username.calloutAction')}
                </TextLink>
              </span>
            </Fact>
            <Fact label={t('account.profile.email')}>
              <span className="flex flex-wrap items-center gap-2 break-all">
                {user.email}
                {user.email_verified ? (
                  <StatusBadge tone="success">{t('account.profile.verified')}</StatusBadge>
                ) : (
                  <StatusBadge tone="warning">{t('account.profile.unverified')}</StatusBadge>
                )}
              </span>
            </Fact>
            {memberSince ? (
              <Fact label={t('account.profile.memberSince')}>
                <time dateTime={user.created_at}>
                  {formatDate(memberSince, formatLocale, user.timezone)}
                </time>
              </Fact>
            ) : null}
          </dl>
        </Card>

        <Card
          title={t('account.preferences.title')}
          description={t('account.preferences.description')}
          actions={
            <ButtonLink to={paths.profileSettings} variant="secondary" size="sm">
              {t('account.preferences.edit')}
            </ButtonLink>
          }
        >
          <dl className="divide-y divide-line">
            <Fact label={t('account.preferences.currency')}>
              <span className="flex flex-wrap items-center gap-2">
                {`${currencyName(user.base_currency, formatLocale, baseCurrency?.name)} (${user.base_currency})`}
                {baseCurrency && !baseCurrency.selectable ? (
                  <StatusBadge tone="warning">
                    {t('account.preferences.currencyRetired')}
                  </StatusBadge>
                ) : null}
              </span>
              {baseCurrency && !baseCurrency.selectable && baseCurrency.replaced_by && retiredOn ? (
                <span className="mt-1 block text-sm text-fg-muted">
                  {t('account.preferences.currencyReplaced', {
                    currency: user.base_currency,
                    replacement: baseCurrency.replaced_by,
                    date: formatDate(retiredOn, formatLocale, 'UTC'),
                  })}
                </span>
              ) : null}
            </Fact>
            <Fact label={t('account.preferences.locale')}>
              {localeDisplayName(user.locale, formatLocale)}
            </Fact>
            <Fact label={t('account.preferences.timezone')}>{user.timezone}</Fact>
          </dl>
        </Card>

        <Card
          title={t('account.security.title')}
          actions={
            <ButtonLink to={paths.securitySettings} variant="secondary" size="sm">
              {t('account.security.manage')}
            </ButtonLink>
          }
        >
          <dl className="divide-y divide-line">
            <Fact label={t('settings.mfa.title')}>
              {user.mfa_enabled ? (
                <StatusBadge tone="success" icon="shield-check">
                  {t('settings.mfa.statusOn')}
                </StatusBadge>
              ) : (
                <StatusBadge tone="warning" icon="shield">
                  {t('settings.mfa.statusOff')}
                </StatusBadge>
              )}
            </Fact>
          </dl>
        </Card>
      </div>
    </>
  );
}
