import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { useToast } from '@/shared/components/toast/ToastContext';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { communitiesApi, useModerationActions } from '../../api';
import { useCommunityError } from '../../errors';
import { communitiesKeys } from '../../keys';
import { REVERSIBLE, actionDoneName, appealStatusLabel, targetName } from '../../labels';
import type { Community, ModerationAction } from '../../types';
import { NoteConfirmDialog } from './NoteConfirmDialog';
import { useMemberNames } from './useMemberNames';

const PAGE = 20;
const NOTE_MAX = 500;

/**
 * Every moderation action in this community, newest first: who acted (or
 * "automatic" after several reports), on what, why, until when, and
 * whether it was reversed. Reversing keeps the record.
 */
export function ActionLogSection({ community }: { community: Community }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const actions = useModerationActions(community.id);
  const nameOf = useMemberNames(community.id);
  const [shown, setShown] = useState(PAGE);
  const [reversing, setReversing] = useState<ModerationAction | null>(null);
  const [error, setError] = useState<string | null>(null);
  const reverse = useMutation({
    mutationFn: ({ action, note }: { action: ModerationAction; note: string }) =>
      communitiesApi.reverseAction(action.id, note),
    onSettled: (_result, _error, { action }) =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: communitiesKeys.moderation(community.id) }),
        queryClient.invalidateQueries({ queryKey: communitiesKeys.feedOf(community.id) }),
        queryClient.invalidateQueries({ queryKey: communitiesKeys.membersOf(community.id) }),
        action.target_type === 'post'
          ? queryClient.invalidateQueries({ queryKey: communitiesKeys.post(action.target_id) })
          : null,
      ]),
  });

  const date = (value: string | undefined) => {
    const parsed = parseTimestamp(value);
    return parsed ? formatDateTime(parsed, formatLocale, user.timezone) : null;
  };

  let content;
  if (actions.isPending) {
    content = <LoadingState label={t('communities.mod.log.loading')} />;
  } else if (actions.isError) {
    content = (
      <ErrorState
        titleAs="p"
        title={t('communities.mod.log.error')}
        error={actions.error}
        retrying={actions.isFetching}
        onRetry={() => {
          void actions.refetch();
        }}
      />
    );
  } else if (actions.data.length === 0) {
    content = <EmptyState titleAs="p" icon="history" title={t('communities.mod.log.empty')} />;
  } else {
    content = (
      <>
        <ul className="divide-y divide-line">
          {actions.data.slice(0, shown).map((action) => {
            const done = actionDoneName(action.action, t);
            const target = targetName(action.target_type, t);
            const created = date(action.created_at);
            const expires = date(action.expires_at);
            const reversed = date(action.reversed_at);
            const by = action.moderator_id
              ? t('communities.mod.log.by', { name: nameOf(action.moderator_id) })
              : t('communities.mod.log.automatic');
            const appeal = action.appeal;
            const appealLabel = appeal ? appealStatusLabel[appeal.status] : undefined;
            return (
              <li key={action.id} className="space-y-2 py-4 first:pt-0 last:pb-0">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-medium text-fg">
                    {t('communities.mod.log.heading', { action: done, target })}
                  </span>
                  {reversed ? (
                    <StatusBadge tone="neutral" icon="undo">
                      {t('communities.mod.log.reversed', { date: reversed })}
                    </StatusBadge>
                  ) : null}
                </div>
                <p className="text-sm text-fg-muted">{[by, created].filter(Boolean).join(' · ')}</p>
                {action.target_user_id ? (
                  <p className="text-sm text-fg">
                    {t('communities.mod.log.affected', { name: nameOf(action.target_user_id) })}
                  </p>
                ) : null}
                {action.reason ? (
                  <p className="text-sm break-words text-fg">
                    {t('communities.mod.log.reason', { reason: action.reason })}
                  </p>
                ) : null}
                {expires && !reversed ? (
                  <p className="text-sm text-fg-muted">
                    {t('communities.mod.log.until', { date: expires })}
                  </p>
                ) : null}
                {appeal && appealLabel ? (
                  <p className="text-sm text-fg-muted">
                    {t('communities.mod.log.appeal', { status: t(appealLabel) })}
                    {appeal.decision_note
                      ? ` ${t('communities.mod.log.appealNote', { note: appeal.decision_note })}`
                      : ''}
                  </p>
                ) : null}
                {REVERSIBLE.has(action.action) && !action.reversed_at ? (
                  <Button
                    size="sm"
                    variant="secondary"
                    aria-label={t('communities.mod.log.reverseNamed', { action: done, target })}
                    onClick={() => {
                      setError(null);
                      setReversing(action);
                    }}
                  >
                    <Icon name="undo" className="size-4" />
                    {t('communities.mod.log.reverse')}
                  </Button>
                ) : null}
              </li>
            );
          })}
        </ul>
        {actions.data.length > shown ? (
          <div className="mt-4 flex justify-center">
            <Button
              variant="secondary"
              onClick={() => {
                setShown((count) => count + PAGE);
              }}
            >
              {t('communities.mod.log.more')}
            </Button>
          </div>
        ) : null}
      </>
    );
  }

  return (
    <Card title={t('communities.mod.log.title')} description={t('communities.mod.log.description')}>
      {content}
      <NoteConfirmDialog
        key={reversing?.id ?? 'none'}
        open={reversing !== null}
        onOpenChange={(open) => {
          if (!open) setReversing(null);
        }}
        title={t('communities.mod.log.reverseTitle', {
          action: reversing ? actionDoneName(reversing.action, t) : '',
        })}
        description={t('communities.mod.log.reverseBody')}
        noteLabel={t('communities.mod.log.reverseNote')}
        noteHelp={t('communities.mod.log.reverseNoteHelp')}
        noteMax={NOTE_MAX}
        confirmLabel={t('communities.mod.log.reverseConfirm')}
        pending={reverse.isPending}
        error={error}
        onConfirm={(note) => {
          if (!reversing || reverse.isPending) return;
          setError(null);
          reverse.mutate(
            { action: reversing, note },
            {
              onSuccess: () => {
                toast.show({ tone: 'success', title: t('communities.mod.log.reverseDone') });
                setReversing(null);
              },
              onError: (failure) => {
                if (hasErrorCode(failure, 'CONFLICT')) {
                  toast.show({ tone: 'info', title: t('communities.mod.log.alreadyReversed') });
                  setReversing(null);
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
