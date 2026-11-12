import { type ReactNode, useState } from 'react';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { useT } from '@/shared/i18n/I18nContext';
import { AccountSelect } from './AccountSelect';

interface AccountActionDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description: ReactNode;
  /** Group currency: only the person's own accounts in it are offered. */
  currency: string;
  accountLabel: string;
  accountHelp?: string;
  /** `required`: the action records into an account; `optional`: it may also record one. */
  account: 'required' | 'optional' | 'none';
  confirmLabel: string;
  pending: boolean;
  error: string | null;
  onConfirm: (accountId: string | null) => void;
}

/** Confirms a settlement step that can also record it in one of your own accounts. */
export function AccountActionDialog(props: AccountActionDialogProps) {
  return (
    <Dialog
      open={props.open}
      onOpenChange={props.onOpenChange}
      title={props.title}
      description={props.description}
      busy={props.pending}
    >
      {props.open ? <AccountActionBody {...props} /> : null}
    </Dialog>
  );
}

function AccountActionBody({
  onOpenChange,
  currency,
  accountLabel,
  accountHelp,
  account,
  confirmLabel,
  pending,
  error,
  onConfirm,
}: AccountActionDialogProps) {
  const t = useT();
  const [accountId, setAccountId] = useState('');
  const [missing, setMissing] = useState(false);
  return (
    <form
      noValidate
      className="space-y-4"
      onSubmit={(event) => {
        event.preventDefault();
        if (pending) return;
        if (account === 'required' && !accountId) {
          setMissing(true);
          return;
        }
        onConfirm(accountId || null);
      }}
    >
      {error ? (
        <Alert tone="danger" live="assertive">
          {error}
        </Alert>
      ) : null}
      {account === 'none' ? null : (
        <AccountSelect
          currency={currency}
          label={accountLabel}
          help={accountHelp}
          optional={account === 'optional'}
          placeholder={
            account === 'optional'
              ? t('groupMoney.form.account.dontRecord')
              : t('groupMoney.record.choose')
          }
          value={accountId}
          error={missing ? t('validation.chooseAccount') : undefined}
          onChange={(value) => {
            setAccountId(value);
            setMissing(false);
          }}
        />
      )}
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button
          variant="secondary"
          disabled={pending}
          onClick={() => {
            onOpenChange(false);
          }}
        >
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={pending}>
          {confirmLabel}
        </Button>
      </div>
    </form>
  );
}
