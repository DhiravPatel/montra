import { useEffect, useEffectEvent } from 'react';

/** The key that moves focus to search (shown next to the field and in aria-keyshortcuts). */
export const SEARCH_SHORTCUT = '/';

/** Input types where a key press is not text entry. */
const NON_TEXT_INPUTS: ReadonlySet<string> = new Set([
  'button',
  'checkbox',
  'color',
  'file',
  'image',
  'radio',
  'range',
  'reset',
  'submit',
]);

/**
 * True while the person is typing somewhere (text fields, selects, rich
 * text) or working inside a dialog or menu, where "/" must keep its normal
 * meaning.
 */
export function isTypingTarget(target: EventTarget | null): boolean {
  if (!(target instanceof Element)) return false;
  if (target instanceof HTMLElement && target.isContentEditable) return true;
  if (target instanceof HTMLTextAreaElement || target instanceof HTMLSelectElement) return true;
  if (target instanceof HTMLInputElement) return !NON_TEXT_INPUTS.has(target.type);
  return (
    target.closest(
      '[contenteditable=""],[contenteditable="true"],[role="textbox"],[role="combobox"],' +
        '[role="searchbox"],[role="dialog"],[role="alertdialog"],[role="menu"],[role="listbox"]',
    ) !== null
  );
}

/** Whether a key press is the search shortcut (plain "/" outside any field). */
export function isSearchShortcut(event: KeyboardEvent): boolean {
  if (event.defaultPrevented || event.isComposing) return false;
  if (event.key !== SEARCH_SHORTCUT) return false;
  // Shift is allowed: some keyboard layouts need it to type "/".
  if (event.ctrlKey || event.metaKey || event.altKey) return false;
  return !isTypingTarget(event.target);
}

/** Whether an element is laid out (not inside a `display: none` part of the shell). */
export function isRendered(element: Element | null): element is HTMLElement {
  return element instanceof HTMLElement && element.getClientRects().length > 0;
}

/**
 * Runs `onShortcut` when "/" is pressed outside text fields. The handler
 * returns true when it handled the key, which stops "/" from being typed
 * and from reaching other handlers (the shell mounts more than one search
 * entry; only the visible one acts).
 */
export function useSearchShortcut(onShortcut: () => boolean, enabled = true): void {
  const handle = useEffectEvent((event: KeyboardEvent) => {
    if (!isSearchShortcut(event)) return;
    if (onShortcut()) event.preventDefault();
  });
  useEffect(() => {
    if (!enabled) return;
    const listener = (event: KeyboardEvent) => {
      handle(event);
    };
    document.addEventListener('keydown', listener);
    return () => {
      document.removeEventListener('keydown', listener);
    };
  }, [enabled]);
}
