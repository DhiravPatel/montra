import { NavLink } from 'react-router';
import { Icon, type IconName } from './Icon';

export interface SubNavItem {
  to: string;
  label: string;
  icon: IconName;
  /** Match the path exactly (for a section's index tab). */
  end?: boolean;
}

const tabClasses =
  'inline-flex min-h-11 items-center gap-2 border-b-4 border-transparent px-1 text-sm font-medium whitespace-nowrap text-fg-muted ' +
  'hover:text-fg aria-[current=page]:border-accent aria-[current=page]:font-semibold aria-[current=page]:text-fg';

/**
 * Tabs between the pages of one area (e.g. categories, rules, tags and
 * merchants). The current page is marked with aria-current, a bar and bold
 * text. Scrolls sideways on narrow screens instead of wrapping.
 */
export function SubNav({ label, items }: { label: string; items: readonly SubNavItem[] }) {
  return (
    <nav aria-label={label} className="mb-6 overflow-x-auto border-b border-line">
      <ul className="flex gap-6">
        {items.map((item) => (
          <li key={item.to}>
            <NavLink to={item.to} end={item.end} className={tabClasses}>
              <Icon name={item.icon} className="size-4" />
              {item.label}
            </NavLink>
          </li>
        ))}
      </ul>
    </nav>
  );
}
