import type { ReactNode } from 'react';
import { appConfig } from '@/shared/config/env';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { isApiError } from '@/shared/api/errors';
import { cx } from '@/shared/utils/cx';
import { Button } from './Button';
import { Icon, type IconName } from './Icon';
import { Spinner } from './Spinner';
import { ExternalLink } from './TextLink';

type HeadingTag = 'h2' | 'h3' | 'p';

interface StateFrameProps {
  icon: IconName;
  iconClassName?: string;
  title: string;
  titleAs?: HeadingTag;
  description?: ReactNode;
  children?: ReactNode;
  className?: string;
  role?: 'alert' | 'status';
}

function StateFrame({
  icon,
  iconClassName,
  title,
  titleAs = 'h3',
  description,
  children,
  className,
  role,
}: StateFrameProps) {
  const Title = titleAs;
  return (
    <div role={role} className={cx('flex flex-col items-center px-4 py-10 text-center', className)}>
      <span
        className={cx(
          'mb-3 inline-flex size-12 items-center justify-center rounded-full bg-surface-muted',
          iconClassName,
        )}
      >
        <Icon name={icon} className="size-6" />
      </span>
      <Title className="text-base font-semibold text-fg">{title}</Title>
      {description ? (
        <div className="mt-1 max-w-md text-sm text-fg-muted">{description}</div>
      ) : null}
      {children ? <div className="mt-5 flex flex-wrap justify-center gap-3">{children}</div> : null}
    </div>
  );
}

/** Loading placeholder. Pass skeleton children to keep layout stable. */
export function LoadingState({
  label,
  children,
  className,
}: {
  label?: string;
  children?: ReactNode;
  className?: string;
}) {
  const t = useT();
  const text = label ?? t('common.loading');
  if (children) {
    return (
      <div role="status" aria-busy="true" className={className}>
        <span className="sr-only">{text}</span>
        {children}
      </div>
    );
  }
  return (
    <div
      role="status"
      className={cx('flex items-center justify-center gap-3 py-10 text-fg-muted', className)}
    >
      <Spinner />
      <span>{text}</span>
    </div>
  );
}

interface EmptyStateProps {
  title: string;
  description?: ReactNode;
  icon?: IconName;
  action?: ReactNode;
  titleAs?: HeadingTag;
}

export function EmptyState({
  title,
  description,
  icon = 'inbox',
  action,
  titleAs,
}: EmptyStateProps) {
  return (
    <StateFrame
      icon={icon}
      title={title}
      titleAs={titleAs}
      description={description}
      iconClassName="text-fg-muted"
    >
      {action}
    </StateFrame>
  );
}

interface ErrorStateProps {
  title?: string;
  /** The failure; its message and request ID are shown. */
  error?: unknown;
  description?: ReactNode;
  onRetry?: () => void;
  retrying?: boolean;
  titleAs?: HeadingTag;
}

/** Recoverable error with retry and the request reference for support. */
export function ErrorState({
  title,
  error,
  description,
  onRetry,
  retrying = false,
  titleAs,
}: ErrorStateProps) {
  const t = useT();
  const requestId = isApiError(error) ? error.requestId : null;
  return (
    <StateFrame
      role="alert"
      icon="alert-triangle"
      iconClassName="bg-danger-soft text-danger"
      title={title ?? t('states.error.title')}
      titleAs={titleAs}
      description={
        <>
          <p>{description ?? describeError(error, t)}</p>
          {requestId ? (
            <p className="mt-2 text-xs">
              {t('common.requestReference')}{' '}
              <code className="font-mono select-all">{requestId}</code>
            </p>
          ) : null}
        </>
      }
    >
      {onRetry ? (
        <Button variant="secondary" onClick={onRetry} loading={retrying}>
          <Icon name="refresh" className="size-4" />
          {t('common.retry')}
        </Button>
      ) : null}
    </StateFrame>
  );
}

export function PermissionDenied({
  title,
  description,
  titleAs,
}: {
  title?: string;
  description?: ReactNode;
  titleAs?: HeadingTag;
}) {
  const t = useT();
  return (
    <StateFrame
      icon="lock"
      iconClassName="text-fg-muted"
      title={title ?? t('states.permissionDenied.title')}
      titleAs={titleAs}
      description={
        description ?? (
          <p>
            {t('states.permissionDenied.description')}{' '}
            <ExternalLink href={`mailto:${appConfig.supportEmail}`}>
              {appConfig.supportEmail}
            </ExternalLink>
          </p>
        )
      }
    />
  );
}
