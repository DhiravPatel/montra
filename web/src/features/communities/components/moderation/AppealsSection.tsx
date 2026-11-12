import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { isStaff } from '../../access';
import { communitiesApi, useModerationActions, useModerationAppeals } from '../../api';
import { useCommunityError } from '../../errors';
import { communitiesKeys } from '../../keys';
import { actionDoneName, targetName } from '../../labels';
import type { Appeal, AppealDecision, Community } from '../../types';
import { UserTextExcerpt } from '../UserText';
import { NoteConfirmDialog } from './NoteConfirmDialog';
import { useMemberNames } from './useMemberNames';

const NOTE_MAX = 1000;

interface Deciding {
  appeal: Appeal;
  decision: AppealDecision;
}

/**
 * Open appeals against this community's actions, each with the action it
 * is against (as the appeal carries it). Another moderator than the one
 * who acted decides; overturning reverses the action.
 */
export function AppealsSection({ community }: { community: Community }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const appeals = useModerationAppeals(community.id);
  const actions = useModerationActions(community.id);
  const nameOf = useMemberNames(community.id);
  const [deciding, setDeciding] = useState<Deciding | null>(null);
  const [error, setError] = useState<string | null>(null);
  const decide = useMutation({
    mutationFn: ({ appeal, decision, note }: Deciding & { note: string }) =>
      communitiesApi.decideAppeal(appeal.id, decision, note),
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: communitiesKeys.moderation(community.id) }),
        queryClient.invalidateQueries({ queryKey: communitiesKeys.feedOf(community.id) }),
      ]),
  });

  let content;
  if (appeals.isPending) {
    content = <LoadingState label={t('communities.mod.appeals.loading')} />;
  } else if (appeals.isError) {
    content = (
      <ErrorState
        titleAs="p"
        title={t('communities.mod.appeals.error')}
        error={appeals.error}
        retrying={appeals.isFetching}
        onRetry={() => {
          void appeals.refetch();
        }}
      />
    );
  } else if (appeals.data.length === 0) {
    content = (
      <EmptyState titleAs="p" icon="check-circle" title={t('communities.mod.appeals.empty')} />
    );
  } else {
    // The appeal carries the action it is against; the log adds who acted.
    const moderatorOf = new Map(
      (actions.data ?? []).map((action) => [action.id, action.moderator_id]),
    );
    content = (
      <ul className="divide-y divide-line">
        {appeals.data.map((appeal) => {
          const action = appeal.action;
          const created = parseTimestamp(appeal.created_at);
          const reversed = parseTimestamp(action.reversed_at);
          const what = t('communities.mod.log.heading', {
            action: actionDoneName(action.action, t),
            target: targetName(action.target_type, t),
          });
          // Another moderator decides appeals against your action (Montra staff may decide any).
          const mineAction = moderatorOf.get(appeal.action_id) === user.id && !isStaff(user);
          return (
            <li key={appeal.id} className="space-y-3 py-4 first:pt-0 last:pb-0">
              <p className="font-medium text-fg">
                {t('communities.mod.appeals.against', { what })}
              </p>
              <p className="text-sm text-fg-muted">
                {[
                  action.target_user_id
                    ? t('communities.mod.appeals.from', { name: nameOf(action.target_user_id) })
                    : null,
                  created
                    ? t('communities.mod.appeals.created', {
                        date: formatDateTime(created, formatLocale, user.timezone),
                      })
                    : null,
                  reversed
                    ? t('communities.mod.log.reversed', {
                        date: formatDateTime(reversed, formatLocale, user.timezone),
                      })
                    : null,
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </p>
              {action.reason ? (
                <p className="text-sm break-words text-fg">
                  {t('communities.mod.log.reason', { reason: action.reason })}
                </p>
              ) : null}
              <blockquote className="border-s-4 border-line ps-3">
                <p className="text-sm font-medium text-fg-muted">
                  {t('communities.mod.appeals.statement')}
                </p>
                <UserTextExcerpt text={appeal.statement} maxChars={2000} className="text-sm" />
              </blockquote>
              {mineAction ? (
                <p className="text-sm text-fg-muted">{t('communities.mod.appeals.yours')}</p>
              ) : (
                <div className="flex flex-wrap gap-2">
                  <Button
                    size="sm"
                    variant="secondary"
                    onClick={() => {
                      setError(null);
                      setDeciding({ appeal, decision: 'upheld' });
                    }}
                  >
                    <Icon name="check" className="size-4" />
                    {t('communities.mod.appeals.uphold')}
                  </Button>
                  <Button
                    size="sm"
                    variant="secondary"
                    onClick={() => {
                      setError(null);
                      setDeciding({ appeal, decision: 'overturned' });
                    }}
                  >
                    <Icon name="undo" className="size-4" />
                    {t('communities.mod.appeals.overturn')}
                  </Button>
                </div>
              )}
            </li>
          );
        })}
      </ul>
    );
  }

  const overturn = deciding?.decision === 'overturned';
  return (
    <Card
      title={t('communities.mod.appeals.title')}
      description={t('communities.mod.appeals.description')}
    >
      {content}
      <NoteConfirmDialog
        key={deciding ? `${deciding.appeal.id}:${deciding.decision}` : 'none'}
        open={deciding !== null}
        onOpenChange={(open) => {
          if (!open) setDeciding(null);
        }}
        title={
          overturn
            ? t('communities.mod.appeals.overturnTitle')
            : t('communities.mod.appeals.upholdTitle')
        }
        description={
          overturn
            ? t('communities.mod.appeals.overturnBody')
            : t('communities.mod.appeals.upholdBody')
        }
        noteLabel={t('communities.mod.appeals.note')}
        noteHelp={t('communities.mod.appeals.noteHelp')}
        noteMax={NOTE_MAX}
        confirmLabel={
          overturn ? t('communities.mod.appeals.overturn') : t('communities.mod.appeals.uphold')
        }
        pending={decide.isPending}
        error={error}
        onConfirm={(note) => {
          if (!deciding || decide.isPending) return;
          setError(null);
          decide.mutate(
            { ...deciding, note },
            {
              onSuccess: () => {
                toast.show({
                  tone: 'success',
                  title: overturn
                    ? t('communities.mod.appeals.overturned')
                    : t('communities.mod.appeals.upheld'),
                });
                setDeciding(null);
              },
              onError: (failure) => {
                if (hasErrorCode(failure, 'CONFLICT')) {
                  toast.show({ tone: 'info', title: t('communities.mod.appeals.alreadyDecided') });
                  setDeciding(null);
                  return;
                }
                setError(describe(failure));
              },
            },
          );
        }}
      />
    </Card>
  );
}
