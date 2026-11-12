import { useMutation } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { paths } from '@/shared/config/paths';
import { domainRuleCode } from '@/shared/finance/domainErrors';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { notificationsApi } from '../api';
import { categoryLabelKey } from '../categories';
import { clearUrlFragment, previewCategory, readUnsubscribeToken } from '../unsubscribeToken';

/** Expired, tampered or malformed links: the server answers 410 (or 422 for the token's shape). */
function isUnusableLink(error: unknown): boolean {
  return hasErrorCode(error, 'GONE') || hasErrorCode(error, 'VALIDATION_ERROR');
}

/**
 * Public page behind the "unsubscribe" link in optional emails. Works
 * signed out: it reads the signed token from the URL fragment once, clears
 * the fragment, says which emails it will turn off, and only posts the
 * token after the user confirms (so link scanners cannot unsubscribe
 * anyone). Security and account emails cannot be turned off.
 */
export function UnsubscribePage() {
  const t = useT();
  useDocumentTitle(t('notifications.unsubscribe.title'));
  // Reading is pure, so React's double render in development sees the same token.
  const [token] = useState(() => readUnsubscribeToken(window.location.hash));
  useEffect(() => {
    clearUrlFragment();
  }, []);
  const preview = token ? previewCategory(token) : null;
  const unsubscribe = useMutation({
    ...sensitiveMutation,
    mutationFn: notificationsApi.unsubscribe,
  });

  const confirm = () => {
    if (!token || unsubscribe.isPending) return;
    unsubscribe.mutate(token);
  };

  const settingsLink = (
    <ButtonLink to={paths.notificationSettings} variant="secondary" className="w-full">
      <Icon name="sliders" className="size-4" />
      {t('notifications.unsubscribe.manage')}
    </ButtonLink>
  );

  let body;
  if (!token) {
    body = (
      <div className="space-y-5">
        <Alert tone="warning" title={t('notifications.unsubscribe.missing.title')}>
          {t('notifications.unsubscribe.missing.body')}
        </Alert>
        {settingsLink}
      </div>
    );
  } else if (unsubscribe.isSuccess) {
    const category = t(categoryLabelKey(unsubscribe.data.category));
    body = (
      <div className="space-y-5">
        <Alert tone="success" live="polite" title={t('notifications.unsubscribe.done.title')}>
          <p>{t('notifications.unsubscribe.done.body', { category })}</p>
          <p>{t('notifications.unsubscribe.stillSent')}</p>
        </Alert>
        {settingsLink}
      </div>
    );
  } else if (unsubscribe.isError && isUnusableLink(unsubscribe.error)) {
    body = (
      <div className="space-y-5">
        <Alert tone="warning" live="assertive" title={t('notifications.unsubscribe.invalid.title')}>
          {t('notifications.unsubscribe.invalid.body')}
        </Alert>
        {settingsLink}
      </div>
    );
  } else if (
    unsubscribe.isError &&
    domainRuleCode(unsubscribe.error)?.code === 'always_on_category'
  ) {
    body = (
      <div className="space-y-5">
        <Alert tone="info" live="assertive" title={t('notifications.unsubscribe.alwaysOn.title')}>
          {t('notifications.unsubscribe.alwaysOn.body')}
        </Alert>
        {settingsLink}
      </div>
    );
  } else {
    body = (
      <div className="space-y-5">
        {unsubscribe.isError ? (
          <Alert tone="danger" live="assertive" title={t('notifications.unsubscribe.failed')}>
            {describeError(unsubscribe.error, t)}
          </Alert>
        ) : null}
        <p className="text-fg">
          {preview
            ? t('notifications.unsubscribe.confirm.category', {
                category: t(categoryLabelKey(preview)),
              })
            : t('notifications.unsubscribe.confirm.generic')}
        </p>
        <p className="text-sm text-fg-muted">{t('notifications.unsubscribe.stillSent')}</p>
        <Button className="w-full" loading={unsubscribe.isPending} onClick={confirm}>
          <Icon name="bell-off" className="size-4" />
          {t('notifications.unsubscribe.confirm.action')}
        </Button>
        {settingsLink}
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-md px-4 py-10 sm:py-16">
      <div className="rounded-xl border border-line bg-surface p-6 shadow-card sm:p-8">
        <h1
          tabIndex={-1}
          data-page-heading=""
          className="text-2xl font-semibold tracking-tight text-fg outline-none"
        >
          {t('notifications.unsubscribe.title')}
        </h1>
        <div className="mt-6">{body}</div>
      </div>
    </div>
  );
}
