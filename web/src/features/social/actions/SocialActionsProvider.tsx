import { useMutation, useQueryClient } from '@tanstack/react-query';
import {
  type ReactNode,
  type RefObject,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { useToast } from '@/shared/components/toast/ToastContext';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { socialApi } from '../api';
import { personActionError, requestActionError } from '../errors';
import { invalidateSocial } from '../hooks';
import { socialKeys } from '../keys';
import { personRef } from '../people';
import type { FriendRequest, PersonRef, PublicProfile } from '../types';
import {
  type RequestAction,
  type SocialActions,
  SocialActionsContext,
} from './SocialActionsContext';

type ConfirmKind = 'remove' | 'block' | 'unblock';

interface Confirmation {
  kind: ConfirmKind;
  person: PersonRef;
}

interface RespondVars {
  request: FriendRequest;
  action: RequestAction;
}

interface MuteVars {
  person: PersonRef;
  muted: boolean;
}

const respondDone: Readonly<Record<RequestAction, MessageKey>> = {
  accept: 'social.requests.accepted',
  decline: 'social.requests.declined',
  cancel: 'social.requests.cancelled',
};

const respondFailed: Readonly<Record<RequestAction, MessageKey>> = {
  accept: 'social.requests.acceptFailed',
  decline: 'social.requests.declineFailed',
  cancel: 'social.requests.cancelFailed',
};

function without<K, V>(map: ReadonlyMap<K, V>, key: K): ReadonlyMap<K, V> {
  const next = new Map(map);
  next.delete(key);
  return next;
}

/** The other person in a request, from your side. */
function otherPerson(request: FriendRequest, action: RequestAction): PersonRef {
  return action === 'cancel' ? request.to : request.from;
}

/** Profile lists in the cache that carry `muted` / `blocked_by_me` for a person. */
function patchProfiles(
  people: PublicProfile[] | undefined,
  userId: string,
  change: Partial<Pick<PublicProfile, 'muted' | 'blocked_by_me' | 'connection'>>,
): PublicProfile[] | undefined {
  return people?.map((person) => (person.user_id === userId ? { ...person, ...change } : person));
}

function patchRequests(
  requests: FriendRequest[] | undefined,
  userId: string,
  change: Partial<Pick<PublicProfile, 'muted'>>,
): FriendRequest[] | undefined {
  return requests?.map((request) => ({
    ...request,
    from: request.from.user_id === userId ? { ...request.from, ...change } : request.from,
    to: request.to.user_id === userId ? { ...request.to, ...change } : request.to,
  }));
}

interface SocialActionsProviderProps {
  children: ReactNode;
  /**
   * Receives focus when the focused row disappears after an action (for
   * example an accepted request), so keyboard users keep their place.
   */
  focusFallbackRef?: RefObject<HTMLElement | null>;
}

export function SocialActionsProvider({ children, focusFallbackRef }: SocialActionsProviderProps) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const inFlight = useRef(new Set<string>());
  const [responding, setResponding] = useState<ReadonlyMap<string, RequestAction>>(new Map());
  const [muting, setMuting] = useState<ReadonlySet<string>>(new Set());
  const [confirmation, setConfirmation] = useState<Confirmation | null>(null);
  const [confirmError, setConfirmError] = useState<string | null>(null);
  const [refocusTick, setRefocusTick] = useState(0);

  // Runs after the dialog (if any) has restored focus: when the focused row
  // is gone, focus moves to the current tab panel instead of the page body.
  useEffect(() => {
    if (refocusTick === 0) return;
    const timer = window.setTimeout(() => {
      const active = document.activeElement;
      if (!active || active === document.body) focusFallbackRef?.current?.focus();
    }, 0);
    return () => {
      window.clearTimeout(timer);
    };
  }, [refocusTick, focusFallbackRef]);
  const refocus = useCallback(() => {
    setRefocusTick((tick) => tick + 1);
  }, []);

  const respondMutation = useMutation({
    mutationFn: ({ request, action }: RespondVars) => socialApi[action](request.id),
    onSuccess: (_result, { request, action }) => {
      toast.show({
        tone: 'success',
        title: t(respondDone[action], { name: otherPerson(request, action).display_name }),
      });
    },
    onError: (error, { action }) => {
      if (hasErrorCode(error, 'NOT_FOUND')) {
        toast.show({ tone: 'info', title: requestActionError(error, t) });
        return;
      }
      toast.show({
        tone: 'danger',
        title: t(respondFailed[action]),
        description: requestActionError(error, t),
      });
    },
    onSettled: async (_result, _error, { request }) => {
      try {
        // The row keeps its spinner until the lists show the answer.
        await invalidateSocial(queryClient);
      } finally {
        inFlight.current.delete(`request:${request.id}`);
        setResponding((map) => without(map, request.id));
        refocus();
      }
    },
  });

  /**
   * Shows a mute change everywhere at once (friends, requests and earlier
   * search answers carry `muted`); the lists are refetched right after.
   */
  const applyMuted = useCallback(
    (userId: string, muted: boolean) => {
      queryClient.setQueryData<PublicProfile[]>(socialKeys.connections(), (people) =>
        patchProfiles(people, userId, { muted }),
      );
      queryClient.setQueriesData<PublicProfile[]>({ queryKey: socialKeys.searches() }, (people) =>
        patchProfiles(people, userId, { muted }),
      );
      queryClient.setQueryData<FriendRequest[]>(socialKeys.requests(), (requests) =>
        patchRequests(requests, userId, { muted }),
      );
    },
    [queryClient],
  );

  const muteMutation = useMutation({
    mutationFn: ({ person, muted }: MuteVars) => socialApi.setMuted(person.user_id, muted),
    onSuccess: (_result, { person, muted }) => {
      applyMuted(person.user_id, muted);
      toast.show(
        muted
          ? {
              tone: 'success',
              title: t('social.mute.done', { name: person.display_name }),
              description: t('social.mute.doneBody'),
            }
          : { tone: 'success', title: t('social.unmute.done', { name: person.display_name }) },
      );
    },
    onError: (error, { muted }) => {
      toast.show({
        tone: 'danger',
        title: t(muted ? 'social.mute.failed' : 'social.unmute.failed'),
        description: describeError(error, t),
      });
    },
    onSettled: async (_result, _error, { person }) => {
      inFlight.current.delete(`mute:${person.user_id}`);
      setMuting((set) => {
        const next = new Set(set);
        next.delete(person.user_id);
        return next;
      });
      await invalidateSocial(queryClient);
    },
  });

  const confirmMutation = useMutation({
    mutationFn: ({ kind, person }: Confirmation) => {
      if (kind === 'remove') return socialApi.removeFriend(person.user_id);
      if (kind === 'block') return socialApi.block(person.user_id);
      return socialApi.unblock(person.user_id);
    },
    // The dialog stays busy until the lists show the change.
    onSettled: () => invalidateSocial(queryClient),
  });

  const finish = (title: string, tone: 'success' | 'info' = 'success') => {
    toast.show({ tone, title });
    setConfirmation(null);
    refocus();
  };

  const runConfirmation = () => {
    if (!confirmation || confirmMutation.isPending) return;
    const { kind, person } = confirmation;
    const name = person.display_name;
    setConfirmError(null);
    confirmMutation.mutate(confirmation, {
      onSuccess: () => {
        if (kind === 'block') {
          // Earlier search answers show the block right away (the API would answer 404 now).
          queryClient.setQueriesData<PublicProfile[]>(
            { queryKey: socialKeys.searches() },
            (people) =>
              patchProfiles(people, person.user_id, { blocked_by_me: true, connection: 'none' }),
          );
          finish(t('social.block.done', { name }));
        } else if (kind === 'unblock') {
          queryClient.setQueriesData<PublicProfile[]>(
            { queryKey: socialKeys.searches() },
            (people) => patchProfiles(people, person.user_id, { blocked_by_me: false }),
          );
          finish(t('social.unblock.done', { name }));
        } else {
          finish(t('social.remove.done', { name }));
        }
      },
      onError: (error) => {
        if (!hasErrorCode(error, 'NOT_FOUND')) {
          setConfirmError(personActionError(error, t));
          return;
        }
        // Already done elsewhere (or the person left Montra): show where things stand.
        if (kind === 'unblock') {
          finish(t('social.unblock.alreadyDone', { name }), 'info');
        } else if (kind === 'remove') {
          finish(t('social.remove.alreadyDone', { name }), 'info');
        } else {
          finish(t('social.block.notFound'), 'info');
        }
      },
    });
  };

  const begin = (key: string): boolean => {
    if (inFlight.current.has(key)) return false;
    inFlight.current.add(key);
    return true;
  };

  const actions: SocialActions = {
    respond: (request, action) => {
      if (!begin(`request:${request.id}`)) return;
      setResponding((map) => new Map(map).set(request.id, action));
      respondMutation.mutate({ request, action });
    },
    respondingTo: (requestId) => responding.get(requestId) ?? null,
    setMuted: (person, muted) => {
      if (!begin(`mute:${person.user_id}`)) return;
      setMuting((set) => new Set(set).add(person.user_id));
      muteMutation.mutate({ person: personRef(person), muted });
    },
    isMuting: (userId) => muting.has(userId),
    confirmRemove: (person) => {
      setConfirmError(null);
      setConfirmation({ kind: 'remove', person: personRef(person) });
    },
    confirmBlock: (person) => {
      setConfirmError(null);
      setConfirmation({ kind: 'block', person: personRef(person) });
    },
    confirmUnblock: (person) => {
      setConfirmError(null);
      setConfirmation({ kind: 'unblock', person: personRef(person) });
    },
  };

  const name = confirmation?.person.display_name ?? '';
  const dialog = useMemo(() => {
    switch (confirmation?.kind) {
      case 'remove':
        return {
          title: t('social.remove.title', { name }),
          description: <p>{t('social.remove.body')}</p>,
          confirmLabel: t('social.remove.confirm'),
          tone: 'danger' as const,
        };
      case 'block':
        return {
          title: t('social.block.title', { name }),
          description: (
            <ul className="list-disc space-y-1 ps-5">
              <li>{t('social.block.effectFriends')}</li>
              <li>{t('social.block.effectHidden')}</li>
              <li>{t('social.block.effectPrivate')}</li>
            </ul>
          ),
          confirmLabel: t('social.block.confirm'),
          tone: 'danger' as const,
        };
      case 'unblock':
        return {
          title: t('social.unblock.title', { name }),
          description: <p>{t('social.unblock.body')}</p>,
          confirmLabel: t('social.unblock.confirm'),
          tone: 'primary' as const,
        };
      default:
        return null;
    }
  }, [confirmation?.kind, name, t]);

  return (
    <SocialActionsContext.Provider value={actions}>
      {children}
      <ConfirmDialog
        open={dialog !== null}
        onOpenChange={(open) => {
          if (!open) setConfirmation(null);
        }}
        title={dialog?.title ?? ''}
        description={dialog?.description ?? null}
        confirmLabel={dialog?.confirmLabel ?? ''}
        tone={dialog?.tone ?? 'danger'}
        onConfirm={runConfirmation}
        pending={confirmMutation.isPending}
        error={confirmError}
      />
    </SocialActionsContext.Provider>
  );
}
