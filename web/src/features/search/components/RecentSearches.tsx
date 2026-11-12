import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { formatRelativeTime, parseTimestamp } from '@/shared/formatting/dates';
import { useNow } from '@/shared/hooks/useNow';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { searchApi, useRecentSearches } from '../api';
import { searchKeys } from '../keys';
import { scopeLabel } from '../labels';
import { isSearchScope } from '../query';
import type { RecentSearch } from '../types';

interface RecentSearchesProps {
  /** Runs a remembered search again. */
  onRun: (recent: RecentSearch) => void;
  /** Called after the history was cleared (the list and its button are gone). */
  onCleared: () => void;
}

/** Submitted searches kept on the account (last 20), with a way to clear them. */
export function RecentSearches({ onRun, onCleared }: RecentSearchesProps) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const now = useNow();
  const recent = useRecentSearches();
  const [confirming, setConfirming] = useState(false);
  const [clearError, setClearError] = useState<string | null>(null);
  const clear = useMutation({
    mutationFn: () => searchApi.clearRecent(),
    onSettled: () => queryClient.invalidateQueries({ queryKey: searchKeys.recent() }),
  });
  const items = recent.data ?? [];

  const confirmClear = () => {
    if (clear.isPending) return;
    setClearError(null);
    clear.mutate(undefined, {
      onSuccess: () => {
        queryClient.setQueryData<RecentSearch[]>(searchKeys.recent(), []);
        setConfirming(false);
        toast.show({ tone: 'success', title: t('search.recent.cleared') });
        // After the dialog has closed: its trigger no longer exists.
        window.setTimeout(onCleared, 0);
      },
      onError: (error) => {
        setClearError(describeError(error, t));
      },
    });
  };

  let content;
  if (recent.isPending) {
    content = <LoadingState label={t('search.recent.loading')} />;
  } else if (recent.isError) {
    content = hasErrorCode(recent.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="p" />
    ) : (
      <ErrorState
        titleAs="p"
        title={t('search.recent.error')}
        error={recent.error}
        retrying={recent.isFetching}
        onRetry={() => {
          void recent.refetch();
        }}
      />
    );
  } else if (items.length === 0) {
    content = (
      <p className="flex items-center gap-2 text-sm text-fg-muted">
        <Icon name="history" className="size-4" />
        {t('search.recent.empty')}
      </p>
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {items.map((item, index) => {
          const scope = isSearchScope(item.scope) ? item.scope : 'all';
          const when = parseTimestamp(item.created_at);
          const details = [
            scope === 'all' ? null : t('search.recent.inScope', { section: t(scopeLabel[scope]) }),
            when ? formatRelativeTime(when, formatLocale, now) : null,
          ].filter(Boolean);
          return (
            <li key={`${item.created_at}-${String(index)}`}>
              <button
                type="button"
                onClick={() => {
                  onRun(item);
                }}
                className="flex min-h-11 w-full items-center gap-3 rounded-md px-2 py-2 text-start hover:bg-surface-muted"
              >
                <Icon name="history" className="text-fg-muted" />
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-medium text-fg">{item.query}</span>
                  {details.length > 0 ? (
                    <span className="block text-sm text-fg-muted">{details.join(' · ')}</span>
                  ) : null}
                </span>
                <Icon name="arrow-right" className="text-fg-muted" />
              </button>
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <>
      <Card
        title={t('search.recent.title')}
        description={t('search.recent.description')}
        actions={
          items.length > 0 ? (
            <Button
              variant="secondary"
              size="sm"
              onClick={() => {
                setClearError(null);
                setConfirming(true);
              }}
            >
              <Icon name="trash" className="size-4" />
              {t('search.recent.clear')}
            </Button>
          ) : null
        }
      >
        {content}
      </Card>
      <ConfirmDialog
        open={confirming}
        onOpenChange={(open) => {
          if (!open) setConfirming(false);
        }}
        title={t('search.recent.clearTitle')}
        description={t('search.recent.clearBody')}
        confirmLabel={t('search.recent.clearConfirm')}
        onConfirm={confirmClear}
        pending={clear.isPending}
        error={clearError}
      />
    </>
  );
}
