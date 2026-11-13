import { Button } from '@/shared/components/Button';
import { buttonClasses } from '@/shared/components/buttonStyles';
import { Icon } from '@/shared/components/Icon';
import { Menu, MenuContent, MenuItem, MenuTrigger } from '@/shared/components/Menu';
import type { BudgetAlert } from '@/shared/finance/types';
import { useT } from '@/shared/i18n/I18nContext';
import type { BudgetAlertActions } from '../alertActions';

interface BudgetAlertButtonsProps {
  alert: BudgetAlert;
  /** The alert in words: each button's name repeats it, so a list of alerts stays unambiguous. */
  message: string;
  actions: BudgetAlertActions;
}

/** Snooze (a day or a week) or reactivate, and dismiss, for one budget alert. */
export function BudgetAlertButtons({ alert, message, actions }: BudgetAlertButtonsProps) {
  const t = useT();
  const busy = actions.busy(alert);
  return (
    <div className="flex shrink-0 flex-wrap gap-2">
      {alert.status === 'active' ? (
        <Menu>
          <MenuTrigger
            className={buttonClasses('secondary', 'sm')}
            aria-label={`${t('budgets.alerts.snooze')}: ${message}`}
            disabled={busy}
          >
            <Icon name="bell-off" className="size-4" />
            {t('budgets.alerts.snooze')}
          </MenuTrigger>
          <MenuContent label={t('budgets.alerts.snooze')}>
            <MenuItem
              icon="clock"
              onSelect={() => {
                actions.snooze(alert, 1);
              }}
            >
              {t('budgets.alerts.snoozeDay')}
            </MenuItem>
            <MenuItem
              icon="calendar"
              onSelect={() => {
                actions.snooze(alert, 7);
              }}
            >
              {t('budgets.alerts.snoozeWeek')}
            </MenuItem>
          </MenuContent>
        </Menu>
      ) : (
        <Button
          variant="secondary"
          size="sm"
          loading={busy}
          aria-label={`${t('budgets.alerts.reactivate')}: ${message}`}
          onClick={() => {
            actions.reactivate(alert);
          }}
        >
          <Icon name="bell" className="size-4" />
          {t('budgets.alerts.reactivate')}
        </Button>
      )}
      {alert.status !== 'dismissed' ? (
        <Button
          variant="ghost"
          size="sm"
          loading={busy}
          aria-label={`${t('budgets.alerts.dismiss')}: ${message}`}
          onClick={() => {
            actions.dismiss(alert);
          }}
        >
          <Icon name="x" className="size-4" />
          {t('budgets.alerts.dismiss')}
        </Button>
      ) : null}
    </div>
  );
}
