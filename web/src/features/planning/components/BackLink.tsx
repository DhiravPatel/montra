import { Icon } from '@/shared/components/Icon';
import { TextLink } from '@/shared/components/TextLink';

/** "← Bills" link above a sub-page's heading. */
export function BackLink({ to, label }: { to: string; label: string }) {
  return (
    <p className="mb-2">
      <TextLink to={to}>
        <Icon name="arrow-left" className="me-1 inline size-4" />
        {label}
      </TextLink>
    </p>
  );
}
