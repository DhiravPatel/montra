import { Alert } from '@/shared/components/Alert';
import { useT } from '@/shared/i18n/I18nContext';

/** Shown above every support form: Montra never needs payment secrets. */
export function SafetyNotice() {
  const t = useT();
  return (
    <Alert tone="warning" title={t('support.safety.title')}>
      <p>{t('support.safety.body')}</p>
    </Alert>
  );
}
