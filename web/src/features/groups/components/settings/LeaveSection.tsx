import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { groupBalancesPath } from '@/shared/config/paths';
import { domainRuleCode } from '@/shared/finance/domainErrors';
import { useT } from '@/shared/i18n/I18nContext';
import { groupsApi } from '../../api';
import { groupErrorMessage, shouldReloadGroup } from '../../errors';
import { groupsKeys, refreshGroups } from '../../keys';
import { leaveGroupPage } from '../../navigation';
import type { GroupDetail } from '../../types';

/**
 * Leaving: the owner transfers ownership first, and everyone settles their
 * balance first (the API answers transfer_ownership_first / balance_open).
 */
export function LeaveSection({ group, reload }: { group: GroupDetail; reload: () => void }) {
  const t = useT();
  const me = useCurrentUser();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  /** A rule the API answered with (shown outside the dialog, with what to do next). */
  const [blocked, setBlocked] = useState<'balance_open' | 'transfer_ownership_first' | null>(null);
  const owner = group.my_role === 'owner';
  const leave = useMutation({ mutationFn: () => groupsApi.removeMember(group.id, me.id) });

  const run = () => {
    if (leave.isPending) return;
    setError(null);
    setBlocked(null);
    leave.mutate(undefined, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('groups.leave.done', { name: group.name }) });
        setConfirming(false);
        void leaveGroupPage(navigate, () => {
          // No access any more: drop the group instead of refetching a 404.
          queryClient.removeQueries({ queryKey: groupsKeys.group(group.id) });
          void refreshGroups(queryClient, { personal: true });
        });
      },
      onError: (failure) => {
        const code = domainRuleCode(failure)?.code;
        if (code === 'balance_open' || code === 'transfer_ownership_first') {
          setConfirming(false);
          setBlocked(code);
          // The role may have changed (e.g. ownership was transferred to you).
          if (code === 'transfer_ownership_first') reload();
          return;
        }
        setError(groupErrorMessage(failure, t));
        if (shouldReloadGroup(failure)) reload();
      },
    });
  };

  return (
    <Card title={t('groups.leave.title')}>
      <div className="space-y-4">
        <p className="text-sm text-fg-muted">
          {owner ? t('groups.leave.ownerHelp') : t('groups.leave.help')}
        </p>
        {blocked ? (
          <Alert tone="warning" live="assertive" title={t('groups.leave.blockedTitle')}>
            <p>
              {blocked === 'balance_open'
                ? t('groups.rule.balance_open')
                : t('groups.rule.transfer_ownership_first')}
            </p>
            {blocked === 'balance_open' ? (
              <TextLink to={groupBalancesPath(group.id)}>{t('groups.leave.balancesLink')}</TextLink>
            ) : null}
          </Alert>
        ) : null}
        <Button
          variant="secondary"
          disabled={owner}
          onClick={() => {
            setError(null);
            setConfirming(true);
          }}
        >
          <Icon name="log-out" className="size-4" />
          {t('groups.leave.action')}
        </Button>
      </div>
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        title={t('groups.leave.confirmTitle', { name: group.name })}
        description={t('groups.leave.confirmBody')}
        confirmLabel={t('groups.leave.confirm')}
        pending={leave.isPending}
        error={error}
        onConfirm={run}
      />
    </Card>
  );
}
