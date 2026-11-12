import { useState } from 'react';
import { useLocation } from 'react-router';
import { Alert } from '@/shared/components/Alert';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { supportRequestPath } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { HelpTopics } from '../components/HelpTopics';
import { MyRequestsList } from '../components/MyRequestsList';
import { NewRequestForm } from '../components/NewRequestForm';
import type { SupportRequest } from '../types';

/** Router state a request page passes to start a follow-up (never put in the URL). */
export interface HelpLocationState {
  followUp?: string;
}

const REFERENCE = /^[A-F0-9]{8}$/;

function followUpReference(state: unknown): string | null {
  if (typeof state !== 'object' || state === null) return null;
  const value = (state as HelpLocationState).followUp;
  return typeof value === 'string' && REFERENCE.test(value) ? value : null;
}

/** Help topics, the user's support requests and a privacy-safe way to contact support. */
export function HelpPage() {
  const t = useT();
  useDocumentTitle(t('support.title'));
  const toast = useToast();
  const location = useLocation();
  const followUp = followUpReference(location.state);
  const [sent, setSent] = useState<SupportRequest | null>(null);

  const onCreated = (request: SupportRequest) => {
    setSent(request);
    toast.show({
      tone: 'success',
      title: t('support.sent.title'),
      description: t('support.reference', { reference: request.reference }),
    });
  };

  return (
    <>
      <PageHeader title={t('support.title')} description={t('support.description')} />
      <div className="space-y-6">
        <HelpTopics />
        <div className="grid gap-6 lg:grid-cols-2 lg:items-start">
          <Card title={t('support.form.title')} description={t('support.form.description')}>
            {sent ? (
              <Alert tone="success" title={t('support.sent.title')} className="mb-5">
                <p>{t('support.sent.body', { reference: sent.reference })}</p>
                <p>
                  <TextLink to={supportRequestPath(sent.id)}>{t('support.sent.view')}</TextLink>
                </p>
              </Alert>
            ) : null}
            <NewRequestForm
              initialSubject={
                followUp ? t('support.form.followUpSubject', { reference: followUp }) : ''
              }
              onCreated={onCreated}
            />
          </Card>
          <MyRequestsList />
        </div>
      </div>
    </>
  );
}
