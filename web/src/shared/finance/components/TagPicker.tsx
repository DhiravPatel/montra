import { useId, useState } from 'react';
import { Button } from '@/shared/components/Button';
import { FieldError, FieldHelp } from '@/shared/components/FieldParts';
import { Icon } from '@/shared/components/Icon';
import { IconButton } from '@/shared/components/IconButton';
import { inputClasses } from '@/shared/components/fieldStyles';
import { useT } from '@/shared/i18n/I18nContext';
import type { Tag } from '../types';

export interface TagSelection {
  tagIds: string[];
  /** New tags, created by the API when the transaction is saved. */
  newNames: string[];
}

interface TagPickerProps {
  tags: readonly Tag[];
  value: TagSelection;
  onChange: (value: TagSelection) => void;
  error?: string | undefined;
  /** Most tags a transaction may carry (contract: 20). */
  max?: number;
}

const TAG_MAX_LENGTH = 40;

/** Existing tags as checkboxes plus a field to add new ones. */
export function TagPicker({ tags, value, onChange, error, max = 20 }: TagPickerProps) {
  const t = useT();
  const id = useId();
  const [draft, setDraft] = useState('');
  const [draftError, setDraftError] = useState<string | null>(null);
  const active = tags.filter((tag) => !tag.archived_at || value.tagIds.includes(tag.id));
  const count = value.tagIds.length + value.newNames.length;

  const toggle = (tagId: string, checked: boolean) => {
    onChange({
      ...value,
      tagIds: checked
        ? [...value.tagIds, tagId]
        : value.tagIds.filter((idValue) => idValue !== tagId),
    });
  };

  const addDraft = () => {
    const name = draft.trim().replace(/\s+/g, ' ');
    if (!name) return;
    if (name.length > TAG_MAX_LENGTH) {
      setDraftError(t('finance.tags.tooLong', { max: TAG_MAX_LENGTH }));
      return;
    }
    if (count >= max) {
      setDraftError(t('finance.tags.tooMany', { max }));
      return;
    }
    const existing = active.find((tag) => tag.name.toLowerCase() === name.toLowerCase());
    if (existing) {
      if (!value.tagIds.includes(existing.id)) toggle(existing.id, true);
    } else if (!value.newNames.some((item) => item.toLowerCase() === name.toLowerCase())) {
      onChange({ ...value, newNames: [...value.newNames, name] });
    }
    setDraft('');
    setDraftError(null);
  };

  const helpId = `${id}-help`;
  const errorId = `${id}-error`;
  const shownError = draftError ?? error;

  return (
    <fieldset className="space-y-3" aria-describedby={shownError ? `${helpId} ${errorId}` : helpId}>
      <legend className="mb-1.5 text-sm font-medium text-fg">
        {t('finance.tags.label')}{' '}
        <span className="font-normal text-fg-muted">({t('common.optional')})</span>
      </legend>
      {active.length > 0 ? (
        <ul className="flex max-h-48 flex-wrap gap-2 overflow-y-auto">
          {active.map((tag) => {
            const checked = value.tagIds.includes(tag.id);
            return (
              <li key={tag.id}>
                <label className="inline-flex min-h-9 cursor-pointer items-center gap-2 rounded-full border border-line-strong px-3 text-sm has-[:checked]:border-accent has-[:checked]:bg-accent-soft has-[:checked]:font-semibold">
                  <input
                    type="checkbox"
                    checked={checked}
                    onChange={(event) => {
                      if (event.target.checked && count >= max) {
                        setDraftError(t('finance.tags.tooMany', { max }));
                        return;
                      }
                      toggle(tag.id, event.target.checked);
                    }}
                    className="size-4 accent-accent"
                  />
                  {tag.name}
                </label>
              </li>
            );
          })}
        </ul>
      ) : null}
      {value.newNames.length > 0 ? (
        <ul className="flex flex-wrap gap-2" aria-label={t('finance.tags.newTags')}>
          {value.newNames.map((name) => (
            <li
              key={name}
              className="inline-flex min-h-9 items-center gap-1 rounded-full border border-accent bg-accent-soft ps-3 text-sm font-semibold"
            >
              <Icon name="tag" className="size-3.5" />
              {name}
              <span className="sr-only"> ({t('finance.tags.willBeCreated')})</span>
              <IconButton
                icon="x"
                size="sm"
                label={t('finance.tags.removeNew', { name })}
                onClick={() => {
                  onChange({ ...value, newNames: value.newNames.filter((item) => item !== name) });
                }}
              />
            </li>
          ))}
        </ul>
      ) : null}
      <div className="flex gap-2">
        <label htmlFor={`${id}-new`} className="sr-only">
          {t('finance.tags.addLabel')}
        </label>
        <input
          id={`${id}-new`}
          value={draft}
          maxLength={TAG_MAX_LENGTH + 10}
          placeholder={t('finance.tags.addPlaceholder')}
          onChange={(event) => {
            setDraft(event.target.value);
            setDraftError(null);
          }}
          onKeyDown={(event) => {
            if (event.key === 'Enter') {
              event.preventDefault(); // add the tag instead of submitting the form
              addDraft();
            }
          }}
          className={inputClasses}
        />
        <Button variant="secondary" onClick={addDraft} disabled={!draft.trim()}>
          <Icon name="plus" className="size-4" />
          {t('finance.tags.add')}
        </Button>
      </div>
      <FieldHelp id={helpId}>{t('finance.tags.help', { max })}</FieldHelp>
      {shownError ? <FieldError id={errorId}>{shownError}</FieldError> : null}
    </fieldset>
  );
}
