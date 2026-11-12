import { useId } from 'react';
import { Controller, useFormContext, useWatch } from 'react-hook-form';
import { MoneyField } from '@/shared/components/MoneyField';
import { type RadioOption, RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { useT } from '@/shared/i18n/I18nContext';
import type { People } from '../people';
import { type PayerMode, type SplitContext, type SplitShape, payersGuidance } from '../splitForm';
import { GuidanceLine, SectionError } from './FormBits';

interface PayerFieldsProps {
  people: People;
  /** The amount in the group currency (null while incomplete). */
  total: string | null;
  context: SplitContext;
  /** Recurring expenses: "whoever adds it pays" is offered (and is the default). */
  allowAdder?: boolean;
}

/** Who paid: one person (the whole amount) or several people with their amounts. */
export function PayerFields({ people, total, context, allowAdder = false }: PayerFieldsProps) {
  const t = useT();
  const errorId = useId();
  const { register, control, formState } = useFormContext<SplitShape>();
  const errors = formState.errors;
  const [mode, payers] = useWatch({ control, name: ['payerMode', 'payers'] });
  const options: RadioOption<PayerMode>[] = [
    ...(allowAdder
      ? [
          {
            value: 'adder' as const,
            label: t('groupMoney.form.payers.adder'),
            description: t('groupMoney.form.payers.adderHelp'),
          },
        ]
      : []),
    { value: 'one', label: t('groupMoney.form.payers.one') },
    { value: 'several', label: t('groupMoney.form.payers.several') },
  ];
  const sectionError = errors.checks?.payers?.message;

  return (
    <fieldset className="space-y-4" aria-describedby={sectionError ? errorId : undefined}>
      <legend className="mb-1 text-base font-semibold text-fg">
        {t('groupMoney.form.payers.legend')}
      </legend>
      <Controller
        control={control}
        name="payerMode"
        render={({ field }) => (
          <RadioGroup<PayerMode>
            legend={t('groupMoney.form.payers.mode')}
            hideLegend
            value={field.value}
            onChange={field.onChange}
            options={options}
            variant={allowAdder ? 'cards' : 'segmented'}
          />
        )}
      />
      {mode === 'one' ? (
        <Select
          label={t('groupMoney.form.payers.paidBy')}
          options={people.active.map((member) => ({
            value: member.user_id,
            label: people.optionLabel(member),
          }))}
          help={t('groupMoney.form.payers.paidByHelp')}
          error={errors.singlePayer?.message}
          {...register('singlePayer')}
        />
      ) : null}
      {mode === 'several' ? (
        <div className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            {payers.map((row, index) => {
              const member = people.active.find((item) => item.user_id === row.userId);
              const name = member ? people.optionLabel(member) : people.name(row.userId);
              return (
                <MoneyField
                  key={row.userId}
                  label={t('groupMoney.form.payers.amountFor', { name })}
                  currency={context.currency}
                  optional
                  error={errors.payers?.[index]?.amount?.message}
                  {...register(`payers.${index}.amount`)}
                />
              );
            })}
          </div>
          <GuidanceLine guidance={payersGuidance(payers, total, context)} />
        </div>
      ) : null}
      <SectionError id={errorId} message={sectionError} />
    </fieldset>
  );
}
