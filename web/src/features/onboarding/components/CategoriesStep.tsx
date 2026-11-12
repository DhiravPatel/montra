import { useState } from 'react';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { categoryName } from '@/shared/finance/categories';
import { useCategories } from '@/shared/finance/reference';
import type { Category } from '@/shared/finance/types';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { useQueryClient } from '@tanstack/react-query';
import { invalidateFinance } from '@/shared/finance/keys';
import { onboardingApi } from '../api';
import { StepActions } from './StepActions';
import type { StepProps } from './types';

const kinds: readonly { kind: Category['kind']; label: MessageKey }[] = [
  { kind: 'expense', label: 'categories.kind.expense' },
  { kind: 'income', label: 'categories.kind.income' },
  { kind: 'both', label: 'categories.kind.both' },
];

/**
 * Starter categories (created by Montra for every account). Unticked ones are
 * archived, not deleted: they can be restored later and history keeps them.
 */
export function CategoriesStep({ onNext, onBack, advancing }: StepProps) {
  const { t, formatLocale } = useI18n();
  const queryClient = useQueryClient();
  const categories = useCategories();
  const [unticked, setUnticked] = useState<ReadonlySet<string>>(new Set());
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (categories.isPending) return <LoadingState label={t('onboarding.categories.loading')} />;
  if (categories.isError) {
    return (
      <ErrorState
        title={t('onboarding.categories.error')}
        error={categories.error}
        onRetry={() => {
          void categories.refetch();
        }}
      />
    );
  }

  const starters = categories.data
    .filter(
      (category) => category.system_key && !category.parent_id && category.status === 'active',
    )
    .sort(
      (a, b) =>
        a.sort_order - b.sort_order ||
        categoryName(a, t).localeCompare(categoryName(b, t), formatLocale),
    );

  const save = async () => {
    if (saving) return;
    const toArchive = starters.filter((category) => unticked.has(category.id));
    if (toArchive.length === 0) {
      onNext('completed');
      return;
    }
    setSaving(true);
    setError(null);
    try {
      for (const category of toArchive) {
        await onboardingApi.archiveCategory(category.id);
      }
      await invalidateFinance(queryClient);
      onNext('completed');
    } catch (failure) {
      await invalidateFinance(queryClient);
      setUnticked(new Set());
      setError(describeError(failure, t));
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      <FormAlert message={error} />
      <p className="text-fg">{t('onboarding.categories.body')}</p>
      {starters.length === 0 ? (
        <p className="text-fg-muted">{t('onboarding.categories.none')}</p>
      ) : (
        kinds.map(({ kind, label }) => {
          const group = starters.filter((category) => category.kind === kind);
          if (group.length === 0) return null;
          return (
            <fieldset key={kind}>
              <legend className="mb-2 font-semibold text-fg">{t(label)}</legend>
              <ul className="grid gap-2 sm:grid-cols-2">
                {group.map((category) => {
                  const id = `starter-${category.id}`;
                  return (
                    <li key={category.id}>
                      <label
                        htmlFor={id}
                        className="flex min-h-11 cursor-pointer items-center gap-3 rounded-md border border-line px-3 py-2 text-sm text-fg has-[:checked]:border-accent has-[:checked]:bg-accent-soft"
                      >
                        <input
                          id={id}
                          type="checkbox"
                          checked={!unticked.has(category.id)}
                          onChange={(event) => {
                            const next = new Set(unticked);
                            if (event.target.checked) next.delete(category.id);
                            else next.add(category.id);
                            setUnticked(next);
                          }}
                          className="size-4 accent-accent"
                        />
                        {categoryName(category, t)}
                      </label>
                    </li>
                  );
                })}
              </ul>
            </fieldset>
          );
        })
      )}
      <p className="text-sm text-fg-muted">{t('onboarding.categories.later')}</p>
      <StepActions
        onBack={onBack}
        onSkip={() => {
          onNext('skipped');
        }}
        primaryLabel={t('common.continue')}
        onPrimary={() => {
          void save();
        }}
        pending={saving || advancing}
      />
    </div>
  );
}
