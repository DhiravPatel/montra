import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Card } from '@/shared/components/Card';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useT } from '@/shared/i18n/I18nContext';
import { isOwner } from '../../access';
import { communitiesApi } from '../../api';
import { communitiesKeys, storeCommunity } from '../../keys';
import type { Community, CommunityPatch } from '../../types';
import { communityValues, hasPatchChanges, toCommunityPatch } from '../../communityFormValues';
import { CommunityForm } from '../CommunityForm';

/**
 * Name, description, rules and topics (moderators) and who can join (the
 * owner). Only the fields that changed are sent, with the community's
 * `version`: when someone else saved first (409), the latest community is
 * loaded and the form starts again from it.
 */
export function DetailsSection({
  community,
  reload,
}: {
  community: Community;
  reload: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const owner = isOwner(community);
  const [conflict, setConflict] = useState(false);
  const update = useMutation({
    mutationFn: (patch: CommunityPatch) => communitiesApi.update(community.id, patch),
    onSuccess: (updated) => {
      storeCommunity(queryClient, updated);
      void queryClient.invalidateQueries({ queryKey: communitiesKeys.lists() });
    },
  });

  return (
    <Card
      title={t('communities.settings.details.title')}
      description={t('communities.settings.details.description')}
    >
      <div className="space-y-5">
        <p className="text-sm text-fg-muted">
          {t('communities.settings.details.slug', { slug: community.slug })}
        </p>
        {conflict ? (
          <Alert tone="warning" live="polite" title={t('finance.conflict.title')}>
            {t('communities.settings.details.conflictBody')}
          </Alert>
        ) : null}
        <CommunityForm
          // Every saved change moves the version: the form restarts from the latest community.
          key={community.version}
          mode="edit"
          initialValues={communityValues(community)}
          canChangeVisibility={owner}
          submitLabel={t('communities.settings.details.save')}
          onSubmit={async (values) => {
            if (update.isPending) return;
            const patch = toCommunityPatch(community, values);
            if (!hasPatchChanges(patch)) {
              toast.show({ tone: 'info', title: t('communities.settings.details.unchanged') });
              return;
            }
            try {
              await update.mutateAsync(patch);
            } catch (error) {
              if (hasErrorCode(error, 'VERSION_CONFLICT')) {
                // The notice above explains it; the reloaded community restarts the form.
                setConflict(true);
                reload();
                return;
              }
              if (hasErrorCode(error, 'FORBIDDEN') || hasErrorCode(error, 'NOT_FOUND')) reload();
              throw error;
            }
            setConflict(false);
            toast.show({ tone: 'success', title: t('communities.settings.details.saved') });
          }}
        />
      </div>
    </Card>
  );
}
