import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { useToast } from '@/shared/components/toast/ToastContext';
import { challengePath, paths } from '@/shared/config/paths';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { challengesApi } from '../api';
import { BackToChallenges } from '../components/BackLink';
import { ChallengeCreateForm } from '../components/ChallengeCreateForm';
import { emptyCreateValues } from '../formValues';
import { challengeChanged } from '../hooks';
import type { ChallengeInput, ChallengeSharing } from '../types';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function idParam(value: string | null): string | null {
  return value && UUID.test(value) ? value : null;
}

/**
 * New challenge. `?group_id=` or `?community_id=` (IDs only) start it for
 * that group or community, e.g. when opened from a group page.
 */
export function ChallengeCreatePage() {
  const t = useT();
  useDocumentTitle(t('challenges.create.title'));
  const user = useCurrentUser();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [params] = useSearchParams();
  const today = todayInTimeZone(user.timezone);
  const [initialValues] = useState(() =>
    emptyCreateValues(today, {
      groupId: idParam(params.get('group_id')),
      communityId: idParam(params.get('community_id')),
    }),
  );
  const create = useMutation({
    mutationFn: (input: ChallengeInput) => challengesApi.create(input),
  });

  const submit = async (input: ChallengeInput, sharing: ChallengeSharing | null) => {
    if (create.isPending) return;
    const challenge = await create.mutateAsync(input);
    void challengeChanged(queryClient, challenge);
    let sharingSaved = true;
    if (sharing) {
      // A second request: the create itself always starts with your progress private.
      try {
        void challengeChanged(
          queryClient,
          await challengesApi.updateSharing(challenge.id, sharing),
        );
      } catch {
        sharingSaved = false;
      }
    }
    if (sharingSaved) {
      toast.show({ tone: 'success', title: t('challenges.create.done') });
    } else {
      toast.show({
        tone: 'warning',
        title: t('challenges.create.done'),
        description: t('challenges.create.sharingFailed'),
      });
    }
    void navigate(challengePath(challenge.id));
  };

  return (
    <>
      <BackToChallenges />
      <PageHeader
        title={t('challenges.create.title')}
        description={t('challenges.create.description')}
      />
      <Card>
        <ChallengeCreateForm
          initialValues={initialValues}
          today={today}
          staff={user.platform_role !== 'user'}
          onSubmit={submit}
          secondaryAction={
            <ButtonLink to={paths.challenges} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
        />
      </Card>
    </>
  );
}
