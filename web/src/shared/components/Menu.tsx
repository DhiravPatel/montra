import * as DropdownMenu from '@radix-ui/react-dropdown-menu';
import type { ReactNode } from 'react';
import { cx } from '@/shared/utils/cx';
import { Icon, type IconName } from './Icon';

/** Accessible dropdown menu (Radix): arrow-key navigation, typeahead, Escape to close. */
export const Menu = DropdownMenu.Root;
export const MenuTrigger = DropdownMenu.Trigger;
export const MenuRadioGroup = DropdownMenu.RadioGroup;

const itemClasses =
  'flex min-h-10 cursor-pointer select-none items-center gap-2 rounded-md px-3 py-2 text-sm text-fg outline-none ' +
  'data-[highlighted]:bg-surface-muted data-[disabled]:cursor-not-allowed data-[disabled]:opacity-60';

export function MenuContent({
  children,
  align = 'end',
  label,
}: {
  children: ReactNode;
  align?: 'start' | 'end';
  label?: string;
}) {
  return (
    <DropdownMenu.Portal>
      <DropdownMenu.Content
        align={align}
        sideOffset={6}
        collisionPadding={8}
        aria-label={label}
        className="z-50 min-w-56 rounded-lg border border-line bg-surface p-1 shadow-overlay"
      >
        {children}
      </DropdownMenu.Content>
    </DropdownMenu.Portal>
  );
}

interface MenuItemProps {
  children: ReactNode;
  icon?: IconName;
  onSelect?: (event: Event) => void;
  disabled?: boolean;
  asChild?: boolean;
  tone?: 'default' | 'danger';
}

export function MenuItem({
  children,
  icon,
  onSelect,
  disabled,
  asChild,
  tone = 'default',
}: MenuItemProps) {
  return (
    <DropdownMenu.Item
      className={cx(itemClasses, tone === 'danger' && 'text-danger')}
      onSelect={onSelect}
      disabled={disabled}
      asChild={asChild}
    >
      {asChild ? (
        children
      ) : (
        <span className="flex items-center gap-2">
          {icon ? <Icon name={icon} className="size-4" /> : null}
          {children}
        </span>
      )}
    </DropdownMenu.Item>
  );
}

export function MenuRadioItem({
  value,
  children,
  icon,
}: {
  value: string;
  children: ReactNode;
  icon?: IconName;
}) {
  return (
    <DropdownMenu.RadioItem value={value} className={cx(itemClasses, 'justify-between')}>
      <span className="flex items-center gap-2">
        {icon ? <Icon name={icon} className="size-4" /> : null}
        {children}
      </span>
      <DropdownMenu.ItemIndicator>
        <Icon name="check" className="size-4 text-accent" />
      </DropdownMenu.ItemIndicator>
    </DropdownMenu.RadioItem>
  );
}

export function MenuLabel({ children }: { children: ReactNode }) {
  return (
    <DropdownMenu.Label className="px-3 pb-1 pt-2 text-xs font-semibold uppercase tracking-wide text-fg-muted">
      {children}
    </DropdownMenu.Label>
  );
}

export function MenuSeparator() {
  return <DropdownMenu.Separator className="my-1 h-px bg-line" />;
}
