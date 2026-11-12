import { useState } from 'react';
import { Alert } from '@/shared/components/Alert';
import { ButtonLink } from '@/shared/components/Button';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { authApi } from '../api';
import { AuthCard } from '../components/AuthCard';
import { EmailRequestForm } from '../components/EmailRequestForm';

export function ForgotPasswordPage() {
  const t = useT();
  const [sentTo, setSentTo] = useState<string | null>(null);
  useDocumentTitle(t('auth.forgot.title'));

  return (
    <AuthCard
      title={t('auth.forgot.title')}
      description={sentTo ? undefined : t('auth.forgot.description')}
      footer={
        <p>
          <TextLink to={paths.signIn}>{t('auth.forgot.backToSignIn')}</TextLink>
        </p>
      }
    >
      {sentTo ? (
        <div className="space-y-5">
          {/* Same message whether or not the account exists (no enumeration). */}
          <Alert tone="info" live="polite" title={t('auth.forgot.sent.title')}>
            <p>{t('auth.forgot.sent.body', { email: sentTo })}</p>
            <p>{t('auth.forgot.sent.expiry')}</p>
          </Alert>
          <ButtonLink to={paths.signIn} variant="secondary" className="w-full">
            {t('auth.forgot.backToSignIn')}
          </ButtonLink>
        </div>
      ) : (
        <EmailRequestForm
          submitLabel={t('auth.forgot.submit')}
          onRequest={authApi.requestPasswordReset}
          onAccepted={setSentTo}
        />
      )}
    </AuthCard>
  );
}
