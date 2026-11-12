import { useEffect, useRef, useState } from 'react';
import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { FileTooLargeError, filePolicies, uploadFile } from '@/shared/files/upload';
import { useAccounts } from '@/shared/finance/reference';
import type { Account } from '@/shared/finance/types';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { importsApi } from '../api';
import { importErrorMessage } from '../errors';
import type { ImportBatch } from '../types';
import { FileField } from './FileField';
import { ProcessingNotice } from './Notices';
import { WizardCard } from './WizardCard';

const STATEMENT_EXTENSIONS = ['csv', 'xlsx', 'ofx', 'qfx'];
const MAX_MB = Math.round(filePolicies.statement_import.maxBytes / (1024 * 1024));

/** Client-side checks before anything is sent (the server re-checks the content). */
function fileProblem(file: File, t: Translate): string | null {
  const extension = file.name.includes('.') ? (file.name.split('.').pop() ?? '').toLowerCase() : '';
  if (extension === 'pdf' || file.type === 'application/pdf') return t('imports.file.pdf');
  if (!STATEMENT_EXTENSIONS.includes(extension)) return t('imports.file.type');
  if (file.size === 0) return t('imports.file.empty');
  if (file.size > filePolicies.statement_import.maxBytes)
    return t('imports.file.tooLarge', { max: MAX_MB });
  return null;
}

/** Imports need an active account the user owns (shared household accounts are the owner's). */
function importableAccounts(accounts: readonly Account[] | undefined): Account[] {
  return (accounts ?? []).filter((account) => account.owned && account.status === 'active');
}

interface StartStepsProps {
  presetAccountId: string | null;
  /** Start on the file step (e.g. after a file could not be read). */
  startWithFile: boolean;
  onStepChange: (step: 'account' | 'file') => void;
  onCreated: (batch: ImportBatch) => void;
}

/** Steps 1–2: choose the account, then upload the statement and start the import. */
export function StartSteps({
  presetAccountId,
  startWithFile,
  onStepChange,
  onCreated,
}: StartStepsProps) {
  const { t } = useI18n();
  const accounts = useAccounts(false);
  const eligible = importableAccounts(accounts.data);
  const [accountId, setAccountId] = useState(presetAccountId ?? '');
  const [requested, setRequested] = useState<'account' | 'file'>(
    startWithFile ? 'file' : 'account',
  );
  const selected = eligible.find((account) => account.id === accountId);
  // The file step needs a valid account; otherwise the user chooses one first.
  const step = requested === 'file' && selected ? 'file' : 'account';
  const [accountError, setAccountError] = useState<string | null>(null);

  useEffect(() => {
    onStepChange(step);
  }, [step, onStepChange]);

  if (accounts.isPending) {
    return (
      <WizardCard title={t('imports.account.title')}>
        <LoadingState label={t('imports.account.loading')} />
      </WizardCard>
    );
  }
  if (accounts.isError) {
    return (
      <WizardCard title={t('imports.account.title')}>
        <ErrorState
          title={t('imports.account.error')}
          error={accounts.error}
          retrying={accounts.isFetching}
          onRetry={() => {
            void accounts.refetch();
          }}
        />
      </WizardCard>
    );
  }
  if (eligible.length === 0) {
    return (
      <WizardCard title={t('imports.account.title')}>
        <EmptyState
          icon="wallet"
          title={t('imports.account.none')}
          description={t('imports.account.noneBody')}
          action={
            <ButtonLink to={paths.accountNew}>
              <Icon name="plus" className="size-4" />
              {t('imports.account.add')}
            </ButtonLink>
          }
        />
      </WizardCard>
    );
  }

  if (step === 'account' || !selected) {
    return (
      <WizardCard title={t('imports.account.title')} description={t('imports.account.description')}>
        <form
          noValidate
          className="space-y-5"
          onSubmit={(event) => {
            event.preventDefault();
            if (!selected) {
              setAccountError(t('validation.chooseAccount'));
              return;
            }
            setAccountError(null);
            setRequested('file');
          }}
        >
          <Select
            label={t('imports.account.label')}
            placeholder={t('imports.account.placeholder')}
            options={eligible.map((account) => ({
              value: account.id,
              label: t('imports.account.option', {
                name: account.name,
                currency: account.currency,
              }),
            }))}
            value={selected ? accountId : ''}
            onChange={(event) => {
              setAccountId(event.target.value);
              setAccountError(null);
            }}
            help={
              selected
                ? t('imports.account.currencyHelp', { currency: selected.currency })
                : undefined
            }
            error={accountError ?? undefined}
          />
          <div className="flex justify-end">
            <Button type="submit">
              {t('common.continue')}
              <Icon name="arrow-right" className="size-4" />
            </Button>
          </div>
        </form>
      </WizardCard>
    );
  }

  return (
    <FileStep
      account={selected}
      onBack={() => {
        setRequested('account');
      }}
      onCreated={onCreated}
    />
  );
}

type Phase = 'idle' | 'uploading' | 'creating';

function FileStep({
  account,
  onBack,
  onCreated,
}: {
  account: Account;
  onBack: () => void;
  onCreated: (batch: ImportBatch) => void;
}) {
  const { t, formatLocale } = useI18n();
  const [file, setFile] = useState<File | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [phase, setPhase] = useState<Phase>('idle');
  const controller = useRef<AbortController | null>(null);
  // One key per import draft: a retry after a lost answer returns the same batch.
  const idempotency = useIdempotencyKey();

  // Leaving the page stops an upload in progress.
  useEffect(
    () => () => {
      controller.current?.abort();
    },
    [],
  );

  const createErrorMessage = (error: unknown): string => {
    if (error instanceof FileTooLargeError) return t('imports.file.tooLarge', { max: MAX_MB });
    if (hasErrorCode(error, 'VALIDATION_ERROR')) {
      const fields = error.details.map((detail) => detail.field);
      if (fields.includes('body.account_id')) return t('imports.errors.accountUnavailable');
      if (fields.includes('body.file_id')) return t('imports.errors.fileNotReady');
    }
    if (hasErrorCode(error, 'CONFLICT')) return t('imports.errors.fileNotReady');
    return importErrorMessage(error, t, formatLocale);
  };

  const start = async () => {
    if (phase !== 'idle') return;
    setNotice(null);
    setFormError(null);
    if (!file) {
      setFileError(t('imports.file.required'));
      return;
    }
    const problem = fileProblem(file, t);
    if (problem) {
      setFileError(problem);
      return;
    }
    setFileError(null);
    const abort = new AbortController();
    controller.current = abort;
    setPhase('uploading');
    try {
      const record = await uploadFile(file, { purpose: 'statement_import', signal: abort.signal });
      setPhase('creating');
      const batch = await importsApi.create(
        { account_id: account.id, file_id: record.id },
        idempotency.key,
      );
      idempotency.renew();
      onCreated(batch);
    } catch (error) {
      setPhase('idle');
      if (abort.signal.aborted) {
        setNotice(t('imports.file.cancelled'));
      } else if (isApiError(error) || error instanceof FileTooLargeError) {
        setFormError(createErrorMessage(error));
      } else {
        setFormError(t('imports.file.failed'));
      }
    } finally {
      controller.current = null;
    }
  };

  const busy = phase !== 'idle';
  return (
    <WizardCard title={t('imports.file.title')} description={t('imports.file.description')}>
      <form
        noValidate
        className="space-y-5"
        onSubmit={(event) => {
          event.preventDefault();
          void start();
        }}
      >
        <FormAlert message={formError} />
        {notice ? (
          <Alert tone="info" live="polite">
            {notice}
          </Alert>
        ) : null}
        <p className="text-sm text-fg">
          {t('imports.file.account', { name: account.name, currency: account.currency })}{' '}
          <Button variant="ghost" size="sm" onClick={onBack} disabled={busy}>
            {t('imports.file.changeAccount')}
          </Button>
        </p>
        <FileField
          label={t('imports.file.label')}
          accept={filePolicies.statement_import.accept}
          help={t('imports.file.help', { max: MAX_MB })}
          error={fileError ?? undefined}
          disabled={busy}
          onChange={(event) => {
            setFile(event.target.files?.[0] ?? null);
            setFileError(null);
            setNotice(null);
          }}
        />
        <Alert tone="info">
          <p>{t('imports.file.noPdf')}</p>
        </Alert>
        <p className="flex items-start gap-2 text-sm text-fg-muted">
          <Icon name="lock" className="mt-0.5 size-4 shrink-0" />
          <span>{t('imports.file.privacy')}</span>
        </p>
        {phase === 'uploading' ? (
          <ProcessingNotice title={t('imports.file.uploading')}>
            {t('imports.file.uploadingBody')}
          </ProcessingNotice>
        ) : null}
        {phase === 'creating' ? <ProcessingNotice title={t('imports.file.starting')} /> : null}
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-between">
          {phase === 'uploading' ? (
            <Button
              variant="secondary"
              onClick={() => {
                controller.current?.abort();
              }}
            >
              <Icon name="x" className="size-4" />
              {t('imports.file.cancelUpload')}
            </Button>
          ) : (
            <Button variant="secondary" onClick={onBack} disabled={busy}>
              <Icon name="arrow-left" className="size-4" />
              {t('common.back')}
            </Button>
          )}
          <Button type="submit" loading={busy}>
            <Icon name="upload" className="size-4" />
            {t('imports.file.submit')}
          </Button>
        </div>
      </form>
    </WizardCard>
  );
}
