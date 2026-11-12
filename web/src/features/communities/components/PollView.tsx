import { useMutation } from '@tanstack/react-query';
import { type SubmitEvent, useId, useState } from 'react';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { useToast } from '@/shared/components/toast/ToastContext';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { communitiesApi } from '../api';
import { useCommunityError } from '../errors';
import type { Poll } from '../types';

function percentOf(votes: number, total: number): number {
  return total > 0 ? Math.round((votes / total) * 100) : 0;
}

/**
 * A poll with its aggregate results (no one sees who voted for what).
 * Voting again replaces your earlier vote until the poll closes. Results
 * are words and numbers; the bars only repeat them.
 */
export function PollView({
  postId,
  poll,
  canVote,
  onVoted,
}: {
  postId: string;
  poll: Poll;
  /** Active member of an active community, and the post is published. */
  canVote: boolean;
  onVoted: (poll: Poll) => void;
}) {
  // Restart the choice from the saved vote whenever it changes.
  return (
    <PollForm
      key={`${poll.id}:${poll.my_votes.join(',')}`}
      postId={postId}
      poll={poll}
      canVote={canVote}
      onVoted={onVoted}
    />
  );
}

function PollForm({
  postId,
  poll,
  canVote,
  onVoted,
}: {
  postId: string;
  poll: Poll;
  canVote: boolean;
  onVoted: (poll: Poll) => void;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const describe = useCommunityError();
  const legendId = useId();
  const [choice, setChoice] = useState<string[]>(poll.my_votes);
  const [error, setError] = useState<string | null>(null);
  const vote = useMutation({ mutationFn: (ids: string[]) => communitiesApi.vote(postId, ids) });
  const closes = parseTimestamp(poll.closes_at);
  const voted = poll.my_votes.length > 0;
  const open = !poll.closed && canVote;
  const multiple = poll.allow_multiple;

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (vote.isPending || !open) return;
    if (choice.length === 0) {
      setError(multiple ? t('communities.poll.chooseSome') : t('communities.poll.chooseOne'));
      return;
    }
    setError(null);
    vote.mutate(choice, {
      onSuccess: (updated) => {
        onVoted(updated);
        toast.show({ tone: 'success', title: t('communities.poll.saved') });
      },
      onError: (failure) => {
        setError(describe(failure));
      },
    });
  };

  const toggle = (optionId: string, checked: boolean) => {
    setError(null);
    if (!multiple) {
      setChoice([optionId]);
      return;
    }
    setChoice((current) =>
      checked ? [...current, optionId] : current.filter((id) => id !== optionId),
    );
  };

  const statusLine = poll.closed
    ? closes
      ? t('communities.poll.closedOn', {
          date: formatDateTime(closes, formatLocale, user.timezone),
        })
      : t('communities.poll.closed')
    : closes
      ? t('communities.poll.closesOn', {
          date: formatDateTime(closes, formatLocale, user.timezone),
        })
      : null;

  return (
    <form noValidate onSubmit={submit} className="space-y-4 rounded-lg border border-line p-4">
      <fieldset aria-describedby={`${legendId}-status`} className="space-y-3">
        <legend className="mb-1 font-semibold break-words text-fg">{poll.question}</legend>
        <p id={`${legendId}-status`} className="text-sm text-fg-muted">
          {[
            multiple ? t('communities.poll.multiple') : t('communities.poll.single'),
            t('communities.poll.total', { count: poll.total_votes }),
            statusLine,
          ]
            .filter(Boolean)
            .join(' · ')}
        </p>
        <ul className="space-y-3">
          {poll.options.map((option) => {
            const percent = percentOf(option.votes, poll.total_votes);
            const mineVote = poll.my_votes.includes(option.id);
            const results = t('communities.poll.result', { count: option.votes, percent });
            return (
              <li key={option.id} className="space-y-1.5">
                <div className="flex items-start gap-3">
                  <input
                    id={`${legendId}-${option.id}`}
                    type={multiple ? 'checkbox' : 'radio'}
                    name={`poll-${poll.id}`}
                    value={option.id}
                    checked={choice.includes(option.id)}
                    disabled={!open}
                    aria-describedby={`${legendId}-${option.id}-result`}
                    onChange={(event) => {
                      toggle(option.id, event.target.checked);
                    }}
                    className="mt-1 size-4 shrink-0 accent-accent"
                  />
                  <div className="min-w-0 flex-1">
                    <label
                      htmlFor={`${legendId}-${option.id}`}
                      className={
                        open ? 'cursor-pointer break-words text-fg' : 'break-words text-fg'
                      }
                    >
                      {option.label}
                    </label>
                    <p
                      id={`${legendId}-${option.id}-result`}
                      className="flex flex-wrap items-center gap-1 text-sm text-fg-muted"
                    >
                      {mineVote ? (
                        <>
                          <Icon name="check" className="size-3.5" />
                          <span className="font-medium">{t('communities.poll.yourVote')}</span>
                          <span aria-hidden="true">·</span>
                        </>
                      ) : null}
                      <span>{results}</span>
                    </p>
                  </div>
                </div>
                <div
                  aria-hidden="true"
                  className="ms-7 h-2 overflow-hidden rounded-full bg-surface-muted"
                >
                  <div className="h-full rounded-full bg-accent" style={{ width: `${percent}%` }} />
                </div>
              </li>
            );
          })}
        </ul>
      </fieldset>
      <FormAlert message={error} />
      <p className="text-sm text-fg-muted">{t('communities.poll.private')}</p>
      {open ? (
        <Button type="submit" variant="secondary" loading={vote.isPending}>
          <Icon name="check" className="size-4" />
          {voted ? t('communities.poll.change') : t('communities.poll.vote')}
        </Button>
      ) : !poll.closed ? (
        <p className="text-sm text-fg-muted">{t('communities.poll.membersVote')}</p>
      ) : null}
    </form>
  );
}
