import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { RefreshFailed } from '@/features/analytics/components/Blocks';
import { reportsApi, useSchedules } from '../api';
import { reportsKeys } from '../keys';
import {
  cadenceLabel,
  formatLabel,
  isReportFormat,
  isReportType,
  reportTypeLabel,
} from '../labels';
import type { ReportSchedule } from '../types';
import { ScheduleDialog } from './ScheduleDialog';

/** Weekly or monthly reports the API prepares by itself; they can be edited, paused and deleted. */
export function SchedulesCard() {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const schedules = useSchedules();
  const [dialogOpen, setDialogOpen] = useState(false);
  // The schedule being edited is read from the list, so a reload after a conflict reaches the form.
  const [editingId, setEditingId] = useState<string | null>(null);
  const [conflict, setConflict] = useState(false);
  const [removing, setRemoving] = useState<ReportSchedule | null>(null);
  const [removeError, setRemoveError] = useState<string | null>(null);
  const refresh = () => queryClient.invalidateQueries({ queryKey: reportsKeys.schedules() });
  const remove = useMutation({
    mutationFn: (schedule: ReportSchedule) => reportsApi.deleteSchedule(schedule.id),
    onSettled: refresh,
  });
  const toggle = useMutation({
    mutationFn: (schedule: ReportSchedule) =>
      reportsApi.updateSchedule(schedule.id, {
        enabled: !schedule.enabled,
        version: schedule.version,
      }),
    onSettled: refresh,
  });
  const editing = editingId ? schedules.data?.find((item) => item.id === editingId) : undefined;

  const runToggle = (schedule: ReportSchedule) => {
    if (toggle.isPending) return;
    toggle.mutate(schedule, {
      onSuccess: (updated) => {
        toast.show({
          tone: 'success',
          title: updated.enabled ? t('reports.schedule.resumed') : t('reports.schedule.pausedDone'),
        });
      },
      onError: (error) => {
        if (hasErrorCode(error, 'VERSION_CONFLICT')) {
          toast.show({
            tone: 'warning',
            title: t('finance.conflict.title'),
            description: t('reports.schedule.reloaded'),
          });
        } else if (hasErrorCode(error, 'NOT_FOUND')) {
          toast.show({ tone: 'info', title: t('reports.schedule.gone') });
        } else {
          toast.show({
            tone: 'danger',
            title: t('reports.schedule.updateFailed'),
            description: describeError(error, t),
          });
        }
      },
    });
  };

  const confirmRemove = () => {
    if (!removing || remove.isPending) return;
    setRemoveError(null);
    remove.mutate(removing, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('reports.schedule.deleted') });
        setRemoving(null);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          toast.show({ tone: 'info', title: t('reports.schedule.gone') });
          setRemoving(null);
        } else {
          setRemoveError(describeError(error, t));
        }
      },
    });
  };

  const add = (
    <Button
      variant="secondary"
      onClick={() => {
        setDialogOpen(true);
      }}
    >
      <Icon name="calendar" className="size-4" />
      {t('reports.schedule.add')}
    </Button>
  );

  let content;
  if (schedules.isPending) {
    content = <LoadingState label={t('reports.schedule.loading')} />;
  } else if (!schedules.data) {
    content = hasErrorCode(schedules.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="h3" />
    ) : (
      <ErrorState
        title={t('reports.schedule.error')}
        error={schedules.error}
        retrying={schedules.isFetching}
        onRetry={() => {
          void schedules.refetch();
        }}
      />
    );
  } else if (schedules.data.length === 0) {
    content = (
      <EmptyState
        icon="calendar"
        title={t('reports.schedule.empty')}
        description={t('reports.schedule.emptyBody')}
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {schedules.data.map((schedule) => {
          const next = parseTimestamp(schedule.next_run_at);
          const details = [
            isReportType(schedule.report_type)
              ? t(reportTypeLabel[schedule.report_type])
              : schedule.report_type,
            isReportFormat(schedule.format) ? t(formatLabel[schedule.format]) : schedule.format,
            t(cadenceLabel[schedule.cadence]),
          ];
          return (
            <li
              key={schedule.id}
              className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center"
            >
              <div className="min-w-0 flex-1 space-y-1">
                <div className="flex flex-wrap items-center gap-2">
                  <p className="font-medium break-words text-fg">{schedule.title}</p>
                  {schedule.enabled ? null : (
                    <StatusBadge tone="neutral" icon="pause">
                      {t('reports.schedule.paused')}
                    </StatusBadge>
                  )}
                </div>
                <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
                {next && schedule.enabled ? (
                  <p className="text-sm text-fg-muted">
                    <time dateTime={schedule.next_run_at}>
                      {t('reports.schedule.nextRun', {
                        date: formatDateTime(next, formatLocale, user.timezone),
                      })}
                    </time>
                  </p>
                ) : null}
                {!schedule.enabled ? (
                  <p className="text-sm text-fg-muted">{t('reports.schedule.pausedHelp')}</p>
                ) : null}
              </div>
              <div className="flex shrink-0 flex-wrap gap-2">
                <Button
                  variant="secondary"
                  size="sm"
                  aria-label={t('reports.schedule.editLabel', { title: schedule.title })}
                  onClick={() => {
                    setConflict(false);
                    setEditingId(schedule.id);
                  }}
                >
                  <Icon name="pencil" className="size-4" />
                  {t('common.edit')}
                </Button>
                <Button
                  variant="secondary"
                  size="sm"
                  loading={toggle.isPending && toggle.variables.id === schedule.id}
                  aria-label={
                    schedule.enabled
                      ? t('reports.schedule.pauseLabel', { title: schedule.title })
                      : t('reports.schedule.resumeLabel', { title: schedule.title })
                  }
                  onClick={() => {
                    runToggle(schedule);
                  }}
                >
                  <Icon name={schedule.enabled ? 'pause' : 'play'} className="size-4" />
                  {schedule.enabled ? t('reports.schedule.pause') : t('reports.schedule.resume')}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  aria-label={t('reports.schedule.deleteLabel', { title: schedule.title })}
                  onClick={() => {
                    setRemoveError(null);
                    setRemoving(schedule);
                  }}
                >
                  <Icon name="trash" className="size-4" />
                  {t('common.delete')}
                </Button>
              </div>
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <Card
      title={t('reports.schedule.title')}
      description={t('reports.schedule.description')}
      actions={add}
    >
      {schedules.isError && schedules.data ? (
        <RefreshFailed
          message={t('reports.stale.schedules')}
          retrying={schedules.isFetching}
          onRetry={() => {
            void schedules.refetch();
          }}
        />
      ) : null}
      {content}
      <ScheduleDialog open={dialogOpen} onOpenChange={setDialogOpen} />
      {editing ? (
        <ScheduleDialog
          open
          schedule={editing}
          conflict={conflict}
          onConflict={() => {
            setConflict(true);
            void refresh();
          }}
          onOpenChange={(open) => {
            if (!open) {
              setEditingId(null);
              setConflict(false);
            }
          }}
        />
      ) : null}
      <ConfirmDialog
        open={removing !== null}
        onOpenChange={(open) => {
          if (!open) setRemoving(null);
        }}
        title={t('reports.schedule.deleteTitle')}
        description={t('reports.schedule.deleteBody', { title: removing?.title ?? '' })}
        confirmLabel={t('reports.schedule.deleteConfirm')}
        onConfirm={confirmRemove}
        pending={remove.isPending}
        error={removeError}
      />
    </Card>
  );
}
