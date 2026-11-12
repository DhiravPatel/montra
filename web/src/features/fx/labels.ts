import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import type { MessageKey } from '@/shared/i18n/types';
import type { RateSource } from './types';

interface SourceDisplay {
  label: MessageKey;
  icon: IconName;
  tone: Tone;
}

/** Where a rate comes from, always as icon + words. */
export const sourceDisplay: Readonly<Record<RateSource, SourceDisplay>> = {
  manual: { label: 'fx.source.manual', icon: 'pencil', tone: 'info' },
  ecb: { label: 'fx.source.ecb', icon: 'landmark', tone: 'neutral' },
  provider: { label: 'fx.source.provider', icon: 'globe', tone: 'neutral' },
};
