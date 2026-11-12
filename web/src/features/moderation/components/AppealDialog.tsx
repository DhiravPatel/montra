import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useState } from 'react';
import { fieldCodeMessage } from '@/features/communities/fieldCodes';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { TextArea } from '@/shared/components/TextArea';
import { useToast } from '@/shared/components/toast/ToastContext';
import { FormAlert } from '@/shared/forms/FormAlert';
import { formatDateTime } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { moderationApi } from '../api';
import { appealErrorMessage } from '../errors';
import { moderationKeys } from '../keys';
import type { ModerationAction } from '../types';

const STATEMENT_MAX = 2000;

/**
 * Asks for a review of a decision that affected you, within the API's
 * 30-day window. Someone other than the moderator who acted decides.
 */
export function AppealDialog({
  action,
  deadline,
  timeZone,
  open,
  onOpenChange,
}: {
  action: ModerationAction;
  deadline: Date;
  timeZone: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [statement, setStatement] = useState('');
  const [fieldError, setFieldError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const appeal = useMutation({
    mutationFn: (text: string) => moderationApi.appeal(action.id, text),
    // The action now carries the appeal, and the appeals list has a new entry.
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: moderationKeys.mine() }),
        queryClient.invalidateQueries({ queryKey: moderationKeys.myAppeals() }),
      ]),
  });

  const close = (next: boolean) => {
    if (!next) {
      setStatement('');
      setFieldError(null);
      setFormError(null);
    }
    onOpenChange(next);
  };

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (appeal.isPending) return;
    const text = statement.trim();
    setFormError(null);
    if (!text) {
      setFieldError(t('moderation.appeal.statementRequired'));
      return;
    }
    if (text.length > STATEMENT_MAX) {
      setFieldError(t('validation.maxLength', { max: STATEMENT_MAX }));
      return;
    }
    setFieldError(null);
    appeal.mutate(text, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title: t('moderation.appeal.sent'),
          description: t('moderation.appeal.sentBody'),
        });
        close(false);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'CONFLICT')) {
          // A review is already open for this decision (the reload shows it).
          toast.show({ tone: 'info', title: appealErrorMessage(error, t) });
          close(false);
          return;
        }
        if (hasErrorCode(error, 'VALIDATION_ERROR')) {
          const detail = error.details.find((item) => item.field === 'body.statement');
          if (detail) {
            setFieldError(fieldCodeMessage(detail, t));
            return;
          }
        }
        setFormError(appealErrorMessage(error, t));
      },
    });
  };

  return (
    <Dialog
      open={open}
      onOpenChange={close}
      title={t('moderation.appeal.title')}
      description={t('moderation.appeal.description', {
        date: formatDateTime(deadline, formatLocale, timeZone),
      })}
      busy={appeal.isPending}
    >
      <form onSubmit={submit} noValidate className="space-y-5">
        <FormAlert message={formError} />
        <TextArea
          label={t('moderation.appeal.statement')}
          help={t('moderation.appeal.statementHelp')}
          rows={5}
          maxLength={STATEMENT_MAX}
          value={statement}
          error={fieldError ?? undefined}
          onChange={(event) => {
            setStatement(event.target.value);
          }}
        />
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button
            variant="secondary"
            disabled={appeal.isPending}
            onClick={() => {
              close(false);
            }}
          >
            {t('common.cancel')}
          </Button>
          <Button type="submit" loading={appeal.isPending}>
            {t('moderation.appeal.submit')}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
