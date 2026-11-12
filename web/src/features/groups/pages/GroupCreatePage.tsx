import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { useToast } from '@/shared/components/toast/ToastContext';
import { groupPath, paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { groupsApi } from '../api';
import { GroupForm } from '../components/GroupForm';
import { emptyGroupValues, toCreateInput } from '../formValues';
import { groupsKeys, refreshGroups } from '../keys';
import type { GroupInput } from '../types';

/** Creates a group, household, trip or event; the creator becomes its owner. */
export function GroupCreatePage() {
  const t = useT();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const user = useCurrentUser();
  useDocumentTitle(t('groups.create.title'));
  const [initialValues] = useState(() => emptyGroupValues(user.base_currency, user.timezone));
  const create = useMutation({
    mutationFn: (body: GroupInput) => groupsApi.create(body),
    onSuccess: (group) => {
      queryClient.setQueryData(groupsKeys.group(group.id), group);
      void refreshGroups(queryClient);
    },
  });

  return (
    <>
      <PageHeader title={t('groups.create.title')} description={t('groups.create.description')} />
      <Card>
        <GroupForm
          mode="create"
          initialValues={initialValues}
          submitLabel={t('groups.create.submit')}
          secondaryAction={
            <ButtonLink to={paths.groups} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onSubmit={async (values) => {
            if (create.isPending) return;
            const group = await create.mutateAsync(toCreateInput(values));
            toast.show({ tone: 'success', title: t('groups.create.done') });
            void navigate(groupPath(group.id));
          }}
        />
      </Card>
    </>
  );
}
