import { Alert } from '@/shared/components/Alert';
import { TextLink } from '@/shared/components/TextLink';
import { billPath, paths } from '@/shared/config/paths';
import type { RecurringRule } from '@/shared/finance/types';
import { useT } from '@/shared/i18n/I18nContext';

/**
 * Bills (and shared group schedules) keep their schedule here but are
 * changed from their own pages (the API refuses edits on this screen:
 * use_bill_screen). A bill's schedule names its bill (`bill_id`).
 */
export function BillScheduleNotice({ rule }: { rule: Pick<RecurringRule, 'kind' | 'bill_id'> }) {
  const t = useT();
  let link = null;
  if (rule.kind === 'bill') {
    link = (
      <TextLink to={rule.bill_id ? billPath(rule.bill_id) : paths.bills}>
        {rule.bill_id ? t('recurring.openBill') : t('recurring.openBills')}
      </TextLink>
    );
  }
  return (
    <Alert tone="info" className="mb-6" title={t('recurring.managedTitle')}>
      <p>{t('recurring.managedBody')}</p>
      {link ? <p>{link}</p> : null}
    </Alert>
  );
}
