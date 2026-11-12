import { zodResolver } from '@hookform/resolvers/zod';
import { useMemo, useState } from 'react';
import { Controller, useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Checkbox } from '@/shared/components/Checkbox';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { fieldIssueMessage } from '@/shared/finance/domainErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { usernameErrorMessage } from '@/features/social/errors';
import { normalizeUsername } from '@/features/social/people';
import type { OwnProfile } from '@/features/social/types';
import { useSaveProfile } from '../profileApi';
import {
  MAX_INTEREST_LENGTH,
  MAX_INTERESTS,
  parseInterests,
  type ProfileValues,
  profilePatch,
  profileValues,
} from '../profileValues';

/** API fields (without `body.`) and the form fields they belong to. */
const FIELD_MAP: Readonly<Record<string, keyof ProfileValues>> = {
  display_name: 'displayName',
  username: 'username',
  bio: 'bio',
  interests: 'interests',
  coarse_location: 'coarseLocation',
  profile_visibility: 'profileVisibility',
  allow_friend_requests: 'allowFriendRequests',
};

/** Name, username, bio, interests, coarse location and who sees them (PATCH /me). */
export function ProfileCard({ profile }: { profile: OwnProfile }) {
  const t = useT();
  const toast = useToast();
  const save = useSaveProfile();
  const [formError, setFormError] = useState<string | null>(null);

  const schema = useMemo(
    () =>
      z.object({
        displayName: z
          .string()
          .trim()
          .min(1, { error: t('profileSettings.profile.displayNameRequired') })
          .max(80, { error: t('profileSettings.profile.displayNameTooLong') }),
        username: z.string().refine(
          (value) => {
            const username = normalizeUsername(value);
            return username === '' || /^[a-z0-9_.]{3,30}$/.test(username);
          },
          { error: t('social.username.invalid') },
        ),
        bio: z.string().max(280, { error: t('profileSettings.profile.bioTooLong') }),
        interests: z.string().refine(
          (value) => {
            const list = parseInterests(value);
            return (
              list.length <= MAX_INTERESTS &&
              list.every((item) => item.length <= MAX_INTEREST_LENGTH)
            );
          },
          {
            error: t('profileSettings.profile.interestsInvalid', {
              count: MAX_INTERESTS,
              length: MAX_INTEREST_LENGTH,
            }),
          },
        ),
        coarseLocation: z.string().max(80, { error: t('profileSettings.profile.locationTooLong') }),
        profileVisibility: z.enum(['private', 'connections', 'public']),
        discoverable: z.boolean(),
        showAchievements: z.boolean(),
        allowFriendRequests: z.enum(['everyone', 'friends_of_friends', 'nobody']),
      }),
    [t],
  );

  const form = useForm<ProfileValues, unknown, ProfileValues>({
    resolver: zodResolver(schema),
    defaultValues: profileValues(profile),
  });
  const { errors } = form.formState;

  const onSubmit = form.handleSubmit((values) => {
    if (save.isPending) return;
    setFormError(null);
    const patch = profilePatch(values, profile);
    if (Object.keys(patch).length === 0) {
      toast.show({ tone: 'info', title: t('profileSettings.nothingChanged') });
      return;
    }
    save.mutate(patch, {
      onSuccess: (updated) => {
        form.reset(profileValues(updated));
        toast.show({ tone: 'success', title: t('profileSettings.profile.saved') });
      },
      onError: (error) => {
        const username = usernameErrorMessage(error, t);
        if (username) {
          form.setError('username', { type: 'server', message: username }, { shouldFocus: true });
          return;
        }
        if (isApiError(error) && hasErrorCode(error, 'VALIDATION_ERROR')) {
          const rest: string[] = [];
          let focused = false;
          for (const detail of error.details) {
            const field = FIELD_MAP[detail.field?.replace(/^body\./, '') ?? ''];
            const message = fieldIssueMessage(detail, t);
            if (field) {
              form.setError(field, { type: 'server', message }, { shouldFocus: !focused });
              focused = true;
            } else {
              rest.push(message);
            }
          }
          if (rest.length > 0) setFormError(rest.join(' '));
          return;
        }
        setFormError(describeError(error, t));
      },
    });
  });

  return (
    <Card
      title={t('profileSettings.profile.title')}
      description={t('profileSettings.profile.description')}
    >
      <form noValidate onSubmit={onSubmit} className="space-y-6">
        <FormAlert message={formError} />
        <div className="grid gap-5 sm:grid-cols-2">
          <TextField
            label={t('profileSettings.profile.displayName')}
            help={t('profileSettings.profile.displayNameHelp')}
            autoComplete="name"
            maxLength={80}
            error={errors.displayName?.message}
            {...form.register('displayName')}
          />
          <TextField
            label={t('social.username.label')}
            optional
            help={t('profileSettings.profile.usernameHelp')}
            autoComplete="off"
            autoCapitalize="none"
            spellCheck={false}
            maxLength={31}
            error={errors.username?.message}
            {...form.register('username')}
          />
        </div>
        <TextArea
          label={t('profileSettings.profile.bio')}
          optional
          help={t('profileSettings.profile.bioHelp')}
          rows={3}
          maxLength={280}
          error={errors.bio?.message}
          {...form.register('bio')}
        />
        <div className="grid gap-5 sm:grid-cols-2">
          <TextField
            label={t('profileSettings.profile.interests')}
            optional
            help={t('profileSettings.profile.interestsHelp', { count: MAX_INTERESTS })}
            error={errors.interests?.message}
            {...form.register('interests')}
          />
          <TextField
            label={t('profileSettings.profile.location')}
            optional
            help={t('profileSettings.profile.locationHelp')}
            maxLength={80}
            error={errors.coarseLocation?.message}
            {...form.register('coarseLocation')}
          />
        </div>

        <Controller
          control={form.control}
          name="profileVisibility"
          render={({ field, fieldState }) => (
            <RadioGroup
              variant="cards"
              legend={t('profileSettings.visibility.legend')}
              help={t('profileSettings.visibility.help')}
              value={field.value}
              onChange={field.onChange}
              error={fieldState.error?.message}
              options={[
                {
                  value: 'private',
                  label: t('profileSettings.visibility.private'),
                  description: t('profileSettings.visibility.privateHelp'),
                },
                {
                  value: 'connections',
                  label: t('profileSettings.visibility.connections'),
                  description: t('profileSettings.visibility.connectionsHelp'),
                },
                {
                  value: 'public',
                  label: t('profileSettings.visibility.public'),
                  description: t('profileSettings.visibility.publicHelp'),
                },
              ]}
            />
          )}
        />
        <div className="space-y-4">
          <Checkbox
            label={t('social.privacy.discoverable')}
            description={t('profileSettings.discoverableHelp')}
            {...form.register('discoverable')}
          />
          <Checkbox
            label={t('profileSettings.showAchievements')}
            description={t('profileSettings.showAchievementsHelp')}
            {...form.register('showAchievements')}
          />
        </div>
        <Controller
          control={form.control}
          name="allowFriendRequests"
          render={({ field }) => (
            <RadioGroup
              variant="cards"
              legend={t('social.privacy.requests.legend')}
              help={t('social.privacy.requests.help')}
              value={field.value}
              onChange={field.onChange}
              options={[
                {
                  value: 'everyone',
                  label: t('social.privacy.requests.everyone'),
                  description: t('social.privacy.requests.everyoneHelp'),
                },
                {
                  value: 'friends_of_friends',
                  label: t('social.privacy.requests.friendsOfFriends'),
                  description: t('social.privacy.requests.friendsOfFriendsHelp'),
                },
                {
                  value: 'nobody',
                  label: t('social.privacy.requests.nobody'),
                  description: t('social.privacy.requests.nobodyHelp'),
                },
              ]}
            />
          )}
        />
        <p className="text-sm text-fg-muted">{t('social.privacy.moneyNote')}</p>
        <Button type="submit" loading={save.isPending}>
          {t('profileSettings.profile.save')}
        </Button>
      </form>
    </Card>
  );
}
