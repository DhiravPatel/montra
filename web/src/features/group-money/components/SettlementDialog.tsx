import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation } from '@tanstack/react-query';
import { useMemo, useRef, useState } from 'react';
import { Controller, type FieldPath, useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { MoneyField } from '@/shared/components/MoneyField';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { exponentFor, useCurrencies } from '@/shared/currency/api';
import { uploadFile } from '@/shared/files/upload';
import { checkAmount } from '@/shared/forms/decimalField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { decimalToInput, normalizeDecimalInput } from '@/shared/formatting/decimal';
import { isLocalDate, todayInTimeZone } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { uploadErrorMessage } from '@/features/receipts/uploads';
import { groupMoneyApi } from '../api';
import { groupMoneyErrorMessage } from '../errors';
import { SETTLEMENT_METHODS, isSettlementMethod, settlementMethodLabel } from '../labels';
import type { People } from '../people';
import type { GroupDetail, Settlement, SettlementInput, SettlementMethod } from '../types';
import { AccountSelect } from './AccountSelect';
import { AttachmentField } from './AttachmentField';

export interface SettlementPrefill {
  payerUserId: string;
  payeeUserId: string;
  /** Exact decimal from the API (a suggestion or the settlement being corrected). */
  amount?: string;
  method?: SettlementMethod;
  note?: string;
  settledOn?: string;
  state?: 'paid' | 'proposed';
}

interface SettlementDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  group: GroupDetail;
  people: People;
  /** `correct` replaces the settlement `correcting` (the original is voided and kept). */
  mode: 'create' | 'correct';
  correcting?: Settlement;
  prefill?: SettlementPrefill | null;
  onSaved: (settlement: Settlement) => void;
}

/**
 * Records a payment made outside Montra (or plans one). Montra never moves
 * money: this only keeps the group's records right. Creating and correcting
 * send an Idempotency-Key, kept while the same draft is retried.
 */
export function SettlementDialog(props: SettlementDialogProps) {
  const { t } = useI18n();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={props.open}
      onOpenChange={props.onOpenChange}
      title={
        props.mode === 'correct'
          ? t('groupMoney.settle.correctTitle')
          : t('groupMoney.settle.title')
      }
      description={t('groupMoney.settle.noMoneyMoves')}
      busy={pending}
      size="lg"
    >
      {props.open ? <SettlementFormGate {...props} onPendingChange={setPending} /> : null}
    </Dialog>
  );
}

interface Values {
  payer: string;
  payee: string;
  amount: string;
  method: string;
  state: 'paid' | 'proposed';
  settledOn: string;
  note: string;
  accountId: string;
}

function SettlementFormGate(
  props: SettlementDialogProps & { onPendingChange: (p: boolean) => void },
) {
  const currencies = useCurrencies();
  if (currencies.isPending) return null;
  const exponent = exponentFor(currencies.data, props.group.base_currency);
  return <SettlementForm {...props} exponent={exponent} />;
}

function SettlementForm({
  onOpenChange,
  group,
  people,
  mode,
  correcting,
  prefill,
  onSaved,
  onPendingChange,
  exponent,
}: SettlementDialogProps & { onPendingChange: (p: boolean) => void; exponent: number }) {
  const { t, formatLocale } = useI18n();
  const currency = group.base_currency;
  const idempotency = useIdempotencyKey();
  const [formError, setFormError] = useState<string | null>(null);
  const [file, setFile] = useState<File | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const uploaded = useRef<{ file: File; id: string } | null>(null);
  const schema = useMemo(
    () =>
      z.custom<Values>().superRefine((values, ctx) => {
        const issue = (path: keyof Values, message: string) => {
          ctx.addIssue({ code: 'custom', path: [path], message });
        };
        if (!values.payer) issue('payer', t('groupMoney.settle.payerRequired'));
        if (!values.payee) issue('payee', t('groupMoney.settle.payeeRequired'));
        if (values.payer && values.payer === values.payee) {
          issue('payee', t('groupMoney.settle.samePerson'));
        }
        checkAmount(ctx, {
          value: values.amount,
          path: 'amount',
          locale: formatLocale,
          currency,
          exponent,
          t,
        });
        if (!isSettlementMethod(values.method))
          issue('method', t('groupMoney.settle.methodRequired'));
        if (!values.settledOn) issue('settledOn', t('validation.dateRequired'));
        else if (!isLocalDate(values.settledOn)) issue('settledOn', t('validation.dateInvalid'));
        if (values.note.length > 500) issue('note', t('validation.maxLength', { max: 500 }));
      }),
    [t, formatLocale, currency, exponent],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      payer: prefill?.payerUserId ?? people.meId,
      payee: prefill?.payeeUserId ?? '',
      amount: prefill?.amount ? decimalToInput(prefill.amount, formatLocale) : '',
      method: prefill?.method ?? 'upi',
      state: prefill?.state ?? 'paid',
      settledOn: prefill?.settledOn ?? todayInTimeZone(group.timezone),
      note: prefill?.note ?? '',
      accountId: '',
    },
  });
  const { register, control, formState } = form;
  const errors = formState.errors;
  const [payer, payee, state] = useWatch({ control, name: ['payer', 'payee', 'state'] });
  const iAmParty = payer === people.meId || payee === people.meId;
  const canRecord = iAmParty && state === 'paid';

  const save = useMutation({
    mutationFn: (body: SettlementInput) =>
      mode === 'correct' && correcting
        ? groupMoneyApi.correctSettlement(group.id, correcting.id, body, idempotency.key)
        : groupMoneyApi.createSettlement(group.id, body, idempotency.key),
  });

  const memberOptions = people.everyone.map((member) => ({
    value: member.user_id,
    label: people.optionLabel(member),
  }));

  const submit = form.handleSubmit(
    async (values) => {
      if (busy) return;
      setFormError(null);
      setBusy(true);
      onPendingChange(true);
      try {
        let receiptFileId: string | undefined;
        if (file) {
          if (uploaded.current?.file === file) receiptFileId = uploaded.current.id;
          else {
            try {
              const record = await uploadFile(file, {
                purpose: 'group_attachment',
                groupId: group.id,
              });
              uploaded.current = { file, id: record.id };
              receiptFileId = record.id;
            } catch (error) {
              setFileError(uploadErrorMessage(error, t, formatLocale));
              return;
            }
          }
        }
        const amount = normalizeDecimalInput(values.amount, formatLocale, { exponent });
        const body: SettlementInput = {
          payer_user_id: values.payer,
          payee_user_id: values.payee,
          amount: amount.ok ? amount.value : values.amount.trim(),
          method: isSettlementMethod(values.method) ? values.method : 'other',
          state: values.state,
          settled_on: values.settledOn,
        };
        if (values.note.trim()) body.note = values.note.trim();
        if (receiptFileId) body.receipt_file_id = receiptFileId;
        if (canRecord && values.accountId) body.account_id = values.accountId;
        try {
          const saved = await save.mutateAsync(body);
          idempotency.renew();
          onSaved(saved);
        } catch (error) {
          if (hasErrorCode(error, 'VALIDATION_ERROR')) {
            const fields: Readonly<Record<string, FieldPath<Values>>> = {
              'body.payer_user_id': 'payer',
              'body.payee_user_id': 'payee',
              'body.amount': 'amount',
              'body.method': 'method',
              'body.settled_on': 'settledOn',
              'body.note': 'note',
              'body.account_id': 'accountId',
            };
            const rest: string[] = [];
            for (const detail of error.details) {
              const field = detail.field ? fields[detail.field] : undefined;
              if (detail.field === 'body.receipt_file_id') setFileError(detail.message);
              else if (field) form.setError(field, { type: 'server', message: detail.message });
              else rest.push(detail.message);
            }
            setFormError(rest.length > 0 ? rest.join(' ') : t('groupMoney.form.fixErrors'));
          } else {
            setFormError(
              groupMoneyErrorMessage(error, t, formatLocale, {
                conflict: t('groupMoney.settle.correctConflict'),
                notFound: t('groupMoney.settlement.notFoundBody'),
              }),
            );
          }
        }
      } finally {
        setBusy(false);
        onPendingChange(false);
      }
    },
    () => {
      setFormError(t('groupMoney.form.fixErrors'));
    },
  );

  return (
    <form onSubmit={submit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      {mode === 'correct' ? <Alert tone="info">{t('groupMoney.settle.correctBody')}</Alert> : null}
      <div className="grid gap-5 sm:grid-cols-2">
        <Select
          label={t('groupMoney.settle.payer')}
          placeholder={t('groupMoney.settle.choosePerson')}
          options={memberOptions}
          error={errors.payer?.message}
          {...register('payer')}
        />
        <Select
          label={t('groupMoney.settle.payee')}
          placeholder={t('groupMoney.settle.choosePerson')}
          options={memberOptions}
          error={errors.payee?.message}
          {...register('payee')}
        />
      </div>
      <div className="grid gap-5 sm:grid-cols-2">
        <MoneyField
          label={t('groupMoney.settle.amount')}
          currency={currency}
          help={t('groupMoney.settle.amountHelp')}
          error={errors.amount?.message}
          {...register('amount')}
        />
        <Select
          label={t('groupMoney.settle.method')}
          options={SETTLEMENT_METHODS.map((value) => ({
            value,
            label: t(settlementMethodLabel[value]),
          }))}
          error={errors.method?.message}
          {...register('method')}
        />
      </div>
      <Controller
        control={control}
        name="state"
        render={({ field }) => (
          <RadioGroup<'paid' | 'proposed'>
            legend={t('groupMoney.settle.state')}
            value={field.value}
            onChange={field.onChange}
            variant="cards"
            options={[
              {
                value: 'paid',
                label: t('groupMoney.settle.statePaid'),
                description: t('groupMoney.settle.statePaidHelp'),
              },
              {
                value: 'proposed',
                label: t('groupMoney.settle.stateProposed'),
                description: t('groupMoney.settle.stateProposedHelp'),
              },
            ]}
          />
        )}
      />
      <TextField
        label={t('groupMoney.settle.date')}
        type="date"
        error={errors.settledOn?.message}
        {...register('settledOn')}
      />
      <TextArea
        label={t('groupMoney.settle.note')}
        optional
        maxLength={500}
        rows={2}
        error={errors.note?.message}
        {...register('note')}
      />
      {canRecord ? (
        <Controller
          control={control}
          name="accountId"
          render={({ field }) => (
            <AccountSelect
              currency={currency}
              label={t('groupMoney.settle.account')}
              optional
              placeholder={t('groupMoney.form.account.dontRecord')}
              help={t('groupMoney.settle.accountHelp')}
              value={field.value}
              error={errors.accountId?.message}
              onChange={field.onChange}
            />
          )}
        />
      ) : null}
      <AttachmentField
        label={t('groupMoney.settle.proof')}
        file={file}
        error={fileError}
        onChange={(picked, problem) => {
          setFile(picked);
          setFileError(problem);
        }}
      />
      <p className="text-sm text-fg-muted">
        {payee === people.meId && state === 'paid'
          ? t('groupMoney.settle.countsNow')
          : t('groupMoney.settle.countsLater')}
      </p>
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button
          variant="secondary"
          disabled={busy}
          onClick={() => {
            onOpenChange(false);
          }}
        >
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={busy}>
          {mode === 'correct'
            ? t('groupMoney.settle.correctSubmit')
            : t('groupMoney.settle.submit')}
        </Button>
      </div>
    </form>
  );
}
