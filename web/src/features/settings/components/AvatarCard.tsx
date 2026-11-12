import { useMutation } from '@tanstack/react-query';
import { type ChangeEvent, useId, useRef, useState } from 'react';
import { isApiError } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { Spinner } from '@/shared/components/Spinner';
import { useToast } from '@/shared/components/toast/ToastContext';
import { filePolicies, uploadFile } from '@/shared/files/upload';
import { fileProblem, fileProblemMessage, uploadErrorMessage } from '@/shared/files/uploadChecks';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import type { OwnProfile } from '@/features/social/types';
import { useAvatarPreview, useSaveProfile } from '../profileApi';

/** The first letters of up to two words of the name (shown without a photo). */
function initials(name: string): string {
  const letters = name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => Array.from(part)[0] ?? '')
    .join('');
  return letters.toUpperCase() || '?';
}

/** PATCH /me {avatar_file_id} refused: not your finished avatar upload. */
function avatarSaveError(error: unknown, t: Translate): string {
  if (isApiError(error) && error.details.some((item) => item.code === 'avatar_file_invalid')) {
    return t('profileSettings.avatar.invalid');
  }
  return describeError(error, t);
}

type Step = 'idle' | 'uploading' | 'saving';

/**
 * Profile photo: upload an image (purpose `avatar`), then point the
 * profile at it; or remove it (`""`; the file itself is kept). The image is
 * shown through a short-lived signed link.
 */
export function AvatarCard({ profile }: { profile: OwnProfile }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const inputId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const save = useSaveProfile();
  const preview = useAvatarPreview(profile.avatar_file_id);
  const [step, setStep] = useState<Step>('idle');
  const [error, setError] = useState<string | null>(null);
  const [confirmRemove, setConfirmRemove] = useState(false);
  const [removeError, setRemoveError] = useState<string | null>(null);
  const upload = useMutation({
    mutationFn: (file: File) => uploadFile(file, { purpose: 'avatar' }),
  });
  const busy = step !== 'idle';

  const onFile = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    // Let the same file be chosen again after a failure.
    event.target.value = '';
    if (!file || busy) return;
    setError(null);
    const problem = fileProblem(file, 'avatar');
    if (problem) {
      setError(
        problem === 'type'
          ? t('profileSettings.avatar.type')
          : fileProblemMessage(problem, 'avatar', t, formatLocale),
      );
      return;
    }
    setStep('uploading');
    upload.mutate(file, {
      onSuccess: (record) => {
        setStep('saving');
        save.mutate(
          { avatar_file_id: record.id },
          {
            onSuccess: () => {
              setStep('idle');
              toast.show({ tone: 'success', title: t('profileSettings.avatar.saved') });
            },
            onError: (failure) => {
              setStep('idle');
              setError(avatarSaveError(failure, t));
            },
          },
        );
      },
      onError: (failure) => {
        setStep('idle');
        setError(uploadErrorMessage(failure, t, formatLocale));
      },
    });
  };

  const remove = () => {
    if (save.isPending) return;
    setRemoveError(null);
    save.mutate(
      { avatar_file_id: '' },
      {
        onSuccess: () => {
          setConfirmRemove(false);
          toast.show({ tone: 'success', title: t('profileSettings.avatar.removed') });
        },
        onError: (failure) => {
          setRemoveError(describeError(failure, t));
        },
      },
    );
  };

  let picture;
  if (!profile.avatar_file_id) {
    picture = (
      <span
        aria-hidden="true"
        className="inline-flex size-full items-center justify-center text-2xl font-semibold text-accent"
      >
        {initials(profile.display_name)}
      </span>
    );
  } else if (preview.isPending) {
    picture = <Spinner label={t('profileSettings.avatar.loading')} />;
  } else if (preview.data?.src) {
    picture = (
      <img
        src={preview.data.src}
        alt={t('profileSettings.avatar.alt')}
        className="size-full object-cover"
      />
    );
  } else {
    picture = (
      <span className="px-2 text-center text-xs text-fg-muted">
        {t('profileSettings.avatar.unavailable')}
      </span>
    );
  }

  return (
    <Card
      title={t('profileSettings.avatar.title')}
      description={t('profileSettings.avatar.description')}
    >
      <div className="flex flex-col gap-5 sm:flex-row sm:items-center">
        <div className="flex size-24 shrink-0 items-center justify-center overflow-hidden rounded-full bg-accent-soft ring-1 ring-line">
          {picture}
        </div>
        <div className="min-w-0 flex-1 space-y-3">
          <FormAlert message={error} />
          {preview.isError ? (
            <p className="text-sm text-fg-muted">{t('profileSettings.avatar.previewFailed')}</p>
          ) : null}
          <p id={`${inputId}-help`} className="text-sm text-fg-muted">
            {t('profileSettings.avatar.help')}
          </p>
          <div className="flex flex-wrap items-center gap-3">
            {/* The visible button opens this file picker; the input itself stays out of the tab order. */}
            <input
              ref={inputRef}
              id={inputId}
              type="file"
              accept={filePolicies.avatar.accept}
              className="sr-only"
              tabIndex={-1}
              aria-label={t('profileSettings.avatar.choose')}
              aria-describedby={`${inputId}-help`}
              disabled={busy}
              onChange={onFile}
            />
            <Button
              variant="secondary"
              loading={busy}
              onClick={() => {
                inputRef.current?.click();
              }}
            >
              <Icon name="upload" className="size-4" />
              {profile.avatar_file_id
                ? t('profileSettings.avatar.change')
                : t('profileSettings.avatar.upload')}
            </Button>
            {profile.avatar_file_id ? (
              <Button
                variant="ghost"
                disabled={busy}
                onClick={() => {
                  setRemoveError(null);
                  setConfirmRemove(true);
                }}
              >
                <Icon name="trash" className="size-4" />
                {t('profileSettings.avatar.remove')}
              </Button>
            ) : null}
          </div>
          <p role="status" className="text-sm text-fg-muted">
            {step === 'uploading'
              ? t('profileSettings.avatar.uploading')
              : step === 'saving'
                ? t('profileSettings.avatar.saving')
                : ''}
          </p>
        </div>
      </div>
      <ConfirmDialog
        open={confirmRemove}
        onOpenChange={setConfirmRemove}
        title={t('profileSettings.avatar.removeTitle')}
        description={t('profileSettings.avatar.removeBody')}
        confirmLabel={t('profileSettings.avatar.removeConfirm')}
        onConfirm={remove}
        pending={save.isPending}
        error={removeError}
      />
    </Card>
  );
}
