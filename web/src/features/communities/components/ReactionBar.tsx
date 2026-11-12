import { useMutation } from '@tanstack/react-query';
import { Icon } from '@/shared/components/Icon';
import { Spinner } from '@/shared/components/Spinner';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { communitiesApi } from '../api';
import { useCommunityError } from '../errors';
import { REACTION_KINDS, reactionLabel } from '../labels';
import { splitReactions } from '../reactions';
import type { ContentTarget, ReactionCounts, ReactionKind } from '../types';

interface Toggle {
  kind: ReactionKind;
  on: boolean;
}

/**
 * Reactions on a post or comment (like, helpful, insightful, support).
 * Each is a toggle button (aria-pressed) with its count; your reactions
 * are marked with a check and a border, not color alone. Adding needs
 * participation; your own reactions can always be removed. The counts and
 * your reactions come from the API's answer, never from local guessing.
 */
export function ReactionBar({
  target,
  id,
  reactions,
  mine,
  canAdd,
  onChange,
}: {
  target: ContentTarget;
  id: string;
  reactions: ReactionCounts;
  mine: readonly string[];
  canAdd: boolean;
  /** Called with the API's answer so the caller updates its copy. */
  onChange: (counts: ReactionCounts, mine: string[]) => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const numbers = new Intl.NumberFormat(formatLocale);
  const describe = useCommunityError();
  const react = useMutation({
    mutationFn: ({ kind, on }: Toggle) => communitiesApi.react(target, id, kind, on),
  });

  const toggle = (kind: ReactionKind) => {
    if (react.isPending) return;
    const on = !mine.includes(kind);
    react.mutate(
      { kind, on },
      {
        onSuccess: (answer) => {
          const next = splitReactions(answer);
          onChange(next.counts, next.mine);
        },
        onError: (error) => {
          toast.show({
            tone: 'danger',
            title: t('communities.reactions.failed'),
            description: describe(error),
          });
        },
      },
    );
  };

  return (
    <div
      role="group"
      aria-label={t('communities.reactions.label')}
      className="flex flex-wrap gap-2"
    >
      {REACTION_KINDS.map((kind) => {
        const pressed = mine.includes(kind);
        const busy = react.isPending && react.variables.kind === kind;
        const label = t(reactionLabel[kind]);
        const count = reactions[kind];
        return (
          <button
            key={kind}
            type="button"
            aria-pressed={pressed}
            aria-label={t('communities.reactions.button', { label, count })}
            aria-busy={busy || undefined}
            disabled={!pressed && !canAdd}
            onClick={() => {
              toggle(kind);
            }}
            className={cx(
              'inline-flex min-h-9 items-center gap-1.5 rounded-full border px-3 text-sm',
              'disabled:cursor-not-allowed disabled:opacity-60',
              pressed
                ? 'border-accent bg-accent-soft font-semibold text-fg'
                : 'border-line-strong bg-surface text-fg hover:bg-surface-muted',
            )}
          >
            {busy ? (
              <Spinner size="sm" />
            ) : pressed ? (
              <Icon name="check" className="size-4" />
            ) : null}
            <span>{label}</span>
            <span className="text-fg-muted tabular-nums">{numbers.format(count)}</span>
          </button>
        );
      })}
    </div>
  );
}
