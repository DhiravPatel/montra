import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type RefObject, type SubmitEvent, useEffect, useRef, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Checkbox } from '@/shared/components/Checkbox';
import { Icon } from '@/shared/components/Icon';
import { IconButton } from '@/shared/components/IconButton';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select } from '@/shared/components/Select';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useT } from '@/shared/i18n/I18nContext';
import { communitiesApi } from '../api';
import { fieldProblems, splitFieldProblems, useCommunityError } from '../errors';
import { communitiesKeys, refreshContent } from '../keys';
import { NEW_POST_KINDS, postKindHelp, postKindLabel } from '../labels';
import {
  BODY_MAX,
  LINK_MAX,
  TITLE_MAX,
  validatePostText,
  validateResourceLink,
} from '../text/postRules';
import type { Community, NewPostKind, PostInput } from '../types';

const QUESTION_MAX = 300;
const OPTION_MAX = 120;
const MAX_OPTIONS = 10;
const POLL_DAYS = ['', '1', '3', '7', '14', '30'] as const;

type Field = 'title' | 'body' | 'link' | 'question' | 'options' | 'closes' | 'label';
type Errors = Partial<Record<Field, string>>;

/** API field (without `body.`) -> composer field. */
const serverFields: Readonly<Partial<Record<string, Field>>> = {
  title: 'title',
  body: 'body',
  link_url: 'link',
  label: 'label',
  poll: 'question',
  'poll.question': 'question',
  'poll.options': 'options',
  'poll.closes_at': 'closes',
};

function chars(text: string): number {
  return Array.from(text).length;
}

/**
 * Starts a post: a discussion, a question, a resource link or a poll.
 * Plain text only; the safety note reminds people never to share account
 * details, card numbers, PINs or OTPs.
 */
export function PostComposer({
  community,
  moderator,
}: {
  community: Community;
  /** Moderators may mark a post as verified guidance. */
  moderator: boolean;
}) {
  const t = useT();
  const [open, setOpen] = useState(false);
  const openButton = useRef<HTMLButtonElement>(null);
  return (
    <Card
      title={t('communities.composer.title')}
      description={t('communities.composer.description')}
    >
      {open ? (
        <ComposerForm
          community={community}
          moderator={moderator}
          onClose={() => {
            setOpen(false);
          }}
          onClosedFocus={openButton}
        />
      ) : (
        <Button
          ref={openButton}
          onClick={() => {
            setOpen(true);
          }}
        >
          <Icon name="pencil" className="size-4" />
          {t('communities.composer.start')}
        </Button>
      )}
    </Card>
  );
}

function ComposerForm({
  community,
  moderator,
  onClose,
  onClosedFocus,
}: {
  community: Community;
  moderator: boolean;
  onClose: () => void;
  onClosedFocus: RefObject<HTMLButtonElement | null>;
}) {
  const t = useT();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const titleRef = useRef<HTMLInputElement>(null);
  const [kind, setKind] = useState<NewPostKind>('discussion');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [link, setLink] = useState('');
  const [question, setQuestion] = useState('');
  const [options, setOptions] = useState<string[]>(['', '']);
  const [multiple, setMultiple] = useState(false);
  const [days, setDays] = useState<(typeof POLL_DAYS)[number]>('');
  const [verified, setVerified] = useState(false);
  const [errors, setErrors] = useState<Errors>({});
  const [formError, setFormError] = useState<string | null>(null);
  const create = useMutation({
    mutationFn: (input: PostInput) => communitiesApi.createPost(community.id, input),
    onSuccess: () => refreshContent(queryClient, community.id),
  });

  useEffect(() => {
    titleRef.current?.focus();
  }, []);

  const close = () => {
    onClose();
    // The button that opened the form comes back; return focus to it.
    window.setTimeout(() => {
      onClosedFocus.current?.focus();
    }, 0);
  };

  const validate = (): Errors => {
    const next: Errors = validatePostText(title, body, t);
    if (kind === 'resource') {
      const linkError = validateResourceLink(link, t);
      if (linkError) next.link = linkError;
    }
    if (kind === 'poll') {
      const q = question.trim();
      if (chars(q) < 3) next.question = t('communities.composer.questionRequired');
      else if (chars(q) > QUESTION_MAX)
        next.question = t('validation.maxLength', { max: QUESTION_MAX });
      const filled = options.map((option) => option.trim()).filter(Boolean);
      const distinct = new Set(filled.map((option) => option.toLowerCase()));
      if (filled.length < 2) next.options = t('communities.field.pollTwo');
      else if (distinct.size !== filled.length) next.options = t('communities.field.pollDistinct');
      else if (filled.some((option) => chars(option) > OPTION_MAX)) {
        next.options = t('validation.maxLength', { max: OPTION_MAX });
      }
    }
    return next;
  };

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (create.isPending) return;
    setFormError(null);
    const next = validate();
    setErrors(next);
    if (Object.keys(next).length > 0) return;
    const text = body.trim();
    const input: PostInput = {
      kind,
      title: title.trim(),
      ...(text ? { body: text } : {}),
      ...(kind === 'resource' ? { link_url: link.trim() } : {}),
      ...(moderator && verified ? { label: 'verified_guidance' as const } : {}),
    };
    if (kind === 'poll') {
      input.poll = {
        question: question.trim(),
        options: options.map((option) => option.trim()).filter(Boolean),
        allow_multiple: multiple,
        ...(days
          ? { closes_at: new Date(Date.now() + Number(days) * 86_400_000).toISOString() }
          : {}),
      };
    }
    create.mutate(input, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('communities.composer.posted') });
        close();
      },
      onError: (error) => {
        const problems = fieldProblems(error, t);
        if (problems.length > 0) {
          const { byField, rest } = splitFieldProblems(problems, serverFields);
          setErrors(byField);
          setFormError(rest.length > 0 ? rest.join(' ') : null);
          return;
        }
        setFormError(describe(error, { codes: { CONFLICT: 'communities.composer.duplicate' } }));
        if (hasErrorCode(error, 'FORBIDDEN')) {
          void queryClient.invalidateQueries({ queryKey: communitiesKeys.communities() });
        }
      },
    });
  };

  return (
    <form noValidate onSubmit={submit} className="space-y-5">
      <FormAlert message={formError} />
      <RadioGroup<NewPostKind>
        legend={t('communities.composer.kind')}
        value={kind}
        onChange={(value) => {
          setKind(value);
          setErrors({});
        }}
        options={NEW_POST_KINDS.map((value) => ({ value, label: t(postKindLabel[value]) }))}
        help={t(postKindHelp[kind])}
      />
      <TextField
        ref={titleRef}
        label={
          kind === 'question'
            ? t('communities.composer.questionTitle')
            : t('communities.composer.postTitle')
        }
        maxLength={TITLE_MAX}
        autoComplete="off"
        value={title}
        error={errors.title}
        onChange={(event) => {
          setTitle(event.target.value);
        }}
      />
      {kind === 'resource' ? (
        <TextField
          type="url"
          label={t('communities.composer.link')}
          help={t('communities.composer.linkHelp')}
          inputMode="url"
          autoComplete="off"
          spellCheck={false}
          maxLength={LINK_MAX}
          value={link}
          error={errors.link}
          onChange={(event) => {
            setLink(event.target.value);
          }}
        />
      ) : null}
      {kind === 'poll' ? (
        <fieldset className="space-y-4 rounded-lg border border-line p-4">
          <legend className="px-1 text-sm font-medium text-fg">
            {t('communities.composer.poll')}
          </legend>
          <TextField
            label={t('communities.composer.pollQuestion')}
            maxLength={QUESTION_MAX}
            autoComplete="off"
            value={question}
            error={errors.question}
            onChange={(event) => {
              setQuestion(event.target.value);
            }}
          />
          <PollOptionsEditor options={options} error={errors.options} onChange={setOptions} />
          <Checkbox
            label={t('communities.composer.pollMultiple')}
            checked={multiple}
            onChange={(event) => {
              setMultiple(event.target.checked);
            }}
          />
          <Select
            label={t('communities.composer.pollCloses')}
            value={days}
            error={errors.closes}
            options={POLL_DAYS.map((value) => ({
              value,
              label: value
                ? t('communities.composer.pollClosesIn', { count: Number(value) })
                : t('communities.composer.pollNeverCloses'),
            }))}
            onChange={(event) => {
              setDays(event.target.value as (typeof POLL_DAYS)[number]);
            }}
          />
        </fieldset>
      ) : null}
      <TextArea
        label={
          kind === 'poll' ? t('communities.composer.pollContext') : t('communities.composer.body')
        }
        help={t('communities.composer.bodyHelp')}
        optional
        rows={5}
        maxLength={BODY_MAX}
        value={body}
        error={errors.body}
        onChange={(event) => {
          setBody(event.target.value);
        }}
      />
      {moderator ? (
        <Checkbox
          label={t('communities.composer.verified')}
          description={t('communities.composer.verifiedHelp')}
          checked={verified}
          error={errors.label}
          onChange={(event) => {
            setVerified(event.target.checked);
          }}
        />
      ) : null}
      <Alert tone="info">{t('communities.composer.safety')}</Alert>
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="ghost" disabled={create.isPending} onClick={close}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={create.isPending}>
          <Icon name="message-square" className="size-4" />
          {t('communities.composer.submit')}
        </Button>
      </div>
    </form>
  );
}

/** Two to ten answer choices; each can be removed while more than two remain. */
function PollOptionsEditor({
  options,
  error,
  onChange,
}: {
  options: string[];
  error: string | undefined;
  onChange: (options: string[]) => void;
}) {
  const t = useT();
  return (
    <fieldset className="space-y-3">
      <legend className="mb-1.5 text-sm font-medium text-fg">
        {t('communities.composer.pollOptions')}
      </legend>
      <ul className="space-y-3">
        {options.map((option, index) => (
          // Options have no identity beyond their position while being written.
          <li key={index} className="flex items-end gap-2">
            <TextField
              className="flex-1"
              label={t('communities.composer.pollOption', { number: index + 1 })}
              maxLength={OPTION_MAX}
              autoComplete="off"
              value={option}
              onChange={(event) => {
                onChange(options.map((item, i) => (i === index ? event.target.value : item)));
              }}
            />
            {options.length > 2 ? (
              <IconButton
                icon="trash"
                label={t('communities.composer.pollRemove', { number: index + 1 })}
                onClick={() => {
                  onChange(options.filter((_, i) => i !== index));
                }}
              />
            ) : null}
          </li>
        ))}
      </ul>
      {error ? (
        <p role="alert" className="flex items-start gap-1.5 text-sm font-medium text-danger">
          <Icon name="alert-circle" className="mt-0.5 size-4" />
          <span>
            <span className="sr-only">{t('common.errorPrefix')} </span>
            {error}
          </span>
        </p>
      ) : null}
      {options.length < MAX_OPTIONS ? (
        <Button
          variant="secondary"
          size="sm"
          onClick={() => {
            onChange([...options, '']);
          }}
        >
          <Icon name="plus" className="size-4" />
          {t('communities.composer.pollAdd')}
        </Button>
      ) : null}
    </fieldset>
  );
}
