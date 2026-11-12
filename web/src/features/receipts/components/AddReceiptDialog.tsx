import { useQueryClient } from '@tanstack/react-query';
import { type ChangeEvent, useEffect, useEffectEvent, useId, useRef, useState } from 'react';
import { newIdempotencyKey } from '@/shared/api/idempotency';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { buttonClasses } from '@/shared/components/buttonStyles';
import { Dialog } from '@/shared/components/Dialog';
import { Icon, type IconName } from '@/shared/components/Icon';
import { IconButton } from '@/shared/components/IconButton';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Spinner } from '@/shared/components/Spinner';
import { TextArea } from '@/shared/components/TextArea';
import { filePolicies, uploadFile } from '@/shared/files/upload';
import { invalidateFinance } from '@/shared/finance/keys';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { cx } from '@/shared/utils/cx';
import { receiptsApi } from '../api';
import { receiptErrorMessage } from '../errors';
import type { Receipt } from '../types';
import {
  failedForSure,
  fileProblem,
  fileProblemMessage,
  formatFileSize,
  uploadErrorMessage,
  wasStopped,
} from '../uploads';

/** A receipt has at most 20 pages; one batch of separate receipts uses the same limit. */
const MAX_FILES = 20;
const NOTES_MAX = 1000;
const POLICY = filePolicies.receipt;

export type AddMode = 'pages' | 'separate';

type FileState = 'waiting' | 'uploading' | 'uploaded' | 'creating' | 'failed' | 'done';
type Phase = 'idle' | 'uploading' | 'creating';

interface PickedFile {
  key: string;
  file: File;
  state: FileState;
  error?: string;
}

const stateLabel: Readonly<Record<FileState, MessageKey>> = {
  waiting: 'receipts.add.state.waiting',
  uploading: 'receipts.add.state.uploading',
  uploaded: 'receipts.add.state.uploaded',
  creating: 'receipts.add.state.creating',
  failed: 'receipts.add.state.failed',
  done: 'receipts.add.state.done',
};

/** null while a request is running (a spinner is shown instead). */
const stateIcon: Readonly<Record<FileState, IconName | null>> = {
  waiting: 'file',
  uploading: null,
  uploaded: 'check',
  creating: null,
  failed: 'alert-circle',
  done: 'check-circle',
};

interface AddReceiptDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Every picked file became part of a receipt. */
  onCreated: (receipts: Receipt[], mode: AddMode) => void;
}

/**
 * Adds receipts from photos or PDFs: each file is uploaded (intent → bytes
 * → complete), then the receipt is created (with an Idempotency-Key) for
 * the person to fill in. No reading is requested. Uploads can be stopped,
 * and pages that never became part of a receipt are deleted when the window
 * closes.
 */
export function AddReceiptDialog({ open, onOpenChange, onCreated }: AddReceiptDialogProps) {
  const { t } = useI18n();
  const [busy, setBusy] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('receipts.add.title')}
      description={t('receipts.add.description')}
      busy={busy}
      size="lg"
    >
      {open ? (
        <AddReceiptForm
          onBusyChange={setBusy}
          onClose={() => {
            onOpenChange(false);
          }}
          onCreated={onCreated}
        />
      ) : null}
    </Dialog>
  );
}

interface Ledger {
  controller: AbortController | null;
  /** Stored files by picked-file key; `claimed` once a receipt was requested with the file. */
  stored: Map<string, { fileId: string; claimed: boolean }>;
  /**
   * One Idempotency-Key per receipt request body, kept while that exact
   * request is retried (a lost answer then replays the first receipt instead
   * of creating a second one) and dropped once it succeeds.
   */
  keys: Map<string, string>;
  alive: boolean;
}

function sameFile(a: File, b: File): boolean {
  return a.name === b.name && a.size === b.size && a.lastModified === b.lastModified;
}

function AddReceiptForm({
  onBusyChange,
  onClose,
  onCreated,
}: {
  onBusyChange: (busy: boolean) => void;
  onClose: () => void;
  onCreated: (receipts: Receipt[], mode: AddMode) => void;
}) {
  const { t, formatLocale } = useI18n();
  const queryClient = useQueryClient();
  const helpId = useId();
  const [files, setFiles] = useState<PickedFile[]>([]);
  const [mode, setMode] = useState<AddMode>('pages');
  const [notes, setNotes] = useState('');
  const [phase, setPhase] = useState<Phase>('idle');
  const [rejected, setRejected] = useState<string[]>([]);
  const [formError, setFormError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [dragging, setDragging] = useState(false);
  const ledger = useRef<Ledger>({
    controller: null,
    stored: new Map(),
    keys: new Map(),
    alive: true,
  });
  const zone = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const current = ledger.current;
    current.alive = true;
    return () => {
      current.alive = false;
      current.controller?.abort();
      // Pages that never became part of a receipt would only use storage: delete them (best effort).
      for (const [key, entry] of current.stored) {
        if (entry.claimed) continue;
        current.stored.delete(key);
        void receiptsApi.deleteFile(entry.fileId).catch(() => undefined);
      }
    };
  }, []);

  const changePhase = (next: Phase) => {
    setPhase(next);
    onBusyChange(next !== 'idle');
  };

  const update = (keys: readonly string[], changes: Partial<PickedFile>) => {
    setFiles((list) =>
      list.map((item) => (keys.includes(item.key) ? { ...item, ...changes } : item)),
    );
  };

  const addFiles = (picked: readonly File[]) => {
    if (phase !== 'idle' || picked.length === 0) return;
    const problems: string[] = [];
    const next = [...files];
    for (const file of picked) {
      const problem = fileProblem(file, 'receipt');
      if (problem) {
        problems.push(
          t('receipts.add.rejected', {
            name: file.name,
            reason: fileProblemMessage(problem, 'receipt', t, formatLocale),
          }),
        );
      } else if (next.some((item) => sameFile(item.file, file))) {
        problems.push(t('receipts.add.alreadyAdded', { name: file.name }));
      } else if (next.length >= MAX_FILES) {
        problems.push(t('receipts.add.tooMany', { max: MAX_FILES }));
        break;
      } else {
        next.push({ key: crypto.randomUUID(), file, state: 'waiting' });
      }
    }
    setFiles(next);
    setRejected(problems);
    setFormError(null);
    setNotice(null);
  };

  // Dropping files is an extra for pointer users; "Choose files" is the keyboard-accessible way.
  const onDragActive = useEffectEvent((active: boolean) => {
    setDragging(active && phase === 'idle');
  });
  const onDropFiles = useEffectEvent((dropped: File[]) => {
    addFiles(dropped);
  });
  useEffect(() => {
    const target = zone.current;
    if (!target) return undefined;
    const over = (event: DragEvent) => {
      event.preventDefault();
      onDragActive(true);
    };
    const leave = () => {
      onDragActive(false);
    };
    const drop = (event: DragEvent) => {
      event.preventDefault();
      onDragActive(false);
      onDropFiles(Array.from(event.dataTransfer?.files ?? []));
    };
    target.addEventListener('dragover', over);
    target.addEventListener('dragleave', leave);
    target.addEventListener('drop', drop);
    return () => {
      target.removeEventListener('dragover', over);
      target.removeEventListener('dragleave', leave);
      target.removeEventListener('drop', drop);
    };
  }, []);

  const remove = (key: string) => {
    const entry = ledger.current.stored.get(key);
    if (entry && !entry.claimed) {
      ledger.current.stored.delete(key);
      void receiptsApi.deleteFile(entry.fileId).catch(() => undefined);
    }
    setFiles((list) => list.filter((item) => item.key !== key));
  };

  const move = (index: number, offset: -1 | 1) => {
    setFiles((list) => {
      const target = index + offset;
      const a = list[index];
      const b = list[target];
      if (!a || !b) return list;
      const next = [...list];
      next[index] = b;
      next[target] = a;
      return next;
    });
  };

  const run = async () => {
    if (phase !== 'idle') return;
    const pending = files.filter((item) => item.state !== 'done');
    if (pending.length === 0) {
      setFormError(t('receipts.add.noFiles'));
      return;
    }
    const current = ledger.current;
    const controller = new AbortController();
    current.controller = controller;
    setFormError(null);
    setNotice(null);
    setRejected([]);
    changePhase('uploading');
    const note = notes.trim();
    const created: Receipt[] = [];
    // Updated from the helpers below (an object, so the latest values are read after the loop).
    const outcome: { failures: number; createError: string | null } = {
      failures: 0,
      createError: null,
    };

    const upload = async (item: PickedFile): Promise<string | null> => {
      const stored = current.stored.get(item.key);
      if (stored) return stored.fileId;
      update([item.key], { state: 'uploading', error: undefined });
      try {
        const record = await uploadFile(item.file, {
          purpose: 'receipt',
          signal: controller.signal,
        });
        current.stored.set(item.key, { fileId: record.id, claimed: false });
        update([item.key], { state: 'uploaded' });
        return record.id;
      } catch (error) {
        if (wasStopped(error, controller.signal)) {
          update([item.key], { state: 'waiting' });
          throw error;
        }
        outcome.failures += 1;
        update([item.key], {
          state: 'failed',
          error: uploadErrorMessage(error, t, formatLocale),
        });
        return null;
      }
    };

    // Creating is quick and cannot be stopped halfway: the receipt may already exist.
    const create = async (keys: string[], fileIds: string[]) => {
      changePhase('creating');
      for (const key of keys) {
        const entry = current.stored.get(key);
        if (entry) entry.claimed = true;
      }
      update(keys, { state: 'creating', error: undefined });
      const draft = JSON.stringify({ fileIds, note });
      const idempotencyKey = current.keys.get(draft) ?? newIdempotencyKey();
      current.keys.set(draft, idempotencyKey);
      try {
        const receipt = await receiptsApi.create(fileIds, note, idempotencyKey);
        current.keys.delete(draft);
        created.push(receipt);
        update(keys, { state: 'done' });
      } catch (error) {
        outcome.failures += 1;
        // Only a definite refusal frees the pages; after a lost answer they may be in use.
        if (failedForSure(error)) {
          for (const key of keys) {
            const entry = current.stored.get(key);
            if (entry) entry.claimed = false;
          }
        }
        const message = receiptErrorMessage(error, 'create', t, formatLocale);
        outcome.createError = message;
        update(keys, { state: 'failed', error: message });
      } finally {
        if (current.alive) changePhase('uploading');
      }
    };

    try {
      if (mode === 'pages') {
        const fileIds: string[] = [];
        for (const item of files) {
          const fileId = await upload(item);
          if (fileId) fileIds.push(fileId);
        }
        if (outcome.failures === 0) {
          await create(
            files.map((item) => item.key),
            fileIds,
          );
        }
      } else {
        for (const item of pending) {
          const fileId = await upload(item);
          if (fileId) await create([item.key], [fileId]);
        }
      }
    } catch (error) {
      // Only stopping reaches here (each step handles its own failures).
      if (current.alive) {
        if (wasStopped(error, controller.signal)) setNotice(t('receipts.add.stopped'));
        else setFormError(describeError(error, t));
      }
    } finally {
      current.controller = null;
      if (current.alive) changePhase('idle');
    }

    if (created.length > 0) void invalidateFinance(queryClient);
    if (!current.alive) return;
    const complete = created.length > 0 && outcome.failures === 0 && !controller.signal.aborted;
    if (complete) {
      onCreated(created, mode);
      return;
    }
    if (outcome.failures > 0) {
      setFormError(
        mode === 'pages'
          ? (outcome.createError ?? t('receipts.add.pagesFailed'))
          : t('receipts.add.someFailed', { count: outcome.failures }),
      );
    }
    if (created.length > 0) {
      setNotice(t('receipts.add.partlyAdded', { count: created.length }));
    }
  };

  const onPick = (event: ChangeEvent<HTMLInputElement>) => {
    addFiles(Array.from(event.target.files ?? []));
    // Allow picking the same file again after removing it.
    event.target.value = '';
  };

  const running = phase !== 'idle';
  const remaining = files.filter((item) => item.state !== 'done');
  const finished = files.filter((item) =>
    ['uploaded', 'creating', 'done'].includes(item.state),
  ).length;
  const retry = files.some((item) => item.state === 'failed');
  const submitLabel = retry
    ? t('receipts.add.retry')
    : mode === 'pages' || remaining.length <= 1
      ? t('receipts.add.submitOne')
      : t('receipts.add.submitMany', { count: remaining.length });

  return (
    <div className="space-y-5">
      <FormAlert message={formError} />
      {rejected.length > 0 ? (
        <Alert tone="warning" live="assertive" title={t('receipts.add.rejectedTitle')}>
          <ul className="list-disc space-y-1 ps-5">
            {rejected.map((problem) => (
              <li key={problem}>{problem}</li>
            ))}
          </ul>
        </Alert>
      ) : null}
      {notice ? (
        <Alert tone="info" live="polite">
          {notice}
        </Alert>
      ) : null}

      <div
        ref={zone}
        className={cx(
          'flex flex-col items-center gap-3 rounded-lg border-2 border-dashed px-4 py-6 text-center',
          dragging ? 'border-accent bg-accent-soft' : 'border-line-strong',
        )}
      >
        <Icon name="upload" className="size-8 text-fg-muted" />
        <p className="text-sm text-fg">{t('receipts.add.dropHint')}</p>
        <label
          className={buttonClasses(
            'secondary',
            'sm',
            cx(
              'cursor-pointer has-[:focus-visible]:outline-3 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-focus',
              running && 'pointer-events-none opacity-60',
            ),
          )}
        >
          <Icon name="plus" className="size-4" />
          {t('receipts.add.choose')}
          <input
            type="file"
            multiple
            accept={POLICY.accept}
            className="sr-only"
            aria-describedby={helpId}
            disabled={running}
            onChange={onPick}
          />
        </label>
        <p id={helpId} className="text-xs text-fg-muted">
          {t('receipts.add.help', {
            size: formatFileSize(POLICY.maxBytes, formatLocale),
            max: MAX_FILES,
          })}
        </p>
      </div>

      {files.length > 0 ? (
        <section aria-labelledby={`${helpId}-files`} className="space-y-2">
          <h3 id={`${helpId}-files`} className="text-sm font-semibold text-fg">
            {t('receipts.add.files', { count: files.length })}
          </h3>
          <ol className="divide-y divide-line rounded-lg border border-line px-3">
            {files.map((item, index) => {
              const label = item.file.name;
              const status = t(stateLabel[item.state]);
              const icon = stateIcon[item.state];
              return (
                <li key={item.key} className="flex items-start gap-3 py-2.5">
                  <span className="mt-0.5 shrink-0 text-fg-muted">
                    {icon === null ? (
                      <Spinner size="sm" />
                    ) : (
                      <Icon
                        name={icon}
                        className={cx(
                          'size-4',
                          item.state === 'failed' && 'text-danger',
                          item.state === 'done' && 'text-success',
                        )}
                      />
                    )}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="break-all text-sm font-medium text-fg">
                      {mode === 'pages' && files.length > 1
                        ? t('receipts.add.pageName', { page: index + 1, name: label })
                        : label}
                    </p>
                    <p className="text-sm text-fg-muted">
                      {[formatFileSize(item.file.size, formatLocale), status].join(' · ')}
                    </p>
                    {item.error ? (
                      <p className="mt-1 flex items-start gap-1.5 text-sm font-medium text-danger">
                        <Icon name="alert-circle" className="mt-0.5 size-4 shrink-0" />
                        <span>{item.error}</span>
                      </p>
                    ) : null}
                  </div>
                  {!running && item.state !== 'done' ? (
                    <div className="flex shrink-0 gap-1">
                      {mode === 'pages' && files.length > 1 ? (
                        <>
                          <IconButton
                            icon="arrow-up"
                            size="sm"
                            label={t('receipts.add.moveUp', { name: label })}
                            disabled={index === 0}
                            onClick={() => {
                              move(index, -1);
                            }}
                          />
                          <IconButton
                            icon="arrow-down"
                            size="sm"
                            label={t('receipts.add.moveDown', { name: label })}
                            disabled={index === files.length - 1}
                            onClick={() => {
                              move(index, 1);
                            }}
                          />
                        </>
                      ) : null}
                      <IconButton
                        icon="x"
                        size="sm"
                        label={t('receipts.add.remove', { name: label })}
                        onClick={() => {
                          remove(item.key);
                        }}
                      />
                    </div>
                  ) : null}
                </li>
              );
            })}
          </ol>
        </section>
      ) : null}

      {files.length > 1 ? (
        <RadioGroup
          legend={t('receipts.add.mode')}
          variant="cards"
          value={mode}
          disabled={running || files.some((item) => item.state === 'done')}
          onChange={setMode}
          options={[
            {
              value: 'pages',
              label: t('receipts.add.modePages'),
              description: t('receipts.add.modePagesHelp'),
            },
            {
              value: 'separate',
              label: t('receipts.add.modeSeparate'),
              description: t('receipts.add.modeSeparateHelp'),
            },
          ]}
        />
      ) : null}

      <TextArea
        label={t('receipts.add.notes')}
        help={
          mode === 'separate' && files.length > 1
            ? t('receipts.add.notesHelpEach')
            : t('receipts.add.notesHelp')
        }
        optional
        rows={2}
        maxLength={NOTES_MAX}
        value={notes}
        disabled={running}
        onChange={(event) => {
          setNotes(event.target.value);
        }}
      />

      <div className="space-y-2">
        {running ? (
          <progress
            max={Math.max(files.length, 1)}
            value={finished}
            aria-label={t('receipts.add.progressLabel')}
            className="h-2 w-full overflow-hidden rounded-full [&::-moz-progress-bar]:bg-accent [&::-webkit-progress-bar]:bg-surface-muted [&::-webkit-progress-value]:bg-accent"
          />
        ) : null}
        <p role="status" className="text-sm text-fg-muted">
          {phase === 'uploading'
            ? t('receipts.add.progress', { done: finished, total: files.length })
            : phase === 'creating'
              ? t('receipts.add.creating')
              : ''}
        </p>
      </div>

      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        {phase === 'uploading' ? (
          <Button
            variant="secondary"
            onClick={() => {
              ledger.current.controller?.abort();
            }}
          >
            <Icon name="x" className="size-4" />
            {t('receipts.add.stop')}
          </Button>
        ) : (
          <Button variant="secondary" disabled={running} onClick={onClose}>
            {files.some((item) => item.state === 'done') ? t('common.close') : t('common.cancel')}
          </Button>
        )}
        <Button
          loading={running}
          onClick={() => {
            void run();
          }}
        >
          <Icon name="upload" className="size-4" />
          {submitLabel}
        </Button>
      </div>
    </div>
  );
}
