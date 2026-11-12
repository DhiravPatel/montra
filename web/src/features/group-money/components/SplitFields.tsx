import { useId } from 'react';
import { Controller, useFormContext, useWatch } from 'react-hook-form';
import { Checkbox } from '@/shared/components/Checkbox';
import { MoneyField } from '@/shared/components/MoneyField';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { TextField } from '@/shared/components/TextField';
import { useT } from '@/shared/i18n/I18nContext';
import { isSplitMethod, splitMethodHelp, splitMethodLabel } from '../labels';
import type { People } from '../people';
import { type SplitContext, type SplitShape, splitGuidance } from '../splitForm';
import type { SplitMethod } from '../types';
import { GuidanceLine, SectionError } from './FormBits';
import { ItemsFields } from './ItemsFields';

interface SplitFieldsProps {
  people: People;
  /** The amount in the group currency (null while incomplete). */
  total: string | null;
  context: SplitContext;
  methods: readonly SplitMethod[];
  /** Called after the method changes (e.g. to start an itemized split with one item). */
  onMethodChange?: (method: string) => void;
}

/**
 * How to split: the method, who shares it and each person's amount,
 * percentage or shares (or the items of an itemized split). The guidance
 * line uses exact decimal math; the server computes the actual shares.
 */
export function SplitFields({ people, total, context, methods, onMethodChange }: SplitFieldsProps) {
  const t = useT();
  const errorId = useId();
  const { register, control, formState } = useFormContext<SplitShape>();
  const errors = formState.errors;
  const [method, participants] = useWatch({ control, name: ['splitMethod', 'participants'] });
  const sectionError = errors.checks?.split?.message;

  return (
    <fieldset className="space-y-4" aria-describedby={sectionError ? errorId : undefined}>
      <legend className="mb-1 text-base font-semibold text-fg">
        {t('groupMoney.form.split.legend')}
      </legend>
      <Controller
        control={control}
        name="splitMethod"
        render={({ field }) => (
          <RadioGroup<string>
            legend={t('groupMoney.form.split.method')}
            value={field.value}
            onChange={(value) => {
              field.onChange(value);
              onMethodChange?.(value);
            }}
            options={methods.map((value) => ({ value, label: t(splitMethodLabel[value]) }))}
            help={isSplitMethod(method) ? t(splitMethodHelp[method]) : undefined}
            error={errors.splitMethod?.message}
          />
        )}
      />
      {method === 'itemized' ? (
        <ItemsFields people={people} total={total} context={context} />
      ) : (
        <>
          <ul className="divide-y divide-line rounded-lg border border-line px-4">
            {participants.map((row, index) => {
              const member = people.active.find((item) => item.user_id === row.userId);
              const name = member ? people.optionLabel(member) : people.name(row.userId);
              const valueError = errors.participants?.[index]?.value?.message;
              return (
                <li
                  key={row.userId}
                  className="flex flex-col gap-3 py-3 sm:flex-row sm:items-start sm:justify-between"
                >
                  <Checkbox
                    label={name}
                    className="pt-2 sm:flex-1"
                    {...register(`participants.${index}.included`)}
                  />
                  {row.included && method === 'exact' ? (
                    <MoneyField
                      label={t('groupMoney.form.split.amountFor', { name })}
                      currency={context.currency}
                      className="sm:w-56"
                      error={valueError}
                      {...register(`participants.${index}.value`)}
                    />
                  ) : null}
                  {row.included && method === 'percentage' ? (
                    <TextField
                      label={t('groupMoney.form.split.percentFor', { name })}
                      inputMode="decimal"
                      autoComplete="off"
                      maxLength={6}
                      className="sm:w-56"
                      error={valueError}
                      {...register(`participants.${index}.value`)}
                    />
                  ) : null}
                  {row.included && method === 'shares' ? (
                    <TextField
                      label={t('groupMoney.form.split.sharesFor', { name })}
                      inputMode="numeric"
                      autoComplete="off"
                      maxLength={7}
                      className="sm:w-56"
                      error={valueError}
                      {...register(`participants.${index}.value`)}
                    />
                  ) : null}
                </li>
              );
            })}
          </ul>
          <GuidanceLine guidance={splitGuidance(method, participants, total, context)} />
        </>
      )}
      <SectionError id={errorId} message={sectionError} />
    </fieldset>
  );
}
