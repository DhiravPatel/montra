import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, type ReactNode, useRef, useState } from 'react';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { useSocialActions } from '../actions/SocialActionsContext';
import { socialApi } from '../api';
import { isSendStateNotice, queryTooShortMin, sendRequestError } from '../errors';
import { invalidateSocial, useFriendRequests, useFriendsList } from '../hooks';
import { socialKeys } from '../keys';
import {
  exactUsernameMatch,
  isValidUsername,
  liveConnection,
  normalizeUsername,
  pendingRequestWith,
} from '../people';
import type { PublicProfile, SendFriendRequestInput } from '../types';
import { PersonActionsMenu } from './PersonActionsMenu';
import { PersonSummary } from './PersonSummary';

const NOTE_MAX = 200;

interface SendProblem {
  message: string;
  tone: 'info' | 'danger';
}

/** One person found by exact username, with the action that fits how you relate. */
function FoundPerson({
  person,
  onShowRequests,
}: {
  person: PublicProfile;
  onShowRequests: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const actions = useSocialActions();
  const friends = useFriendsList();
  const requests = useFriendRequests();
  const [note, setNote] = useState('');
  const [problem, setProblem] = useState<SendProblem | null>(null);
  const send = useMutation({
    mutationFn: (body: SendFriendRequestInput) => socialApi.send(body),
    // The card shows the new state once the lists have caught up.
    onSettled: () => invalidateSocial(queryClient),
  });
  const name = person.display_name;
  const connection = liveConnection(person, friends.data, requests.data);
  const pending = pendingRequestWith(requests.data, person.user_id);
  const running = pending ? actions.respondingTo(pending.id) : null;

  const onSend = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (send.isPending) return;
    setProblem(null);
    const message = note.trim();
    send.mutate(
      { user_id: person.user_id, ...(message ? { message } : {}) },
      {
        onSuccess: (request) => {
          setNote('');
          toast.show(
            request.status === 'accepted'
              ? { tone: 'success', title: t('social.requests.accepted', { name }) }
              : {
                  tone: 'success',
                  title: t('social.send.done', { name }),
                  description: t('social.send.doneBody'),
                },
          );
        },
        onError: (error) => {
          // Already friends, a request already waiting, requests closed: not a failure to fix.
          setProblem({
            message: sendRequestError(error, t, name),
            tone: isSendStateNotice(error) ? 'info' : 'danger',
          });
        },
      },
    );
  };

  const viewRequests = (
    <Button variant="secondary" size="sm" onClick={onShowRequests}>
      <Icon name="inbox" className="size-4" />
      {t('social.find.viewRequests')}
    </Button>
  );

  let status: ReactNode = null;
  let body: ReactNode = null;
  if (connection === 'friend') {
    status = (
      <StatusBadge tone="success" icon="users">
        {t('social.find.status.friend')}
      </StatusBadge>
    );
  } else if (connection === 'request_sent') {
    status = (
      <StatusBadge tone="info" icon="clock">
        {t('social.find.status.sent')}
      </StatusBadge>
    );
    body = pending ? (
      <Button
        variant="secondary"
        size="sm"
        loading={running === 'cancel'}
        aria-label={t('social.requests.cancelTo', { name })}
        onClick={() => {
          actions.respond(pending, 'cancel');
        }}
      >
        {t('social.requests.cancel')}
      </Button>
    ) : (
      viewRequests
    );
  } else if (connection === 'request_received') {
    status = (
      <StatusBadge tone="info" icon="inbox">
        {t('social.find.status.received')}
      </StatusBadge>
    );
    body = pending ? (
      <>
        <Button
          size="sm"
          loading={running === 'accept'}
          disabled={running === 'decline'}
          aria-label={t('social.requests.acceptFrom', { name })}
          onClick={() => {
            actions.respond(pending, 'accept');
          }}
        >
          <Icon name="check" className="size-4" />
          {t('social.requests.accept')}
        </Button>
        <Button
          variant="secondary"
          size="sm"
          loading={running === 'decline'}
          disabled={running === 'accept'}
          aria-label={t('social.requests.declineFrom', { name })}
          onClick={() => {
            actions.respond(pending, 'decline');
          }}
        >
          {t('social.requests.decline')}
        </Button>
      </>
    ) : (
      viewRequests
    );
  } else if (connection === 'self') {
    status = (
      <StatusBadge tone="neutral" icon="user">
        {t('social.find.status.self')}
      </StatusBadge>
    );
  }

  return (
    <article
      aria-label={t('social.find.resultLabel', { name })}
      className="space-y-4 rounded-lg border border-line p-4"
    >
      <div className="flex items-start justify-between gap-3">
        <PersonSummary person={person}>{status}</PersonSummary>
        {connection === 'self' ? null : <PersonActionsMenu person={person} />}
      </div>
      {connection === 'none' ? (
        <form noValidate onSubmit={onSend} className="space-y-3">
          <TextField
            label={t('social.send.note')}
            optional
            help={t('social.send.noteHelp', { max: NOTE_MAX })}
            value={note}
            maxLength={NOTE_MAX}
            onChange={(event) => {
              setNote(event.target.value);
            }}
          />
          <Button
            type="submit"
            loading={send.isPending}
            aria-label={t('social.send.actionTo', { name })}
          >
            <Icon name="user-plus" className="size-4" />
            {t('social.send.action')}
          </Button>
        </form>
      ) : null}
      {body ? <div className="flex flex-wrap gap-2">{body}</div> : null}
      {connection === 'friend' ? (
        <p className="text-sm text-fg-muted">{t('social.find.alreadyFriends', { name })}</p>
      ) : null}
      {problem ? (
        <Alert tone={problem.tone} live="assertive">
          {problem.message}
        </Alert>
      ) : null}
    </article>
  );
}

type Outcome = { kind: 'self' } | { kind: 'search'; username: string };

/**
 * Find someone by their exact username and send a request. Searches run
 * only when asked (the API rate-limits social actions). The API finds
 * people by exact username only (and only those who chose to be findable;
 * new accounts are hidden until they turn it on); the exact match is
 * checked again here so nothing else is ever shown.
 */
export function FindPeoplePanel({ onShowRequests }: { onShowRequests: () => void }) {
  const t = useT();
  const user = useCurrentUser();
  const announce = useAnnounce();
  const queryClient = useQueryClient();
  const inputRef = useRef<HTMLInputElement>(null);
  const [value, setValue] = useState('');
  const [fieldError, setFieldError] = useState<string | undefined>(undefined);
  const [outcome, setOutcome] = useState<Outcome | null>(null);
  const [searching, setSearching] = useState(false);
  const [searchError, setSearchError] = useState<unknown>(null);
  const username = outcome?.kind === 'search' ? outcome.username : '';
  // Reads what runSearch fetched (and later block removals); never fetches by itself.
  const results = useQuery({
    queryKey: socialKeys.search(username),
    queryFn: ({ signal }) => socialApi.search(username, signal),
    enabled: false,
  });
  const match =
    outcome?.kind === 'search' && results.data ? exactUsernameMatch(results.data, username) : null;

  const runSearch = async (next: string) => {
    setOutcome({ kind: 'search', username: next });
    setSearchError(null);
    setSearching(true);
    try {
      const people = await queryClient.query({
        queryKey: socialKeys.search(next),
        queryFn: ({ signal }) => socialApi.search(next, signal),
        staleTime: 0,
      });
      const found = exactUsernameMatch(people, next);
      announce(
        found
          ? t('social.find.foundAnnouncement', { name: found.display_name, username: next })
          : t('social.find.notFoundTitle', { username: next }),
      );
    } catch (error) {
      const min = queryTooShortMin(error);
      if (min !== null) {
        // The API wants a longer username (query_too_short {min}): explain it at the field.
        setOutcome(null);
        setFieldError(t('social.find.tooShort', { count: min }));
        inputRef.current?.focus();
        return;
      }
      setSearchError(error);
      announce(describeError(error, t), 'assertive');
    } finally {
      setSearching(false);
    }
  };

  const onSubmit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (searching) return;
    const next = normalizeUsername(value);
    if (!isValidUsername(next)) {
      setFieldError(next === '' ? t('social.find.required') : t('social.find.invalid'));
      inputRef.current?.focus();
      return;
    }
    setFieldError(undefined);
    if (next === user.username?.toLowerCase()) {
      setOutcome({ kind: 'self' });
      setSearchError(null);
      announce(t('social.find.self'));
      return;
    }
    void runSearch(next);
  };

  let result: ReactNode = null;
  if (outcome?.kind === 'self') {
    result = (
      <Alert tone="info" title={t('social.find.self')}>
        {t('social.find.selfBody')}
      </Alert>
    );
  } else if (outcome?.kind === 'search') {
    if (searchError) {
      result = (
        <ErrorState
          title={t('social.find.error')}
          titleAs="p"
          error={searchError}
          retrying={searching}
          onRetry={() => {
            void runSearch(username);
          }}
        />
      );
    } else if (match?.blocked_by_me) {
      // Blocked from this result: the API would not find them any more; the page says why.
      result = (
        <Alert tone="info" title={t('social.find.blockedNow', { username })}>
          {t('social.find.blockedNowBody')}
        </Alert>
      );
    } else if (match) {
      // Keyed so a note or message never carries over to another person.
      result = <FoundPerson key={match.user_id} person={match} onShowRequests={onShowRequests} />;
    } else if (searching) {
      result = <LoadingState label={t('social.find.searching')} />;
    } else if (results.data) {
      result = (
        <EmptyState
          icon="search"
          titleAs="p"
          title={t('social.find.notFoundTitle', { username })}
          description={
            <>
              <p>{t('social.find.notFoundBody')}</p>
              {user.username ? (
                <p className="mt-2">{t('social.find.shareYours', { username: user.username })}</p>
              ) : null}
            </>
          }
        />
      );
    }
  }

  return (
    <Card title={t('social.find.title')} description={t('social.find.description')}>
      <form
        role="search"
        aria-label={t('social.find.title')}
        noValidate
        onSubmit={onSubmit}
        className="flex flex-col gap-3 sm:flex-row sm:items-start"
      >
        <TextField
          ref={inputRef}
          className="min-w-0 flex-1"
          label={t('social.find.label')}
          help={t('social.find.help')}
          error={fieldError}
          value={value}
          maxLength={31}
          autoComplete="off"
          autoCapitalize="none"
          spellCheck={false}
          onChange={(event) => {
            setValue(event.target.value);
          }}
        />
        <Button type="submit" loading={searching} className="sm:mt-7">
          <Icon name="search" className="size-4" />
          {t('social.find.submit')}
        </Button>
      </form>
      {result ? <div className="mt-6">{result}</div> : null}
    </Card>
  );
}
