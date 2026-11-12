import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { useT } from '@/shared/i18n/I18nContext';

interface LoadMoreButtonProps {
  /** The API said there is another page (meta.next_cursor). */
  hasMore: boolean;
  /** The next page is loading. */
  loading: boolean;
  /** Loading the next page failed (the loaded items stay on screen). */
  failed?: boolean;
  onLoadMore: () => void;
  className?: string;
}

/**
 * "Load more" for cursor-paginated lists. The cursor stays in memory (never
 * in the URL); a failed page keeps what is shown and offers the button again.
 */
export function LoadMoreButton({
  hasMore,
  loading,
  failed = false,
  onLoadMore,
  className,
}: LoadMoreButtonProps) {
  const t = useT();
  if (!hasMore) return null;
  return (
    <div className={className ?? 'mt-4 space-y-3'}>
      {failed && !loading ? (
        <Alert tone="danger" live="assertive">
          {t('finance.list.loadMoreFailed')}
        </Alert>
      ) : null}
      <div className="flex justify-center">
        <Button
          variant="secondary"
          loading={loading}
          onClick={() => {
            if (!loading) onLoadMore();
          }}
        >
          {loading ? t('finance.list.loadingMore') : t('common.loadMore')}
        </Button>
      </div>
    </div>
  );
}
