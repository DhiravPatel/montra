import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Dialog } from '@/shared/components/Dialog';
import { Icon } from '@/shared/components/Icon';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths } from '@/shared/config/paths';
import { isStaleRecordError } from '@/shared/finance/domainErrors';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import { shareCandidateOptions, useGroups, useShareCandidates } from '@/shared/finance/sharing';
import type { Goal, GoalMember, GoalMemberUpdate } from '@/shared/finance/types';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { goalsApi } from '../api';
import { goalErrorMessage } from '../errors';
import {
  CONTRIBUTION_VISIBILITIES,
  MEMBER_ROLES,
  type MemberRole,
  isContributionVisibility,
  isMemberRole,
  memberRoleHelp,
  memberRoleLabel,
  memberVisibilityLabel,
  myVisibilityLabel,
} from '../labels';
import { goalPeople, memberName, sharedWith } from '../people';

/**
 * A select whose new choice is applied with a button, so moving through the
 * options with the arrow keys never saves on its own.
 */
function SaveableSelect<T extends string>({
  label,
  value,
  options,
  isValue,
  saveLabel,
  pending,
  onSave,
}: {
  label: string;
  value: T;
  options: { value: T; label: string }[];
  isValue: (value: string) => value is T;
  saveLabel: string;
  pending: boolean;
  onSave: (value: T) => void;
}) {
  const [draft, setDraft] = useState<T>(value);
  return (
    <div className="flex min-w-0 flex-1 flex-wrap items-end gap-2">
      <Select
        label={label}
        className="min-w-40 flex-1"
        value={draft}
        options={options}
        onChange={(event) => {
          const next = event.target.value;
          if (isValue(next)) setDraft(next);
        }}
      />
      {draft !== value ? (
        <Button
          size="sm"
          loading={pending}
          onClick={() => {
            onSave(draft);
          }}
        >
          {saveLabel}
        </Button>
      ) : null}
    </div>
  );
}

function AddMemberDialog({
  goal,
  open,
  onOpenChange,
}: {
  goal: Goal;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('goals.members.addTitle')}
      description={t('goals.members.addDescription')}
      busy={pending}
    >
      {open ? (
        <AddMemberForm
          goal={goal}
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function AddMemberForm({
  goal,
  onPendingChange,
  onDone,
}: {
  goal: Goal;
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const candidates = useShareCandidates({
    groupId: goal.group_id,
    exclude: goalPeople(goal).map((member) => member.user_id),
  });
  const [userId, setUserId] = useState('');
  const [role, setRole] = useState<MemberRole>('contributor');
  const [personError, setPersonError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const add = useMutation({
    mutationFn: () => goalsApi.addMember(goal.id, { user_id: userId, role }, goal.version),
    onSuccess: (updated) => {
      queryClient.setQueryData(financeKeys.goal(updated.id), updated);
      void invalidateFinance(queryClient);
    },
  });

  if (candidates.isPending) return <LoadingState label={t('goals.members.candidatesLoading')} />;
  if (candidates.isError) {
    return (
      <ErrorState
        titleAs="p"
        title={t('goals.members.candidatesError')}
        error={candidates.error}
        onRetry={candidates.refetch}
      />
    );
  }
  if (candidates.candidates.length === 0) {
    return (
      <div className="space-y-5">
        <p className="text-sm text-fg-muted">{t('goals.members.noCandidates')}</p>
        <div className="flex justify-end">
          <Button variant="secondary" onClick={onDone}>
            {t('common.close')}
          </Button>
        </div>
      </div>
    );
  }

  const submit = () => {
    if (add.isPending) return;
    setFormError(null);
    if (!userId) {
      setPersonError(t('goals.members.personRequired'));
      return;
    }
    setPersonError(null);
    onPendingChange(true);
    add.mutate(undefined, {
      onSuccess: () => {
        onPendingChange(false);
        toast.show({ tone: 'success', title: t('goals.members.added') });
        onDone();
      },
      onError: (error) => {
        onPendingChange(false);
        if (
          hasErrorCode(error, 'VALIDATION_ERROR') &&
          error.details.some((detail) => detail.field === 'body.user_id')
        ) {
          setPersonError(t('goals.members.notConnected'));
        } else {
          setFormError(goalErrorMessage(error, t, formatLocale));
          if (isStaleRecordError(error)) {
            void queryClient.invalidateQueries({ queryKey: financeKeys.goal(goal.id) });
          }
        }
      },
    });
  };

  return (
    <form
      noValidate
      className="space-y-5"
      onSubmit={(event) => {
        event.preventDefault();
        submit();
      }}
    >
      {formError ? (
        <Alert tone="danger" live="assertive">
          {formError}
        </Alert>
      ) : null}
      <Select
        label={t('goals.members.person')}
        placeholder={t('goals.members.personPlaceholder')}
        options={shareCandidateOptions(candidates.candidates, t)}
        value={userId}
        error={personError ?? undefined}
        onChange={(event) => {
          setUserId(event.target.value);
        }}
      />
      <RadioGroup
        legend={t('goals.members.role')}
        variant="cards"
        value={role}
        onChange={setRole}
        options={MEMBER_ROLES.map((value) => ({
          value,
          label: t(memberRoleLabel[value]),
          description: t(memberRoleHelp[value]),
        }))}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={add.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={add.isPending}>
          {t('goals.members.addSubmit')}
        </Button>
      </div>
    </form>
  );
}

/** Who can see the goal; the owner manages people, everyone manages their own sharing. */
export function GoalMembersCard({ goal }: { goal: Goal }) {
  const { t, formatLocale } = useI18n();
  const me = useCurrentUser();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const groups = useGroups(Boolean(goal.group_id));
  const [adding, setAdding] = useState(false);
  const [removing, setRemoving] = useState<GoalMember | null>(null);
  const [removeError, setRemoveError] = useState<string | null>(null);
  const owner = goal.access === 'owner';
  const people = goalPeople(goal);
  const others = sharedWith(goal);
  // The owner is listed too, so the owner also chooses what others see of their contributions.
  const myMembership = people.find((member) => member.user_id === me.id);
  const leaving = removing !== null && removing.user_id === me.id;

  /** Reload the goal after a stale version or a refused change. */
  const reloadIfStale = (error: unknown) => {
    if (isStaleRecordError(error)) {
      void queryClient.invalidateQueries({ queryKey: financeKeys.goal(goal.id) });
    }
  };

  const update = useMutation({
    mutationFn: ({ userId, body }: { userId: string; body: GoalMemberUpdate }) =>
      goalsApi.updateMember(goal.id, userId, body, goal.version),
    onSuccess: (updated) => {
      queryClient.setQueryData(financeKeys.goal(updated.id), updated);
      void invalidateFinance(queryClient);
    },
  });
  const remove = useMutation({
    mutationFn: (member: GoalMember) =>
      goalsApi.removeMember(goal.id, member.user_id, goal.version),
  });

  const changeRole = (member: GoalMember, role: MemberRole) => {
    update.mutate(
      { userId: member.user_id, body: { role } },
      {
        onSuccess: () => {
          toast.show({ tone: 'success', title: t('goals.members.roleChanged') });
        },
        onError: (error) => {
          reloadIfStale(error);
          toast.show({
            tone: 'danger',
            title: t('goals.members.roleFailed'),
            description: goalErrorMessage(error, t, formatLocale),
          });
        },
      },
    );
  };

  const confirmRemove = () => {
    if (!removing || remove.isPending) return;
    setRemoveError(null);
    const self = removing.user_id === me.id;
    remove.mutate(removing, {
      onSuccess: () => {
        setRemoving(null);
        if (self) {
          // The goal is no longer visible: forget it before leaving the page.
          queryClient.removeQueries({ queryKey: financeKeys.goal(goal.id) });
          void invalidateFinance(queryClient);
          toast.show({ tone: 'success', title: t('goals.members.left') });
          void navigate(paths.goals);
        } else {
          void queryClient.invalidateQueries({ queryKey: financeKeys.goal(goal.id) });
          void invalidateFinance(queryClient);
          toast.show({ tone: 'success', title: t('goals.members.removed') });
        }
      },
      onError: (error) => {
        reloadIfStale(error);
        setRemoveError(goalErrorMessage(error, t, formatLocale));
      },
    });
  };

  const groupName = goal.group_id
    ? groups.data?.find((group) => group.id === goal.group_id)?.name
    : undefined;

  const personName = (member: GoalMember) => {
    if (member.user_id === me.id) return t('goals.members.you', { name: memberName(member, t) });
    // The owner's name is left out when their profile is not visible to you.
    if (member.role === 'owner' && !goal.owner.display_name) return t('goals.members.ownerOther');
    return memberName(member, t);
  };

  return (
    <>
      <Card
        title={t('goals.members.title')}
        description={t('goals.members.description')}
        actions={
          owner && goal.status !== 'archived' ? (
            <Button
              variant="secondary"
              size="sm"
              onClick={() => {
                setAdding(true);
              }}
            >
              <Icon name="plus" className="size-4" />
              {t('goals.members.add')}
            </Button>
          ) : null
        }
      >
        <ul className="divide-y divide-line">
          {people.map((member) => {
            const isOwnerRow = member.role === 'owner';
            const name = personName(member);
            const joined = parseTimestamp(member.joined_at);
            const joinedDate = joined ? formatDate(joined, formatLocale, me.timezone) : null;
            return (
              <li key={member.user_id} className="space-y-3 py-3 first:pt-0 last:pb-0">
                <div className="flex items-start gap-3">
                  <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-full bg-surface-muted text-fg-muted">
                    <Icon name={isOwnerRow ? 'shield' : 'user'} className="size-4" />
                  </span>
                  <div className="min-w-0 flex-1 space-y-0.5">
                    <p className="font-medium text-fg">{name}</p>
                    <p className="text-sm text-fg-muted">
                      {[
                        t(memberRoleLabel[member.role]),
                        t(memberVisibilityLabel[member.contribution_visibility]),
                      ].join(' · ')}
                    </p>
                    {joinedDate ? (
                      <p className="text-sm text-fg-muted">
                        {isOwnerRow
                          ? t('goals.members.createdOn', { date: joinedDate })
                          : t('goals.members.joined', { date: joinedDate })}
                      </p>
                    ) : null}
                  </div>
                </div>
                {/* The owner's role is fixed and the owner cannot leave or be removed. */}
                {owner && !isOwnerRow && isMemberRole(member.role) ? (
                  <div className="flex flex-wrap items-end gap-3 ps-12">
                    <SaveableSelect
                      // Starts again from the saved role whenever it changes.
                      key={`${member.user_id}:${member.role}`}
                      label={t('goals.members.roleFor', { name: memberName(member, t) })}
                      value={member.role}
                      isValue={isMemberRole}
                      options={MEMBER_ROLES.map((value) => ({
                        value,
                        label: t(memberRoleLabel[value]),
                      }))}
                      saveLabel={t('goals.members.saveRole')}
                      pending={update.isPending}
                      onSave={(role) => {
                        changeRole(member, role);
                      }}
                    />
                    <Button
                      variant="secondary"
                      size="sm"
                      aria-label={t('goals.members.removeLabel', { name: memberName(member, t) })}
                      onClick={() => {
                        setRemoveError(null);
                        setRemoving(member);
                      }}
                    >
                      <Icon name="trash" className="size-4" />
                      {t('goals.members.removeConfirm')}
                    </Button>
                  </div>
                ) : null}
              </li>
            );
          })}
        </ul>
        {others.length === 0 && owner && !(goal.group_id && goal.visibility === 'members') ? (
          <p className="mt-3 text-sm text-fg-muted">{t('goals.members.none')}</p>
        ) : null}
        {goal.group_id && goal.visibility === 'members' ? (
          <p className="mt-4 flex items-start gap-2 text-sm text-fg-muted">
            <Icon name="users" className="mt-0.5 size-4" />
            {t('goals.members.groupNote', { group: groupName ?? t('goals.detail.group') })}
          </p>
        ) : null}
        {myMembership ? (
          <div className="mt-5 space-y-4 border-t border-line pt-5">
            <SaveableSelect
              key={myMembership.contribution_visibility}
              label={t('goals.members.myVisibility')}
              value={myMembership.contribution_visibility}
              isValue={isContributionVisibility}
              options={CONTRIBUTION_VISIBILITIES.map((value) => ({
                value,
                label: t(myVisibilityLabel[value]),
              }))}
              saveLabel={t('goals.members.saveVisibility')}
              pending={update.isPending}
              onSave={(next) => {
                update.mutate(
                  { userId: me.id, body: { contribution_visibility: next } },
                  {
                    onSuccess: () => {
                      toast.show({ tone: 'success', title: t('goals.members.myVisibilitySaved') });
                    },
                    onError: (error) => {
                      reloadIfStale(error);
                      toast.show({
                        tone: 'danger',
                        title: t('goals.members.myVisibilityFailed'),
                        description: goalErrorMessage(error, t, formatLocale),
                      });
                    },
                  },
                );
              }}
            />
            {myMembership.role === 'owner' ? (
              <p className="text-sm text-fg-muted">{t('goals.members.ownerStays')}</p>
            ) : (
              <Button
                variant="secondary"
                onClick={() => {
                  setRemoveError(null);
                  setRemoving(myMembership);
                }}
              >
                <Icon name="log-out" className="size-4" />
                {t('goals.members.leave')}
              </Button>
            )}
          </div>
        ) : null}
      </Card>
      {owner ? <AddMemberDialog goal={goal} open={adding} onOpenChange={setAdding} /> : null}
      <ConfirmDialog
        open={removing !== null}
        onOpenChange={(open) => {
          if (!open) setRemoving(null);
        }}
        title={
          leaving
            ? t('goals.members.leaveTitle')
            : t('goals.members.removeTitle', { name: removing?.display_name ?? '' })
        }
        description={leaving ? t('goals.members.leaveBody') : t('goals.members.removeBody')}
        confirmLabel={leaving ? t('goals.members.leave') : t('goals.members.removeConfirm')}
        onConfirm={confirmRemove}
        pending={remove.isPending}
        error={removeError}
      />
    </>
  );
}
