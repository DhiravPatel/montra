import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { absDecimal } from '@/shared/formatting/decimal';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useGroupBalances, useSettlementSuggestions, useSettlements } from '../api';
import { GroupMoneyPage } from '../components/GroupMoneyPage';
import { type SettlementPrefill, SettlementDialog } from '../components/SettlementDialog';
import { SettlementRow, TransferList } from '../components/Transfers';
import { groupMoneyKeys, refreshAfterGroupWrite } from '../keys';
import { type People, byCurrency, isReadOnlyGroup, usePeople } from '../people';
import type { GroupBalances, GroupDetail, MemberBalance, Money } from '../types';

type DebtView = 'simplified' | 'original';

export function GroupBalancesPage() {
  const { t } = useI18n();
  const { groupId = '' } = useParams();
  useDocumentTitle(t('groupMoney.balances.title'));
  return (
    <GroupMoneyPage groupId={groupId} title={t('groupMoney.balances.title')}>
      {(group) => <Balances group={group} />}
    </GroupMoneyPage>
  );
}

function sign(money: Pick<Money, 'amount_minor'>): -1 | 0 | 1 {
  return money.amount_minor > 0 ? 1 : money.amount_minor < 0 ? -1 : 0;
}

/** A positive amount for sentences like "You owe ₹500.00" (no arithmetic: the sign is dropped). */
function magnitude(money: Money): Money {
  return { ...money, amount: absDecimal(money.amount) };
}

function Balances({ group }: { group: GroupDetail }) {
  const { t } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const people = usePeople(group);
  const readOnly = isReadOnlyGroup(group);
  const balances = useGroupBalances(group.id);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [prefill, setPrefill] = useState<SettlementPrefill | null>(null);

  const record = (next: SettlementPrefill | null) => {
    setPrefill(next);
    setDialogOpen(true);
  };

  let main;
  if (balances.isPending) {
    main = <LoadingState label={t('groupMoney.balances.loading')} />;
  } else if (balances.isError) {
    main = hasErrorCode(balances.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('groupMoney.balances.error')}
        error={balances.error}
        retrying={balances.isFetching}
        onRetry={() => {
          void balances.refetch();
        }}
      />
    );
  } else {
    main = (
      <>
        <MyBalanceCard
          balances={balances.data}
          people={people}
          readOnly={readOnly}
          onRecord={() => {
            record(null);
          }}
        />
        <DebtsCard balances={balances.data} people={people} />
        <MembersCard balances={balances.data} people={people} />
      </>
    );
  }

  return (
    <div className="space-y-6">
      <Alert tone="info" title={t('groupMoney.balances.noMoneyTitle')}>
        {t('groupMoney.balances.noMoneyBody')}
      </Alert>
      {main}
      <SuggestionsCard
        group={group}
        people={people}
        readOnly={readOnly}
        onRecord={(transfer) => {
          record(transfer);
        }}
      />
      <SettlementsCard
        group={group}
        people={people}
        readOnly={readOnly}
        onRecord={() => {
          record(null);
        }}
      />
      <SettlementDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        group={group}
        people={people}
        mode="create"
        prefill={prefill}
        onSaved={(settlement) => {
          setDialogOpen(false);
          queryClient.setQueryData(groupMoneyKeys.settlement(group.id, settlement.id), settlement);
          void refreshAfterGroupWrite(queryClient);
          toast.show({
            tone: 'success',
            title:
              settlement.status === 'confirmed'
                ? t('groupMoney.settle.doneConfirmed')
                : settlement.status === 'proposed'
                  ? t('groupMoney.settle.doneProposed')
                  : t('groupMoney.settle.done'),
          });
        }}
      />
    </div>
  );
}

function MyBalanceCard({
  balances,
  people,
  readOnly,
  onRecord,
}: {
  balances: GroupBalances;
  people: People;
  readOnly: boolean;
  onRecord: () => void;
}) {
  const { t } = useI18n();
  const format = useFormatMoney();
  const mine = balances.balances.find((entry) => people.isMe(entry.user_id));
  const net = balances.my_net;
  const direction = sign(net);
  return (
    <Card
      title={t('groupMoney.balances.yours')}
      actions={
        readOnly ? null : (
          <Button size="sm" onClick={onRecord}>
            <Icon name="handshake" className="size-4" />
            {t('groupMoney.balances.record')}
          </Button>
        )
      }
    >
      <p className="text-lg font-semibold text-fg">
        {direction === 0
          ? t('groupMoney.balances.settled')
          : direction > 0
            ? t('groupMoney.balances.youAreOwed', { amount: format(magnitude(net)) })
            : t('groupMoney.balances.youOwe', { amount: format(magnitude(net)) })}
      </p>
      {mine && sign(mine.pending_out) > 0 ? (
        <p className="mt-2 text-sm text-fg-muted">
          {t('groupMoney.balances.pendingOut', { amount: format(mine.pending_out) })}
        </p>
      ) : null}
      {mine && sign(mine.pending_in) > 0 ? (
        <p className="mt-2 text-sm text-fg-muted">
          {t('groupMoney.balances.pendingIn', { amount: format(mine.pending_in) })}
        </p>
      ) : null}
      {balances.disputed_expenses > 0 ? (
        <p className="mt-2 text-sm text-fg-muted">
          {t('groupMoney.balances.disputed', { count: balances.disputed_expenses })}
        </p>
      ) : null}
    </Card>
  );
}

function DebtsCard({ balances, people }: { balances: GroupBalances; people: People }) {
  const { t } = useI18n();
  const [view, setView] = useState<DebtView>(balances.simplify_enabled ? 'simplified' : 'original');
  const transfers = view === 'simplified' ? balances.simplified : balances.original_debts;
  return (
    <Card title={t('groupMoney.balances.debts')} description={t('groupMoney.balances.debtsBody')}>
      <div className="space-y-5">
        <RadioGroup<DebtView>
          legend={t('groupMoney.balances.view')}
          value={view}
          onChange={setView}
          variant="cards"
          options={[
            {
              value: 'simplified',
              label: t('groupMoney.balances.simplified'),
              description: t('groupMoney.balances.simplifiedHelp'),
            },
            {
              value: 'original',
              label: t('groupMoney.balances.original'),
              description: t('groupMoney.balances.originalHelp'),
            },
          ]}
        />
        {transfers.length === 0 ? (
          <EmptyState
            icon="check-circle"
            title={t('groupMoney.balances.allSettled')}
            description={t('groupMoney.balances.allSettledBody')}
          />
        ) : (
          <TransferList
            transfers={transfers}
            people={people}
            label={(currency) =>
              view === 'simplified'
                ? t('groupMoney.balances.simplifiedIn', { currency })
                : t('groupMoney.balances.originalIn', { currency })
            }
          />
        )}
      </div>
    </Card>
  );
}

function NetText({ entry }: { entry: MemberBalance }) {
  const { t } = useI18n();
  const direction = sign(entry.net);
  if (direction === 0)
    return <span className="text-fg-muted">{t('groupMoney.balances.even')}</span>;
  return (
    <span className="inline-flex flex-wrap items-baseline justify-end gap-1">
      <span className="text-fg-muted">
        {direction > 0 ? t('groupMoney.balances.isOwed') : t('groupMoney.balances.owes')}
      </span>
      <MoneyText money={magnitude(entry.net)} className="font-semibold" />
    </span>
  );
}

function MembersCard({ balances, people }: { balances: GroupBalances; people: People }) {
  const { t } = useI18n();
  const groups = byCurrency(balances.balances, (entry) => entry.net.currency);
  // Former members with an open balance stay listed by the server until it is settled.
  const formerListed = balances.balances.some((entry) => entry.member_status !== 'active');
  return (
    <Card
      title={t('groupMoney.balances.members')}
      description={t('groupMoney.balances.membersBody')}
    >
      {formerListed ? (
        <p className="mb-4 text-sm text-fg-muted">{t('groupMoney.balances.formerMembers')}</p>
      ) : null}
      {balances.balances.length === 0 ? (
        <p className="text-sm text-fg-muted">{t('groupMoney.balances.noMembers')}</p>
      ) : (
        groups.map(([currency, rows]) => (
          // The table scrolls sideways on narrow screens, so keyboard users must
          // be able to focus the scroll area (axe scrollable-region-focusable).
          <div
            key={currency}
            role="region"
            aria-label={t('groupMoney.balances.membersIn', { currency })}
            // eslint-disable-next-line jsx-a11y/no-noninteractive-tabindex -- a scrollable region needs focus to scroll by keyboard (WCAG 2.1.1)
            tabIndex={0}
            className="overflow-x-auto"
          >
            <table className="w-full min-w-max border-collapse text-sm">
              <caption className="sr-only">
                {t('groupMoney.balances.membersIn', { currency })}
              </caption>
              <thead>
                <tr className="border-b border-line">
                  {[
                    t('groupMoney.breakdown.person'),
                    t('groupMoney.balances.paid'),
                    t('groupMoney.balances.share'),
                    t('groupMoney.balances.sent'),
                    t('groupMoney.balances.received'),
                    t('groupMoney.balances.balance'),
                  ].map((column, index) => (
                    <th
                      key={column}
                      scope="col"
                      className={`py-2 pe-4 font-medium text-fg-muted ${index === 0 ? 'text-start' : 'text-end'}`}
                    >
                      {column}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((entry) => (
                  <tr key={entry.user_id} className="border-b border-line last:border-b-0">
                    <th scope="row" className="py-2 pe-4 text-start font-normal text-fg">
                      {people.name(entry.user_id, entry.display_name)}
                      {entry.member_status === 'active' ? null : (
                        <span className="block text-xs text-fg-muted">
                          {entry.member_status === 'removed'
                            ? t('groupMoney.people.removed')
                            : t('groupMoney.people.leftGroup')}
                        </span>
                      )}
                    </th>
                    <td className="py-2 pe-4 text-end">
                      <MoneyText money={entry.paid} />
                    </td>
                    <td className="py-2 pe-4 text-end">
                      <MoneyText money={entry.share} />
                    </td>
                    <td className="py-2 pe-4 text-end">
                      <MoneyText money={entry.settlements_sent} />
                    </td>
                    <td className="py-2 pe-4 text-end">
                      <MoneyText money={entry.settlements_received} />
                    </td>
                    <td className="py-2 pe-4 text-end">
                      <NetText entry={entry} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ))
      )}
    </Card>
  );
}

function SuggestionsCard({
  group,
  people,
  readOnly,
  onRecord,
}: {
  group: GroupDetail;
  people: People;
  readOnly: boolean;
  onRecord: (prefill: SettlementPrefill) => void;
}) {
  const { t } = useI18n();
  const [mine, setMine] = useState(false);
  const suggestions = useSettlementSuggestions(group.id, mine);

  let content;
  if (suggestions.isPending) {
    content = <LoadingState label={t('groupMoney.suggestions.loading')} />;
  } else if (suggestions.isError) {
    content = (
      <ErrorState
        title={t('groupMoney.suggestions.error')}
        error={suggestions.error}
        retrying={suggestions.isFetching}
        onRetry={() => {
          void suggestions.refetch();
        }}
      />
    );
  } else if (suggestions.data.suggestions.length === 0) {
    content = (
      <p className="text-sm text-fg-muted">
        {mine ? t('groupMoney.suggestions.emptyMine') : t('groupMoney.suggestions.empty')}
      </p>
    );
  } else {
    content = (
      <div className="space-y-3">
        <p className="text-sm text-fg-muted">
          {suggestions.data.mode === 'simplified'
            ? t('groupMoney.suggestions.modeSimplified')
            : t('groupMoney.suggestions.modeOriginal')}
        </p>
        <TransferList
          transfers={suggestions.data.suggestions}
          people={people}
          label={(currency) => t('groupMoney.suggestions.listIn', { currency })}
          action={
            readOnly
              ? undefined
              : (transfer) => (
                  <Button
                    variant="secondary"
                    size="sm"
                    aria-label={t('groupMoney.suggestions.recordFor', {
                      from: people.name(transfer.from_user_id, transfer.from_name),
                      to: people.inSentence(transfer.to_user_id, transfer.to_name),
                    })}
                    onClick={() => {
                      onRecord({
                        payerUserId: transfer.from_user_id,
                        payeeUserId: transfer.to_user_id,
                        amount: transfer.amount.amount,
                      });
                    }}
                  >
                    {t('groupMoney.suggestions.record')}
                  </Button>
                )
          }
        />
      </div>
    );
  }

  return (
    <Card
      title={t('groupMoney.suggestions.title')}
      description={t('groupMoney.suggestions.body')}
      actions={
        <label className="inline-flex min-h-9 cursor-pointer items-center gap-2 text-sm text-fg">
          <input
            type="checkbox"
            checked={mine}
            onChange={(event) => {
              setMine(event.target.checked);
            }}
            className="size-4 accent-accent"
          />
          {t('groupMoney.suggestions.onlyMine')}
        </label>
      }
    >
      {content}
    </Card>
  );
}

function SettlementsCard({
  group,
  people,
  readOnly,
  onRecord,
}: {
  group: GroupDetail;
  people: People;
  readOnly: boolean;
  onRecord: () => void;
}) {
  const { t } = useI18n();
  const [includeVoided, setIncludeVoided] = useState(false);
  const settlements = useSettlements(group.id, includeVoided);

  let content;
  if (settlements.isPending) {
    content = <LoadingState label={t('groupMoney.settlements.loading')} />;
  } else if (settlements.isError) {
    content = (
      <ErrorState
        title={t('groupMoney.settlements.error')}
        error={settlements.error}
        retrying={settlements.isFetching}
        onRetry={() => {
          void settlements.refetch();
        }}
      />
    );
  } else if (settlements.data.length === 0) {
    content = (
      <EmptyState
        icon="handshake"
        title={t('groupMoney.settlements.empty')}
        description={t('groupMoney.settlements.emptyBody')}
        action={
          readOnly ? undefined : (
            <Button variant="secondary" onClick={onRecord}>
              {t('groupMoney.balances.record')}
            </Button>
          )
        }
      />
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {settlements.data.map((settlement) => (
          <SettlementRow
            key={settlement.id}
            settlement={settlement}
            people={people}
            groupId={group.id}
          />
        ))}
      </ul>
    );
  }

  return (
    <Card
      title={t('groupMoney.settlements.title')}
      description={t('groupMoney.settlements.body')}
      actions={
        <label className="inline-flex min-h-9 cursor-pointer items-center gap-2 text-sm text-fg">
          <input
            type="checkbox"
            checked={includeVoided}
            onChange={(event) => {
              setIncludeVoided(event.target.checked);
            }}
            className="size-4 accent-accent"
          />
          {t('groupMoney.settlements.showVoided')}
        </label>
      }
    >
      {content}
    </Card>
  );
}
