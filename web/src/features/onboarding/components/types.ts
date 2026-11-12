import type { Preferences } from '@/shared/finance/types';

export interface StepProps {
  preferences: Preferences;
  /** Records the step and moves on. */
  onNext: (outcome: 'completed' | 'skipped') => void;
  onBack?: () => void;
  /** True while progress is being recorded. */
  advancing: boolean;
}
