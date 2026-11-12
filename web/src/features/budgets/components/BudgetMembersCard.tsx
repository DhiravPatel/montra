import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths } from '@/shared/config/paths';
import { invalidateFinance } from '@/shared/finance/keys';
import type { Budget, BudgetMember } from '@/shared/finance/types';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { budgetsApi } from '../api';
import { memberRoleLabel } from '../labels';
import { MemberDialog } from './MemberDialog';

/** Who the budget is shared with. The owner manages people; others can leave. */
export function BudgetMembersCard({ budget }: { budget: Budget }) {
  const t = useT();
  const me = useCurrentUser();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const owner = budget.access === 'owner';
  const members = budget.members;
  const archived = budget.status === 'archived';
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<BudgetMember | null>(null);
  const [removing, setRemoving] = useState<BudgetMember | null>(null);
  const [leaving, setLeaving] = useState(false);
  const [confirmError, setConfirmError] = useState<string | null>(null);
  const remove = useMutation({
    mutationFn: (userId: string) => budgetsApi.removeMember(budget.id, userId),
  });

  const confirmRemove = () => {
    if (!removing || remove.isPending) return;
    setConfirmError(null);
    remove.mutate(removing.user_id, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title: t('budgets.members.removed', { name: removing.display_name }),
        });
        setRemoving(null);
        void invalidateFinance(queryClient);
      },
      onError: (error) => {
        setConfirmError(
          hasErrorCode(error, 'FORBIDDEN')
            ? t('budgets.members.forbidden')
            : describeError(error, t),
        );
      },
    });
  };

  const confirmLeave = () => {
    if (remove.isPending) return;
    setConfirmError(null);
    remove.mutate(me.id, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('budgets.members.left') });
        setLeaving(false);
        void invalidateFinance(queryClient);
        void navigate(paths.budgets);
      },
      onError: (error) => {
        setConfirmError(describeError(error, t));
      },
    });
  };

  return (
    <Card
      title={t('budgets.members.title')}
      description={
        budget.group_id ? t('budgets.members.groupDescription') : t('budgets.members.description')
      }
      actions={
        owner && !archived ? (
          <Button
            variant="secondary"
            size="sm"
            onClick={() => {
              setEditing(null);
              setDialogOpen(true);
            }}
          >
            <Icon name="share" className="size-4" />
            {t('budgets.members.add')}
          </Button>
        ) : null
      }
    >
      <p className="mb-4 text-sm text-fg">
        {budget.visibility === 'members'
          ? t('budgets.members.visibilityMembers')
          : t('budgets.members.visibilityPrivate')}
      </p>
      {owner ? null : (
        <p className="mb-4 flex flex-wrap items-center gap-2 text-sm text-fg">
          <StatusBadge tone="neutral" icon="user">
            {t('budgets.members.owner')}
          </StatusBadge>
          <span className="font-medium">{budget.owner_display_name}</span>
        </p>
      )}
      {members.length === 0 ? (
        <p className="text-sm text-fg-muted">{t('budgets.members.none')}</p>
      ) : (
        <ul className="divide-y divide-line">
          {members.map((member) => {
            const you = member.user_id === me.id;
            return (
              <li
                key={member.user_id}
                className="flex flex-col gap-3 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-center"
              >
                <div className="min-w-0 flex-1 space-y-1">
                  <p className="font-medium text-fg">
                    {member.display_name}
                    {you ? (
                      <span className="font-normal text-fg-muted"> {t('budgets.members.you')}</span>
                    ) : null}
                  </p>
                  <div className="flex flex-wrap items-center gap-2 text-sm text-fg-muted">
                    <StatusBadge tone="neutral" icon={member.role === 'editor' ? 'pencil' : 'eye'}>
                      {t(memberRoleLabel[member.role])}
                    </StatusBadge>
                    {member.allocation ? (
                      <span>
                        {t('budgets.members.allocationShort')}{' '}
                        <MoneyText money={member.allocation} />
                      </span>
                    ) : null}
                  </div>
                </div>
                {owner && !archived ? (
                  <div className="flex shrink-0 gap-2">
                    <Button
                      variant="secondary"
                      size="sm"
                      aria-label={`${t('budgets.members.change')}: ${member.display_name}`}
                      onClick={() => {
                        setEditing(member);
                        setDialogOpen(true);
                      }}
                    >
                      <Icon name="pencil" className="size-4" />
                      {t('budgets.members.change')}
                    </Button>
                    <Button
                      variant="secondary"
                      size="sm"
                      aria-label={`${t('budgets.members.remove')}: ${member.display_name}`}
                      onClick={() => {
                        setConfirmError(null);
                        setRemoving(member);
                      }}
                    >
                      <Icon name="trash" className="size-4" />
                      {t('budgets.members.remove')}
                    </Button>
                  </div>
                ) : null}
              </li>
            );
          })}
        </ul>
      )}
      {owner ? null : (
        <div className="mt-5 border-t border-line pt-5">
          <Button
            variant="secondary"
            onClick={() => {
              setConfirmError(null);
              setLeaving(true);
            }}
          >
            <Icon name="log-out" className="size-4" />
            {t('budgets.members.leave')}
          </Button>
        </div>
      )}
      <MemberDialog
        open={dialogOpen}
        onOpenChange={(open) => {
          setDialogOpen(open);
          if (!open) setEditing(null);
        }}
        budget={budget}
        member={editing}
      />
      <ConfirmDialog
        open={removing !== null}
        onOpenChange={(open) => {
          if (!open) setRemoving(null);
        }}
        title={t('budgets.members.removeTitle')}
        description={t('budgets.members.removeBody', { name: removing?.display_name ?? '' })}
        confirmLabel={t('budgets.members.remove')}
        onConfirm={confirmRemove}
        pending={remove.isPending}
        error={confirmError}
      />
      <ConfirmDialog
        open={leaving}
        onOpenChange={setLeaving}
        title={t('budgets.members.leaveTitle')}
        description={t('budgets.members.leaveBody')}
        confirmLabel={t('budgets.members.leave')}
        onConfirm={confirmLeave}
        pending={remove.isPending}
        error={confirmError}
      />
    </Card>
  );
}
