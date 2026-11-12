import { Card } from '@/shared/components/Card';
import { Fact, Facts } from '@/shared/components/Facts';
import { MoneyText } from '@/shared/components/MoneyText';
import { accountOptionLabel } from '@/shared/finance/options';
import { useAccounts } from '@/shared/finance/reference';
import { useGroups } from '@/shared/finance/sharing';
import type { Goal } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import { goalTypeName, priorityLabel, scheduleLabel } from '../labels';

export function GoalDetailsCard({ goal }: { goal: Goal }) {
  const { t, formatLocale } = useI18n();
  const formatMoney = useFormatMoney();
  const owner = goal.access === 'owner';
  // Only the owner's own accounts can be linked (and read).
  const accounts = useAccounts(true);
  const groups = useGroups(Boolean(goal.group_id));
  const linkedAccount =
    owner && goal.linked_account_id
      ? accounts.data?.find((account) => account.id === goal.linked_account_id)
      : undefined;
  const group = goal.group_id ? groups.data?.find((item) => item.id === goal.group_id) : undefined;
  const schedule = t(scheduleLabel[goal.contribution_schedule]);
  return (
    <Card title={t('goals.detail.details')}>
      <Facts>
        <Fact label={t('goals.form.type')}>{goalTypeName(goal.goal_type, t)}</Fact>
        <Fact label={t('goals.detail.target')}>
          <MoneyText money={goal.target} />
        </Fact>
        <Fact label={t('goals.form.startDate')}>
          {formatLocalDate(goal.start_date, formatLocale, 'long')}
        </Fact>
        <Fact label={t('goals.form.targetDate')}>
          {goal.target_date
            ? formatLocalDate(goal.target_date, formatLocale, 'long')
            : t('goals.detail.notSet')}
        </Fact>
        <Fact label={t('goals.detail.plan')}>
          {goal.contribution_schedule !== 'none' && goal.planned_contribution
            ? t('goals.detail.planValue', {
                schedule,
                amount: formatMoney(goal.planned_contribution),
              })
            : schedule}
        </Fact>
        <Fact label={t('goals.form.priority')}>{t(priorityLabel(goal.priority))}</Fact>
        {linkedAccount ? (
          <Fact label={t('goals.form.linkedAccount')}>
            <span className="block">{accountOptionLabel(linkedAccount)}</span>
            <span className="block text-sm text-fg-muted">
              {t('goals.detail.linkedAccountNote')}
            </span>
          </Fact>
        ) : null}
        {goal.group_id ? (
          <Fact label={t('goals.detail.group')}>
            <span className="block">{group?.name ?? t('goals.form.groupInactive')}</span>
            <span className="block text-sm text-fg-muted">
              {goal.visibility === 'members'
                ? t('goals.visibility.members')
                : t('goals.visibility.private')}
            </span>
          </Fact>
        ) : null}
        <Fact label={t('goals.detail.reminders')}>
          {goal.reminders_enabled ? t('goals.detail.remindersOn') : t('goals.detail.remindersOff')}
        </Fact>
        {goal.description ? (
          <Fact label={t('goals.form.descriptionField')}>
            <span className="whitespace-pre-line">{goal.description}</span>
          </Fact>
        ) : null}
        {goal.notes ? (
          <Fact label={t('goals.form.notes')}>
            <span className="whitespace-pre-line">{goal.notes}</span>
          </Fact>
        ) : null}
      </Facts>
    </Card>
  );
}
