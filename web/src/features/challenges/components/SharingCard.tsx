import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useT } from '@/shared/i18n/I18nContext';
import { challengesApi } from '../api';
import { challengeErrorMessage } from '../errors';
import { challengeChanged } from '../hooks';
import type { Challenge, ChallengeParticipation, ChallengeSharing } from '../types';
import { type SharingChoice, sharingBody } from '../sharing';
import { SharingFields } from './SharingFields';

/**
 * What you share (PATCH /challenges/{id}/participation). Remounted with the
 * saved values whenever the API's answer changes them.
 */
export function SharingCard({
  challenge,
  me,
}: {
  challenge: Challenge;
  me: ChallengeParticipation;
}) {
  return (
    <SharingForm
      key={`${String(me.share_progress)}-${String(me.show_on_leaderboard)}`}
      challenge={challenge}
      me={me}
    />
  );
}

function SharingForm({ challenge, me }: { challenge: Challenge; me: ChallengeParticipation }) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [choice, setChoice] = useState<SharingChoice>({
    share: me.share_progress,
    leaderboard: me.show_on_leaderboard,
  });
  const [error, setError] = useState<string | null>(null);
  const save = useMutation({
    mutationFn: (body: ChallengeSharing) => challengesApi.updateSharing(challenge.id, body),
  });
  const body = sharingBody(choice, challenge.leaderboard_enabled);
  const unchanged =
    body.share_progress === me.share_progress &&
    (!challenge.leaderboard_enabled || body.show_on_leaderboard === me.show_on_leaderboard);

  return (
    <Card
      title={t('challenges.sharing.title')}
      description={
        me.share_progress ? t('challenges.sharing.sharedNow') : t('challenges.sharing.privateNow')
      }
    >
      <form
        className="space-y-5"
        onSubmit={(event) => {
          event.preventDefault();
          if (save.isPending || unchanged) return;
          setError(null);
          save.mutate(body, {
            onSuccess: (updated) => {
              void challengeChanged(queryClient, updated);
              toast.show({ tone: 'success', title: t('challenges.sharing.saved') });
            },
            onError: (failure) => {
              setError(challengeErrorMessage(failure, t));
            },
          });
        }}
      >
        {error ? (
          <Alert tone="danger" live="assertive">
            {error}
          </Alert>
        ) : null}
        <SharingFields
          value={choice}
          onChange={setChoice}
          leaderboardEnabled={challenge.leaderboard_enabled}
          disabled={save.isPending}
        />
        <Button type="submit" variant="secondary" loading={save.isPending} disabled={unchanged}>
          {t('challenges.sharing.save')}
        </Button>
      </form>
    </Card>
  );
}
