import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useState } from 'react';
import { isApiError } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { useToast } from '@/shared/components/toast/ToastContext';
import { domainRuleCode } from '@/shared/finance/domainErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { notificationsApi } from '../api';
import {
  ALWAYS_ON_CATEGORIES,
  CHANNELS,
  categoryInfo,
  categorySections,
  channelLabel,
  isNotificationCategory,
} from '../categories';
import { notificationsKeys } from '../keys';
import type {
  DigestTiming,
  EmailDigest,
  NotificationChannel,
  NotificationPreference,
  NotificationPreferencePatch,
} from '../types';

interface Setting {
  enabled: boolean;
  digest: DigestTiming;
  locked: boolean;
}

type Settings = ReadonlyMap<string, Setting>;

const settingKey = (category: string, channel: NotificationChannel) => `${category}|${channel}`;

/**
 * A failed save in words. The server refuses to turn off security and
 * account notifications (a field error on `items[i].enabled`, or the coded
 * rule `always_on_category`); the form never sends that, but says so if a
 * locked category changed on the server meanwhile.
 */
function saveErrorMessage(error: unknown, t: Translate): string {
  const alwaysOn =
    domainRuleCode(error)?.code === 'always_on_category' ||
    (isApiError(error) &&
      error.code === 'VALIDATION_ERROR' &&
      error.details.some((detail) => /^body\.items\[\d+\]\.enabled$/.test(detail.field ?? '')));
  return alwaysOn ? t('notifications.prefs.alwaysOn.title') : describeError(error, t);
}

/** Category-level rows (group-specific rows are left as they are). */
function toSettings(preferences: readonly NotificationPreference[]): Settings {
  const settings = new Map<string, Setting>();
  for (const row of preferences) {
    if (row.group_id) continue;
    settings.set(settingKey(row.category, row.channel), {
      enabled: row.locked ? true : row.enabled,
      digest: row.digest,
      locked: row.locked,
    });
  }
  return settings;
}

/** Categories in display order: known sections first, then anything newer from the server. */
function categoryGroups(settings: Settings) {
  const present = new Set([...settings.keys()].map((key) => key.split('|')[0] ?? ''));
  const known = categorySections
    .map((section) => ({
      ...section,
      categories: section.categories.filter((category) => present.has(category)),
    }))
    .filter((section) => section.categories.length > 0);
  const others = [...present].filter((category) => category && !isNotificationCategory(category));
  return others.length > 0
    ? [...known, { id: 'other', label: 'notifications.section.other' as const, categories: others }]
    : known;
}

interface PreferencesFormProps {
  preferences: readonly NotificationPreference[];
  /** The account-level summary setting; null while unknown. */
  emailDigest: EmailDigest | null;
}

/** The email timing choices for one category (a summary here overrides the account setting). */
function timingOptions(emailDigest: EmailDigest | null, t: Translate) {
  const follow =
    emailDigest === 'daily'
      ? t('notifications.timing.followDaily')
      : emailDigest === 'weekly'
        ? t('notifications.timing.followWeekly')
        : t('notifications.timing.immediate');
  return [
    { value: 'immediate', label: follow },
    { value: 'daily', label: t('notifications.timing.daily') },
    { value: 'weekly', label: t('notifications.timing.weekly') },
  ];
}

function isDigestTiming(value: string): value is DigestTiming {
  return value === 'immediate' || value === 'daily' || value === 'weekly';
}

/**
 * Which notifications arrive where: one group of channel checkboxes per
 * category, and for email the timing (right away, or held for a daily or
 * weekly summary, which overrides the account setting for that category).
 * Security and account notifications are always on in Montra and by email
 * (the server marks them `locked`). Saving sends only the changed rows,
 * and in each only the field that changed: the server keeps the rest.
 */
export function PreferencesForm({ preferences, emailDigest }: PreferencesFormProps) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [base] = useState(() => toSettings(preferences));
  const [draft, setDraft] = useState<Settings>(base);
  const [error, setError] = useState<string | null>(null);
  const hasGroupRows = preferences.some((row) => Boolean(row.group_id));
  // The form remounts with the saved rows (keyed by the query), so the toast
  // lives on the mutation rather than on this render's mutate() call.
  const save = useMutation({
    mutationFn: notificationsApi.updatePreferences,
    onSuccess: (updated) => {
      toast.show({ tone: 'success', title: t('notifications.prefs.saved') });
      queryClient.setQueryData(notificationsKeys.preferences(), updated);
    },
  });

  const changes: NotificationPreferencePatch[] = [];
  for (const [key, setting] of draft) {
    const before = base.get(key);
    if (!before || setting.locked) continue;
    const enabledChanged = before.enabled !== setting.enabled;
    const digestChanged = before.digest !== setting.digest;
    if (!enabledChanged && !digestChanged) continue;
    const [category, channel] = key.split('|') as [string, NotificationChannel];
    changes.push({
      category,
      channel,
      ...(enabledChanged ? { enabled: setting.enabled } : {}),
      ...(digestChanged ? { digest: setting.digest } : {}),
    });
  }
  const dirty = changes.length > 0;

  const update = (category: string, channel: NotificationChannel, change: Partial<Setting>) => {
    setDraft((current) => {
      const key = settingKey(category, channel);
      const setting = current.get(key);
      if (!setting || setting.locked) return current;
      const next = new Map(current);
      next.set(key, { ...setting, ...change });
      return next;
    });
  };

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (save.isPending || !dirty) return;
    setError(null);
    save.mutate(changes, {
      onError: (failure) => {
        setError(saveErrorMessage(failure, t));
      },
    });
  };

  const summaryNote =
    emailDigest === 'daily'
      ? t('notifications.prefs.digestDaily')
      : emailDigest === 'weekly'
        ? t('notifications.prefs.digestWeekly')
        : t('notifications.prefs.digestOff');
  const timings = timingOptions(emailDigest, t);

  return (
    <form noValidate onSubmit={submit} className="space-y-6">
      <Alert tone="info" title={t('notifications.prefs.alwaysOn.title')}>
        {t('notifications.prefs.alwaysOn.body')}
      </Alert>
      <ul className="space-y-1 text-sm text-fg-muted">
        <li>{t('notifications.prefs.inAppHelp')}</li>
        <li>{t('notifications.prefs.deviceHelp')}</li>
        <li>{summaryNote}</li>
        {hasGroupRows ? <li>{t('notifications.prefs.groupRows')}</li> : null}
      </ul>
      <FormAlert message={error} />
      {categoryGroups(draft).map((section) => (
        <section key={section.id} aria-labelledby={`notification-section-${section.id}`}>
          <h3
            id={`notification-section-${section.id}`}
            className="mb-3 text-base font-semibold text-fg"
          >
            {t(section.label)}
          </h3>
          <div className="space-y-3">
            {section.categories.map((category) => {
              const known = isNotificationCategory(category) ? categoryInfo[category] : null;
              const label = known ? t(known.label) : category;
              const email = draft.get(settingKey(category, 'email'));
              const showTiming = email !== undefined && email.enabled && !email.locked;
              return (
                <fieldset key={category} className="rounded-lg border border-line p-4">
                  <legend className="px-1 text-sm font-semibold text-fg">{label}</legend>
                  {known ? <p className="text-sm text-fg-muted">{t(known.description)}</p> : null}
                  {ALWAYS_ON_CATEGORIES.has(category) ? (
                    <p className="mt-1 flex items-center gap-1.5 text-sm font-medium text-fg">
                      <Icon name="lock" className="size-4 text-fg-muted" />
                      {t('notifications.prefs.alwaysOnShort')}
                    </p>
                  ) : null}
                  <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                    {CHANNELS.map((channel) => {
                      const setting = draft.get(settingKey(category, channel));
                      if (!setting) return null;
                      return (
                        <Checkbox
                          key={channel}
                          label={t(channelLabel[channel])}
                          aria-label={`${t(channelLabel[channel])}: ${label}`}
                          description={
                            setting.locked ? t('notifications.prefs.lockedChannel') : undefined
                          }
                          checked={setting.enabled}
                          disabled={setting.locked || save.isPending}
                          onChange={(event) => {
                            update(category, channel, { enabled: event.target.checked });
                          }}
                        />
                      );
                    })}
                  </div>
                  {showTiming ? (
                    <Select
                      className="mt-3 sm:w-80"
                      label={t('notifications.prefs.emailTiming')}
                      aria-label={`${t('notifications.prefs.emailTiming')}: ${label}`}
                      value={email.digest}
                      disabled={save.isPending}
                      options={timings}
                      onChange={(event) => {
                        const value = event.target.value;
                        if (isDigestTiming(value)) update(category, 'email', { digest: value });
                      }}
                    />
                  ) : null}
                </fieldset>
              );
            })}
          </div>
        </section>
      ))}
      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" loading={save.isPending} disabled={!dirty && !save.isPending}>
          {t('notifications.prefs.save')}
        </Button>
        {dirty ? (
          <>
            <Button
              variant="ghost"
              disabled={save.isPending}
              onClick={() => {
                setDraft(base);
                setError(null);
              }}
            >
              {t('notifications.prefs.discard')}
            </Button>
            <p role="status" className="text-sm text-fg-muted">
              {t('notifications.prefs.unsaved', { count: changes.length })}
            </p>
          </>
        ) : null}
      </div>
    </form>
  );
}
