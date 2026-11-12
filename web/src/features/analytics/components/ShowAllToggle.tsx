import { Button } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';

/** Expands a top-N list to every row the API returned (and back). */
export function ShowAllToggle({
  expanded,
  onToggle,
  showAllLabel,
  showFewerLabel,
}: {
  expanded: boolean;
  onToggle: () => void;
  showAllLabel: string;
  showFewerLabel: string;
}) {
  return (
    <Button variant="ghost" size="sm" aria-expanded={expanded} onClick={onToggle}>
      <Icon name="chevron-down" className={expanded ? 'size-4 rotate-180' : 'size-4'} />
      {expanded ? showFewerLabel : showAllLabel}
    </Button>
  );
}
