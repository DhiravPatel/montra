import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { useToast } from '@/shared/components/toast/ToastContext';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useT } from '@/shared/i18n/I18nContext';
import { groupsApi } from '../../api';
import { groupErrorMessage, shouldReloadGroup } from '../../errors';
import { groupsKeys, refreshGroups } from '../../keys';
import {
  NOTIFICATION_LEVELS,
  notificationLevelDescription,
  notificationLevelLabel,
} from '../../labels';
import type { GroupDetail, NotificationLevel } from '../../types';

/** Each member chooses how much they hear about this group. */
export function NotificationsSection({
  group,
  reload,
}: {
  group: GroupDetail;
  reload: () => void;
}) {
  const t = useT();
  const me = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const current = group.members.find((member) => member.user_id === me.id)?.notification_level;
  const [draft, setDraft] = useState<NotificationLevel>(current ?? 'all');
  const [error, setError] = useState<string | null>(null);
  const save = useMutation({
    mutationFn: (level: NotificationLevel) =>
      groupsApi.updateMember(group.id, me.id, { notification_level: level }),
    onSuccess: (updated) => {
      queryClient.setQueryData(groupsKeys.group(updated.id), updated);
      void refreshGroups(queryClient);
    },
  });

  if (!current) return null;
  // The API accepts member changes only while the group is active.
  const archived = group.status !== 'active';

  return (
    <Card
      title={t('groups.settings.notifications.title')}
      description={t('groups.settings.notifications.description')}
    >
      <form
        noValidate
        className="space-y-4"
        onSubmit={(event) => {
          event.preventDefault();
          if (save.isPending || draft === current) return;
          setError(null);
          save.mutate(draft, {
            onSuccess: () => {
              toast.show({ tone: 'success', title: t('groups.settings.notifications.done') });
            },
            onError: (failure) => {
              setError(groupErrorMessage(failure, t));
              if (shouldReloadGroup(failure)) reload();
            },
          });
        }}
      >
        <FormAlert message={error} />
        {archived ? (
          <p className="text-sm text-fg-muted">{t('groups.settings.notifications.archived')}</p>
        ) : null}
        <RadioGroup<NotificationLevel>
          legend={t('groups.settings.notifications.legend')}
          hideLegend
          variant="cards"
          disabled={archived}
          value={draft}
          onChange={setDraft}
          options={NOTIFICATION_LEVELS.map((level) => ({
            value: level,
            label: t(notificationLevelLabel[level]),
            description: t(notificationLevelDescription[level]),
          }))}
        />
        {draft === current || archived ? null : (
          <Button type="submit" size="sm" loading={save.isPending}>
            {t('groups.settings.notifications.submit')}
          </Button>
        )}
      </form>
    </Card>
  );
}
