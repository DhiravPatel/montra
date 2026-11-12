import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths } from '@/shared/config/paths';
import { detailParam } from '@/shared/finance/domainErrors';
import { formatDate, formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import { privacyApi } from '../api';
import { isNothingScheduled } from '../errors';
import { useDeletion } from '../hooks';
import { privacyKeys } from '../keys';
import type { Deletion } from '../types';
import { DeletionDialog } from './DeletionDialog';

const consequenceKeys: Readonly<Partial<Record<string, MessageKey>>> = {
  signed_out_and_integrations_revoked:
    'privacySettings.deletion.code.signed_out_and_integrations_revoked',
  personal_records_deleted: 'privacySettings.deletion.code.personal_records_deleted',
  documents_removed: 'privacySettings.deletion.code.documents_removed',
  profile_removed_posts_anonymized:
    'privacySettings.deletion.code.profile_removed_posts_anonymized',
  irreversible_after_date: 'privacySettings.deletion.code.irreversible_after_date',
};

const retainedKeys: Readonly<Partial<Record<string, MessageKey>>> = {
  shared_group_records_anonymized: 'privacySettings.deletion.code.shared_group_records_anonymized',
  security_audit_records_retained: 'privacySettings.deletion.code.security_audit_records_retained',
};

interface DisclosureItem {
  /** Localized text, or the API's English sentence for a code this app doesn't know. */
  text: string;
  english: boolean;
}

/**
 * The API's disclosure, localized by code (`consequence_codes` and
 * `retained_codes` follow the English lists' order). Sentences without a
 * known code are shown as sent and marked as English for screen readers.
 */
function codedItems(
  english: readonly string[],
  codes: readonly string[],
  keys: Readonly<Partial<Record<string, MessageKey>>>,
  t: Translate,
): DisclosureItem[] {
  return english.map((text, index) => {
    const code = codes[index];
    const key = code ? keys[code] : undefined;
    return key ? { text: t(key), english: false } : { text, english: true };
  });
}

/** Groups you own: who takes them over, or that they are deleted (the name is user text). */
function groupItems(deletion: Deletion, t: Translate): DisclosureItem[] {
  return deletion.group_impact_details.map((impact) => {
    const name = detailParam(impact.params, 'group_name');
    if (name && impact.code === 'ownership_transfer') {
      return {
        text: t('privacySettings.deletion.code.ownership_transfer', { name }),
        english: false,
      };
    }
    if (name && impact.code === 'group_deleted') {
      return { text: t('privacySettings.deletion.code.group_deleted', { name }), english: false };
    }
    return { text: impact.text, english: true };
  });
}

function DisclosureList({ title, items }: { title: string; items: readonly DisclosureItem[] }) {
  if (items.length === 0) return null;
  return (
    <div className="space-y-2">
      <h3 className="font-semibold text-fg">{title}</h3>
      <ul className="list-disc space-y-1 ps-5 text-sm text-fg">
        {items.map((item, index) => (
          // The same sentence can't repeat in one list; the index keeps keys unique anyway.
          <li key={`${String(index)}-${item.text}`} lang={item.english ? 'en' : undefined}>
            {item.text}
          </li>
        ))}
      </ul>
    </div>
  );
}

function DisclosureLists({ deletion }: { deletion: Deletion }) {
  const { t } = useI18n();
  const consequences = codedItems(
    deletion.consequences,
    deletion.consequence_codes,
    consequenceKeys,
    t,
  );
  // Older answers may lack details: fall back to the English group sentences.
  const groups =
    deletion.group_impact_details.length > 0
      ? groupItems(deletion, t)
      : deletion.group_impact.map((text) => ({ text, english: true }));
  const retained = codedItems(deletion.retained, deletion.retained_codes, retainedKeys, t);
  const someEnglish = [...consequences, ...groups, ...retained].some((item) => item.english);
  return (
    <div className="space-y-5">
      <DisclosureList title={t('privacySettings.deletion.consequences')} items={consequences} />
      <DisclosureList title={t('privacySettings.deletion.groupImpact')} items={groups} />
      <DisclosureList title={t('privacySettings.deletion.retained')} items={retained} />
      {someEnglish ? (
        <p className="text-xs text-fg-muted">{t('privacySettings.deletion.englishOnly')}</p>
      ) : null}
    </div>
  );
}

interface DeletionCardProps {
  /** The grace period from GET /limits, when known. */
  graceDays: number | null;
}

/**
 * Account deletion: the consequences, retained records and group impact come
 * from the API; scheduling needs a typed confirmation and re-authentication;
 * a scheduled deletion can be cancelled until its date.
 */
export function DeletionCard({ graceDays }: DeletionCardProps) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const deletion = useDeletion();
  const [open, setOpen] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);

  const cancel = useMutation({
    mutationFn: privacyApi.cancelDeletion,
    onSuccess: (updated) => {
      queryClient.setQueryData(privacyKeys.deletion(), updated);
    },
  });

  const cancelDeletion = () => {
    if (cancel.isPending) return;
    setCancelError(null);
    cancel.mutate(undefined, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title: t('privacySettings.deletion.cancelled'),
          description: t('privacySettings.deletion.cancelledBody'),
        });
      },
      onError: (error) => {
        if (isNothingScheduled(error)) {
          // Nothing scheduled any more: show the current state.
          void deletion.refetch();
          setCancelError(t('privacySettings.deletion.nothingToCancel'));
          return;
        }
        setCancelError(describeError(error, t));
      },
    });
  };

  const onScheduled = (scheduled: Deletion) => {
    setOpen(false);
    const when = parseTimestamp(scheduled.scheduled_for);
    toast.show({
      tone: 'success',
      title: t('privacySettings.deletion.scheduledToast'),
      ...(when
        ? {
            description: t('privacySettings.deletion.scheduledFor', {
              date: formatDate(when, formatLocale, user.timezone),
            }),
          }
        : {}),
    });
  };

  let content;
  if (deletion.isPending) {
    content = <LoadingState label={t('privacySettings.deletion.loading')} />;
  } else if (deletion.isError) {
    content = hasErrorCode(deletion.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="h3" />
    ) : (
      <ErrorState
        titleAs="h3"
        title={t('privacySettings.deletion.error')}
        error={deletion.error}
        retrying={deletion.isFetching}
        onRetry={() => {
          void deletion.refetch();
        }}
      />
    );
  } else {
    const current = deletion.data;
    const scheduledFor = parseTimestamp(current.scheduled_for);
    if (current.status === 'scheduled') {
      content = (
        <div className="space-y-5">
          <Alert tone="warning" live="polite" title={t('privacySettings.deletion.scheduledTitle')}>
            <p>
              {scheduledFor
                ? t('privacySettings.deletion.scheduledBody', {
                    date: formatDateTime(scheduledFor, formatLocale, user.timezone),
                  })
                : t('privacySettings.deletion.scheduledBodyNoDate')}
            </p>
            <p>{t('privacySettings.deletion.exportFirst')}</p>
          </Alert>
          {cancelError ? (
            <Alert tone="danger" live="assertive">
              {cancelError}
            </Alert>
          ) : null}
          <Button loading={cancel.isPending} onClick={cancelDeletion}>
            <Icon name="undo" className="size-4" />
            {t('privacySettings.deletion.cancel')}
          </Button>
          <DisclosureLists deletion={current} />
        </div>
      );
    } else if (current.status === 'processing' || current.status === 'completed') {
      content = (
        <Alert tone="info" live="polite" title={t('privacySettings.deletion.processingTitle')}>
          <p>{t('privacySettings.deletion.processingBody')}</p>
        </Alert>
      );
    } else {
      content = (
        <div className="space-y-5">
          {current.status === 'failed' ? (
            <Alert tone="danger" title={t('privacySettings.deletion.failedTitle')}>
              <p>
                {t('privacySettings.deletion.failedBody')}{' '}
                <TextLink to={paths.help}>{t('privacySettings.deletion.contactSupport')}</TextLink>
              </p>
            </Alert>
          ) : null}
          <p className="text-sm text-fg">
            {graceDays !== null
              ? t('privacySettings.deletion.grace', { count: graceDays })
              : t('privacySettings.deletion.graceUnknown')}
          </p>
          <DisclosureLists deletion={current} />
          {cancelError ? (
            <Alert tone="info" live="polite">
              {cancelError}
            </Alert>
          ) : null}
          <Button
            variant="danger"
            onClick={() => {
              setCancelError(null);
              setOpen(true);
            }}
          >
            <Icon name="trash" className="size-4" />
            {t('privacySettings.deletion.start')}
          </Button>
        </div>
      );
    }
  }

  return (
    <Card
      title={t('privacySettings.deletion.title')}
      description={t('privacySettings.deletion.description')}
    >
      {content}
      <DeletionDialog
        open={open}
        onOpenChange={setOpen}
        graceDays={graceDays}
        onScheduled={onScheduled}
      />
    </Card>
  );
}
