import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { Menu, MenuContent, MenuItem, MenuSeparator, MenuTrigger } from '@/shared/components/Menu';
import { PageHeader } from '@/shared/components/PageHeader';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths, withQuery } from '@/shared/config/paths';
import { categoryName } from '@/shared/finance/categories';
import { invalidateFinance } from '@/shared/finance/keys';
import { useCategories } from '@/shared/finance/reference';
import type { Category } from '@/shared/finance/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { categoriesApi } from '../api';
import { CategoryDialog, type CategoryDialogMode } from '../components/CategoryDialog';
import { ColorDot } from '../components/ColorField';
import { MergeCategoriesDialog } from '../components/MergeCategoriesDialog';
import { OrganizeSubNav } from '../components/OrganizeSubNav';
import { inUseList, organizeErrorMessage } from '../errors';
import { categoryKindLabel, organizeTree } from '../labels';

interface Confirm {
  action: 'archive' | 'delete';
  category: Category;
}

const triggerClasses =
  'inline-flex size-11 shrink-0 cursor-pointer items-center justify-center rounded-md border border-transparent ' +
  'text-fg-muted hover:bg-surface-muted hover:text-fg';

function CategoryRow({
  category,
  isChild,
  onEdit,
  onAddSub,
  onConfirm,
  onRestore,
  restoring,
}: {
  category: Category;
  isChild: boolean;
  onEdit: (category: Category) => void;
  onAddSub: (category: Category) => void;
  onConfirm: (confirm: Confirm) => void;
  onRestore: (category: Category) => void;
  restoring: boolean;
}) {
  const { t } = useI18n();
  const name = categoryName(category, t);
  const active = category.status === 'active';
  const details = [
    t(categoryKindLabel[category.kind]),
    t('organize.transactionCount', { count: category.transaction_count }),
  ];
  return (
    <div className="flex items-center gap-3 py-3">
      <ColorDot color={category.color} className={isChild ? 'size-2.5' : undefined} />
      <div className="min-w-0 flex-1 space-y-1">
        <p className={cx('text-fg', isChild ? 'font-normal' : 'font-medium')}>{name}</p>
        <p className="text-sm text-fg-muted">{details.join(' · ')}</p>
        {!category.include_in_budgets || !active ? (
          <div className="flex flex-wrap gap-2">
            {category.status === 'archived' ? (
              <StatusBadge icon="archive">{t('organize.archived')}</StatusBadge>
            ) : null}
            {category.status === 'merged' ? (
              <StatusBadge icon="git-merge">{t('organize.categories.merged')}</StatusBadge>
            ) : null}
            {!category.include_in_budgets ? (
              <StatusBadge icon="info">{t('organize.categories.notInBudgets')}</StatusBadge>
            ) : null}
          </div>
        ) : null}
      </div>
      {category.status === 'archived' ? (
        <Button
          variant="secondary"
          size="sm"
          loading={restoring}
          aria-label={`${t('organize.categories.restore.action')}: ${name}`}
          onClick={() => {
            onRestore(category);
          }}
        >
          <Icon name="archive-restore" className="size-4" />
          {t('organize.categories.restore.action')}
        </Button>
      ) : null}
      {active ? (
        <Menu>
          <MenuTrigger className={triggerClasses} aria-label={t('organize.actionsFor', { name })}>
            <Icon name="more-horizontal" />
          </MenuTrigger>
          <MenuContent>
            <MenuItem
              icon="pencil"
              onSelect={() => {
                onEdit(category);
              }}
            >
              {t('common.edit')}
            </MenuItem>
            {!isChild ? (
              <MenuItem
                icon="plus"
                onSelect={() => {
                  onAddSub(category);
                }}
              >
                {t('organize.categories.addSub')}
              </MenuItem>
            ) : null}
            <MenuItem asChild>
              <Link
                to={withQuery(paths.transactions, { category_id: category.id, range: 'all' })}
                className="flex items-center gap-2"
              >
                <Icon name="list" className="size-4" />
                {t('organize.viewTransactions')}
              </Link>
            </MenuItem>
            <MenuSeparator />
            <MenuItem
              icon="archive"
              onSelect={() => {
                onConfirm({ action: 'archive', category });
              }}
            >
              {t('organize.categories.archive.action')}
            </MenuItem>
            {category.transaction_count === 0 ? (
              <MenuItem
                icon="trash"
                tone="danger"
                onSelect={() => {
                  onConfirm({ action: 'delete', category });
                }}
              >
                {t('organize.categories.delete.action')}
              </MenuItem>
            ) : null}
          </MenuContent>
        </Menu>
      ) : null}
    </div>
  );
}

/** Category hierarchy with create, edit, archive/restore, delete and merge. */
export function CategoriesPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('organize.categories.title'));
  const toast = useToast();
  const queryClient = useQueryClient();
  const [showArchived, setShowArchived] = useState(false);
  const categories = useCategories(showArchived);
  // Parent choices and subcategory checks always use the full list.
  const all = useCategories(true);
  const [dialog, setDialog] = useState<CategoryDialogMode | null>(null);
  const [mergeOpen, setMergeOpen] = useState(false);
  const [confirm, setConfirm] = useState<Confirm | null>(null);
  const [confirmError, setConfirmError] = useState<string | null>(null);

  const lifecycle = useMutation({
    mutationFn: async ({ action, category }: Confirm) => {
      if (action === 'archive') await categoriesApi.archive(category.id);
      else await categoriesApi.remove(category.id);
    },
    onSettled: () => invalidateFinance(queryClient),
  });
  const restore = useMutation({
    mutationFn: (category: Category) => categoriesApi.restore(category.id),
    onSettled: () => invalidateFinance(queryClient),
  });

  const runConfirm = () => {
    if (!confirm || lifecycle.isPending) return;
    setConfirmError(null);
    lifecycle.mutate(confirm, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title:
            confirm.action === 'archive'
              ? t('organize.categories.archive.done')
              : t('organize.categories.delete.done'),
        });
        setConfirm(null);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          toast.show({ tone: 'info', title: t('organize.categories.notFound') });
          setConfirm(null);
        } else if (confirm.action === 'delete' && hasErrorCode(error, 'CONFLICT')) {
          // 409 category_in_use names what still uses it (only non-zero counts).
          const list = inUseList(error, t, formatLocale);
          setConfirmError(
            list
              ? t('organize.categories.delete.inUseList', { list })
              : t('organize.categories.delete.inUse'),
          );
        } else {
          setConfirmError(organizeErrorMessage(error, t, formatLocale));
        }
      },
    });
  };

  const rowProps = {
    onEdit: (category: Category) => {
      setDialog({ kind: 'edit', category });
    },
    onAddSub: (category: Category) => {
      setDialog({ kind: 'create', parent: category });
    },
    onConfirm: (next: Confirm) => {
      setConfirmError(null);
      setConfirm(next);
    },
    onRestore: (category: Category) => {
      restore.mutate(category, {
        onSuccess: () => {
          toast.show({ tone: 'success', title: t('organize.categories.restore.done') });
        },
        onError: (error) => {
          toast.show({
            tone: 'danger',
            title: t('organize.categories.restore.failed'),
            description: organizeErrorMessage(error, t, formatLocale),
          });
        },
      });
    },
  };

  const addButton = (
    <Button
      onClick={() => {
        setDialog({ kind: 'create' });
      }}
    >
      <Icon name="plus" className="size-4" />
      {t('organize.categories.add')}
    </Button>
  );

  let content;
  if (categories.isPending) {
    content = <LoadingState label={t('organize.categories.loading')} />;
  } else if (categories.isError) {
    content = hasErrorCode(categories.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('organize.categories.error')}
        error={categories.error}
        retrying={categories.isFetching}
        onRetry={() => {
          void categories.refetch();
        }}
      />
    );
  } else {
    const tree = organizeTree(categories.data, t, formatLocale);
    content =
      tree.length === 0 ? (
        <EmptyState
          icon="folder"
          title={t('organize.categories.empty.title')}
          description={t('organize.categories.empty.body')}
          action={addButton}
        />
      ) : (
        <ul className="divide-y divide-line">
          {tree.map(({ category, children }) => (
            <li key={category.id}>
              <CategoryRow
                category={category}
                isChild={false}
                restoring={restore.isPending && restore.variables.id === category.id}
                {...rowProps}
              />
              {children.length > 0 ? (
                <ul
                  aria-label={t('organize.categories.subcategories', {
                    name: categoryName(category, t),
                  })}
                  className="ms-4 mb-3 divide-y divide-line border-s-2 border-line ps-4"
                >
                  {children.map((child) => (
                    <li key={child.id}>
                      <CategoryRow
                        category={child}
                        isChild
                        restoring={restore.isPending && restore.variables.id === child.id}
                        {...rowProps}
                      />
                    </li>
                  ))}
                </ul>
              ) : null}
            </li>
          ))}
        </ul>
      );
  }

  const confirmName = confirm ? categoryName(confirm.category, t) : '';
  return (
    <>
      <PageHeader
        title={t('organize.categories.title')}
        description={t('organize.categories.description')}
        actions={
          <>
            {addButton}
            <Button
              variant="secondary"
              disabled={!all.isSuccess}
              onClick={() => {
                setMergeOpen(true);
              }}
            >
              <Icon name="git-merge" className="size-4" />
              {t('organize.categories.merge')}
            </Button>
          </>
        }
      />
      <OrganizeSubNav />
      <Card
        title={t('organize.categories.list.title')}
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
      <CategoryDialog
        mode={dialog}
        categories={all.data ?? categories.data ?? []}
        onClose={() => {
          setDialog(null);
        }}
      />
      <MergeCategoriesDialog
        open={mergeOpen}
        onOpenChange={setMergeOpen}
        categories={all.data ?? []}
      />
      <ConfirmDialog
        open={confirm !== null}
        onOpenChange={(open) => {
          if (!open) setConfirm(null);
        }}
        title={
          confirm?.action === 'delete'
            ? t('organize.categories.delete.title')
            : t('organize.categories.archive.title')
        }
        description={
          confirm?.action === 'delete'
            ? t('organize.categories.delete.body', { name: confirmName })
            : t('organize.categories.archive.body', { name: confirmName })
        }
        confirmLabel={
          confirm?.action === 'delete'
            ? t('organize.categories.delete.confirm')
            : t('organize.categories.archive.confirm')
        }
        onConfirm={runConfirm}
        pending={lifecycle.isPending}
        error={confirmError}
      />
    </>
  );
}
