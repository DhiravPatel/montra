import { zodResolver } from '@hookform/resolvers/zod';
import { type ReactNode, useMemo, useState } from 'react';
import { Controller, useForm, useWatch } from 'react-hook-form';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { applyCodedServerErrors } from '@/features/communities/fieldCodes';
import { groupOptions, useGroups } from '@/shared/finance/sharing';
import { FormAlert } from '@/shared/forms/FormAlert';
import { addDaysToLocalDate, isLocalDate } from '@/shared/formatting/dates';
import { useT } from '@/shared/i18n/I18nContext';
import { createErrorMessage } from '../errors';
import {
  type CreateValues,
  MAX_SPAN_DAYS,
  PERCENT_MAX,
  TARGET_MAX,
  TEXT_MAX,
  TITLE_MAX,
  createSchema,
  createServerFields,
  toChallengeInput,
} from '../formValues';
import { useMyCommunities } from '../hooks';
import {
  CHALLENGE_METRICS,
  CHALLENGE_TYPES,
  challengeTypeLabel,
  metricHelp,
  metricLabel,
  visibilityHelp,
  visibilityLabel,
} from '../labels';
import type { ChallengeInput, ChallengeSharing, ChallengeVisibility } from '../types';

const targetHelp = {
  days: 'challenges.form.targetHelp.days',
  streak: 'challenges.form.targetHelp.streak',
  milestones: 'challenges.form.targetHelp.milestones',
  percent: 'challenges.form.targetHelp.percent',
} as const;

interface ChallengeCreateFormProps {
  initialValues: CreateValues;
  /** The user's calendar date (YYYY-MM-DD in their time zone). */
  today: string;
  /** Montra staff may also create public (curated) challenges. */
  staff: boolean;
  /**
   * Creates the challenge, then saves your sharing choice when you made one.
   * Rejects with the API error of the create so the form can show it.
   */
  onSubmit: (input: ChallengeInput, sharing: ChallengeSharing | null) => Promise<void>;
  secondaryAction?: ReactNode;
}

/**
 * Creates a challenge for yourself, a group or a community. Progress is
 * counted in days or check-ins (never money); your own progress stays
 * private unless you choose to share it.
 */
export function ChallengeCreateForm({
  initialValues,
  today,
  staff,
  onSubmit,
  secondaryAction,
}: ChallengeCreateFormProps) {
  const t = useT();
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const schema = useMemo(() => createSchema(t, today), [t, today]);
  const form = useForm<CreateValues, unknown, CreateValues>({
    resolver: zodResolver(schema),
    defaultValues: initialValues,
  });
  const [metric, visibility, startsOn, leaderboard, shareProgress] = useWatch({
    control: form.control,
    name: ['metric', 'visibility', 'startsOn', 'leaderboard', 'shareProgress'],
  });
  const groups = useGroups(visibility === 'group');
  const communities = useMyCommunities(visibility === 'community');
  const shared = visibility !== 'private';

  const onValid = form.handleSubmit(async (values) => {
    if (submitting) return;
    const input = toChallengeInput(values);
    if (!input) return;
    setFormError(null);
    const sharing: ChallengeSharing | null =
      input.visibility !== 'private' && values.shareProgress
        ? {
            share_progress: true,
            show_on_leaderboard: Boolean(input.leaderboard_enabled) && values.showOnLeaderboard,
          }
        : null;
    setSubmitting(true);
    try {
      await onSubmit(input, sharing);
    } catch (error) {
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyCodedServerErrors(error, form.setError, createServerFields, t);
        setFormError(
          rest.length > 0
            ? rest.join(' ')
            : error.details.length === 0
              ? t('errors.VALIDATION_ERROR')
              : null,
        );
      } else {
        setFormError(createErrorMessage(error, t));
      }
    } finally {
      setSubmitting(false);
    }
  });

  const { errors } = form.formState;
  const visibilityChoices: ChallengeVisibility[] = staff
    ? ['private', 'group', 'community', 'public']
    : ['private', 'group', 'community'];
  const endMin = isLocalDate(startsOn) && startsOn > today ? startsOn : today;
  const endMax = isLocalDate(startsOn) ? addDaysToLocalDate(startsOn, MAX_SPAN_DAYS) : undefined;

  // The choice list renders (and registers) once loaded, so a preset group or
  // community from the link shows as selected.
  let audience: ReactNode = null;
  if (visibility === 'group') {
    audience = groups.isPending ? (
      <Select
        key="groups-loading"
        label={t('challenges.form.group')}
        placeholder={t('challenges.form.groupsLoading')}
        disabled
      />
    ) : (
      <Select
        key="groups"
        label={t('challenges.form.group')}
        placeholder={t('challenges.form.groupPlaceholder')}
        options={groupOptions(groups.data)}
        help={
          groups.isError
            ? t('challenges.form.groupsError')
            : groups.data.length === 0
              ? t('challenges.form.noGroups')
              : t('challenges.form.groupHelp')
        }
        error={errors.groupId?.message}
        {...form.register('groupId')}
      />
    );
  } else if (visibility === 'community') {
    audience = communities.isPending ? (
      <Select
        key="communities-loading"
        label={t('challenges.form.community')}
        placeholder={t('challenges.form.communitiesLoading')}
        disabled
      />
    ) : (
      <Select
        key="communities"
        label={t('challenges.form.community')}
        placeholder={t('challenges.form.communityPlaceholder')}
        options={(communities.data ?? []).map((community) => ({
          value: community.id,
          label: community.name,
        }))}
        help={
          communities.isError
            ? t('challenges.form.communitiesError')
            : communities.data.length === 0
              ? t('challenges.form.noCommunities')
              : t('challenges.form.communityHelp')
        }
        error={errors.communityId?.message}
        {...form.register('communityId')}
      />
    );
  }

  return (
    <form onSubmit={onValid} noValidate className="space-y-6">
      <FormAlert message={formError} />
      <TextField
        label={t('challenges.form.title')}
        help={t('challenges.form.titleHelp')}
        maxLength={TITLE_MAX}
        autoComplete="off"
        error={errors.title?.message}
        {...form.register('title')}
      />
      <Select
        label={t('challenges.form.type')}
        placeholder={t('challenges.form.typePlaceholder')}
        options={CHALLENGE_TYPES.map((type) => ({
          value: type,
          label: t(challengeTypeLabel(type)),
        }))}
        error={errors.challengeType?.message}
        {...form.register('challengeType')}
      />
      <TextArea
        label={t('challenges.form.description')}
        optional
        maxLength={TEXT_MAX}
        help={t('challenges.form.textHelp')}
        error={errors.description?.message}
        {...form.register('description')}
      />

      <fieldset className="space-y-5 rounded-lg border border-line p-4">
        <legend className="px-1 text-sm font-semibold text-fg">{t('challenges.form.goal')}</legend>
        <Controller
          control={form.control}
          name="metric"
          render={({ field }) => (
            <RadioGroup
              legend={t('challenges.form.metric')}
              variant="cards"
              value={field.value}
              onChange={field.onChange}
              error={errors.metric?.message}
              options={CHALLENGE_METRICS.map((value) => ({
                value,
                label: t(metricLabel[value]),
                description: t(metricHelp[value]),
              }))}
            />
          )}
        />
        <TextField
          label={t('challenges.form.target')}
          inputMode="numeric"
          autoComplete="off"
          maxLength={4}
          className="sm:max-w-xs"
          help={t(targetHelp[metric], {
            max: metric === 'percent' ? PERCENT_MAX : TARGET_MAX,
          })}
          error={errors.target?.message}
          {...form.register('target')}
        />
        <div className="grid gap-5 sm:grid-cols-2">
          <TextField
            label={t('challenges.form.startsOn')}
            type="date"
            error={errors.startsOn?.message}
            {...form.register('startsOn')}
          />
          <TextField
            label={t('challenges.form.endsOn')}
            type="date"
            min={endMin}
            max={endMax}
            help={t('challenges.form.endsOnHelp')}
            error={errors.endsOn?.message}
            {...form.register('endsOn')}
          />
        </div>
        <TextArea
          label={t('challenges.form.rules')}
          optional
          maxLength={TEXT_MAX}
          help={t('challenges.form.rulesHelp')}
          error={errors.rules?.message}
          {...form.register('rules')}
        />
      </fieldset>

      <fieldset className="space-y-5 rounded-lg border border-line p-4">
        <legend className="px-1 text-sm font-semibold text-fg">
          {t('challenges.form.privacy')}
        </legend>
        <Controller
          control={form.control}
          name="visibility"
          render={({ field }) => (
            <RadioGroup
              legend={t('challenges.form.visibility')}
              variant="cards"
              value={field.value}
              onChange={field.onChange}
              error={errors.visibility?.message}
              options={visibilityChoices.map((value) => ({
                value,
                label: t(visibilityLabel[value]),
                description: t(visibilityHelp[value]),
              }))}
            />
          )}
        />
        {audience}
        {shared ? (
          <>
            <Checkbox
              label={t('challenges.form.leaderboard')}
              description={t('challenges.form.leaderboardHelp')}
              error={errors.leaderboard?.message}
              {...form.register('leaderboard')}
            />
            <div className="space-y-4 rounded-md bg-surface-muted p-4">
              <p className="text-sm font-medium text-fg">{t('challenges.form.yourProgress')}</p>
              <Checkbox
                label={t('challenges.sharing.share')}
                description={t('challenges.sharing.shareHelp')}
                {...form.register('shareProgress')}
              />
              {leaderboard && shareProgress ? (
                <Checkbox
                  label={t('challenges.sharing.leaderboard')}
                  description={t('challenges.sharing.leaderboardHelp')}
                  {...form.register('showOnLeaderboard')}
                />
              ) : null}
              {leaderboard && !shareProgress ? (
                <p className="text-sm text-fg-muted">
                  {t('challenges.sharing.leaderboardNeedsShare')}
                </p>
              ) : null}
            </div>
          </>
        ) : (
          <p className="text-sm text-fg-muted">{t('challenges.sharing.privateChallenge')}</p>
        )}
      </fieldset>

      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        {secondaryAction}
        <Button type="submit" loading={submitting}>
          {t('challenges.create.submit')}
        </Button>
      </div>
    </form>
  );
}
