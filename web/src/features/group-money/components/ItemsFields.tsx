import { useId } from 'react';
import { Controller, useFieldArray, useFormContext, useWatch } from 'react-hook-form';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { FieldError } from '@/shared/components/FieldParts';
import { Icon } from '@/shared/components/Icon';
import { MoneyField } from '@/shared/components/MoneyField';
import { TextField } from '@/shared/components/TextField';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import { formatMoney } from '@/shared/formatting/money';
import { useT } from '@/shared/i18n/I18nContext';
import { fromMinor, sumMinor, toMinor } from '../exact';
import type { People } from '../people';
import type { Guidance, ItemRowValues, SplitContext, SplitShape } from '../splitForm';
import { GuidanceLine, SectionError } from './FormBits';

interface ItemsShape {
  items: ItemRowValues[];
  checks?: SplitShape['checks'];
}

function itemsGuidance(
  items: readonly ItemRowValues[],
  total: string | null,
  context: SplitContext,
): Guidance {
  const { t } = context;
  const money = (amount: string) => {
    try {
      return formatMoney(amount, context.currency, context.locale);
    } catch {
      return `${amount} ${context.currency}`;
    }
  };
  const sum = sumMinor(
    items.map((item) => {
      const value = normalizeDecimalInput(item.amount, context.locale, {
        exponent: context.exponent,
        allowZero: true,
      });
      return value.ok ? (toMinor(value.value, context.exponent) ?? 0n) : 0n;
    }),
  );
  const totalMinor = total === null ? null : toMinor(total, context.exponent);
  if (totalMinor === null) return { tone: 'neutral', text: t('groupMoney.guide.enterTotal') };
  if (sum > totalMinor) {
    return {
      tone: 'warning',
      text: t('groupMoney.guide.itemsOver', {
        amount: money(fromMinor(sum - totalMinor, context.exponent)),
      }),
    };
  }
  if (sum === totalMinor) return { tone: 'success', text: t('groupMoney.guide.itemsDone') };
  return {
    tone: 'neutral',
    text: t('groupMoney.guide.itemsRest', {
      items: money(fromMinor(sum, context.exponent)),
      rest: money(fromMinor(totalMinor - sum, context.exponent)),
    }),
  };
}

/**
 * Lines of an itemized split: each item's amount and who shared it. Tax,
 * tip or service (the total minus the items) is shared by the server in
 * proportion to each person's items.
 */
export function ItemsFields({
  people,
  total,
  context,
}: {
  people: People;
  total: string | null;
  context: SplitContext;
}) {
  const t = useT();
  const errorId = useId();
  const { register, control, formState } = useFormContext<ItemsShape>();
  const errors = formState.errors;
  const { fields, append, remove } = useFieldArray({ control, name: 'items' });
  const items = useWatch({ control, name: 'items' });
  const order = new Map(people.active.map((member, index) => [member.user_id, index]));
  const sectionError = errors.checks?.items?.message;

  return (
    <div className="space-y-4">
      {fields.map((field, index) => (
        <fieldset key={field.id} className="space-y-4 rounded-lg border border-line p-4">
          <legend className="px-1 text-sm font-semibold text-fg">
            {t('groupMoney.form.items.itemNumber', { number: index + 1 })}
          </legend>
          <div className="grid gap-4 sm:grid-cols-3">
            <TextField
              label={t('groupMoney.form.items.description')}
              maxLength={200}
              autoComplete="off"
              className="sm:col-span-3"
              error={errors.items?.[index]?.description?.message}
              {...register(`items.${index}.description`)}
            />
            <MoneyField
              label={t('groupMoney.form.items.amount')}
              currency={context.currency}
              className="sm:col-span-2"
              error={errors.items?.[index]?.amount?.message}
              {...register(`items.${index}.amount`)}
            />
            <TextField
              label={t('groupMoney.form.items.quantity')}
              optional
              inputMode="decimal"
              autoComplete="off"
              maxLength={13}
              error={errors.items?.[index]?.quantity?.message}
              {...register(`items.${index}.quantity`)}
            />
          </div>
          <Controller
            control={control}
            name={`items.${index}.sharedBy`}
            render={({ field: sharedBy, fieldState }) => {
              const sharedError = fieldState.error?.message;
              const sharedErrorId = `${field.id}-shared-error`;
              return (
                <fieldset
                  className="space-y-2"
                  aria-describedby={sharedError ? sharedErrorId : undefined}
                >
                  <legend className="text-sm font-medium text-fg">
                    {t('groupMoney.form.items.sharedBy')}
                  </legend>
                  <div className="flex flex-wrap gap-x-6 gap-y-2">
                    {people.active.map((member) => (
                      <Checkbox
                        key={member.user_id}
                        label={people.optionLabel(member)}
                        checked={sharedBy.value.includes(member.user_id)}
                        onChange={(event) => {
                          const next = event.target.checked
                            ? [...sharedBy.value, member.user_id]
                            : sharedBy.value.filter((id) => id !== member.user_id);
                          sharedBy.onChange(
                            [...new Set(next)].sort(
                              (a, b) => (order.get(a) ?? 0) - (order.get(b) ?? 0),
                            ),
                          );
                        }}
                      />
                    ))}
                  </div>
                  {sharedError ? <FieldError id={sharedErrorId}>{sharedError}</FieldError> : null}
                </fieldset>
              );
            }}
          />
          {fields.length > 1 ? (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                remove(index);
              }}
            >
              <Icon name="trash" className="size-4" />
              {t('groupMoney.form.items.remove', { number: index + 1 })}
            </Button>
          ) : null}
        </fieldset>
      ))}
      <Button
        variant="secondary"
        size="sm"
        onClick={() => {
          append({ description: '', amount: '', quantity: '', sharedBy: [] });
        }}
      >
        <Icon name="plus" className="size-4" />
        {t('groupMoney.form.items.add')}
      </Button>
      <GuidanceLine guidance={itemsGuidance(items, total, context)} />
      <SectionError id={errorId} message={sectionError} />
    </div>
  );
}
