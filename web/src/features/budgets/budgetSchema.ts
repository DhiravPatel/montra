import { z } from 'zod';
import { checkAmount } from '@/shared/forms/decimalField';
import { isLocalDate } from '@/shared/formatting/dates';
import { normalizeDecimalInput } from '@/shared/formatting/decimal';
import type { Translate } from '@/shared/i18n/types';
import { type BudgetAmounts, type BudgetFormValues, allowedAllocationTargets } from './formValues';
import { isBudgetPeriod, isBudgetType, isGroupBudgetType, isRolloverPolicy } from './labels';

const allocationSchema = z.object({
  target: z.enum(['category', 'merchant', 'account', 'member', 'label']),
  categoryId: z.string(),
  merchantId: z.string(),
  merchantName: z.string(),
  accountId: z.string(),
  memberUserId: z.string(),
  label: z.string(),
  limit: z.string(),
});

/** Validation for the budget form (the API checks everything again). */
export function buildBudgetSchema(
  t: Translate,
  locale: string,
  exponent: (currency: string) => number,
) {
  return z
    .object({
      name: z
        .string()
        .trim()
        .min(1, { error: t('budgets.form.nameRequired') })
        .max(80, { error: t('validation.maxLength', { max: 80 }) }),
      budgetType: z.string().refine(isBudgetType, { error: t('budgets.form.typeRequired') }),
      period: z.string().refine(isBudgetPeriod, { error: t('budgets.form.periodRequired') }),
      startsOn: z.string(),
      endsOn: z.string(),
      currency: z.string().regex(/^[A-Z]{3}$/, { error: t('budgets.form.currencyRequired') }),
      limit: z.string(),
      rolloverPolicy: z.string().refine(isRolloverPolicy),
      rolloverCap: z.string(),
      includedAccountIds: z.array(z.string()),
      excludedCategoryIds: z.array(z.string()),
      merchants: z.array(z.object({ id: z.string(), name: z.string() })),
      allocations: z.array(allocationSchema),
      alertsMode: z.enum(['levels', 'off']),
      alertThresholds: z.array(z.number()),
      alertForecast: z.boolean(),
      includePending: z.boolean(),
      refundsRestore: z.boolean(),
      countGroupShares: z.boolean(),
      groupId: z.string(),
      visibility: z.enum(['private', 'members']),
      notes: z.string().max(1000, { error: t('validation.maxLength', { max: 1000 }) }),
    })
    .superRefine((values, ctx) => {
      const issue = (path: string, message: string) => {
        ctx.addIssue({ code: 'custom', path: [path], message });
      };
      const digits = exponent(values.currency);
      const money = { locale, currency: values.currency, exponent: digits, t };
      checkAmount(ctx, { ...money, value: values.limit, path: 'limit' });
      if (values.rolloverPolicy !== 'none') {
        checkAmount(ctx, {
          ...money,
          value: values.rolloverCap,
          path: 'rolloverCap',
          allowZero: true,
          optional: true,
        });
      }

      if (!values.startsOn) {
        issue('startsOn', t('validation.dateRequired'));
      } else if (!isLocalDate(values.startsOn)) {
        issue('startsOn', t('validation.dateInvalid'));
      }
      if (values.period === 'custom' && !values.endsOn) {
        issue('endsOn', t('budgets.form.endRequired'));
      } else if (values.endsOn && !isLocalDate(values.endsOn)) {
        issue('endsOn', t('validation.dateInvalid'));
      } else if (values.endsOn && values.startsOn && values.endsOn < values.startsOn) {
        issue('endsOn', t('budgets.form.endBeforeStart'));
      }

      const grouped = Boolean(values.groupId);
      const type = values.budgetType;
      const allowedTargets = allowedAllocationTargets(type, grouped);
      if (grouped && !isGroupBudgetType(type)) {
        issue('budgetType', t('budgets.form.groupTypeOnly'));
      }

      values.allocations.forEach((allocation, index) => {
        const at = (field: string) => `allocations.${index}.${field}`;
        if (!allowedTargets.includes(allocation.target)) {
          let message = t('budgets.form.alloc.notForThisType');
          if (grouped) message = t('budgets.form.alloc.groupMembersOnly');
          else if (allocation.target === 'member')
            message = t('budgets.form.alloc.memberGroupOnly');
          else if (allocation.target === 'merchant')
            message = t('budgets.form.alloc.merchantTypeOnly');
          else if (allocation.target === 'account')
            message = t('budgets.form.alloc.accountTypeOnly');
          issue(at('target'), message);
        }
        checkAmount(ctx, { ...money, value: allocation.limit, path: at('limit') });
        if (allocation.label.trim().length > 80) {
          issue(at('label'), t('validation.maxLength', { max: 80 }));
        }
        switch (allocation.target) {
          case 'category':
            if (!allocation.categoryId)
              issue(at('categoryId'), t('budgets.form.alloc.categoryRequired'));
            break;
          case 'merchant':
            if (!allocation.merchantId)
              issue(at('merchantId'), t('budgets.form.alloc.merchantRequired'));
            break;
          case 'account':
            if (!allocation.accountId)
              issue(at('accountId'), t('budgets.form.alloc.accountRequired'));
            break;
          case 'member':
            if (!allocation.memberUserId)
              issue(at('memberUserId'), t('budgets.form.alloc.memberRequired'));
            break;
          case 'label':
            if (!allocation.label.trim()) issue(at('label'), t('budgets.form.alloc.labelRequired'));
            break;
        }
      });

      const has = (target: string) => values.allocations.some((a) => a.target === target);
      if ((type === 'envelope' || type === 'zero_based') && values.allocations.length === 0) {
        issue('allocations', t('budgets.form.allocationsRequired'));
      }
      if (type === 'category' && !has('category')) {
        issue('allocations', t('budgets.form.categoryAllocationRequired'));
      }
      // Personal budgets only: group budgets count all of the group's expenses.
      if (!grouped) {
        if (type === 'merchant' && values.merchants.length === 0) {
          issue('merchants', t('budgets.form.merchantRequired'));
        } else if (type !== 'merchant' && values.merchants.length > 0) {
          issue('merchants', t('budgets.form.merchantsTypeOnly'));
        }
        if (type === 'account' && values.includedAccountIds.length === 0) {
          issue('includedAccountIds', t('budgets.form.accountRequired'));
        }
      }
      if (values.alertsMode === 'levels' && values.alertThresholds.length === 0) {
        issue('alertThresholds', t('budgets.form.thresholdsRequired'));
      }
    });
}

/** Exact canonical amounts for valid form values (already checked by the schema). */
export function readAmounts(
  values: BudgetFormValues,
  locale: string,
  exponent: number,
): BudgetAmounts {
  const canonical = (raw: string, allowZero: boolean) => {
    const result = normalizeDecimalInput(raw, locale, { exponent, allowZero });
    return result.ok ? result.value : raw.trim();
  };
  return {
    limit: canonical(values.limit, false),
    rolloverCap:
      values.rolloverPolicy !== 'none' && values.rolloverCap.trim()
        ? canonical(values.rolloverCap, true)
        : null,
    allocationLimits: values.allocations.map((allocation) => canonical(allocation.limit, false)),
  };
}
