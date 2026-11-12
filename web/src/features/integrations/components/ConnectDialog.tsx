import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useId, useState } from 'react';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Dialog } from '@/shared/components/Dialog';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { useAccounts, writableAccounts } from '@/shared/finance/reference';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useI18n } from '@/shared/i18n/I18nContext';
import { browserNavigation, integrationsApi, isSafeProviderUrl } from '../api';
import { integrationErrorMessage } from '../errors';
import { integrationsKeys } from '../keys';
import { dataLabelKey } from '../labels';
import type { Provider } from '../types';

interface ConnectDialogProps {
  provider: Provider;
  onClose: () => void;
}

/**
 * Consent before connecting: what Montra will read, why and for how long,
 * what it never asks for, and which Montra account to fill. Continuing
 * records the consent and opens the provider's own approval page; Montra
 * never sees bank passwords, PINs, OTPs or CVVs.
 */
export function ConnectDialog({ provider, onClose }: ConnectDialogProps) {
  const { t, lang } = useI18n();
  const queryClient = useQueryClient();
  const accounts = useAccounts();
  const choices = writableAccounts(accounts.data);
  const [accountId, setAccountId] = useState('');
  const [agreed, setAgreed] = useState(false);
  const [fieldErrors, setFieldErrors] = useState<{ account?: string; consent?: string }>({});
  const [error, setError] = useState<string | null>(null);
  const [redirecting, setRedirecting] = useState(false);
  const consentHeadingId = useId();
  const connect = useMutation({
    mutationFn: (account: string) => integrationsApi.connect(provider.id, account),
    onSettled: () => queryClient.invalidateQueries({ queryKey: integrationsKeys.overview() }),
  });
  const busy = connect.isPending || redirecting;
  // Server-provided consent text is English; mark it so screen readers pronounce it right.
  const serverLang = lang === 'en' ? undefined : 'en';
  const scope = provider.consent_scope.map((item) => {
    const key = dataLabelKey(item);
    return key ? t(key) : item;
  });

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (busy) return;
    const next: { account?: string; consent?: string } = {};
    if (!accountId) next.account = t('integrations.connect.accountRequired');
    if (!agreed) next.consent = t('integrations.connect.consentRequired');
    setFieldErrors(next);
    if (next.account || next.consent) return;
    setError(null);
    connect.mutate(accountId, {
      onSuccess: (result) => {
        if (!isSafeProviderUrl(result.authorize_url)) {
          setError(t('integrations.connect.badRedirect'));
          return;
        }
        setRedirecting(true);
        browserNavigation.assign(result.authorize_url);
      },
      onError: (failure) => {
        setError(integrationErrorMessage(failure, t, 'connect'));
      },
    });
  };

  return (
    <Dialog
      open
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
      title={t('integrations.connect.title', { provider: provider.name })}
      description={t('integrations.connect.description', { provider: provider.name })}
      busy={busy}
      size="lg"
    >
      <form noValidate onSubmit={submit} className="space-y-5">
        <FormAlert message={error} />
        <section aria-labelledby={consentHeadingId} className="space-y-3">
          <h3 id={consentHeadingId} className="text-sm font-semibold text-fg">
            {t('integrations.connect.consentHeading')}
          </h3>
          <dl className="space-y-3 text-sm">
            <div>
              <dt className="font-medium text-fg">{t('integrations.connect.purpose')}</dt>
              <dd className="text-fg-muted" lang={serverLang}>
                {provider.consent_purpose}
              </dd>
            </div>
            <div>
              <dt className="font-medium text-fg">{t('integrations.connect.shared')}</dt>
              <dd className="text-fg-muted">
                <ul className="list-inside list-disc">
                  {scope.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              </dd>
            </div>
            <div>
              <dt className="font-medium text-fg">{t('integrations.connect.duration')}</dt>
              <dd className="text-fg-muted">
                {t('integrations.connect.days', { count: provider.consent_days })}
              </dd>
            </div>
          </dl>
        </section>
        <Alert tone="info" title={t('integrations.connect.neverTitle')}>
          <ul className="list-inside list-disc space-y-1">
            <li>{t('integrations.connect.neverCredentials', { provider: provider.name })}</li>
            <li>{t('integrations.connect.neverPayments')}</li>
            <li>{t('integrations.connect.disconnectAnyTime')}</li>
          </ul>
        </Alert>
        {accounts.isPending ? (
          <p role="status" className="text-sm text-fg-muted">
            {t('integrations.connect.loadingAccounts')}
          </p>
        ) : choices.length === 0 ? (
          <Alert tone="warning" title={t('integrations.connect.noAccount.title')}>
            <p>{t('integrations.connect.noAccount.body')}</p>
            <TextLink to={paths.accountNew}>{t('integrations.connect.noAccount.action')}</TextLink>
          </Alert>
        ) : (
          <Select
            label={t('integrations.connect.account')}
            help={t('integrations.connect.accountHelp', { provider: provider.name })}
            placeholder={t('integrations.connect.accountPlaceholder')}
            value={accountId}
            error={fieldErrors.account}
            disabled={busy}
            options={choices.map((account) => ({
              value: account.id,
              label: `${account.name} (${account.currency})`,
            }))}
            onChange={(event) => {
              setAccountId(event.target.value);
            }}
          />
        )}
        <Checkbox
          label={t('integrations.connect.agree', {
            provider: provider.name,
            data: scope.join(', '),
            count: provider.consent_days,
          })}
          checked={agreed}
          error={fieldErrors.consent}
          disabled={busy}
          onChange={(event) => {
            setAgreed(event.target.checked);
          }}
        />
        {redirecting ? (
          <p role="status" className="text-sm text-fg-muted">
            {t('integrations.connect.redirecting', { provider: provider.name })}
          </p>
        ) : null}
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button variant="secondary" disabled={busy} onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" loading={busy} disabled={choices.length === 0}>
            <Icon name="external-link" className="size-4" />
            {t('integrations.connect.continue', { provider: provider.name })}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
