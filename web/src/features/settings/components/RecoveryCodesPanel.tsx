import { useState } from 'react';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { CopyButton } from '@/shared/components/CopyButton';
import { Icon } from '@/shared/components/Icon';
import { formatDateTime } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { downloadTextFile } from '@/shared/utils/clipboard';

interface RecoveryCodesPanelProps {
  codes: readonly string[];
  context: 'enabled' | 'regenerated';
  onDone: () => void;
}

/** Recovery codes are shown exactly once; the user confirms they saved them. */
export function RecoveryCodesPanel({ codes, context, onDone }: RecoveryCodesPanelProps) {
  const { t, formatLocale } = useI18n();
  const [saved, setSaved] = useState(false);

  if (codes.length === 0) {
    return (
      <Alert tone="danger" live="assertive" title={t('settings.mfa.codes.missing')}>
        <Button variant="secondary" onClick={onDone}>
          {t('common.close')}
        </Button>
      </Alert>
    );
  }

  const fileText = [
    t('settings.mfa.codes.fileHeading'),
    t('settings.mfa.codes.fileGenerated', { date: formatDateTime(new Date(), formatLocale) }),
    '',
    ...codes.map((code, index) => `${index + 1}. ${code}`),
    '',
    t('settings.mfa.codes.fileFooter'),
  ].join('\n');

  return (
    <div className="space-y-5">
      {context === 'enabled' ? (
        <Alert tone="success" live="polite" title={t('settings.mfa.enabled.title')}>
          {t('settings.mfa.enabled.body')}
        </Alert>
      ) : null}
      <Alert tone="warning" title={t('settings.mfa.codes.title')}>
        {t('settings.mfa.codes.body')}
      </Alert>
      <ol className="grid gap-2 rounded-lg border border-line bg-surface-muted p-4 font-mono text-sm text-fg sm:grid-cols-2">
        {codes.map((code) => (
          <li key={code} className="select-all tracking-wider">
            {code}
          </li>
        ))}
      </ol>
      <div className="flex flex-wrap gap-3">
        <CopyButton value={codes.join('\n')} label={t('settings.mfa.codes.copy')} />
        <Button
          variant="secondary"
          size="sm"
          onClick={() => {
            downloadTextFile('montra-recovery-codes.txt', fileText);
          }}
        >
          <Icon name="download" className="size-4" />
          {t('settings.mfa.codes.download')}
        </Button>
      </div>
      <Checkbox
        label={t('settings.mfa.codes.confirmSaved')}
        checked={saved}
        onChange={(event) => {
          setSaved(event.currentTarget.checked);
        }}
      />
      <Button disabled={!saved} onClick={onDone}>
        {t('settings.mfa.codes.done')}
      </Button>
    </div>
  );
}
