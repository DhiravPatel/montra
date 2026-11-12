import { useMutation, useQuery } from '@tanstack/react-query';
import { type JSX, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths } from '@/shared/config/paths';
import { usePreferences } from '@/shared/finance/reference';
import type { OnboardingInput } from '@/shared/finance/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { onboardingApi } from '../api';
import { AccountsStep } from '../components/AccountsStep';
import { CategoriesStep } from '../components/CategoriesStep';
import { IncomeStep } from '../components/IncomeStep';
import { NotificationsStep } from '../components/NotificationsStep';
import { PrivacyStep } from '../components/PrivacyStep';
import { RegionStep } from '../components/RegionStep';
import type { StepProps } from '../components/types';
import { WelcomeStep } from '../components/WelcomeStep';
import {
  ONBOARDING_STEPS,
  type OnboardingProgress,
  type OnboardingStepId,
  recordStep,
  resumeIndex,
  skipRemaining,
} from '../steps';

const stepComponents: Readonly<
  Record<Exclude<OnboardingStepId, 'welcome'>, (props: StepProps) => JSX.Element>
> = {
  privacy: PrivacyStep,
  region: RegionStep,
  income: IncomeStep,
  accounts: AccountsStep,
  categories: CategoriesStep,
  notifications: NotificationsStep,
};

/**
 * Post-sign-up setup (spec §4.1, §20B.2): every step after the welcome is
 * optional, progress is recorded with `POST /me/onboarding`, and finishing or
 * skipping marks onboarding complete. Bank linking is never asked for.
 */
export function OnboardingPage() {
  const t = useT();
  useDocumentTitle(t('onboarding.title'));
  const saved = useQuery({
    queryKey: ['me', 'onboarding'],
    queryFn: ({ signal }) => onboardingApi.get(signal),
    staleTime: 0,
  });
  // Without saved progress (an older API or an error) setup simply starts at the welcome.
  const initial: OnboardingProgress | null = saved.isPending
    ? null
    : saved.isSuccess
      ? { completed: saved.data.completed_steps, skipped: saved.data.skipped_steps }
      : { completed: [], skipped: [] };
  // One page heading for the whole flow, so focus and the route announcement stay on it.
  return (
    <div className="mx-auto max-w-3xl">
      <PageHeader title={t('onboarding.title')} description={t('onboarding.description')} />
      {initial ? (
        <OnboardingFlow initial={initial} />
      ) : (
        <LoadingState label={t('onboarding.loading')} />
      )}
    </div>
  );
}

function OnboardingFlow({ initial }: { initial: OnboardingProgress }) {
  const t = useT();
  const toast = useToast();
  const navigate = useNavigate();
  const { refreshUser } = useAuth();
  const preferences = usePreferences();
  const [index, setIndex] = useState(() => resumeIndex(initial));
  const [progress, setProgress] = useState<OnboardingProgress>(initial);
  const [finished, setFinished] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const headingRef = useRef<HTMLHeadingElement>(null);
  const moved = useRef(false);
  const record = useMutation({ mutationFn: (body: OnboardingInput) => onboardingApi.record(body) });

  // Move focus to the new step's heading after Continue/Back/Skip (not on first load).
  useEffect(() => {
    if (!moved.current) return;
    headingRef.current?.focus();
  }, [index, finished]);

  const submitProgress = async (next: OnboardingProgress, complete: boolean) => {
    await record.mutateAsync({
      completed_steps: next.completed,
      skipped_steps: next.skipped,
      complete,
    });
    if (complete) await refreshUser();
  };

  const go = (nextIndex: number) => {
    moved.current = true;
    setError(null);
    setIndex(nextIndex);
  };

  const advance = (outcome: 'completed' | 'skipped') => {
    if (record.isPending) return;
    const next = recordStep(progress, index, outcome);
    setProgress(next);
    const last = index === ONBOARDING_STEPS.length - 1;
    submitProgress(next, last)
      .then(() => {
        if (last) {
          moved.current = true;
          setFinished(true);
        } else {
          go(index + 1);
        }
      })
      .catch((failure: unknown) => {
        if (last) {
          setError(describeError(failure, t));
          return;
        }
        // Saving progress is a convenience; the step's own changes are already saved.
        toast.show({ tone: 'warning', title: t('onboarding.progressNotSaved') });
        go(index + 1);
      });
  };

  const skipAll = () => {
    if (record.isPending) return;
    setError(null);
    submitProgress(skipRemaining(progress), true)
      .then(() => {
        toast.show({ tone: 'info', title: t('onboarding.skipped') });
        void navigate(paths.dashboard);
      })
      .catch((failure: unknown) => {
        setError(describeError(failure, t));
      });
  };

  let body;
  if (preferences.isPending) {
    body = <LoadingState label={t('onboarding.loading')} />;
  } else if (preferences.isError) {
    body = (
      <ErrorState
        title={t('onboarding.loadFailed')}
        error={preferences.error}
        retrying={preferences.isFetching}
        onRetry={() => {
          void preferences.refetch();
        }}
      />
    );
  } else if (finished) {
    body = (
      <div className="space-y-5">
        <p className="text-fg">{t('onboarding.done.body')}</p>
        <div className="flex flex-wrap gap-3">
          <ButtonLink to={paths.dashboard}>
            <Icon name="home" className="size-4" />
            {t('onboarding.done.dashboard')}
          </ButtonLink>
          <ButtonLink to={paths.transactionNew} variant="secondary">
            <Icon name="plus" className="size-4" />
            {t('transactions.add')}
          </ButtonLink>
        </div>
      </div>
    );
  } else {
    const step = ONBOARDING_STEPS[index];
    if (!step || step.id === 'welcome') {
      body = (
        <WelcomeStep
          onStart={() => {
            advance('completed');
          }}
          onSkipAll={skipAll}
          skipping={record.isPending}
        />
      );
    } else {
      const Step = stepComponents[step.id];
      body = (
        <Step
          preferences={preferences.data}
          advancing={record.isPending}
          onNext={advance}
          onBack={() => {
            go(index - 1);
          }}
        />
      );
    }
  }

  const current = ONBOARDING_STEPS[index];
  const title = finished ? t('onboarding.done.title') : current ? t(current.title) : '';

  return (
    <>
      {!finished ? (
        <nav aria-label={t('onboarding.progressLabel')} className="mb-6">
          <p className="mb-2 text-sm font-medium text-fg">
            {t('onboarding.stepOf', { current: index + 1, total: ONBOARDING_STEPS.length })}
          </p>
          <ol className="flex gap-1.5">
            {ONBOARDING_STEPS.map((step, position) => (
              <li
                key={step.id}
                aria-current={position === index ? 'step' : undefined}
                className={cx(
                  'h-1.5 flex-1 rounded-full',
                  position < index
                    ? 'bg-accent'
                    : position === index
                      ? 'bg-accent-hover'
                      : 'bg-line',
                )}
              >
                <span className="sr-only">
                  {t(step.title)}
                  {position < index ? ` (${t('onboarding.stepDone')})` : ''}
                </span>
              </li>
            ))}
          </ol>
        </nav>
      ) : null}
      {error ? (
        <Alert tone="danger" live="assertive" className="mb-6">
          {error}
        </Alert>
      ) : null}
      <Card>
        <h2
          ref={headingRef}
          tabIndex={-1}
          className="mb-5 text-xl font-semibold text-fg outline-none"
        >
          {title}
        </h2>
        {body}
      </Card>
    </>
  );
}
