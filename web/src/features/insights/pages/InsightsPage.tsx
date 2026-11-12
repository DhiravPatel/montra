import {
  type InfiniteData,
  type QueryClient,
  useMutation,
  useQueryClient,
} from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { useParams, useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Disclosure } from '@/shared/components/Disclosure';
import { PageHeader } from '@/shared/components/PageHeader';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { insightsApi, useInsight, useInsights } from '../api';
import { FeedbackDialog } from '../components/FeedbackDialog';
import { InsightCard } from '../components/InsightCard';
import { MutedTypesCard } from '../components/MutedTypesCard';
import { muteKey, muteScopeOf } from '../evidence';
import {
  INSIGHTS_LIST_HEADING_ID,
  insightThanksId,
  LINKED_INSIGHT_HEADING_ID,
  insightTitleId,
  MUTED_TYPES_HEADING_ID,
} from '../ids';
import { INSIGHT_KINDS, isInsightKind, kindLabel, muteBody, subtypeLabel } from '../labels';
import { insightsKeys } from '../keys';
import type {
  Insight,
  InsightAction,
  InsightActionInput,
  InsightFeedback,
  InsightFeedbackState,
  InsightKindFilter,
  InsightListQuery,
  InsightMute,
  InsightPage,
  UnmuteResult,
} from '../types';

type View = 'active' | 'all';

const doneMessage: Readonly<Record<Exclude<InsightAction, 'snooze'>, MessageKey>> = {
  dismiss: 'insights.action.done.dismiss',
  expected: 'insights.action.done.expected',
  resolved: 'insights.action.done.resolved',
  mute: 'insights.action.done.mute',
  reopen: 'insights.action.done.reopen',
};

function isListQuery(value: unknown): value is InsightListQuery {
  return (
    typeof value === 'object' && value !== null && 'all' in value && typeof value.all === 'boolean'
  );
}

/**
 * Shows the server's updated insight in every cached list page at once (the
 * lists are refetched as well): the active list drops it unless it is
 * active again, the full list replaces it.
 */
function applyUpdate(queryClient: QueryClient, updated: Insight) {
  // An insight opened from a link is cached on its own too (any status).
  if (queryClient.getQueryData(insightsKeys.detail(updated.id))) {
    queryClient.setQueryData(insightsKeys.detail(updated.id), updated);
  }
  for (const [key, data] of queryClient.getQueriesData<InfiniteData<InsightPage>>({
    queryKey: insightsKeys.lists(),
  })) {
    if (!data) continue;
    const query = key[3];
    const keep = (isListQuery(query) && query.all) || updated.status === 'active';
    queryClient.setQueryData<InfiniteData<InsightPage>>(key, {
      ...data,
      pages: data.pages.map((page) => ({
        ...page,
        items: keep
          ? page.items.map((item) => (item.id === updated.id ? updated : item))
          : page.items.filter((item) => item.id !== updated.id),
      })),
    });
  }
}

/** Moves focus once the list has re-rendered: to `id` if it is still shown, else to `fallback`. */
function focusAfterRender(id: string, fallback: string) {
  window.requestAnimationFrame(() => {
    (document.getElementById(id) ?? document.getElementById(fallback))?.focus();
  });
}

/**
 * Rule-based insights (spec §4.13, §20B.14): unusual activity and savings
 * ideas with the explanation and the numbers behind them, in the
 * interface language where the server gives a message code. People can
 * dismiss, snooze, mark expected or resolved, mute a kind of insight, and
 * say whether it helped. Nothing here changes their records, and nothing
 * calls the AI endpoints: insights come from fixed rules on the server.
 */
export function InsightsPage() {
  const { t, formatLocale } = useI18n();
  useDocumentTitle(t('nav.insights'));
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const { insightId } = useParams<{ insightId?: string }>();
  const [params, setParams] = useSearchParams();
  const view: View = params.get('show') === 'all' ? 'all' : 'active';
  const requestedKind = params.get('kind');
  const kind: InsightKindFilter = isInsightKind(requestedKind) ? requestedKind : '';
  const insights = useInsights({ all: view === 'all', kind });
  // A link to one insight (notification): read it by ID, whatever its status.
  const linked = useInsight(insightId);
  // The linked insight is shown on its own above the list, never twice.
  const items = insights.data?.pages
    .flatMap((page) => page.items)
    .filter((item) => item.id !== insightId);

  const [muting, setMuting] = useState<Insight | null>(null);
  const [muteError, setMuteError] = useState<string | null>(null);
  const [reporting, setReporting] = useState<Insight | null>(null);
  const [reportError, setReportError] = useState<string | null>(null);
  // Answers sent in this visit, for a server answer that does not echo my_feedback.
  const [sent, setSent] = useState<ReadonlyMap<string, InsightFeedbackState>>(() => new Map());

  const act = useMutation({
    mutationFn: ({ insight, input }: { insight: Insight; input: InsightActionInput }) =>
      insightsApi.act(insight.id, input),
    onSettled: () => queryClient.invalidateQueries({ queryKey: insightsKeys.all }),
  });
  const feedback = useMutation({
    mutationFn: ({
      insight,
      value,
      note,
    }: {
      insight: Insight;
      value: InsightFeedback;
      note?: string;
    }) => insightsApi.feedback(insight.id, { feedback: value, ...(note ? { note } : {}) }),
  });
  const unmute = useMutation({
    mutationFn: async (mute: InsightMute): Promise<UnmuteResult> => {
      try {
        return await insightsApi.unmute(mute.subtype, mute.scope);
      } catch (error) {
        // Already unmuted (another device or an earlier attempt): nothing left to reopen.
        if (!hasErrorCode(error, 'NOT_FOUND')) throw error;
        return { subtype: mute.subtype, scope: mute.scope, reopened: 0, insights: [] };
      }
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: insightsKeys.all }),
  });
  const locked = act.isPending || unmute.isPending;

  const setFilters = (next: { view?: View; kind?: InsightKindFilter }) => {
    const nextView = next.view ?? view;
    const nextKind = next.kind ?? kind;
    const query: Record<string, string> = {};
    if (nextView === 'all') query.show = 'all';
    if (nextKind) query.kind = nextKind;
    setParams(query, { replace: true });
  };

  const actionDone = (updated: Insight, action: InsightAction) => {
    applyUpdate(queryClient, updated);
    const until = parseTimestamp(updated.snoozed_until);
    toast.show({
      tone: 'success',
      title:
        action === 'snooze'
          ? until
            ? t('insights.action.done.snooze', {
                date: formatDate(until, formatLocale, user.timezone),
              })
            : t('insights.action.done.snoozeNoDate')
          : t(doneMessage[action]),
    });
    focusAfterRender(insightTitleId(updated.id), INSIGHTS_LIST_HEADING_ID);
  };

  const actionFailed = (error: unknown): string | null => {
    if (hasErrorCode(error, 'NOT_FOUND')) {
      toast.show({ tone: 'info', title: t('insights.action.gone') });
      return null;
    }
    return describeError(error, t);
  };

  const runAction = (insight: Insight, input: InsightActionInput) => {
    if (locked) return;
    act.mutate(
      { insight, input },
      {
        onSuccess: (updated) => {
          actionDone(updated, input.action);
        },
        onError: (error) => {
          const message = actionFailed(error);
          if (message) {
            toast.show({
              tone: 'danger',
              title: t('insights.action.failed'),
              description: message,
            });
          }
        },
      },
    );
  };

  const confirmMute = () => {
    if (!muting || locked) return;
    setMuteError(null);
    act.mutate(
      { insight: muting, input: { action: 'mute' } },
      {
        onSuccess: (updated) => {
          setMuting(null);
          actionDone(updated, 'mute');
        },
        onError: (error) => {
          const message = actionFailed(error);
          if (message) setMuteError(message);
          else setMuting(null);
        },
      },
    );
  };

  /** Removes a mute rule; the API reopens the insights it covered and returns them. */
  const runUnmute = (mute: InsightMute) => {
    if (locked) return;
    unmute.mutate(mute, {
      onSuccess: (result) => {
        for (const insight of result.insights) applyUpdate(queryClient, insight);
        toast.show({
          tone: 'success',
          title:
            result.reopened > 0
              ? t('insights.action.done.unmute', { count: result.reopened })
              : t('insights.action.done.unmuteNone'),
        });
        const [first] = result.insights;
        focusAfterRender(first ? insightTitleId(first.id) : '', MUTED_TYPES_HEADING_ID);
      },
      onError: (error) => {
        toast.show({
          tone: 'danger',
          title: t('insights.unmute.failed'),
          description: describeError(error, t),
        });
      },
    });
  };

  const sendFeedback = (insight: Insight, value: InsightFeedback, note?: string) => {
    if (feedback.isPending) return;
    setReportError(null);
    feedback.mutate(
      { insight, value, ...(note ? { note } : {}) },
      {
        onSuccess: (updated) => {
          applyUpdate(queryClient, updated);
          setSent((previous) =>
            new Map(previous).set(
              insight.id,
              updated.my_feedback ?? {
                feedback: value,
                ...(note ? { note } : {}),
                updated_at: new Date().toISOString(),
              },
            ),
          );
          setReporting(null);
          // After the buttons (or the dialog) are gone, continue at the thank-you note.
          window.setTimeout(() => {
            document.getElementById(insightThanksId(insight.id))?.focus();
          }, 0);
        },
        onError: (error) => {
          const message = describeError(error, t);
          if (reporting) setReportError(message);
          else
            toast.show({
              tone: 'danger',
              title: t('insights.feedback.failed'),
              description: message,
            });
        },
      },
    );
  };

  const linkedId = linked.data?.id ?? null;
  const focusedTarget = useRef<string | null>(null);
  useEffect(() => {
    if (!linkedId || focusedTarget.current === linkedId) return;
    // Two frames: after the route announcer has focused the page heading.
    let frame = window.requestAnimationFrame(() => {
      frame = window.requestAnimationFrame(() => {
        focusedTarget.current = linkedId;
        const element = document.getElementById(insightTitleId(linkedId));
        element?.scrollIntoView({ block: 'center' });
        element?.focus({ preventScroll: true });
      });
    });
    return () => {
      window.cancelAnimationFrame(frame);
    };
  }, [linkedId]);

  const renderCard = (insight: Insight, highlighted: boolean) => (
    <InsightCard
      insight={insight}
      highlighted={highlighted}
      busy={
        (act.isPending && act.variables.insight.id === insight.id) ||
        (unmute.isPending &&
          unmute.variables.subtype === insight.subtype &&
          (unmute.variables.scope === '*' || unmute.variables.scope === muteScopeOf(insight)))
      }
      locked={locked}
      feedback={insight.my_feedback ?? sent.get(insight.id) ?? null}
      feedbackBusy={feedback.isPending}
      onAction={(input) => {
        runAction(insight, input);
      }}
      onMute={() => {
        setMuteError(null);
        setMuting(insight);
      }}
      onUnmute={() => {
        runUnmute({
          subtype: insight.subtype,
          scope: muteScopeOf(insight),
          created_at: insight.created_at,
        });
      }}
      onFeedback={(value) => {
        sendFeedback(insight, value);
      }}
      onReport={() => {
        if (feedback.isPending) return;
        setReportError(null);
        setReporting(insight);
      }}
    />
  );

  let linkedContent = null;
  if (insightId) {
    if (linked.data) {
      // A failed refresh keeps showing the insight already read.
      linkedContent = renderCard(linked.data, true);
    } else if (linked.isPending) {
      linkedContent = <LoadingState label={t('insights.linked.loading')} />;
    } else {
      linkedContent = hasErrorCode(linked.error, 'NOT_FOUND') ? (
        <Alert tone="info">{t('insights.linked.missing')}</Alert>
      ) : hasErrorCode(linked.error, 'FORBIDDEN') ? (
        <PermissionDenied titleAs="p" />
      ) : (
        <ErrorState
          titleAs="p"
          title={t('insights.linked.error')}
          error={linked.error}
          retrying={linked.isFetching}
          onRetry={() => {
            void linked.refetch();
          }}
        />
      );
    }
  }

  let content;
  if (insights.isPending) {
    content = <LoadingState label={t('insights.loading')} />;
  } else if (insights.isLoadingError) {
    content = hasErrorCode(insights.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('insights.error')}
        error={insights.error}
        retrying={insights.isFetching}
        onRetry={() => {
          void insights.refetch();
        }}
      />
    );
  } else if (!items || items.length === 0) {
    content = (
      <EmptyState
        icon="trending-up"
        title={kind ? t('insights.empty.filtered') : t('insights.empty.title')}
        description={t('insights.empty.body')}
      />
    );
  } else {
    content = (
      <div className="space-y-4">
        <ul className="space-y-4">
          {items.map((insight) => (
            <li key={insight.id}>{renderCard(insight, false)}</li>
          ))}
        </ul>
        {insights.isFetchNextPageError ? (
          <p role="alert" className="text-sm text-danger">
            {t('insights.moreFailed')}
          </p>
        ) : null}
        {insights.hasNextPage ? (
          <div className="flex justify-center">
            <Button
              variant="secondary"
              loading={insights.isFetchingNextPage}
              onClick={() => {
                void insights.fetchNextPage();
              }}
            >
              {t('common.loadMore')}
            </Button>
          </div>
        ) : null}
      </div>
    );
  }

  return (
    <>
      <PageHeader title={t('nav.insights')} description={t('insights.description')} />
      <Disclosure summary={t('insights.howItWorks.title')} className="-mt-2 mb-6">
        <p className="max-w-prose text-sm text-fg-muted">{t('insights.howItWorks.body')}</p>
      </Disclosure>

      {insightId ? (
        <section aria-labelledby={LINKED_INSIGHT_HEADING_ID} className="mb-8 space-y-4">
          <h2 id={LINKED_INSIGHT_HEADING_ID} className="text-lg font-semibold text-fg">
            {t('insights.linked.title')}
          </h2>
          {linkedContent}
        </section>
      ) : null}

      <div className="mb-6 flex flex-wrap items-end gap-4">
        <RadioGroup<View>
          legend={t('insights.filter.show')}
          value={view}
          onChange={(next) => {
            setFilters({ view: next });
          }}
          options={[
            { value: 'active', label: t('insights.filter.active') },
            { value: 'all', label: t('insights.filter.all') },
          ]}
        />
        <Select
          label={t('insights.filter.kind')}
          value={kind}
          onChange={(event) => {
            const next = event.target.value;
            setFilters({ kind: isInsightKind(next) ? next : '' });
          }}
          options={[
            { value: '', label: t('insights.filter.allKinds') },
            ...INSIGHT_KINDS.map((value) => ({ value, label: t(kindLabel[value]) })),
          ]}
          className="w-full sm:w-64"
        />
      </div>

      <section aria-labelledby={INSIGHTS_LIST_HEADING_ID} className="space-y-4">
        <div className="flex flex-wrap items-baseline justify-between gap-2">
          <h2
            id={INSIGHTS_LIST_HEADING_ID}
            tabIndex={-1}
            className="text-lg font-semibold text-fg outline-none"
          >
            {view === 'all' ? t('insights.list.all') : t('insights.list.active')}
          </h2>
          {items && items.length > 0 ? (
            <p className="text-sm text-fg-muted">
              {insights.hasNextPage
                ? t('insights.countMore', { count: items.length })
                : t('insights.count', { count: items.length })}
            </p>
          ) : null}
        </div>
        {content}
      </section>

      <MutedTypesCard
        pendingKey={unmute.isPending ? muteKey(unmute.variables) : null}
        locked={locked}
        onUnmute={runUnmute}
      />

      <ConfirmDialog
        open={muting !== null}
        onOpenChange={(open) => {
          if (!open) setMuting(null);
        }}
        title={t('insights.mute.title')}
        description={
          muting ? (
            <>
              <p>
                {t(muteBody(muting.subtype, muteScopeOf(muting)), {
                  type: t(subtypeLabel(muting.subtype, muting.kind)),
                })}
              </p>
              <p className="mt-2">{t('insights.mute.note')}</p>
            </>
          ) : null
        }
        confirmLabel={t('insights.mute.confirm')}
        tone="primary"
        onConfirm={confirmMute}
        pending={act.isPending}
        error={muteError}
      />
      <FeedbackDialog
        key={reporting?.id ?? 'closed'}
        insight={reporting}
        pending={feedback.isPending}
        error={reportError}
        onOpenChange={(open) => {
          if (!open) setReporting(null);
        }}
        onSubmit={(note) => {
          if (reporting) sendFeedback(reporting, 'incorrect', note);
        }}
      />
    </>
  );
}
