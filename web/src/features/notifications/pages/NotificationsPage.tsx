import { type InfiniteData, useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useNow } from '@/shared/hooks/useNow';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { notificationsApi, useNotificationList, useUnreadCount } from '../api';
import {
  NOTIFICATION_CATEGORIES,
  categoryInfo,
  categoryLabelKey,
  isNotificationCategory,
} from '../categories';
import { NotificationItem } from '../components/NotificationItem';
import { notificationsKeys, refreshNotifications } from '../keys';
import type {
  AppNotification,
  NotificationFilters,
  NotificationPage,
  NotificationView,
} from '../types';

const VIEWS: readonly NotificationView[] = ['inbox', 'unread', 'archived'];

function isView(value: string | null): value is NotificationView {
  return value !== null && (VIEWS as readonly string[]).includes(value);
}

/** View and category live in the URL (enum values only), so back and forward keep them. */
function useFilters(): [NotificationFilters, (next: NotificationFilters) => void] {
  const [params, setParams] = useSearchParams();
  const view = params.get('view');
  const category = params.get('category') ?? '';
  const filters: NotificationFilters = {
    view: isView(view) ? view : 'inbox',
    category: isNotificationCategory(category) ? category : '',
  };
  const setFilters = (next: NotificationFilters) => {
    const search = new URLSearchParams();
    if (next.view !== 'inbox') search.set('view', next.view);
    if (next.category) search.set('category', next.category);
    setParams(search, { replace: true });
  };
  return [filters, setFilters];
}

interface UpdateVariables {
  notification: AppNotification;
  change: { read?: boolean; archived?: boolean };
}

/** Replaces one notification in every cached page of every list. */
function replaceInLists(
  data: InfiniteData<NotificationPage> | undefined,
  updated: AppNotification,
): InfiniteData<NotificationPage> | undefined {
  if (!data) return data;
  return {
    ...data,
    pages: data.pages.map((page) => ({
      ...page,
      items: page.items.map((item) => (item.id === updated.id ? updated : item)),
    })),
  };
}

/**
 * The notification center (spec §4.17): newest first, with views for
 * unread and archived notifications, a category filter, cursor pages,
 * read/unread, archive and "mark all as read". Opening a notification
 * marks it read and goes to the related page (IDs only in links).
 */
export function NotificationsPage() {
  const t = useT();
  useDocumentTitle(t('notifications.center.title'));
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const now = useNow();
  const [filters, setFilters] = useFilters();
  const list = useNotificationList(filters);
  const unread = useUnreadCount();
  const [pendingIds, setPendingIds] = useState<ReadonlySet<string>>(() => new Set());

  const setPending = (id: string, pending: boolean) => {
    setPendingIds((current) => {
      const next = new Set(current);
      if (pending) next.add(id);
      else next.delete(id);
      return next;
    });
  };

  // Callbacks live on the mutation (not on mutate) so they also run for a
  // notification opened just before the page unmounts.
  const update = useMutation({
    mutationFn: ({ notification, change }: UpdateVariables) =>
      notificationsApi.update(notification.id, change),
    onMutate: ({ notification }) => {
      setPending(notification.id, true);
    },
    onSuccess: (updated, { change }) => {
      queryClient.setQueriesData<InfiniteData<NotificationPage>>(
        { queryKey: notificationsKeys.lists() },
        (data) => replaceInLists(data, updated),
      );
      if (change.archived !== undefined) {
        void queryClient.invalidateQueries({ queryKey: notificationsKeys.lists() });
        toast.show({
          tone: 'success',
          title: change.archived
            ? t('notifications.item.archived')
            : t('notifications.item.unarchived'),
        });
      }
    },
    onError: (error) => {
      if (hasErrorCode(error, 'NOT_FOUND')) {
        toast.show({ tone: 'info', title: t('notifications.item.gone') });
        void queryClient.invalidateQueries({ queryKey: notificationsKeys.lists() });
        return;
      }
      toast.show({
        tone: 'danger',
        title: t('notifications.item.updateFailed'),
        description: describeError(error, t),
      });
    },
    onSettled: (_data, _error, { notification }) => {
      setPending(notification.id, false);
      void queryClient.invalidateQueries({ queryKey: notificationsKeys.unreadCount() });
    },
  });

  const readAll = useMutation({
    mutationFn: notificationsApi.readAll,
    onSettled: () => refreshNotifications(queryClient),
  });

  const markAllRead = () => {
    if (readAll.isPending) return;
    readAll.mutate(undefined, {
      onSuccess: (result) => {
        const updated = result.updated ?? 0;
        toast.show({
          tone: 'success',
          title:
            updated > 0
              ? t('notifications.center.allRead', { count: updated })
              : t('notifications.center.nothingToMark'),
        });
      },
      onError: (error) => {
        toast.show({
          tone: 'danger',
          title: t('notifications.center.allReadFailed'),
          description: describeError(error, t),
        });
      },
    });
  };

  const change = (notification: AppNotification, body: UpdateVariables['change']) => {
    if (pendingIds.has(notification.id)) return;
    update.mutate({ notification, change: body });
  };

  const categoryOptions = NOTIFICATION_CATEGORIES.map((category) => ({
    value: category,
    label: t(categoryInfo[category].label),
  }));

  let content;
  if (list.isPending) {
    content = <LoadingState label={t('notifications.center.loading')} />;
  } else if (list.isError) {
    content = hasErrorCode(list.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('notifications.center.error')}
        error={list.error}
        retrying={list.isFetching}
        onRetry={() => {
          void list.refetch();
        }}
      />
    );
  } else {
    const items = list.data.pages.flatMap((page) => page.items);
    if (items.length === 0) {
      const category = filters.category ? t(categoryLabelKey(filters.category)) : '';
      content = (
        <EmptyState
          icon={filters.view === 'archived' ? 'archive' : 'bell'}
          title={
            filters.view === 'unread'
              ? t('notifications.center.empty.unread')
              : filters.view === 'archived'
                ? t('notifications.center.empty.archived')
                : t('notifications.center.empty.inbox')
          }
          description={
            category
              ? t('notifications.center.empty.category', { category })
              : filters.view === 'archived'
                ? t('notifications.center.empty.archivedBody')
                : t('notifications.center.empty.inboxBody')
          }
        />
      );
    } else {
      content = (
        <>
          <ul className="divide-y divide-line">
            {items.map((notification) => (
              <NotificationItem
                key={notification.id}
                notification={notification}
                pending={pendingIds.has(notification.id)}
                now={now}
                timeZone={user.timezone}
                onOpen={(opened) => {
                  if (!opened.read_at) change(opened, { read: true });
                }}
                onToggleRead={(item) => {
                  change(item, { read: !item.read_at });
                }}
                onToggleArchive={(item) => {
                  change(item, { archived: !item.archived_at });
                }}
              />
            ))}
          </ul>
          <div className="mt-6 flex flex-col items-center gap-3">
            <p role="status" className="text-sm text-fg-muted">
              {t('notifications.center.showing', { count: items.length })}
            </p>
            {list.hasNextPage ? (
              <Button
                variant="secondary"
                loading={list.isFetchingNextPage}
                onClick={() => {
                  void list.fetchNextPage();
                }}
              >
                {t('common.loadMore')}
              </Button>
            ) : null}
          </div>
        </>
      );
    }
  }

  const noUnread = unread.isSuccess && unread.data === 0;

  return (
    <>
      <PageHeader
        title={t('notifications.center.title')}
        description={t('notifications.center.description')}
        actions={
          <>
            <Button
              variant="secondary"
              loading={readAll.isPending}
              disabled={noUnread}
              onClick={markAllRead}
            >
              <Icon name="check-circle" className="size-4" />
              {t('notifications.center.markAllRead')}
            </Button>
            <ButtonLink to={paths.notificationSettings} variant="ghost">
              <Icon name="sliders" className="size-4" />
              {t('notifications.center.settings')}
            </ButtonLink>
          </>
        }
      />
      <Card>
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <RadioGroup<NotificationView>
            legend={t('notifications.center.view')}
            hideLegend
            value={filters.view}
            onChange={(view) => {
              setFilters({ ...filters, view });
            }}
            options={[
              { value: 'inbox', label: t('notifications.center.view.inbox') },
              { value: 'unread', label: t('notifications.center.view.unread') },
              { value: 'archived', label: t('notifications.center.view.archived') },
            ]}
          />
          <Select
            label={t('notifications.center.category')}
            optional
            className="sm:w-64"
            value={filters.category}
            placeholder={t('notifications.center.allCategories')}
            options={categoryOptions}
            onChange={(event) => {
              setFilters({ ...filters, category: event.target.value });
            }}
          />
        </div>
        {content}
      </Card>
    </>
  );
}
