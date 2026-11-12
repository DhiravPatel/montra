import { afterEach, describe, expect, it } from 'vitest';
import { isSearchShortcut } from './shortcut';

/** Dispatches a key press on `target` and reports whether it counts as the search shortcut. */
function press(target: Element, init: KeyboardEventInit = {}): boolean {
  let result = false;
  const listener = (event: KeyboardEvent) => {
    result = isSearchShortcut(event);
  };
  document.addEventListener('keydown', listener);
  target.dispatchEvent(
    new KeyboardEvent('keydown', { key: '/', bubbles: true, cancelable: true, ...init }),
  );
  document.removeEventListener('keydown', listener);
  return result;
}

function add<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  setup: (element: HTMLElementTagNameMap[K]) => void = () => undefined,
) {
  const element = document.createElement(tag);
  setup(element);
  document.body.append(element);
  return element;
}

describe('search shortcut', () => {
  afterEach(() => {
    document.body.replaceChildren();
  });

  it('is a plain "/" outside fields (Shift allowed for keyboard layouts that need it)', () => {
    expect(press(document.body)).toBe(true);
    expect(press(add('button'))).toBe(true);
    expect(press(document.body, { shiftKey: true })).toBe(true);
    expect(press(document.body, { key: '?' })).toBe(false);
    expect(press(document.body, { ctrlKey: true })).toBe(false);
    expect(press(document.body, { metaKey: true })).toBe(false);
    expect(press(document.body, { altKey: true })).toBe(false);
  });

  it('never fires while typing or inside a dialog or menu', () => {
    expect(press(add('input'))).toBe(false);
    expect(
      press(
        add('input', (input) => {
          input.type = 'search';
        }),
      ),
    ).toBe(false);
    expect(press(add('textarea'))).toBe(false);
    expect(press(add('select'))).toBe(false);
    expect(
      press(
        add('div', (div) => {
          div.setAttribute('contenteditable', 'true');
        }),
      ),
    ).toBe(false);
    const dialog = add('div', (div) => {
      div.setAttribute('role', 'dialog');
    });
    const inside = document.createElement('button');
    dialog.append(inside);
    expect(press(inside)).toBe(false);
    // Buttons that look like inputs are not text entry.
    expect(
      press(
        add('input', (input) => {
          input.type = 'checkbox';
        }),
      ),
    ).toBe(true);
  });

  it('yields to a handler that already took the key', () => {
    const target = add('button');
    target.addEventListener('keydown', (event) => {
      event.preventDefault();
    });
    expect(press(target)).toBe(false);
  });
});
