import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { useToast } from '@/shared/components/toast/ToastContext';
import { communityPath, paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { communitiesApi } from '../api';
import { BackToCommunities } from '../components/CommunityGate';
import { emptyCommunityValues, toCommunityInput } from '../communityFormValues';
import { CommunityForm } from '../components/CommunityForm';
import { communitiesKeys, storeCommunity } from '../keys';
import type { CommunityInput } from '../types';

/** Creates a community; the creator becomes its owner. */
export function CommunityCreatePage() {
  const t = useT();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  useDocumentTitle(t('communities.create.title'));
  const create = useMutation({
    mutationFn: (body: CommunityInput) => communitiesApi.create(body),
    onSuccess: (community) => {
      storeCommunity(queryClient, community);
      void queryClient.invalidateQueries({ queryKey: communitiesKeys.lists() });
    },
  });

  return (
    <>
      <BackToCommunities />
      <PageHeader
        title={t('communities.create.title')}
        description={t('communities.create.description')}
      />
      <Card>
        <CommunityForm
          mode="create"
          initialValues={emptyCommunityValues}
          canChangeVisibility
          submitLabel={t('communities.create.submit')}
          secondaryAction={
            <ButtonLink to={paths.communities} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onSubmit={async (values) => {
            if (create.isPending) return;
            const community = await create.mutateAsync(toCommunityInput(values));
            toast.show({
              tone: 'success',
              title: t('communities.create.done', { name: community.name }),
            });
            void navigate(communityPath(community.id));
          }}
        />
      </Card>
    </>
  );
}
