import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useEffect, useRef, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useAuth } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Checkbox } from '@/shared/components/Checkbox';
import { RadioGroup, type RadioOption } from '@/shared/components/RadioGroup';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { socialApi } from '../api';
import { usernameErrorMessage } from '../errors';
import { useOwnProfile } from '../hooks';
import { socialKeys } from '../keys';
import { isValidUsername, normalizeUsername } from '../people';
import type { FriendRequestPolicy, OwnProfile, OwnProfilePatch } from '../types';

function useSaveProfile() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (patch: OwnProfilePatch) => socialApi.updateProfile(patch),
    onSuccess: (profile) => {
      queryClient.setQueryData(socialKeys.profile(), profile);
    },
  });
}

/** Choose or change the username people use to find you. */
function UsernameCard({ profile, focusOnMount }: { profile: OwnProfile; focusOnMount: boolean }) {
  const t = useT();
  const toast = useToast();
  const { refreshUser } = useAuth();
  const save = useSaveProfile();
  const inputRef = useRef<HTMLInputElement>(null);
  const [value, setValue] = useState(profile.username ?? '');
  const [error, setError] = useState<string | undefined>(undefined);
  const [formError, setFormError] = useState<string | null>(null);

  // "Choose a username" elsewhere on the page brings keyboard focus here.
  useEffect(() => {
    if (focusOnMount) inputRef.current?.focus();
  }, [focusOnMount]);

  const onSubmit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (save.isPending) return;
    setFormError(null);
    const username = normalizeUsername(value);
    if (!isValidUsername(username)) {
      setError(username === '' ? t('social.username.required') : t('social.username.invalid'));
      inputRef.current?.focus();
      return;
    }
    setError(undefined);
    if (username === profile.username) {
      toast.show({ tone: 'info', title: t('social.username.unchanged', { username }) });
      return;
    }
    save.mutate(
      { username },
      {
        onSuccess: (updated) => {
          const saved = updated.username ?? username;
          setValue(saved);
          toast.show({
            tone: 'success',
            title: t('social.username.saved', { username: saved }),
            description: updated.discoverable_by_username
              ? t('social.username.savedFindable')
              : t('social.username.savedHidden'),
          });
          // The signed-in user carries the username too (used across the app).
          void refreshUser();
        },
        onError: (failure) => {
          const problem = usernameErrorMessage(failure, t);
          if (problem) setError(problem);
          else if (hasErrorCode(failure, 'VALIDATION_ERROR'))
            setError(t('social.username.unavailable'));
          else setFormError(describeError(failure, t));
          inputRef.current?.focus();
        },
      },
    );
  };

  return (
    <Card title={t('social.username.title')} description={t('social.username.description')}>
      <form noValidate onSubmit={onSubmit} className="space-y-4">
        <FormAlert message={formError} />
        {profile.username ? (
          <p className="text-sm text-fg">
            {t('social.username.current', { username: profile.username })}
          </p>
        ) : (
          <Alert tone="info">{t('social.username.none')}</Alert>
        )}
        <TextField
          ref={inputRef}
          label={t('social.username.label')}
          help={t('social.username.help')}
          error={error}
          value={value}
          maxLength={31}
          autoComplete="off"
          autoCapitalize="none"
          spellCheck={false}
          onChange={(event) => {
            setValue(event.target.value);
          }}
        />
        <Button type="submit" loading={save.isPending}>
          {profile.username ? t('social.username.change') : t('social.username.save')}
        </Button>
      </form>
    </Card>
  );
}

/** Who can find you by username and who can send you friend requests. */
function PrivacySettingsCard({ profile }: { profile: OwnProfile }) {
  const t = useT();
  const toast = useToast();
  const save = useSaveProfile();
  const [discoverable, setDiscoverable] = useState(profile.discoverable_by_username);
  const [policy, setPolicy] = useState<FriendRequestPolicy>(profile.allow_friend_requests);
  const [formError, setFormError] = useState<string | null>(null);

  const options: RadioOption<FriendRequestPolicy>[] = [
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
  ];

  const onSubmit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (save.isPending) return;
    setFormError(null);
    save.mutate(
      { discoverable_by_username: discoverable, allow_friend_requests: policy },
      {
        onSuccess: () => {
          toast.show({ tone: 'success', title: t('social.privacy.saved') });
        },
        onError: (failure) => {
          setFormError(describeError(failure, t));
        },
      },
    );
  };

  return (
    <Card title={t('social.privacy.title')} description={t('social.privacy.description')}>
      <form noValidate onSubmit={onSubmit} className="space-y-6">
        <FormAlert message={formError} />
        <Checkbox
          label={t('social.privacy.discoverable')}
          description={
            <>
              <span className="block">
                {profile.username
                  ? t('social.privacy.discoverableHelp', { username: profile.username })
                  : t('social.privacy.discoverableNoUsername')}
              </span>
              {/* New accounts are hidden until they opt in (the API's default). */}
              {profile.discoverable_by_username ? null : (
                <span className="mt-1 block">{t('social.privacy.hiddenByDefault')}</span>
              )}
            </>
          }
          checked={discoverable}
          onChange={(event) => {
            setDiscoverable(event.target.checked);
          }}
        />
        <RadioGroup
          variant="cards"
          legend={t('social.privacy.requests.legend')}
          help={t('social.privacy.requests.help')}
          value={policy}
          onChange={setPolicy}
          options={options}
        />
        <p className="text-sm text-fg-muted">{t('social.privacy.moneyNote')}</p>
        <Button type="submit" loading={save.isPending}>
          {t('social.privacy.save')}
        </Button>
      </form>
    </Card>
  );
}

/** Your username and social privacy settings (both saved with PATCH /me). */
export function PrivacyPanel({ focusUsername }: { focusUsername: boolean }) {
  const t = useT();
  const profile = useOwnProfile();

  if (profile.isPending || profile.isError) {
    return (
      <Card title={t('social.privacy.title')}>
        {profile.isPending ? (
          <LoadingState label={t('social.privacy.loading')} />
        ) : hasErrorCode(profile.error, 'FORBIDDEN') ? (
          <PermissionDenied />
        ) : (
          <ErrorState
            title={t('social.privacy.error')}
            error={profile.error}
            retrying={profile.isFetching}
            onRetry={() => {
              void profile.refetch();
            }}
          />
        )}
      </Card>
    );
  }

  return (
    <>
      <UsernameCard profile={profile.data} focusOnMount={focusUsername} />
      <PrivacySettingsCard profile={profile.data} />
    </>
  );
}
