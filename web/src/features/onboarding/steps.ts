import type { MessageKey } from '@/shared/i18n/types';

/**
 * Onboarding steps, named as the API records them (`POST /me/onboarding`).
 * Every step except the welcome can be skipped; bank linking is never asked.
 * The region step covers the API's country, currency and timezone steps.
 */
export const ONBOARDING_STEPS = [
  { id: 'welcome', apiSteps: ['welcome'], title: 'onboarding.welcome.title', skippable: false },
  { id: 'privacy', apiSteps: ['privacy'], title: 'onboarding.privacy.title', skippable: true },
  {
    id: 'region',
    apiSteps: ['country', 'currency', 'timezone'],
    title: 'onboarding.region.title',
    skippable: true,
  },
  { id: 'income', apiSteps: ['income'], title: 'onboarding.income.title', skippable: true },
  { id: 'accounts', apiSteps: ['accounts'], title: 'onboarding.accounts.title', skippable: true },
  {
    id: 'categories',
    apiSteps: ['categories'],
    title: 'onboarding.categories.title',
    skippable: true,
  },
  {
    id: 'notifications',
    apiSteps: ['notifications'],
    title: 'onboarding.notifications.title',
    skippable: true,
  },
] as const satisfies readonly {
  id: string;
  apiSteps: readonly string[];
  title: MessageKey;
  skippable: boolean;
}[];

export type OnboardingStepId = (typeof ONBOARDING_STEPS)[number]['id'];

export interface OnboardingProgress {
  completed: string[];
  skipped: string[];
}

/** Records a step as completed or skipped (a later choice replaces an earlier one). */
export function recordStep(
  progress: OnboardingProgress,
  stepIndex: number,
  outcome: 'completed' | 'skipped',
): OnboardingProgress {
  const step = ONBOARDING_STEPS[stepIndex];
  if (!step) return progress;
  const names: readonly string[] = step.apiSteps;
  const completed = progress.completed.filter((name) => !names.includes(name));
  const skipped = progress.skipped.filter((name) => !names.includes(name));
  return outcome === 'completed'
    ? { completed: [...completed, ...names], skipped }
    : { completed, skipped: [...skipped, ...names] };
}

/** Everything not yet decided, marked skipped (used by "Skip setup"). */
export function skipRemaining(progress: OnboardingProgress): OnboardingProgress {
  const decided = new Set([...progress.completed, ...progress.skipped]);
  const rest = ONBOARDING_STEPS.flatMap((step) => [...step.apiSteps]).filter(
    (name) => !decided.has(name),
  );
  return { completed: progress.completed, skipped: [...progress.skipped, ...rest] };
}

/** Where to resume: the first step not yet completed or skipped (the welcome when nothing is saved). */
export function resumeIndex(progress: OnboardingProgress): number {
  const decided = new Set([...progress.completed, ...progress.skipped]);
  if (decided.size === 0) return 0;
  const index = ONBOARDING_STEPS.findIndex(
    (step) => !step.apiSteps.every((name) => decided.has(name)),
  );
  return index === -1 ? 0 : index;
}
