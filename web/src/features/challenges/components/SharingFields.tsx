import { Checkbox } from '@/shared/components/Checkbox';
import { useT } from '@/shared/i18n/I18nContext';
import type { SharingChoice } from '../sharing';

/**
 * The two opt-ins: share your percentage with people in the challenge, and
 * (when the challenge has a leaderboard) appear on it. Both start off.
 */
export function SharingFields({
  value,
  onChange,
  leaderboardEnabled,
  disabled = false,
}: {
  value: SharingChoice;
  onChange: (value: SharingChoice) => void;
  leaderboardEnabled: boolean;
  disabled?: boolean;
}) {
  const t = useT();
  return (
    <div className="space-y-4">
      <Checkbox
        label={t('challenges.sharing.share')}
        description={t('challenges.sharing.shareHelp')}
        checked={value.share}
        disabled={disabled}
        onChange={(event) => {
          const share = event.target.checked;
          onChange({ share, leaderboard: share && value.leaderboard });
        }}
      />
      {leaderboardEnabled ? (
        <Checkbox
          label={t('challenges.sharing.leaderboard')}
          description={
            value.share
              ? t('challenges.sharing.leaderboardHelp')
              : t('challenges.sharing.leaderboardNeedsShare')
          }
          checked={value.share && value.leaderboard}
          disabled={disabled || !value.share}
          onChange={(event) => {
            onChange({ ...value, leaderboard: event.target.checked });
          }}
        />
      ) : null}
    </div>
  );
}
