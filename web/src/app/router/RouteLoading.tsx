import { LoadingState } from '@/shared/components/states';

/** Shown while a code-split route loads on first visit. */
export function RouteLoading() {
  return (
    <div className="flex min-h-dvh items-center justify-center">
      <LoadingState />
    </div>
  );
}
