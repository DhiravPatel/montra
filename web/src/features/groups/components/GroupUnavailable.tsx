import { useMutation } from '@tanstack/react-query';
import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { EmptyState } from '@/shared/components/states';
import { TextArea } from '@/shared/components/TextArea';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths } from '@/shared/config/paths';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useT } from '@/shared/i18n/I18nContext';
import { groupsApi } from '../api';
import { groupErrorMessage } from '../errors';

const MESSAGE_MAX = 300;

/**
 * A group the API answers 404 for: deleted, never existed, or the user is
 * not (or no longer) a member. Non-members cannot learn more, but someone
 * who knows the group's link (e.g. a former member) may ask to join; the
 * admins decide.
 */
export function GroupUnavailable({ groupId }: { groupId: string }) {
  const t = useT();
  const [asking, setAsking] = useState(false);
  const [sent, setSent] = useState(false);
  return (
    <>
      {sent ? (
        <Alert tone="success" live="polite" className="mb-6" title={t('groups.joinRequest.sent')}>
          {t('groups.joinRequest.sentBody')}
        </Alert>
      ) : null}
      <EmptyState
        titleAs="h2"
        icon="users"
        title={t('groups.unavailable.title')}
        description={t('groups.unavailable.body')}
        action={
          <>
            <ButtonLink to={paths.groups}>{t('groups.backToList')}</ButtonLink>
            {sent ? null : (
              <Button
                variant="secondary"
                onClick={() => {
                  setAsking(true);
                }}
              >
                {t('groups.joinRequest.action')}
              </Button>
            )}
          </>
        }
      />
      <JoinRequestDialog
        groupId={groupId}
        open={asking}
        onOpenChange={setAsking}
        onSent={() => {
          setSent(true);
        }}
      />
    </>
  );
}

function JoinRequestDialog({
  groupId,
  open,
  onOpenChange,
  onSent,
}: {
  groupId: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSent: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const [message, setMessage] = useState('');
  const [error, setError] = useState<string | null>(null);
  const request = useMutation({
    mutationFn: () => groupsApi.requestToJoin(groupId, message.trim()),
  });
  const close = () => {
    onOpenChange(false);
    setError(null);
  };
  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (!next) close();
      }}
      title={t('groups.joinRequest.title')}
      description={t('groups.joinRequest.description')}
      busy={request.isPending}
    >
      <form
        noValidate
        className="space-y-5"
        onSubmit={(event) => {
          event.preventDefault();
          if (request.isPending) return;
          setError(null);
          request.mutate(undefined, {
            onSuccess: () => {
              toast.show({ tone: 'success', title: t('groups.joinRequest.sent') });
              onSent();
              close();
            },
            onError: (failure) => {
              if (hasErrorCode(failure, 'NOT_FOUND')) {
                setError(t('groups.joinRequest.notFound'));
              } else {
                setError(
                  groupErrorMessage(failure, t, {
                    conflicts: {
                      already_member: 'groups.joinRequest.alreadyMember',
                      join_request_pending: 'groups.joinRequest.pending',
                    },
                    codes: { CONFLICT: 'groups.joinRequest.conflict' },
                  }),
                );
              }
            },
          });
        }}
      >
        <FormAlert message={error} />
        <TextArea
          label={t('groups.joinRequest.message')}
          help={t('groups.joinRequest.messageHelp')}
          optional
          maxLength={MESSAGE_MAX}
          value={message}
          onChange={(event) => {
            setMessage(event.target.value);
          }}
        />
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button variant="secondary" disabled={request.isPending} onClick={close}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" loading={request.isPending}>
            {t('groups.joinRequest.submit')}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
