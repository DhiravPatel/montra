import { cx } from '@/shared/utils/cx';

/** Someone's community identity exactly as the API returns it: display name and @username. */
export function PersonName({
  name,
  username,
  className,
}: {
  name: string;
  username?: string | undefined;
  className?: string;
}) {
  return (
    <span className={cx('min-w-0 break-words', className)}>
      <span className="font-medium text-fg">{name}</span>
      {username ? (
        <span className="ms-1.5 text-sm break-all text-fg-muted">@{username}</span>
      ) : null}
    </span>
  );
}
