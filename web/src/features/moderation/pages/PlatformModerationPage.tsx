import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { PermissionDenied } from '@/shared/components/states';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { type ActionTarget, ActionDialog } from '../components/staff/ActionDialog';
import { ActionsListCard } from '../components/staff/ActionsListCard';
import { AppealsQueue } from '../components/staff/AppealsQueue';
import { DecideDialog } from '../components/staff/DecideDialog';
import { ReportsQueue } from '../components/staff/ReportsQueue';
import { ReverseDialog } from '../components/staff/ReverseDialog';
import { useStaffAppeals, useStaffReports } from '../hooks';
import type { ModerationAppeal, QueueStatus } from '../types';

/**
 * Platform moderation for Montra support and admin staff: the report
 * queue, actions (confirmed and audited), reversals and appeal decisions.
 * Shows only what the API returns; the server decides who may use it.
 */
export function PlatformModerationPage() {
  const t = useT();
  useDocumentTitle(t('moderation.staff.title'));
  const user = useCurrentUser();
  const [status, setStatus] = useState<QueueStatus>('open');
  const reports = useStaffReports(status);
  const appeals = useStaffAppeals();
  const [actOpen, setActOpen] = useState(false);
  const [target, setTarget] = useState<ActionTarget | null>(null);
  const [reverseId, setReverseId] = useState<string | null>(null);
  const [deciding, setDeciding] = useState<ModerationAppeal | null>(null);
  const forbidden =
    hasErrorCode(reports.error, 'FORBIDDEN') || hasErrorCode(appeals.error, 'FORBIDDEN');

  const openAction = (next: ActionTarget | null) => {
    setTarget(next);
    setActOpen(true);
  };

  if (forbidden) {
    return (
      <>
        <PageHeader title={t('moderation.staff.title')} />
        <PermissionDenied titleAs="h2" description={t('moderation.staff.forbidden')} />
      </>
    );
  }

  return (
    <>
      <PageHeader
        title={t('moderation.staff.title')}
        description={t('moderation.staff.description')}
        actions={
          <Button
            onClick={() => {
              openAction(null);
            }}
          >
            <Icon name="shield" className="size-4" />
            {t('moderation.staff.newAction')}
          </Button>
        }
      />
      <Alert tone="info" className="mb-6" title={t('moderation.staff.audit.title')}>
        {t('moderation.staff.audit.body')}
      </Alert>
      <div className="grid gap-6 xl:grid-cols-3">
        <div className="space-y-6 xl:col-span-2">
          <ReportsQueue
            status={status}
            onStatusChange={setStatus}
            timeZone={user.timezone}
            onAct={openAction}
          />
          <ActionsListCard timeZone={user.timezone} onReverse={setReverseId} />
        </div>
        <div className="space-y-6">
          <AppealsQueue timeZone={user.timezone} onDecide={setDeciding} />
        </div>
      </div>
      <ActionDialog
        open={actOpen}
        target={target}
        onOpenChange={(open) => {
          setActOpen(open);
          if (!open) setTarget(null);
        }}
      />
      <ReverseDialog
        actionId={reverseId}
        open={reverseId !== null}
        onOpenChange={(open) => {
          if (!open) setReverseId(null);
        }}
      />
      <DecideDialog
        appeal={deciding}
        open={deciding !== null}
        onOpenChange={(open) => {
          if (!open) setDeciding(null);
        }}
      />
    </>
  );
}
