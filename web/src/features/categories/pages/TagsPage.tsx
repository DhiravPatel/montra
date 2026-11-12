import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths, withQuery } from '@/shared/config/paths';
import { invalidateFinance } from '@/shared/finance/keys';
import { useTags } from '@/shared/finance/reference';
import type { Tag } from '@/shared/finance/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { tagsApi } from '../api';
import { ColorDot } from '../components/ColorField';
import { OrganizeSubNav } from '../components/OrganizeSubNav';
import { TagDialog, type TagDialogMode } from '../components/TagDialog';
import { organizeErrorMessage } from '../errors';

/** Tags with usage counts: create, rename/recolor, archive and delete. */
export function TagsPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('tags.title'));
  const toast = useToast();
  const queryClient = useQueryClient();
  const tags = useTags();
  const [showArchived, setShowArchived] = useState(false);
  const [dialog, setDialog] = useState<TagDialogMode | null>(null);
  const [removing, setRemoving] = useState<Tag | null>(null);
  const [removeError, setRemoveError] = useState<string | null>(null);

  const archive = useMutation({
    mutationFn: (tag: Tag) =>
      tagsApi.update(tag.id, { archived: !tag.archived_at, version: tag.version }),
    onSettled: () => invalidateFinance(queryClient),
  });
  const remove = useMutation({
    mutationFn: (tag: Tag) => tagsApi.remove(tag.id),
    onSettled: () => invalidateFinance(queryClient),
  });

  const addButton = (
    <Button
      onClick={() => {
        setDialog({ kind: 'create' });
      }}
    >
      <Icon name="plus" className="size-4" />
      {t('tags.add')}
    </Button>
  );

  let content;
  if (tags.isPending) {
    content = <LoadingState label={t('tags.loading')} />;
  } else if (tags.isError) {
    content = hasErrorCode(tags.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('tags.error')}
        error={tags.error}
        retrying={tags.isFetching}
        onRetry={() => {
          void tags.refetch();
        }}
      />
    );
  } else if (tags.data.length === 0) {
    content = (
      <EmptyState
        icon="tag"
        title={t('tags.empty.title')}
        description={t('tags.empty.body')}
        action={addButton}
      />
    );
  } else {
    const visible = tags.data
      .filter((tag) => showArchived || !tag.archived_at)
      .sort((a, b) => a.name.localeCompare(b.name, formatLocale));
    content =
      visible.length === 0 ? (
        <p className="py-6 text-center text-sm text-fg-muted">{t('tags.allArchived')}</p>
      ) : (
        <ul className="divide-y divide-line">
          {visible.map((tag) => {
            const archived = Boolean(tag.archived_at);
            const pending = archive.isPending && archive.variables.id === tag.id;
            return (
              <li
                key={tag.id}
                className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center"
              >
                <div className="flex min-w-0 flex-1 items-start gap-3">
                  <ColorDot color={tag.color} className="mt-1.5" />
                  <div className="min-w-0 space-y-1">
                    <p className="font-medium text-fg">{tag.name}</p>
                    <p className="text-sm text-fg-muted">
                      {tag.usage_count > 0 ? (
                        <TextLink
                          to={withQuery(paths.transactions, { tag_id: tag.id, range: 'all' })}
                        >
                          {t('tags.usage', { count: tag.usage_count })}
                        </TextLink>
                      ) : (
                        t('tags.unused')
                      )}
                    </p>
                    {archived ? (
                      <StatusBadge icon="archive">{t('organize.archived')}</StatusBadge>
                    ) : null}
                  </div>
                </div>
                <div className="flex shrink-0 flex-wrap gap-2">
                  <Button
                    variant="secondary"
                    size="sm"
                    aria-label={`${t('common.edit')}: ${tag.name}`}
                    onClick={() => {
                      setDialog({ kind: 'edit', tag });
                    }}
                  >
                    <Icon name="pencil" className="size-4" />
                    {t('common.edit')}
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    loading={pending}
                    aria-label={`${archived ? t('tags.unarchive.action') : t('tags.archive.action')}: ${tag.name}`}
                    onClick={() => {
                      archive.mutate(tag, {
                        onSuccess: () => {
                          toast.show({
                            tone: 'success',
                            title: archived ? t('tags.unarchive.done') : t('tags.archive.done'),
                          });
                        },
                        onError: (error) => {
                          // A stale version: the list is refetched (onSettled), so the
                          // user sees the tag as it is now and can try again.
                          toast.show({
                            tone: hasErrorCode(error, 'VERSION_CONFLICT') ? 'warning' : 'danger',
                            title: hasErrorCode(error, 'VERSION_CONFLICT')
                              ? t('finance.conflict.title')
                              : t('tags.status.failed'),
                            description: hasErrorCode(error, 'VERSION_CONFLICT')
                              ? t('tags.status.reloaded')
                              : organizeErrorMessage(error, t, formatLocale),
                          });
                        },
                      });
                    }}
                  >
                    <Icon name={archived ? 'archive-restore' : 'archive'} className="size-4" />
                    {archived ? t('tags.unarchive.action') : t('tags.archive.action')}
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    aria-label={`${t('tags.delete.action')}: ${tag.name}`}
                    onClick={() => {
                      setRemoveError(null);
                      setRemoving(tag);
                    }}
                  >
                    <Icon name="trash" className="size-4" />
                    {t('tags.delete.action')}
                  </Button>
                </div>
              </li>
            );
          })}
        </ul>
      );
  }

  return (
    <>
      <PageHeader title={t('tags.title')} description={t('tags.description')} actions={addButton} />
      <OrganizeSubNav />
      <Card
        title={t('tags.list.title')}
        actions={
          <label className="inline-flex min-h-9 cursor-pointer items-center gap-2 text-sm text-fg">
            <input
              type="checkbox"
              checked={showArchived}
              onChange={(event) => {
                setShowArchived(event.target.checked);
              }}
              className="size-4 accent-accent"
            />
            {t('organize.showArchived')}
          </label>
        }
      >
        {content}
      </Card>
      <TagDialog
        mode={dialog}
        onClose={() => {
          setDialog(null);
        }}
      />
      <ConfirmDialog
        open={removing !== null}
        onOpenChange={(open) => {
          if (!open) setRemoving(null);
        }}
        title={t('tags.delete.title')}
        description={
          removing && removing.usage_count > 0
            ? t('tags.delete.body', { name: removing.name, count: removing.usage_count })
            : t('tags.delete.bodyUnused', { name: removing?.name ?? '' })
        }
        confirmLabel={t('tags.delete.confirm')}
        pending={remove.isPending}
        error={removeError}
        onConfirm={() => {
          if (!removing || remove.isPending) return;
          setRemoveError(null);
          remove.mutate(removing, {
            onSuccess: () => {
              toast.show({ tone: 'success', title: t('tags.delete.done') });
              setRemoving(null);
            },
            onError: (error) => {
              if (hasErrorCode(error, 'NOT_FOUND')) {
                toast.show({ tone: 'info', title: t('tags.notFound') });
                setRemoving(null);
              } else {
                setRemoveError(organizeErrorMessage(error, t, formatLocale));
              }
            },
          });
        }}
      />
    </>
  );
}
