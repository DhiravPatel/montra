import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { useI18n } from '@/shared/i18n/I18nContext';
import { dataLabelKey, providerKindLabel, providerStatusLook } from '../labels';
import type { Provider } from '../types';

interface ProviderItemProps {
  provider: Provider;
  onConnect: (provider: Provider) => void;
}

/** A country's name in the interface language ("IN" → "India"); the code if unknown. */
function regionName(code: string, lang: string): string {
  try {
    return new Intl.DisplayNames([lang], { type: 'region' }).of(code) ?? code;
  } catch {
    return code;
  }
}

/**
 * A provider from the registry with its status exactly as the server
 * reports it. Only `available` providers can be connected; the others say
 * why they are not offered (and are never presented as working).
 */
export function ProviderItem({ provider, onConnect }: ProviderItemProps) {
  const { t, lang } = useI18n();
  const look = providerStatusLook[provider.status];
  const capabilities = provider.capabilities
    .map((item) => dataLabelKey(item))
    .filter((key) => key !== null)
    .map((key) => t(key));
  const countries = provider.countries.map((code) => regionName(code, lang));

  return (
    <li className="flex flex-col gap-3 py-5 first:pt-0 last:pb-0 sm:flex-row sm:items-start sm:justify-between">
      <div className="min-w-0 space-y-1">
        <div className="flex flex-wrap items-center gap-2">
          <h3 className="text-base font-semibold text-fg">{provider.name}</h3>
          <StatusBadge tone={look.tone} icon={look.icon}>
            {t(look.label)}
          </StatusBadge>
        </div>
        <p className="text-sm text-fg-muted">
          {[t(providerKindLabel[provider.kind]), countries.join(', ')].filter(Boolean).join(' · ')}
        </p>
        {capabilities.length > 0 ? (
          <p className="text-sm text-fg-muted">
            {t('integrations.provider.reads', { data: capabilities.join(', ') })}
          </p>
        ) : null}
        {provider.status === 'available' ? null : (
          <p className="text-sm text-fg">
            {provider.status === 'not_configured'
              ? t('integrations.provider.notConfiguredHelp')
              : t('integrations.provider.unavailableHelp')}
            {provider.status_reason ? (
              <>
                {' '}
                <span lang={lang === 'en' ? undefined : 'en'}>{provider.status_reason}</span>
              </>
            ) : null}
          </p>
        )}
      </div>
      {provider.status === 'available' ? (
        <Button
          className="shrink-0"
          aria-label={`${t('integrations.provider.connect')}: ${provider.name}`}
          onClick={() => {
            onConnect(provider);
          }}
        >
          <Icon name="link" className="size-4" />
          {t('integrations.provider.connect')}
        </Button>
      ) : null}
    </li>
  );
}
