import { Button, ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { ResendVerification } from './ResendVerification';

interface CheckEmailPanelProps {
  email: string;
  onUseDifferentEmail: () => void;
}

/** Shown after registration (the API always answers 202, whether or not the email is new). */
export function CheckEmailPanel({ email, onUseDifferentEmail }: CheckEmailPanelProps) {
  const t = useT();
  return (
    <div className="space-y-5">
      <div className="flex gap-3 rounded-lg border border-info/40 bg-info-soft p-4 text-sm text-fg">
        <Icon name="mail" className="mt-0.5 text-info" />
        <div className="space-y-2">
          <p>{t('auth.checkEmail.body', { email })}</p>
          <p className="text-fg-muted">{t('auth.checkEmail.expiry')}</p>
        </div>
      </div>
      <div className="space-y-2">
        <p className="text-sm text-fg-muted">{t('auth.checkEmail.noEmail')}</p>
        <ResendVerification email={email} />
      </div>
      <div className="flex flex-wrap gap-3 border-t border-line pt-5">
        <ButtonLink to={paths.signIn}>{t('auth.checkEmail.signIn')}</ButtonLink>
        <Button variant="ghost" onClick={onUseDifferentEmail}>
          {t('auth.checkEmail.differentEmail')}
        </Button>
      </div>
    </div>
  );
}
