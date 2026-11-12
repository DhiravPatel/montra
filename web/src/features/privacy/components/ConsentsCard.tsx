import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths } from '@/shared/config/paths';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import { privacyApi } from '../api';
import {
  OPTIONAL_CONSENTS,
  type OptionalConsent,
  REQUIRED_CONSENTS,
  activeConsent,
  consentTitle,
  consentVersion,
} from '../consents';
import { useConsentHistory, useConsents } from '../hooks';
import { privacyKeys } from '../keys';
import type { Consent } from '../types';

/** Where a consent's real control lives, when it is not only this record. */
const relatedLinks: Partial<Record<OptionalConsent['type'], { to: string; label: MessageKey }>> = {
  push_notifications: {
    to: paths.notificationSettings,
    label: 'privacySettings.consent.push_notifications.link',
  },
  contacts_discovery: {
    to: `${paths.friends}?tab=privacy`,
    label: 'privacySettings.consent.contacts_discovery.link',
  },
};

/** GET /legal did not list a version for this consent type, so it cannot be granted. */
class UnknownConsentVersion extends Error {
  constructor() {
    super('No current wording version for this consent.');
    this.name = 'UnknownConsentVersion';
  }
}

function isVersionRefused(error: unknown): boolean {
  return (
    hasErrorCode(error, 'VALIDATION_ERROR') &&
    error.details.some((detail) => detail.field === 'body.version')
  );
}

function changeErrorMessage(error: unknown, give: boolean, t: Translate): string {
  if (error instanceof UnknownConsentVersion) return t('privacySettings.consents.versionUnknown');
  if (give && hasErrorCode(error, 'VALIDATION_ERROR')) {
    if (error.details.some((detail) => detail.field === 'body.version')) {
      return t('privacySettings.consents.versionChanged');
    }
  }
  return describeError(error, t);
}

function ConsentHistory() {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const history = useConsentHistory(true);
  const when = (value: string | undefined) => {
    const date = parseTimestamp(value);
    return date ? formatDateTime(date, formatLocale, user.timezone) : '—';
  };
  if (history.isPending)
    return <LoadingState label={t('privacySettings.consents.historyLoading')} />;
  if (history.isError) {
    return (
      <ErrorState
        titleAs="h3"
        title={t('privacySettings.consents.historyError')}
        error={history.error}
        retrying={history.isFetching}
        onRetry={() => {
          void history.refetch();
        }}
      />
    );
  }
  const rows = [...history.data].sort((a, b) => b.granted_at.localeCompare(a.granted_at));
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-max border-collapse text-sm">
        <caption className="sr-only">{t('privacySettings.consents.historyTitle')}</caption>
        <thead>
          <tr className="border-b border-line text-start">
            <th scope="col" className="py-2 pe-4 text-start font-medium text-fg-muted">
              {t('privacySettings.consents.historyConsent')}
            </th>
            <th scope="col" className="py-2 pe-4 text-start font-medium text-fg-muted">
              {t('privacySettings.consents.historyGiven')}
            </th>
            <th scope="col" className="py-2 pe-4 text-start font-medium text-fg-muted">
              {t('privacySettings.consents.historyWithdrawn')}
            </th>
            <th scope="col" className="py-2 pe-4 text-start font-medium text-fg-muted">
              {t('privacySettings.consents.historyVersion')}
            </th>
          </tr>
        </thead>
        <tbody>
          {rows.map((consent) => (
            <tr key={consent.id} className="border-b border-line last:border-b-0">
              <th scope="row" className="py-2 pe-4 text-start font-normal text-fg">
                {t(consentTitle(consent.consent_type))}
              </th>
              <td className="py-2 pe-4 text-fg">{when(consent.granted_at)}</td>
              <td className="py-2 pe-4 text-fg">
                {consent.revoked_at
                  ? when(consent.revoked_at)
                  : t('privacySettings.consents.stillOn')}
              </td>
              <td className="py-2 pe-4 font-mono text-fg-muted">{consent.version}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

interface ConsentRowProps {
  consent: OptionalConsent;
  active: Consent | undefined;
  pending: boolean;
  onChange: (consent: OptionalConsent, give: boolean) => void;
}

function ConsentRow({ consent, active, pending, onChange }: ConsentRowProps) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const granted = parseTimestamp(active?.granted_at);
  const title = t(consent.title);
  const action = active
    ? t('privacySettings.consents.withdraw')
    : t('privacySettings.consents.give');
  const link = relatedLinks[consent.type];
  return (
    <li className="flex flex-col gap-3 py-5 first:pt-0 last:pb-0 sm:flex-row sm:items-start sm:justify-between">
      <div className="min-w-0 space-y-1.5">
        <div className="flex flex-wrap items-center gap-2">
          <h3 className="font-semibold text-fg">{title}</h3>
          {active ? (
            <StatusBadge tone="success" icon="check-circle">
              {t('privacySettings.consents.on')}
            </StatusBadge>
          ) : (
            <StatusBadge tone="neutral" icon="x-circle">
              {t('privacySettings.consents.off')}
            </StatusBadge>
          )}
        </div>
        <p className="text-sm text-fg">{t(consent.body)}</p>
        <p className="text-sm text-fg-muted">{t(consent.whenOff)}</p>
        {consent.grantable ? null : (
          <p className="text-sm text-fg-muted">{t('privacySettings.consents.otherApp')}</p>
        )}
        {link ? (
          <p className="text-sm">
            <TextLink to={link.to}>{t(link.label)}</TextLink>
          </p>
        ) : null}
        {active && granted ? (
          <p className="text-xs text-fg-muted">
            {t('privacySettings.consents.givenOn', {
              date: formatDateTime(granted, formatLocale, user.timezone),
              version: active.version,
            })}
          </p>
        ) : null}
      </div>
      <Button
        variant="secondary"
        size="sm"
        className="shrink-0"
        loading={pending}
        aria-label={`${action}: ${title}`}
        onClick={() => {
          onChange(consent, !active);
        }}
      >
        {action}
      </Button>
    </li>
  );
}

/** Optional processing the user can allow or withdraw, plus the consents needed to use Montra. */
export function ConsentsCard() {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const consents = useConsents();
  const historyId = useId();
  const [showHistory, setShowHistory] = useState(false);

  const change = useMutation({
    mutationFn: async ({ consent, give }: { consent: OptionalConsent; give: boolean }) => {
      if (give) {
        // The API accepts only the current wording version, which GET /legal publishes.
        const legal = await queryClient.query({
          queryKey: privacyKeys.legal(),
          queryFn: ({ signal }) => privacyApi.legal(signal),
          staleTime: 10 * 60_000,
        });
        const version = consentVersion(legal, consent.type);
        if (!version) throw new UnknownConsentVersion();
        await privacyApi.grant({ consent_type: consent.type, version });
      } else {
        await privacyApi.revoke(consent.type);
      }
    },
    onError: (error) => {
      // The wording changed since it was loaded: the next try reads the new version.
      if (isVersionRefused(error))
        void queryClient.invalidateQueries({ queryKey: privacyKeys.legal() });
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: privacyKeys.consents() }),
  });

  const onChange = (consent: OptionalConsent, give: boolean) => {
    if (change.isPending) return;
    const name = t(consent.title);
    change.mutate(
      { consent, give },
      {
        onSuccess: () => {
          toast.show({
            tone: 'success',
            title: give
              ? t('privacySettings.consents.given', { name })
              : t('privacySettings.consents.withdrawn', { name }),
          });
        },
        onError: (error) => {
          if (!give && hasErrorCode(error, 'NOT_FOUND')) {
            // Already withdrawn (perhaps in another tab): the list reloads.
            toast.show({ tone: 'info', title: t('privacySettings.consents.alreadyOff', { name }) });
            return;
          }
          toast.show({
            tone: 'danger',
            title: t('privacySettings.consents.failed', { name }),
            description: changeErrorMessage(error, give, t),
          });
        },
      },
    );
  };

  let content;
  if (consents.isPending) {
    content = <LoadingState label={t('privacySettings.consents.loading')} />;
  } else if (consents.isError) {
    content = hasErrorCode(consents.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="h3" />
    ) : (
      <ErrorState
        titleAs="h3"
        title={t('privacySettings.consents.error')}
        error={consents.error}
        retrying={consents.isFetching}
        onRetry={() => {
          void consents.refetch();
        }}
      />
    );
  } else {
    const list = consents.data;
    // AI consents can only be withdrawn here, so they are listed only while given.
    const shown = OPTIONAL_CONSENTS.filter(
      (consent) => consent.grantable || activeConsent(list, consent.type),
    );
    const pendingType = change.isPending ? change.variables.consent.type : null;
    content = (
      <div className="space-y-6">
        <ul className="divide-y divide-line">
          {shown.map((consent) => (
            <ConsentRow
              key={consent.type}
              consent={consent}
              active={activeConsent(list, consent.type)}
              pending={pendingType === consent.type}
              onChange={onChange}
            />
          ))}
        </ul>
        <div className="space-y-3 border-t border-line pt-5">
          <h3 className="font-semibold text-fg">{t('privacySettings.consents.requiredTitle')}</h3>
          <ul className="space-y-2 text-sm">
            {REQUIRED_CONSENTS.map((type) => {
              const accepted = activeConsent(list, type);
              const date = parseTimestamp(accepted?.granted_at);
              return (
                <li key={type} className="flex flex-wrap items-center gap-x-2 gap-y-1">
                  <TextLink to={type === 'terms' ? paths.terms : paths.privacy}>
                    {t(consentTitle(type))}
                  </TextLink>
                  <span className="text-fg-muted">
                    {accepted && date
                      ? t('privacySettings.consents.accepted', {
                          date: formatDateTime(date, formatLocale, user.timezone),
                          version: accepted.version,
                        })
                      : t('privacySettings.consents.notRecorded')}
                  </span>
                </li>
              );
            })}
          </ul>
          <p className="text-sm text-fg-muted">{t('privacySettings.consents.requiredBody')}</p>
        </div>
      </div>
    );
  }

  return (
    <Card
      title={t('privacySettings.consents.title')}
      description={t('privacySettings.consents.description')}
    >
      {content}
      <div className="mt-6 border-t border-line pt-4">
        <Button
          variant="ghost"
          size="sm"
          aria-expanded={showHistory}
          aria-controls={historyId}
          onClick={() => {
            setShowHistory((value) => !value);
          }}
        >
          <Icon name="history" className="size-4" />
          {showHistory
            ? t('privacySettings.consents.hideHistory')
            : t('privacySettings.consents.showHistory')}
        </Button>
        <div id={historyId} hidden={!showHistory} className="mt-3">
          {showHistory ? <ConsentHistory /> : null}
        </div>
      </div>
    </Card>
  );
}
