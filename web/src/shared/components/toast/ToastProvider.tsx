import { type ReactNode, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { Icon } from '../Icon';
import { IconButton } from '../IconButton';
import { toneIcon, toneSurface, toneText } from '../tones';
import { type ToastApi, ToastContext, type ToastOptions, type ToastTone } from './ToastContext';

interface ToastItem extends ToastOptions {
  id: number;
  tone: ToastTone;
}

const AUTO_DISMISS_MS = 6000;
const MAX_VISIBLE = 4;

function ToastCard({ item, onDismiss }: { item: ToastItem; onDismiss: (id: number) => void }) {
  const t = useT();
  const [paused, setPaused] = useState(false);
  const cardRef = useRef<HTMLDivElement>(null);

  // Hovering or focusing a toast pauses its timer (WCAG 2.2.1 Timing Adjustable).
  useEffect(() => {
    const card = cardRef.current;
    if (!card) return;
    const pause = () => {
      setPaused(true);
    };
    const resume = () => {
      setPaused(false);
    };
    card.addEventListener('pointerenter', pause);
    card.addEventListener('pointerleave', resume);
    card.addEventListener('focusin', pause);
    card.addEventListener('focusout', resume);
    return () => {
      card.removeEventListener('pointerenter', pause);
      card.removeEventListener('pointerleave', resume);
      card.removeEventListener('focusin', pause);
      card.removeEventListener('focusout', resume);
    };
  }, []);

  useEffect(() => {
    // Errors stay until dismissed; others auto-dismiss unless hovered/focused.
    if (item.tone === 'danger' || paused) return;
    const timer = window.setTimeout(() => {
      onDismiss(item.id);
    }, AUTO_DISMISS_MS);
    return () => {
      window.clearTimeout(timer);
    };
  }, [item.id, item.tone, paused, onDismiss]);

  return (
    <div
      ref={cardRef}
      className={cx(
        'pointer-events-auto flex w-full items-start gap-3 rounded-lg border p-4 text-sm text-fg shadow-overlay',
        toneSurface[item.tone],
      )}
    >
      <Icon name={toneIcon[item.tone]} className={cx('mt-0.5', toneText[item.tone])} />
      <div className="min-w-0 flex-1">
        <p className="font-semibold">{item.title}</p>
        {item.description ? <p className="mt-1 text-fg-muted">{item.description}</p> : null}
      </div>
      <IconButton
        icon="x"
        size="sm"
        label={t('common.dismissNotification')}
        className="-me-2 -mt-2"
        onClick={() => {
          onDismiss(item.id);
        }}
      />
    </div>
  );
}

/** Toast notifications rendered inside persistent live regions. */
export function ToastProvider({ children }: { children: ReactNode }) {
  const t = useT();
  const [items, setItems] = useState<ToastItem[]>([]);
  const nextId = useRef(1);

  const dismiss = useCallback((id: number) => {
    setItems((list) => list.filter((item) => item.id !== id));
  }, []);

  const show = useCallback((options: ToastOptions) => {
    const id = nextId.current++;
    setItems((list) => [
      ...list.slice(-(MAX_VISIBLE - 1)),
      { ...options, id, tone: options.tone ?? 'info' },
    ]);
  }, []);

  const api = useMemo<ToastApi>(() => ({ show, dismiss }), [show, dismiss]);
  const polite = items.filter((item) => item.tone !== 'danger');
  const assertive = items.filter((item) => item.tone === 'danger');

  return (
    <ToastContext.Provider value={api}>
      {children}
      <section
        aria-label={t('common.notifications')}
        className="pointer-events-none fixed inset-x-4 top-4 z-[70] flex flex-col gap-2 sm:inset-x-auto sm:end-4 sm:w-96"
      >
        <div role="alert" className="flex flex-col gap-2">
          {assertive.map((item) => (
            <ToastCard key={item.id} item={item} onDismiss={dismiss} />
          ))}
        </div>
        <div role="status" className="flex flex-col gap-2">
          {polite.map((item) => (
            <ToastCard key={item.id} item={item} onDismiss={dismiss} />
          ))}
        </div>
      </section>
    </ToastContext.Provider>
  );
}
