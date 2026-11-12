import { useMutation } from '@tanstack/react-query';
import { type SubmitEvent, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { TextArea } from '@/shared/components/TextArea';
import { useToast } from '@/shared/components/toast/ToastContext';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useT } from '@/shared/i18n/I18nContext';
import { communitiesApi } from '../api';
import { fieldProblems, useCommunityError } from '../errors';
import { REPORT_REASONS, reportReasonLabel } from '../labels';
import { looksSecret } from '../text/userText';
import type { ContentTarget, ReportReason } from '../types';

const DETAILS_MAX = 1000;

/**
 * Reports a post (POST /posts/{id}/reports) or a comment (POST
 * /content-reports) to the community's moderators. The reported person is
 * not told who reported them.
 */
export function ReportDialog({
  target,
  open,
  onOpenChange,
}: {
  target: { type: ContentTarget; id: string } | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const t = useT();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={
        target?.type === 'comment'
          ? t('communities.report.titleComment')
          : t('communities.report.titlePost')
      }
      description={t('communities.report.description')}
      busy={pending}
    >
      {open && target ? (
        <ReportForm
          target={target}
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function ReportForm({
  target,
  onPendingChange,
  onDone,
}: {
  target: { type: ContentTarget; id: string };
  onPendingChange: (pending: boolean) => void;
  onDone: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const describe = useCommunityError();
  const [reason, setReason] = useState<ReportReason | ''>('');
  const [reasonError, setReasonError] = useState<string | null>(null);
  const [details, setDetails] = useState('');
  const [detailsError, setDetailsError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const report = useMutation({
    mutationFn: (chosen: ReportReason) =>
      communitiesApi.report(target.type, target.id, chosen, details.trim()),
  });

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (report.isPending) return;
    setFormError(null);
    const text = details.trim();
    const badReason = reason === '' ? t('communities.report.reasonRequired') : null;
    let badDetails: string | null = null;
    if (Array.from(text).length > DETAILS_MAX) {
      badDetails = t('validation.maxLength', { max: DETAILS_MAX });
    } else if (looksSecret(text)) {
      badDetails = t('communities.field.secret');
    }
    setReasonError(badReason);
    setDetailsError(badDetails);
    if (reason === '' || badDetails) return;
    onPendingChange(true);
    report.mutate(reason, {
      onSuccess: () => {
        onPendingChange(false);
        toast.show({
          tone: 'success',
          title: t('communities.report.sent'),
          description: t('communities.report.sentBody'),
        });
        onDone();
      },
      onError: (error) => {
        onPendingChange(false);
        if (hasErrorCode(error, 'CONFLICT')) {
          toast.show({ tone: 'info', title: t('communities.report.already') });
          onDone();
          return;
        }
        const problems = fieldProblems(error, t);
        const forDetails = problems.find((problem) => problem.field === 'details');
        if (forDetails) {
          setDetailsError(forDetails.message);
          return;
        }
        setFormError(
          describe(error, {
            rules: { own_content: 'communities.report.ownContent' },
            codes: { NOT_FOUND: 'communities.report.gone' },
          }),
        );
      },
    });
  };

  return (
    <form noValidate onSubmit={submit} className="space-y-5">
      <FormAlert message={formError} />
      <RadioGroup<ReportReason | ''>
        legend={t('communities.report.reason')}
        variant="cards"
        value={reason}
        onChange={(value) => {
          setReason(value);
          setReasonError(null);
        }}
        options={REPORT_REASONS.map((value) => ({ value, label: t(reportReasonLabel[value]) }))}
        error={reasonError ?? undefined}
      />
      <TextArea
        label={t('communities.report.details')}
        help={t('communities.report.detailsHelp')}
        optional
        rows={3}
        maxLength={DETAILS_MAX}
        value={details}
        error={detailsError ?? undefined}
        onChange={(event) => {
          setDetails(event.target.value);
          setDetailsError(null);
        }}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={report.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={report.isPending}>
          {t('communities.report.submit')}
        </Button>
      </div>
    </form>
  );
}
