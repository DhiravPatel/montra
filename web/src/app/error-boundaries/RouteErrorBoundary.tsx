import { isRouteErrorResponse, useRouteError } from 'react-router';
import { ButtonLink } from '@/shared/components/Button';
import { ErrorState } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';

/** Rendered by the router when a route throws while rendering or loading. */
export function RouteErrorBoundary() {
  const error = useRouteError();
  const t = useT();
  const notFound = isRouteErrorResponse(error) && error.status === 404;
  useDocumentTitle(notFound ? t('notFound.title') : t('states.error.title'));

  return (
    <main id="main" tabIndex={-1} className="mx-auto max-w-xl px-4 py-16 outline-none">
      <h1 className="sr-only">{notFound ? t('notFound.title') : t('states.error.title')}</h1>
      <ErrorState
        titleAs="p"
        title={notFound ? t('notFound.title') : t('states.error.title')}
        description={notFound ? t('notFound.description') : t('states.routeError.description')}
        onRetry={
          notFound
            ? undefined
            : () => {
                window.location.reload();
              }
        }
      />
      <div className="mt-2 flex justify-center">
        <ButtonLink variant="ghost" to={paths.landing}>
          {t('notFound.home')}
        </ButtonLink>
      </div>
    </main>
  );
}
