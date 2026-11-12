import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { MoneyField } from '@/shared/components/MoneyField';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import { shareCandidateOptions, useShareCandidates } from '@/shared/finance/sharing';
import type { Budget, BudgetMember } from '@/shared/finance/types';
import { decimalIssueMessage } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { decimalToInput, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import { budgetsApi } from '../api';
import { type MemberRole, memberRoleHelp, memberRoleLabel } from '../labels';

interface MemberDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  budget: Budget;
  /** Change this member; add someone new when null. */
  member: BudgetMember | null;
}

/** Share the budget with a friend or group member, or change someone's role/allocation. */
export function MemberDialog({ open, onOpenChange, budget, member }: MemberDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={member ? t('budgets.members.editTitle') : t('budgets.members.addTitle')}
      description={member ? member.display_name : t('budgets.members.addDescription')}
      busy={pending}
    >
      {open ? (
        <MemberForm
          budget={budget}
          member={member}
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function MemberForm({
  budget,
  member,
  onPendingChange,
  onDone,
}: {
  budget: Budget;
  member: BudgetMember | null;
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const currencies = useCurrencies();
  const candidates = useShareCandidates({
    groupId: budget.group_id,
    exclude: [budget.owner_user_id, ...budget.members.map((item) => item.user_id)],
    enabled: member === null,
  });
  const [userId, setUserId] = useState('');
  const [role, setRole] = useState<MemberRole>(member?.role ?? 'viewer');
  const [allocation, setAllocation] = useState(
    member?.allocation ? decimalToInput(member.allocation.amount, formatLocale) : '',
  );
  const [userError, setUserError] = useState<string | null>(null);
  const [allocationError, setAllocationError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const save = useMutation({
    mutationFn: (body: { userId: string; role: MemberRole; allocation: string | null }) => {
      const allocationPart = body.allocation ? { allocation: body.allocation } : {};
      return member
        ? budgetsApi.updateMember(budget.id, body.userId, { role: body.role, ...allocationPart })
        : budgetsApi.addMember(budget.id, {
            user_id: body.userId,
            role: body.role,
            ...allocationPart,
          });
    },
    onSuccess: (updated) => {
      queryClient.setQueryData(financeKeys.budget(updated.id), updated);
      void invalidateFinance(queryClient);
    },
  });

  if (member === null) {
    if (candidates.isError) {
      return (
        <ErrorState
          titleAs="p"
          title={t('budgets.members.candidatesError')}
          error={candidates.error}
          onRetry={candidates.refetch}
        />
      );
    }
    if (candidates.isPending)
      return <LoadingState label={t('budgets.members.candidatesLoading')} />;
    if (candidates.candidates.length === 0) {
      return (
        <EmptyState
          titleAs="p"
          icon="users"
          title={t('budgets.members.noCandidates')}
          description={t('budgets.members.noCandidatesBody')}
        />
      );
    }
  }

  const submit = async () => {
    if (save.isPending) return;
    setUserError(null);
    setAllocationError(null);
    setFormError(null);
    const target = member?.user_id ?? userId;
    if (!target) {
      setUserError(t('budgets.members.chooseSomeone'));
      return;
    }
    let amount: string | null = null;
    if (allocation.trim()) {
      const exponent = exponentFor(currencies.data, budget.currency);
      const result = normalizeDecimalInput(allocation, formatLocale, { exponent, allowZero: true });
      if (!result.ok) {
        setAllocationError(decimalIssueMessage(result.issue, t, budget.currency, exponent));
        return;
      }
      amount = result.value;
    }
    onPendingChange(true);
    try {
      await save.mutateAsync({ userId: target, role, allocation: amount });
      onPendingChange(false);
      toast.show({
        tone: 'success',
        title: member ? t('budgets.members.updated') : t('budgets.members.added'),
      });
      onDone();
    } catch (error) {
      onPendingChange(false);
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        // Fields are reported as body.user_id and body.allocation.
        const allocationDetail = error.details.find((detail) =>
          detail.field?.includes('allocation'),
        );
        const userDetail = member
          ? undefined
          : error.details.find((detail) => detail.field === 'body.user_id');
        if (allocationDetail) setAllocationError(allocationDetail.message);
        if (userDetail) setUserError(userDetail.message);
        const rest = error.details.filter(
          (detail) => detail !== allocationDetail && detail !== userDetail,
        );
        setFormError(
          rest.length > 0
            ? rest.map((detail) => detail.message).join(' ')
            : allocationDetail || userDetail
              ? null
              : t('errors.VALIDATION_ERROR'),
        );
      } else if (hasErrorCode(error, 'FORBIDDEN')) {
        setFormError(t('budgets.members.forbidden'));
      } else {
        setFormError(describeError(error, t));
      }
    }
  };

  return (
    <form
      noValidate
      className="space-y-5"
      onSubmit={(event) => {
        event.preventDefault();
        void submit();
      }}
    >
      <FormAlert message={formError} />
      {member ? null : (
        <Select
          label={t('budgets.members.person')}
          help={t('budgets.members.personHelp')}
          placeholder={t('budgets.members.personPlaceholder')}
          options={shareCandidateOptions(candidates.candidates, t)}
          value={userId}
          error={userError ?? undefined}
          onChange={(event) => {
            setUserId(event.target.value);
          }}
        />
      )}
      <RadioGroup<MemberRole>
        legend={t('budgets.members.role')}
        variant="cards"
        value={role}
        onChange={setRole}
        options={(['viewer', 'editor'] as const).map((value) => ({
          value,
          label: t(memberRoleLabel[value]),
          description: t(memberRoleHelp[value]),
        }))}
      />
      <MoneyField
        label={t('budgets.members.allocation')}
        help={t('budgets.members.allocationHelp')}
        optional
        currency={budget.currency}
        value={allocation}
        error={allocationError ?? undefined}
        onChange={(event) => {
          setAllocation(event.target.value);
        }}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={save.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={save.isPending}>
          {member ? t('common.save') : t('budgets.members.addSubmit')}
        </Button>
      </div>
    </form>
  );
}
