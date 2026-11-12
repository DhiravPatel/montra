import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon, type IconName } from '@/shared/components/Icon';
import { useToast } from '@/shared/components/toast/ToastContext';
import { goalEditPath } from '@/shared/config/paths';
import { isStaleRecordError } from '@/shared/finance/domainErrors';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { Goal, GoalStatus } from '@/shared/finance/types';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { goalsApi } from '../api';
import { goalErrorMessage } from '../errors';

type LifecycleAction = 'pause' | 'resume' | 'reopen' | 'restore' | 'achieve' | 'cancel' | 'archive';

/** Status changes the API accepts from each status. */
const ACTIONS: Readonly<Record<GoalStatus, readonly LifecycleAction[]>> = {
  active: ['pause', 'achieve', 'cancel', 'archive'],
  paused: ['resume', 'achieve', 'cancel', 'archive'],
  achieved: ['archive'],
  cancelled: ['reopen', 'archive'],
  archived: ['restore'],
};

const ICONS: Readonly<Record<LifecycleAction, IconName>> = {
  pause: 'pause',
  resume: 'play',
  reopen: 'rotate-ccw',
  restore: 'archive-restore',
  achieve: 'flag',
  cancel: 'x-circle',
  archive: 'archive',
};

const COPY: Readonly<
  Record<
    LifecycleAction,
    {
      action: MessageKey;
      title: MessageKey;
      body: MessageKey;
      confirm: MessageKey;
      done: MessageKey;
    }
  >
> = {
  pause: {
    action: 'goals.lifecycle.pause.action',
    title: 'goals.lifecycle.pause.title',
    body: 'goals.lifecycle.pause.body',
    confirm: 'goals.lifecycle.pause.confirm',
    done: 'goals.lifecycle.pause.done',
  },
  resume: {
    action: 'goals.lifecycle.resume.action',
    title: 'goals.lifecycle.resume.title',
    body: 'goals.lifecycle.resume.body',
    confirm: 'goals.lifecycle.resume.confirm',
    done: 'goals.lifecycle.resume.done',
  },
  reopen: {
    action: 'goals.lifecycle.reopen.action',
    title: 'goals.lifecycle.reopen.title',
    body: 'goals.lifecycle.reopen.body',
    confirm: 'goals.lifecycle.reopen.confirm',
    done: 'goals.lifecycle.reopen.done',
  },
  restore: {
    action: 'goals.lifecycle.restore.action',
    title: 'goals.lifecycle.restore.title',
    body: 'goals.lifecycle.restore.body',
    confirm: 'goals.lifecycle.restore.confirm',
    done: 'goals.lifecycle.restore.done',
  },
  achieve: {
    action: 'goals.lifecycle.achieve.action',
    title: 'goals.lifecycle.achieve.title',
    body: 'goals.lifecycle.achieve.body',
    confirm: 'goals.lifecycle.achieve.confirm',
    done: 'goals.lifecycle.achieve.done',
  },
  cancel: {
    action: 'goals.lifecycle.cancel.action',
    title: 'goals.lifecycle.cancel.title',
    body: 'goals.lifecycle.cancel.body',
    confirm: 'goals.lifecycle.cancel.confirm',
    done: 'goals.lifecycle.cancel.done',
  },
  archive: {
    action: 'goals.lifecycle.archive.action',
    title: 'goals.lifecycle.archive.title',
    body: 'goals.lifecycle.archive.body',
    confirm: 'goals.lifecycle.archive.confirm',
    done: 'goals.lifecycle.archive.done',
  },
};

/** Sends the version on screen, so a goal changed elsewhere is not acted on blindly. */
function run(goal: Goal, action: LifecycleAction): Promise<Goal> {
  switch (action) {
    case 'archive':
      return goalsApi.archive(goal.id, goal.version);
    // Reopening a cancelled goal and restoring an archived one both resume it.
    case 'reopen':
    case 'restore':
    case 'resume':
      return goalsApi.transition(goal.id, 'resume', goal.version);
    case 'pause':
    case 'achieve':
    case 'cancel':
      return goalsApi.transition(goal.id, action, goal.version);
  }
}

/** Owner-only: edit, pause/resume, achieve, cancel, archive/restore (with confirmation). */
export function GoalManageCard({ goal }: { goal: Goal }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [action, setAction] = useState<LifecycleAction | null>(null);
  const [error, setError] = useState<string | null>(null);
  const mutation = useMutation({
    mutationFn: (next: LifecycleAction) => run(goal, next),
    onSuccess: (updated) => {
      queryClient.setQueryData(financeKeys.goal(updated.id), updated);
      void invalidateFinance(queryClient);
    },
  });

  const confirm = () => {
    if (!action || mutation.isPending) return;
    setError(null);
    mutation.mutate(action, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t(COPY[action].done) });
        setAction(null);
      },
      onError: (failure) => {
        // A stale version or a status that changed elsewhere (422
        // invalid_status_transition): explain it and load the current goal.
        setError(goalErrorMessage(failure, t, formatLocale));
        if (isStaleRecordError(failure)) {
          void queryClient.invalidateQueries({ queryKey: financeKeys.goal(goal.id) });
        }
      },
    });
  };

  const destructive = action === 'cancel' || action === 'archive';

  return (
    <>
      <Card title={t('goals.manage.title')}>
        <div className="flex flex-col gap-3">
          {goal.status !== 'archived' ? (
            <ButtonLink to={goalEditPath(goal.id)} variant="secondary">
              <Icon name="pencil" className="size-4" />
              {t('goals.edit.action')}
            </ButtonLink>
          ) : null}
          {ACTIONS[goal.status].map((item) => (
            <Button
              key={item}
              variant="secondary"
              onClick={() => {
                setError(null);
                setAction(item);
              }}
            >
              <Icon name={ICONS[item]} className="size-4" />
              {t(COPY[item].action)}
            </Button>
          ))}
        </div>
      </Card>
      <ConfirmDialog
        open={action !== null}
        onOpenChange={(open) => {
          if (!open) setAction(null);
        }}
        tone={destructive ? 'danger' : 'primary'}
        title={action ? t(COPY[action].title) : ''}
        description={action ? t(COPY[action].body) : ''}
        confirmLabel={action ? t(COPY[action].confirm) : ''}
        cancelLabel={action === 'cancel' ? t('goals.lifecycle.keep') : undefined}
        onConfirm={confirm}
        pending={mutation.isPending}
        error={error}
      />
    </>
  );
}
