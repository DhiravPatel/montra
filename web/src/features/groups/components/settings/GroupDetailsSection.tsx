import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Card } from '@/shared/components/Card';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useT } from '@/shared/i18n/I18nContext';
import { canEditGroup } from '../../access';
import { groupsApi } from '../../api';
import { shouldReloadGroup } from '../../errors';
import { groupToValues, toUpdateInput } from '../../formValues';
import { groupsKeys, refreshGroups } from '../../keys';
import type { GroupDetail, GroupPatch } from '../../types';
import { GroupFacts } from '../GroupAboutCard';
import { GroupForm } from '../GroupForm';

/**
 * Owners and admins edit the group (only the changed settings are sent,
 * with the version they edited); everyone else sees the settings read-only.
 */
export function GroupDetailsSection({ group, reload }: { group: GroupDetail; reload: () => void }) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [conflict, setConflict] = useState(false);
  const update = useMutation({
    mutationFn: (body: GroupPatch) => groupsApi.update(group.id, body),
    onSuccess: (updated) => {
      queryClient.setQueryData(groupsKeys.group(updated.id), updated);
      void refreshGroups(queryClient);
    },
  });

  if (!canEditGroup(group)) {
    return (
      <Card title={t('groups.settings.details.title')}>
        <div className="space-y-4">
          <p className="text-sm text-fg-muted">
            {group.status === 'archived'
              ? t('groups.settings.details.archived')
              : t('groups.settings.details.readOnly')}
          </p>
          <GroupFacts group={group} />
        </div>
      </Card>
    );
  }

  return (
    <Card title={t('groups.settings.details.title')}>
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-6" title={t('finance.conflict.title')}>
          {t('finance.conflict.body')}
        </Alert>
      ) : null}
      <GroupForm
        // Remount with the latest values after a version conflict reload.
        key={group.version}
        mode="edit"
        initialValues={groupToValues(group)}
        submitLabel={t('groups.settings.details.submit')}
        onError={(error) => {
          if (hasErrorCode(error, 'VERSION_CONFLICT')) {
            setConflict(true);
            reload();
            return true;
          }
          if (shouldReloadGroup(error)) reload();
          return false;
        }}
        onSubmit={async (values) => {
          if (update.isPending) return;
          setConflict(false);
          const patch = toUpdateInput(group, values);
          if (!patch) {
            toast.show({ tone: 'info', title: t('groups.settings.details.noChanges') });
            return;
          }
          await update.mutateAsync(patch);
          toast.show({ tone: 'success', title: t('groups.settings.details.done') });
        }}
      />
    </Card>
  );
}
