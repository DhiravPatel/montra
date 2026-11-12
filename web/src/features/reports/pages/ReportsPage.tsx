import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { rangeLabel } from '@/shared/finance/labels';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useNow } from '@/shared/hooks/useNow';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { RefreshFailed } from '@/features/analytics/components/Blocks';
import { reportsApi, useLimits, useReports } from '../api';
import { ReportDialog } from '../components/ReportDialog';
import { ReportItem } from '../components/ReportItem';
import { SchedulesCard } from '../components/SchedulesCard';
import { downloadReportFile } from '../download';
import { repeatInput } from '../formValues';
import { reportsKeys } from '../keys';
import { failureMessage, isReportType, PERIOD_TYPES } from '../labels';
import { isActiveStatus } from '../polling';
import type { Report, ReportList, ReportStatus, ReportType } from '../types';

/** Tells the person when a report they are waiting for is ready or could not be made. */
function useCompletionNotices(list: ReportList | undefined) {
  const t = useT();
  const toast = useToast();
  const seen = useRef<Map<string, ReportStatus> | null>(null);
  useEffect(() => {
    if (!list) return;
    const before = seen.current;
    if (before) {
      for (const report of list.reports) {
        const was = before.get(report.id);
        if (!was || !isActiveStatus(was) || isActiveStatus(report.status)) continue;
        if (report.status === 'completed') {
          toast.show({ tone: 'success', title: t('reports.toast.ready', { title: report.title }) });
        } else if (report.status === 'failed') {
          toast.show({
            tone: 'warning',
            title: t('reports.toast.failed', { title: report.title }),
            description: t(failureMessage(report.error_code)),
          });
        }
      }
    }
    seen.current = new Map(list.reports.map((report) => [report.id, report.status]));
  }, [list, t, toast]);
}

/**
 * Reports and exports (spec §4.11, §20B.12): request a report, follow it
 * while it is prepared, download the file, and schedule repeating reports.
 */
export function ReportsPage() {
  const t = useT();
  useDocumentTitle(t('reports.title'));
  const toast = useToast();
  const queryClient = useQueryClient();
  const reports = useReports();
  const limits = useLimits();
  const [creating, setCreating] = useState(false);
  const [deleting, setDeleting] = useState<Report | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const now = useNow();
  useCompletionNotices(reports.data);

  const refreshList = () => queryClient.invalidateQueries({ queryKey: reportsKeys.list() });
  const download = useMutation({
    mutationFn: async (report: Report) => {
      const access = await reportsApi.access(report.id);
      await downloadReportFile(access, report.format);
    },
  });
  const repeat = useMutation({
    mutationFn: (input: { report: Report; type: ReportType }) =>
      reportsApi.create(repeatInput(input.report, input.type)),
    onSuccess: refreshList,
  });
  const remove = useMutation({
    mutationFn: (report: Report) => reportsApi.remove(report.id),
    onSettled: refreshList,
  });

  const confirmDelete = () => {
    if (!deleting || remove.isPending) return;
    setDeleteError(null);
    remove.mutate(deleting, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('reports.delete.done') });
        setDeleting(null);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          toast.show({ tone: 'info', title: t('reports.delete.gone') });
          setDeleting(null);
          return;
        }
        setDeleteError(describeError(error, t));
      },
    });
  };

  const onDownload = (report: Report) => {
    if (download.isPending) return;
    download.mutate(report, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('reports.download.started') });
      },
      onError: (error) => {
        if (hasErrorCode(error, 'GONE')) {
          toast.show({
            tone: 'warning',
            title: t('reports.download.expired'),
            description: t('reports.download.expiredBody'),
          });
          void refreshList();
        } else if (hasErrorCode(error, 'CONFLICT')) {
          toast.show({ tone: 'info', title: t('reports.download.notReady') });
          void refreshList();
        } else if (hasErrorCode(error, 'NOT_FOUND')) {
          toast.show({ tone: 'warning', title: t('reports.download.missing') });
          void refreshList();
        } else {
          toast.show({
            tone: 'danger',
            title: t('reports.download.failed'),
            description: describeError(error, t),
          });
        }
      },
    });
  };

  const onRepeat = (report: Report) => {
    if (repeat.isPending || !isReportType(report.report_type)) return;
    repeat.mutate(
      { report, type: report.report_type },
      {
        onSuccess: () => {
          const { range, from } = report.filters;
          // A named period ("Last month") is worked out again for today.
          const relative =
            isReportType(report.report_type) &&
            PERIOD_TYPES.has(report.report_type) &&
            !from &&
            range
              ? t(rangeLabel[range])
              : null;
          toast.show({
            tone: 'success',
            title: t('reports.create.done'),
            description: relative
              ? t('reports.create.doneRelative', { period: relative })
              : t('reports.create.doneBody'),
          });
        },
        onError: (error) => {
          toast.show({
            tone: 'danger',
            title: t('reports.create.failed'),
            description: describeError(error, t),
          });
        },
      },
    );
  };

  const openCreate = () => {
    setCreating(true);
  };

  let content;
  if (reports.isPending) {
    content = <LoadingState label={t('reports.list.loading')} />;
  } else if (!reports.data) {
    content = hasErrorCode(reports.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="h3" />
    ) : (
      <ErrorState
        title={t('reports.list.error')}
        error={reports.error}
        retrying={reports.isFetching}
        onRetry={() => {
          void reports.refetch();
        }}
      />
    );
  } else if (reports.data.reports.length === 0) {
    content = (
      <EmptyState
        icon="file-text"
        title={t('reports.list.empty')}
        description={t('reports.list.emptyBody')}
        action={
          <Button onClick={openCreate}>
            <Icon name="plus" className="size-4" />
            {t('reports.create.action')}
          </Button>
        }
      />
    );
  } else {
    const { reports: list, serverTime } = reports.data;
    content = (
      <ul className="divide-y divide-line" aria-busy={reports.isFetching || undefined}>
        {list.map((report) => (
          <ReportItem
            key={report.id}
            report={report}
            serverTime={serverTime}
            now={now}
            downloading={download.isPending && download.variables.id === report.id}
            repeating={repeat.isPending && repeat.variables.report.id === report.id}
            onDownload={onDownload}
            onRepeat={onRepeat}
            onDelete={(report) => {
              setDeleteError(null);
              setDeleting(report);
            }}
          />
        ))}
      </ul>
    );
  }

  const days = limits.data?.export_download_days;
  return (
    <>
      <PageHeader
        title={t('reports.title')}
        description={t('reports.description')}
        actions={
          <Button onClick={openCreate}>
            <Icon name="plus" className="size-4" />
            {t('reports.create.action')}
          </Button>
        }
      />
      <div className="grid gap-6">
        <Card
          title={t('reports.list.title')}
          description={
            <>
              {t('reports.list.description')}
              {days ? <> {t('reports.list.retention', { count: days })}</> : null}
            </>
          }
        >
          {reports.isError && reports.data ? (
            <RefreshFailed
              message={t('reports.stale.list')}
              retrying={reports.isFetching}
              onRetry={() => {
                void reports.refetch();
              }}
            />
          ) : null}
          {content}
        </Card>
        <SchedulesCard />
      </div>
      <ReportDialog open={creating} onOpenChange={setCreating} />
      <ConfirmDialog
        open={deleting !== null}
        onOpenChange={(open) => {
          if (!open && !remove.isPending) setDeleting(null);
        }}
        tone="danger"
        title={t('reports.delete.title')}
        description={
          deleting && isActiveStatus(deleting.status)
            ? t('reports.delete.bodyRunning', { title: deleting.title })
            : t('reports.delete.body', { title: deleting?.title ?? '' })
        }
        confirmLabel={t('reports.delete.confirm')}
        onConfirm={confirmDelete}
        pending={remove.isPending}
        error={deleteError}
      />
    </>
  );
}
