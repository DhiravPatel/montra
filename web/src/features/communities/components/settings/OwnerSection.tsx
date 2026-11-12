import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useT } from '@/shared/i18n/I18nContext';
import { isOwner } from '../../access';
import { communitiesApi, useCommunityMembers } from '../../api';
import { useCommunityError } from '../../errors';
import { refreshCommunity, storeCommunity } from '../../keys';
import type { Community } from '../../types';

function SubSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="space-y-3 border-t border-line pt-6 first:border-t-0 first:pt-0">
      <h3 className="text-base font-semibold text-fg">{title}</h3>
      {children}
    </div>
  );
}

function TransferOwnership({ community, reload }: { community: Community; reload: () => void }) {
  const t = useT();
  const me = useCurrentUser();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const members = useCommunityMembers(community.id, 'active');
  const [userId, setUserId] = useState('');
  const [choiceError, setChoiceError] = useState<string | null>(null);
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const transfer = useMutation({
    mutationFn: (target: string) => communitiesApi.transferOwnership(community.id, target),
    onSuccess: (updated) => {
      storeCommunity(queryClient, updated);
      void refreshCommunity(queryClient, community.id);
    },
  });

  if (members.isPending) return <LoadingState label={t('communities.settings.members.loading')} />;
  if (members.isError) {
    return (
      <ErrorState
        titleAs="p"
        title={t('communities.settings.members.error')}
        error={members.error}
        retrying={members.isFetching}
        onRetry={() => {
          void members.refetch();
        }}
      />
    );
  }

  const candidates = members.data.filter((member) => member.user_id !== me.id);
  const chosen = candidates.find((member) => member.user_id === userId);

  if (candidates.length === 0) {
    return (
      <p className="text-sm text-fg-muted">{t('communities.settings.owner.transfer.nobody')}</p>
    );
  }

  return (
    <>
      <p className="text-sm text-fg-muted">{t('communities.settings.owner.transfer.help')}</p>
      <div className="flex flex-wrap items-end gap-3">
        <Select
          className="min-w-56 flex-1"
          label={t('communities.settings.owner.transfer.to')}
          placeholder={t('communities.settings.owner.transfer.placeholder')}
          options={candidates.map((member) => ({
            value: member.user_id,
            label: member.username
              ? `${member.display_name} (@${member.username})`
              : member.display_name,
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
              setChoiceError(t('communities.settings.owner.transfer.required'));
              return;
            }
            setError(null);
            setConfirming(true);
          }}
        >
          <Icon name="key" className="size-4" />
          {t('communities.settings.owner.transfer.action')}
        </Button>
      </div>
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        tone="primary"
        title={t('communities.settings.owner.transfer.confirmTitle', {
          name: chosen?.display_name ?? '',
        })}
        description={t('communities.settings.owner.transfer.confirmBody')}
        confirmLabel={t('communities.settings.owner.transfer.confirm')}
        pending={transfer.isPending}
        error={error}
        onConfirm={() => {
          if (!chosen || transfer.isPending) return;
          setError(null);
          transfer.mutate(chosen.user_id, {
            onSuccess: () => {
              toast.show({
                tone: 'success',
                title: t('communities.settings.owner.transfer.done', { name: chosen.display_name }),
              });
              setConfirming(false);
              setUserId('');
            },
            onError: (failure) => {
              setError(
                describe(failure, {
                  codes: { NOT_FOUND: 'communities.settings.members.notMember' },
                }),
              );
              if (hasErrorCode(failure, 'FORBIDDEN')) reload();
            },
          });
        }}
      />
    </>
  );
}

function ArchiveRestore({ community, reload }: { community: Community; reload: () => void }) {
  const t = useT();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const archived = community.status === 'archived';
  const change = useMutation({
    mutationFn: () =>
      archived ? communitiesApi.restore(community.id) : communitiesApi.archive(community.id),
    onSuccess: (updated) => {
      storeCommunity(queryClient, updated);
      void refreshCommunity(queryClient, community.id);
    },
  });

  const run = () => {
    if (change.isPending) return;
    setError(null);
    change.mutate(undefined, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title: archived
            ? t('communities.settings.owner.restore.done')
            : t('communities.settings.owner.archive.done'),
        });
        setConfirming(false);
      },
      onError: (failure) => {
        const message = describe(failure);
        if (confirming) setError(message);
        else {
          toast.show({
            tone: 'danger',
            title: t('communities.settings.owner.failed'),
            description: message,
          });
        }
        if (hasErrorCode(failure, 'FORBIDDEN')) reload();
      },
    });
  };

  if (community.status === 'suspended') {
    return <p className="text-sm text-fg-muted">{t('communities.rule.community_suspended')}</p>;
  }

  if (archived) {
    return (
      <>
        <p className="text-sm text-fg-muted">{t('communities.settings.owner.restore.help')}</p>
        <Button variant="secondary" loading={change.isPending} onClick={run}>
          <Icon name="archive-restore" className="size-4" />
          {t('communities.settings.owner.restore.action')}
        </Button>
      </>
    );
  }

  return (
    <>
      <p className="text-sm text-fg-muted">{t('communities.settings.owner.archive.help')}</p>
      <Button
        variant="secondary"
        onClick={() => {
          setError(null);
          setConfirming(true);
        }}
      >
        <Icon name="archive" className="size-4" />
        {t('communities.settings.owner.archive.action')}
      </Button>
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        title={t('communities.settings.owner.archive.confirmTitle', { name: community.name })}
        description={t('communities.settings.owner.archive.confirmBody')}
        confirmLabel={t('communities.settings.owner.archive.confirm')}
        pending={change.isPending}
        error={error}
        onConfirm={run}
      />
    </>
  );
}

/** Ownership and the community's lifecycle (owner only). */
export function OwnerSection({ community, reload }: { community: Community; reload: () => void }) {
  const t = useT();
  if (!isOwner(community)) return null;
  return (
    <Card
      title={t('communities.settings.owner.title')}
      description={t('communities.settings.owner.description')}
    >
      <div className="space-y-6">
        <SubSection title={t('communities.settings.owner.transfer.title')}>
          <TransferOwnership community={community} reload={reload} />
        </SubSection>
        <SubSection
          title={
            community.status === 'archived'
              ? t('communities.settings.owner.restore.title')
              : t('communities.settings.owner.archive.title')
          }
        >
          <ArchiveRestore community={community} reload={reload} />
        </SubSection>
      </div>
    </Card>
  );
}
