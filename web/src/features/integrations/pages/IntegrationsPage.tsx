import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { useAccounts } from '@/shared/finance/reference';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { useIntegrations } from '../api';
import { ConnectDialog } from '../components/ConnectDialog';
import { ConnectionItem } from '../components/ConnectionItem';
import { DisconnectDialog } from '../components/DisconnectDialog';
import { ProviderItem } from '../components/ProviderItem';
import { integrationErrorMessage } from '../errors';
import type { Connection, Provider } from '../types';

interface Disconnecting {
  connection: Connection;
  mode: 'disconnect' | 'delete-data';
}

/**
 * Connected services (spec §4.18). Montra is manual-first: everything
 * works without connections. Providers show the server's honest status
 * (none is enabled until it is approved and configured); connecting needs
 * explicit consent and happens at the provider, never with bank
 * passwords, PINs, OTPs or CVVs.
 */
export function IntegrationsPage() {
  const t = useT();
  useDocumentTitle(t('integrations.title'));
  const user = useCurrentUser();
  const overview = useIntegrations();
  const accounts = useAccounts(true);
  const [connecting, setConnecting] = useState<Provider | null>(null);
  const [disconnecting, setDisconnecting] = useState<Disconnecting | null>(null);

  const accountNames = new Map((accounts.data ?? []).map((account) => [account.id, account.name]));

  let content;
  if (overview.isPending) {
    content = <LoadingState label={t('integrations.loading')} />;
  } else if (overview.isError) {
    content = hasErrorCode(overview.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('integrations.error')}
        description={integrationErrorMessage(overview.error, t, 'load')}
        error={overview.error}
        retrying={overview.isFetching}
        onRetry={() => {
          void overview.refetch();
        }}
      />
    );
  } else {
    const { providers, connections } = overview.data;
    const providersById = new Map(providers.map((provider) => [provider.id, provider]));
    const anyAvailable = providers.some((provider) => provider.status === 'available');
    content = (
      <div className="space-y-6">
        <Card title={t('integrations.connections.title')}>
          {connections.length === 0 ? (
            <EmptyState
              icon="link"
              title={t('integrations.connections.empty')}
              description={t('integrations.connections.emptyBody')}
              action={
                <ButtonLink to={paths.importNew} variant="secondary">
                  <Icon name="upload" className="size-4" />
                  {t('integrations.importInstead')}
                </ButtonLink>
              }
            />
          ) : (
            <ul className="divide-y divide-line">
              {connections.map((connection) => (
                <ConnectionItem
                  key={connection.id}
                  connection={connection}
                  provider={providersById.get(connection.provider)}
                  accountName={
                    connection.linked_account_id
                      ? (accountNames.get(connection.linked_account_id) ?? null)
                      : null
                  }
                  timeZone={user.timezone}
                  onReconnect={setConnecting}
                  onDisconnect={(item, mode) => {
                    setDisconnecting({ connection: item, mode });
                  }}
                />
              ))}
            </ul>
          )}
        </Card>
        <Card
          title={t('integrations.providers.title')}
          description={
            anyAvailable
              ? t('integrations.providers.description')
              : t('integrations.providers.noneAvailable')
          }
        >
          {providers.length === 0 ? (
            <EmptyState icon="link" title={t('integrations.providers.empty')} />
          ) : (
            <ul className="divide-y divide-line">
              {providers.map((provider) => (
                <ProviderItem key={provider.id} provider={provider} onConnect={setConnecting} />
              ))}
            </ul>
          )}
        </Card>
      </div>
    );
  }

  const disconnectingProvider = disconnecting
    ? overview.data?.providers.find((provider) => provider.id === disconnecting.connection.provider)
    : undefined;

  return (
    <>
      <PageHeader title={t('integrations.title')} description={t('integrations.description')} />
      <Alert tone="info" title={t('integrations.manualFirst.title')} className="mb-6">
        <p>{t('integrations.manualFirst.body')}</p>
        <p>{t('integrations.manualFirst.never')}</p>
      </Alert>
      {content}
      {connecting ? (
        <ConnectDialog
          key={connecting.id}
          provider={connecting}
          onClose={() => {
            setConnecting(null);
          }}
        />
      ) : null}
      {disconnecting ? (
        <DisconnectDialog
          key={`${disconnecting.connection.id}-${disconnecting.mode}`}
          connection={disconnecting.connection}
          mode={disconnecting.mode}
          providerName={disconnectingProvider?.name ?? t('integrations.connection.unknownProvider')}
          onClose={() => {
            setDisconnecting(null);
          }}
        />
      ) : null}
    </>
  );
}
