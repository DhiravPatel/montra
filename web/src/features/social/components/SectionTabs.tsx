import { type KeyboardEvent, type ReactNode, type RefObject, useRef } from 'react';
import { Icon, type IconName } from '@/shared/components/Icon';
import { useI18n } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';

export interface SectionTab<T extends string> {
  id: T;
  label: string;
  icon: IconName;
  /** A count after the label (e.g. requests waiting) and how it is read aloud. */
  count?: { value: number; spoken: string } | null;
}

const tabClasses =
  'inline-flex min-h-11 cursor-pointer items-center gap-2 border-b-4 px-1 text-sm whitespace-nowrap ' +
  'hover:text-fg aria-selected:border-accent aria-selected:font-semibold aria-selected:text-fg';

const tabId = (prefix: string, id: string) => `${prefix}-tab-${id}`;
const panelId = (prefix: string, id: string) => `${prefix}-panel-${id}`;

/**
 * Tabs within one page (WAI-ARIA tabs pattern): arrow keys move between
 * tabs and select them, Home and End jump to the ends, and the selected tab
 * is marked by a bar and bold text, not color alone.
 */
export function SectionTabs<T extends string>({
  label,
  idPrefix,
  tabs,
  selected,
  onSelect,
}: {
  label: string;
  idPrefix: string;
  tabs: readonly SectionTab<T>[];
  selected: T;
  onSelect: (id: T) => void;
}) {
  const { dir } = useI18n();
  const refs = useRef(new Map<T, HTMLButtonElement>());

  const onKeyDown = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    const forward = dir === 'rtl' ? 'ArrowLeft' : 'ArrowRight';
    const back = dir === 'rtl' ? 'ArrowRight' : 'ArrowLeft';
    let next: number;
    if (event.key === forward) next = (index + 1) % tabs.length;
    else if (event.key === back) next = (index - 1 + tabs.length) % tabs.length;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = tabs.length - 1;
    else return;
    event.preventDefault();
    const tab = tabs[next];
    if (!tab) return;
    onSelect(tab.id);
    refs.current.get(tab.id)?.focus();
  };

  return (
    <div className="mb-6 overflow-x-auto border-b border-line">
      <div role="tablist" aria-label={label} className="flex gap-6">
        {tabs.map((tab, index) => {
          const active = tab.id === selected;
          return (
            <button
              key={tab.id}
              ref={(element) => {
                if (element) refs.current.set(tab.id, element);
                else refs.current.delete(tab.id);
              }}
              type="button"
              role="tab"
              id={tabId(idPrefix, tab.id)}
              aria-selected={active}
              aria-controls={panelId(idPrefix, tab.id)}
              tabIndex={active ? 0 : -1}
              className={cx(tabClasses, active ? 'text-fg' : 'border-transparent text-fg-muted')}
              onClick={() => {
                onSelect(tab.id);
              }}
              onKeyDown={(event) => {
                onKeyDown(event, index);
              }}
            >
              <Icon name={tab.icon} className="size-4" />
              {tab.label}
              {tab.count && tab.count.value > 0 ? (
                <span className="inline-flex min-w-6 items-center justify-center rounded-full border border-line-strong px-1.5 text-xs font-semibold text-fg">
                  <span aria-hidden="true">{tab.count.value}</span>
                  <span className="sr-only">, {tab.count.spoken}</span>
                </span>
              ) : null}
            </button>
          );
        })}
      </div>
    </div>
  );
}

/**
 * Every tab's panel exists (so aria-controls always points somewhere); only
 * the selected one renders its content.
 */
export function SectionTabPanels<T extends string>({
  idPrefix,
  tabs,
  selected,
  panelRef,
  children,
}: {
  idPrefix: string;
  tabs: readonly SectionTab<T>[];
  selected: T;
  /** The selected panel (focus target when the focused row disappears). */
  panelRef?: RefObject<HTMLDivElement | null>;
  children: ReactNode;
}) {
  return (
    <>
      {tabs.map((tab) => {
        const active = tab.id === selected;
        return (
          <div
            key={tab.id}
            ref={active ? panelRef : undefined}
            role="tabpanel"
            id={panelId(idPrefix, tab.id)}
            aria-labelledby={tabId(idPrefix, tab.id)}
            hidden={!active}
            // Focusable from script only (focus fallback); panels always hold controls.
            tabIndex={-1}
            className="space-y-6 rounded-xl focus-visible:outline-offset-4"
          >
            {active ? children : null}
          </div>
        );
      })}
    </>
  );
}
