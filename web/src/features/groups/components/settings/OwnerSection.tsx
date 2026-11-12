import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useState } from 'react';
import { useNavigate } from 'react-router';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { groupBalancesPath } from '@/shared/config/paths';
import { domainRuleCode } from '@/shared/finance/domainErrors';
import { useT } from '@/shared/i18n/I18nContext';
import { groupsApi } from '../../api';
import { groupErrorMessage, shouldReloadGroup } from '../../errors';
import { groupsKeys, refreshGroups } from '../../keys';
import { leaveGroupPage } from '../../navigation';
import { memberName } from '../../people';
import type { Group, GroupDetail } from '../../types';

/** Ownership and the group's lifecycle: transfer, archive or restore, delete (owner only). */
export function OwnerSection({ group, reload }: { group: GroupDetail; reload: () => void }) {
  const t = useT();
  if (group.my_role !== 'owner') return null;
  return (
    <Card title={t('groups.owner.title')} description={t('groups.owner.description')}>
      <div className="space-y-8">
        <TransferOwnership group={group} reload={reload} />
        <ArchiveRestore group={group} reload={reload} />
        <DeleteGroup group={group} reload={reload} />
      </div>
    </Card>
  );
}

function SubSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="space-y-3 border-t border-line pt-6 first:border-t-0 first:pt-0">
      <h3 className="text-base font-semibold text-fg">{title}</h3>
      {children}
    </div>
  );
}

function TransferOwnership({ group, reload }: { group: GroupDetail; reload: () => void }) {
  const t = useT();
  const me = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [userId, setUserId] = useState('');
  const [choiceError, setChoiceError] = useState<string | null>(null);
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const transfer = useMutation({
    mutationFn: (target: string) => groupsApi.transferOwnership(group.id, target),
    onSuccess: (updated) => {
      queryClient.setQueryData(groupsKeys.group(updated.id), updated);
      void refreshGroups(queryClient);
    },
  });
  const candidates = group.members.filter(
    (member) => member.status === 'active' && member.user_id !== me.id,
  );
  const chosen = candidates.find((member) => member.user_id === userId);

  if (candidates.length === 0) {
    return (
      <SubSection title={t('groups.owner.transfer.title')}>
        <p className="text-sm text-fg-muted">{t('groups.owner.transfer.nobody')}</p>
      </SubSection>
    );
  }

  return (
    <SubSection title={t('groups.owner.transfer.title')}>
      <p className="text-sm text-fg-muted">{t('groups.owner.transfer.help')}</p>
      <div className="flex flex-wrap items-end gap-3">
        <Select
          className="min-w-56 flex-1"
          label={t('groups.owner.transfer.to')}
          placeholder={t('groups.owner.transfer.placeholder')}
          options={candidates.map((member) => ({
            value: member.user_id,
            label: memberName(member),
          }))}
          value={userId}
          error={choiceError ?? undefined}
          onChange={(event) => {
            setUserId(event.target.value);
            setChoiceError(null);
          }}
        />
        <Button
          variant="secondary"
          onClick={() => {
            if (!chosen) {
              setChoiceError(t('groups.owner.transfer.required'));
              return;
            }
            setError(null);
            setConfirming(true);
          }}
        >
          <Icon name="key" className="size-4" />
          {t('groups.owner.transfer.action')}
        </Button>
      </div>
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        tone="primary"
        title={t('groups.owner.transfer.confirmTitle', { name: chosen?.display_name ?? '' })}
        description={t('groups.owner.transfer.confirmBody')}
        confirmLabel={t('groups.owner.transfer.confirm')}
        pending={transfer.isPending}
        error={error}
        onConfirm={() => {
          if (!chosen || transfer.isPending) return;
          setError(null);
          transfer.mutate(chosen.user_id, {
            onSuccess: () => {
              toast.show({
                tone: 'success',
                title: t('groups.owner.transfer.done', { name: chosen.display_name }),
              });
              setConfirming(false);
              setUserId('');
            },
            onError: (failure) => {
              setError(groupErrorMessage(failure, t));
              if (shouldReloadGroup(failure)) reload();
            },
          });
        }}
      />
    </SubSection>
  );
}

function ArchiveRestore({ group, reload }: { group: GroupDetail; reload: () => void }) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const archived = group.status === 'archived';
  const change = useMutation({
    mutationFn: (): Promise<Group> =>
      archived ? groupsApi.restore(group.id) : groupsApi.archive(group.id),
    // Archiving pauses the group's recurring bills (personal calendars change).
    onSuccess: () => refreshGroups(queryClient, { personal: true }),
  });

  const run = () => {
    if (change.isPending) return;
    setError(null);
    change.mutate(undefined, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title: archived ? t('groups.owner.restore.done') : t('groups.owner.archive.done'),
        });
        setConfirming(false);
      },
      onError: (failure) => {
        const message = groupErrorMessage(failure, t, {
          codes: { CONFLICT: 'groups.owner.restore.notArchived' },
        });
        if (confirming) setError(message);
        else toast.show({ tone: 'danger', title: t('groups.owner.failed'), description: message });
        if (shouldReloadGroup(failure)) reload();
      },
    });
  };

  if (archived) {
    return (
      <SubSection title={t('groups.owner.restore.title')}>
        <p className="text-sm text-fg-muted">{t('groups.owner.restore.help')}</p>
        <Button variant="secondary" loading={change.isPending} onClick={run}>
          <Icon name="archive-restore" className="size-4" />
          {t('groups.owner.restore.action')}
        </Button>
      </SubSection>
    );
  }

  return (
    <SubSection title={t('groups.owner.archive.title')}>
      <p className="text-sm text-fg-muted">{t('groups.owner.archive.help')}</p>
      <Button
        variant="secondary"
        onClick={() => {
          setError(null);
          setConfirming(true);
        }}
      >
        <Icon name="archive" className="size-4" />
        {t('groups.owner.archive.action')}
      </Button>
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        title={t('groups.owner.archive.confirmTitle', { name: group.name })}
        description={t('groups.owner.archive.confirmBody')}
        confirmLabel={t('groups.owner.archive.confirm')}
        pending={change.isPending}
        error={error}
        onConfirm={run}
      />
    </SubSection>
  );
}

function DeleteGroup({ group, reload }: { group: GroupDetail; reload: () => void }) {
  const t = useT();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  /** Open balances block deleting: shown outside the dialog with a way to settle up. */
  const [blocked, setBlocked] = useState(false);
  const remove = useMutation({ mutationFn: () => groupsApi.remove(group.id) });

  const run = () => {
    if (remove.isPending) return;
    setError(null);
    setBlocked(false);
    remove.mutate(undefined, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('groups.owner.delete.done') });
        setConfirming(false);
        void leaveGroupPage(navigate, () => {
          // The group is gone: drop it instead of refetching a 404.
          queryClient.removeQueries({ queryKey: groupsKeys.group(group.id) });
          void refreshGroups(queryClient, { personal: true });
        });
      },
      onError: (failure) => {
        if (domainRuleCode(failure)?.code === 'balances_open') {
          setConfirming(false);
          setBlocked(true);
          return;
        }
        setError(groupErrorMessage(failure, t));
        if (shouldReloadGroup(failure)) reload();
      },
    });
  };

  return (
    <SubSection title={t('groups.owner.delete.title')}>
      <p className="text-sm text-fg-muted">{t('groups.owner.delete.help')}</p>
      {blocked ? (
        <Alert tone="warning" live="assertive" title={t('groups.owner.delete.blockedTitle')}>
          <p>{t('groups.rule.balances_open')}</p>
          <TextLink to={groupBalancesPath(group.id)}>
            {t('groups.owner.delete.balancesLink')}
          </TextLink>
        </Alert>
      ) : null}
      <Button
        variant="danger"
        onClick={() => {
          setError(null);
          setConfirming(true);
        }}
      >
        <Icon name="trash" className="size-4" />
        {t('groups.owner.delete.action')}
      </Button>
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        title={t('groups.owner.delete.confirmTitle', { name: group.name })}
        description={t('groups.owner.delete.confirmBody')}
        confirmLabel={t('groups.owner.delete.confirm')}
        pending={remove.isPending}
        error={error}
        onConfirm={run}
      />
    </SubSection>
  );
}
