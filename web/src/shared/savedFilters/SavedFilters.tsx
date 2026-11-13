import { type SubmitEvent, useId, useRef, useState } from 'react';
import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Dialog } from '@/shared/components/Dialog';
import { Icon } from '@/shared/components/Icon';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { rateLimitMessage } from '@/shared/finance/rateLimit';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import {
  filterObject,
  SAVED_FILTER_NAME_MAX,
  type SavedFilter,
  type SavedFilterQuery,
  type SavedFilterScope,
  useCreateSavedFilter,
  useDeleteSavedFilter,
  useSavedFilters,
} from './api';

/** What a screen can make of a saved filter: the value to apply, and whether parts were left out. */
export interface ParsedFilter<T> {
  value: T;
  /** Some keys or values could not be applied on this screen. */
  partial: boolean;
}

interface SavedFiltersProps<T> {
  scope: Exclude<SavedFilterScope, 'reports'>;
  /** The screen's filters in the API's query shape, or null when there is nothing to save. */
  current: SavedFilterQuery | null;
  /** Reads a stored filter defensively; null when this screen cannot use it. */
  parse: (filter: SavedFilterQuery) => ParsedFilter<T> | null;
  onApply: (value: T) => void;
}

function nameLength(name: string): number {
  // Characters as the API counts them (code points), not UTF-16 units.
  return Array.from(name).length;
}

function validateName(name: string, t: Translate): string | null {
  if (!name) return t('savedFilters.errors.nameRequired');
  if (nameLength(name) > SAVED_FILTER_NAME_MAX) return t('savedFilters.errors.nameTooLong');
  return null;
}

/**
 * "Saved filters" button and dialog: save the screen's current filters under
 * a name, apply a saved one, or delete one after confirming. Saved filters
 * live on the account (GET/POST/DELETE /saved-filters), not in the browser.
 */
export function SavedFilters<T>({ scope, current, parse, onApply }: SavedFiltersProps<T>) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const user = useCurrentUser();
  const formId = useId();
  const nameRef = useRef<HTMLInputElement>(null);
  const list = useSavedFilters(scope);
  const create = useCreateSavedFilter(scope);
  const remove = useDeleteSavedFilter(scope);
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [nameError, setNameError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<SavedFilter | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const items = list.data ?? [];

  const reset = () => {
    setName('');
    setNameError(null);
    setFormError(null);
    create.reset();
  };

  const save = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    // The dialog is portaled, but React events still bubble to a form around the button.
    event.stopPropagation();
    if (!current || create.isPending) return;
    const trimmed = name.trim();
    const invalid = validateName(trimmed, t);
    setFormError(null);
    setNameError(invalid);
    if (invalid) {
      nameRef.current?.focus();
      return;
    }
    create.mutate(
      { name: trimmed, filter: current },
      {
        onSuccess: (saved) => {
          setName('');
          toast.show({ tone: 'success', title: t('savedFilters.save.done', { name: saved.name }) });
        },
        onError: (error) => {
          if (hasErrorCode(error, 'CONFLICT')) {
            setNameError(t('savedFilters.errors.duplicate', { name: trimmed }));
            nameRef.current?.focus();
            return;
          }
          if (hasErrorCode(error, 'VALIDATION_ERROR')) {
            const fields = error.details.map((detail) => detail.field ?? '');
            if (fields.some((field) => field === 'body.name')) {
              setNameError(t('savedFilters.errors.nameInvalid'));
              nameRef.current?.focus();
              return;
            }
            if (fields.some((field) => field.startsWith('body.filter'))) {
              setFormError(t('savedFilters.errors.filterRejected'));
              return;
            }
          }
          setFormError(
            rateLimitMessage(error, t, formatLocale, user.timezone) ?? describeError(error, t),
          );
        },
      },
    );
  };

  const apply = (item: SavedFilter) => {
    const object = filterObject(item.filter);
    const parsed = object ? parse(object) : null;
    if (!parsed) return;
    setOpen(false);
    onApply(parsed.value);
    toast.show({
      tone: parsed.partial ? 'info' : 'success',
      title: t('savedFilters.applied', { name: item.name }),
      ...(parsed.partial ? { description: t('savedFilters.appliedPartly') } : {}),
    });
  };

  const confirmDelete = () => {
    if (!deleting || remove.isPending) return;
    setDeleteError(null);
    const { id, name: deletedName } = deleting;
    remove.mutate(id, {
      onSuccess: () => {
        setDeleting(null);
        toast.show({ tone: 'success', title: t('savedFilters.deleted', { name: deletedName }) });
      },
      onError: (error) => {
        setDeleteError(
          rateLimitMessage(error, t, formatLocale, user.timezone) ?? describeError(error, t),
        );
      },
    });
  };

  let listContent;
  if (list.isPending) {
    listContent = <LoadingState label={t('savedFilters.list.loading')} />;
  } else if (list.isError) {
    listContent =
      isApiError(list.error) && list.error.code === 'FORBIDDEN' ? (
        <PermissionDenied titleAs="p" />
      ) : (
        <ErrorState
          titleAs="p"
          title={t('savedFilters.list.error')}
          error={list.error}
          retrying={list.isFetching}
          onRetry={() => {
            void list.refetch();
          }}
        />
      );
  } else if (items.length === 0) {
    listContent = <p className="text-sm text-fg-muted">{t('savedFilters.list.empty')}</p>;
  } else {
    listContent = (
      <ul className="divide-y divide-line">
        {items.map((item) => {
          const object = filterObject(item.filter);
          const usable = object !== null && parse(object) !== null;
          const savedAt = parseTimestamp(item.created_at);
          return (
            <li key={item.id} className="flex flex-wrap items-center gap-2 py-2">
              <div className="min-w-0 flex-1">
                <p className="break-words font-medium text-fg">{item.name}</p>
                <p className="text-sm text-fg-muted">
                  {usable
                    ? savedAt
                      ? t('savedFilters.list.savedOn', {
                          date: formatDate(savedAt, formatLocale, user.timezone),
                        })
                      : null
                    : t('savedFilters.list.unusable')}
                </p>
              </div>
              <Button
                size="sm"
                variant="secondary"
                disabled={!usable}
                aria-label={t('savedFilters.applyNamed', { name: item.name })}
                onClick={() => {
                  apply(item);
                }}
              >
                {t('savedFilters.apply')}
              </Button>
              <Button
                size="sm"
                variant="ghost"
                aria-label={t('savedFilters.deleteNamed', { name: item.name })}
                onClick={() => {
                  setDeleteError(null);
                  setDeleting(item);
                }}
              >
                <Icon name="trash" className="size-4" />
                {t('savedFilters.delete')}
              </Button>
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <>
      <Button
        variant="secondary"
        onClick={() => {
          reset();
          setOpen(true);
        }}
      >
        <Icon name="bookmark" className="size-4" />
        {items.length > 0
          ? t('savedFilters.open', { count: items.length })
          : t('savedFilters.openEmpty')}
      </Button>
      <Dialog
        open={open}
        onOpenChange={(next) => {
          setOpen(next);
          if (!next) setDeleting(null);
        }}
        title={t(`savedFilters.title.${scope}`)}
        description={t('savedFilters.description')}
        size="lg"
      >
        <section aria-labelledby={`${formId}-save`} className="space-y-3">
          <h3 id={`${formId}-save`} className="text-base font-semibold text-fg">
            {t(`savedFilters.save.title.${scope}`)}
          </h3>
          {current ? (
            <form noValidate onSubmit={save} className="space-y-3">
              {formError ? <FormAlert message={formError} /> : null}
              <div className="flex flex-col gap-3 sm:flex-row sm:items-start">
                <TextField
                  ref={nameRef}
                  label={t('savedFilters.save.name')}
                  help={t('savedFilters.save.nameHelp')}
                  value={name}
                  error={nameError ?? undefined}
                  autoComplete="off"
                  className="flex-1"
                  onChange={(event) => {
                    setName(event.target.value);
                    if (nameError) setNameError(null);
                  }}
                />
                <Button type="submit" loading={create.isPending} className="sm:mt-[26px]">
                  {t('savedFilters.save.submit')}
                </Button>
              </div>
            </form>
          ) : (
            <p className="text-sm text-fg-muted">{t(`savedFilters.save.nothing.${scope}`)}</p>
          )}
        </section>
        <section
          aria-labelledby={`${formId}-list`}
          className="mt-6 space-y-2 border-t border-line pt-4"
        >
          <h3 id={`${formId}-list`} className="text-base font-semibold text-fg">
            {t(`savedFilters.list.title.${scope}`)}
          </h3>
          {listContent}
        </section>
        <ConfirmDialog
          open={deleting !== null}
          onOpenChange={(next) => {
            if (!next) setDeleting(null);
          }}
          title={t('savedFilters.delete.title', { name: deleting?.name ?? '' })}
          description={t('savedFilters.delete.body')}
          confirmLabel={t('savedFilters.delete.confirm')}
          onConfirm={confirmDelete}
          pending={remove.isPending}
          error={deleteError}
        />
      </Dialog>
    </>
  );
}
