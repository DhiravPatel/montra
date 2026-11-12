import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { useToast } from '@/shared/components/toast/ToastContext';
import { communityPath } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { challengesApi } from '../api';
import { challengeRuleCode, joinErrorMessage } from '../errors';
import { challengeChanged, challengeStale } from '../hooks';
import type { Challenge, ChallengeSharing } from '../types';
import { type SharingChoice, sharingBody } from '../sharing';
import { SharingFields } from './SharingFields';

/** Joining is optional and private by default: both sharing choices start off. */
export function JoinDialog({
  challenge,
  open,
  onOpenChange,
}: {
  challenge: Challenge;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [choice, setChoice] = useState<SharingChoice>({ share: false, leaderboard: false });
  const [error, setError] = useState<unknown>(null);
  const join = useMutation({
    mutationFn: (body: ChallengeSharing) => challengesApi.join(challenge.id, body),
  });
  const rejoin = challenge.me?.status === 'left';

  const close = (next: boolean) => {
    if (!next) {
      setChoice({ share: false, leaderboard: false });
      setError(null);
    }
    onOpenChange(next);
  };

  const submit = () => {
    if (join.isPending) return;
    setError(null);
    join.mutate(sharingBody(choice, challenge.leaderboard_enabled), {
      onSuccess: (updated) => {
        void challengeChanged(queryClient, updated);
        toast.show({ tone: 'success', title: t('challenges.join.done') });
        close(false);
      },
      onError: (failure) => {
        setError(failure);
        // Already joined (409) or no longer open: show the latest state behind the dialog.
        if (
          challengeRuleCode(failure) === 'challenge_not_open' ||
          hasErrorCode(failure, 'CONFLICT')
        ) {
          void challengeStale(queryClient, challenge.id);
        }
      },
    });
  };

  const needsCommunity = challengeRuleCode(error) === 'join_community_first';

  return (
    <Dialog
      open={open}
      onOpenChange={close}
      title={rejoin ? t('challenges.join.rejoinTitle') : t('challenges.join.title')}
      description={t('challenges.join.description')}
      busy={join.isPending}
    >
      <div className="space-y-5">
        {error ? (
          <Alert tone="danger" live="assertive">
            <p>{joinErrorMessage(error, t)}</p>
            {needsCommunity && challenge.community_id ? (
              <p>
                <ButtonLink
                  to={communityPath(challenge.community_id)}
                  variant="secondary"
                  size="sm"
                >
                  {t('challenges.join.openCommunity')}
                </ButtonLink>
              </p>
            ) : null}
          </Alert>
        ) : null}
        {challenge.visibility === 'private' ? null : (
          <SharingFields
            value={choice}
            onChange={setChoice}
            leaderboardEnabled={challenge.leaderboard_enabled}
            disabled={join.isPending}
          />
        )}
        <p className="text-sm text-fg-muted">{t('challenges.join.changeLater')}</p>
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button
            variant="secondary"
            disabled={join.isPending}
            onClick={() => {
              close(false);
            }}
          >
            {t('common.cancel')}
          </Button>
          <Button loading={join.isPending} onClick={submit}>
            {rejoin ? t('challenges.join.rejoinSubmit') : t('challenges.join.submit')}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}
