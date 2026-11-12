import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { Alert } from '@/shared/components/Alert';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { integrationsApi, useIntegrations } from '../api';
import { integrationErrorMessage } from '../errors';
import { integrationsKeys } from '../keys';

const PROVIDER_ID = /^[a-z0-9_]{1,40}$/;
const STATE = /^[A-Za-z0-9_-]{16,128}$/;

interface ProviderAnswer {
  code: string | null;
  state: string | null;
  /** The provider sent an OAuth `error` (e.g. the user declined). */
  declined: boolean;
}

/** Reads the provider's redirect parameters (the values are kept in memory only). */
function readAnswer(search: string): ProviderAnswer {
  const params = new URLSearchParams(search);
  const code = params.get('code');
  const state = params.get('state');
  return {
    code: code && code.length <= 2048 ? code : null,
    state: state && STATE.test(state) ? state : null,
    declined: params.has('error'),
  };
}

/**
 * Where the provider sends the user back after approving (or declining)
 * access. The page reads `code` and `state` once, removes them from the
 * address bar and history, and asks the API to finish the connection
 * (GET /integrations/{provider}/callback) as the signed-in user who
 * started it. The state is single use, so the request is made only once.
 * Codes and states are never logged, stored or put in query keys.
 */
export function IntegrationCallbackPage() {
  const t = useT();
  useDocumentTitle(t('integrations.callback.title'));
  const params = useParams();
  const provider = params.provider && PROVIDER_ID.test(params.provider) ? params.provider : null;
  const location = useLocation();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [answer] = useState(() => readAnswer(location.search));
  const overview = useIntegrations();
  const providerName =
    overview.data?.providers.find((item) => item.id === provider)?.name ??
    t('integrations.callback.theProvider');

  const complete = useMutation({
    ...sensitiveMutation,
    mutationFn: () =>
      integrationsApi.callback(provider ?? '', answer.state ?? '', answer.code ?? ''),
    onSettled: () => queryClient.invalidateQueries({ queryKey: integrationsKeys.all }),
  });
  const { mutate } = complete;
  const started = useRef(false);
  const ready = Boolean(provider && answer.code && answer.state && !answer.declined);

  useEffect(() => {
    // Drop the one-time values from the URL as soon as they are read.
    if (location.search) {
      void navigate({ pathname: location.pathname, search: '', hash: '' }, { replace: true });
    }
  }, [location.pathname, location.search, navigate]);

  useEffect(() => {
    // The state is single use: call exactly once, even under StrictMode re-runs.
    if (!ready || started.current) return;
    started.current = true;
    mutate();
  }, [ready, mutate]);

  const back = (
    <ButtonLink to={paths.integrations} variant="secondary">
      <Icon name="arrow-left" className="size-4" />
      {t('integrations.callback.back')}
    </ButtonLink>
  );

  let body;
  if (answer.declined) {
    body = (
      <Alert tone="warning" title={t('integrations.callback.declined.title')}>
        {t('integrations.callback.declined.body', { provider: providerName })}
      </Alert>
    );
  } else if (!ready) {
    body = (
      <Alert tone="warning" title={t('integrations.callback.missing.title')}>
        {t('integrations.callback.missing.body')}
      </Alert>
    );
  } else if (complete.isSuccess) {
    body = (
      <Alert
        tone="success"
        live="polite"
        title={t('integrations.callback.success.title', { provider: providerName })}
      >
        {t('integrations.callback.success.body')}
      </Alert>
    );
  } else if (complete.isError && hasErrorCode(complete.error, 'GONE')) {
    body = (
      <Alert tone="warning" live="assertive" title={t('integrations.callback.expired.title')}>
        {t('integrations.callback.expired.body')}
      </Alert>
    );
  } else if (
    complete.isError &&
    (hasErrorCode(complete.error, 'PROVIDER_UNAVAILABLE') ||
      hasErrorCode(complete.error, 'FEATURE_NOT_CONFIGURED'))
  ) {
    body = (
      <Alert tone="danger" live="assertive" title={t('integrations.callback.failed.title')}>
        {integrationErrorMessage(complete.error, t, 'callback')}
      </Alert>
    );
  } else if (complete.isError) {
    body = (
      <ErrorState
        titleAs="h2"
        title={t('integrations.callback.failed.title')}
        description={integrationErrorMessage(complete.error, t, 'callback')}
        error={complete.error}
        retrying={complete.isPending}
        onRetry={() => {
          mutate();
        }}
      />
    );
  } else {
    body = <LoadingState label={t('integrations.callback.pending', { provider: providerName })} />;
  }

  return (
    <>
      <PageHeader title={t('integrations.callback.title')} />
      <Card>
        <div className="space-y-5">
          {body}
          {complete.isPending || (ready && complete.isIdle) ? null : back}
        </div>
      </Card>
    </>
  );
}
