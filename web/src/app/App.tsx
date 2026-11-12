import { RouterProvider, createBrowserRouter } from 'react-router';
import { AppErrorBoundary } from './error-boundaries/AppErrorBoundary';
import { AppProviders } from './providers/AppProviders';
import { createQueryClient } from './providers/queryClient';
import { routes } from './router/routes';

const queryClient = createQueryClient();
const router = createBrowserRouter(routes);

export function App() {
  return (
    <AppErrorBoundary>
      <AppProviders queryClient={queryClient}>
        <RouterProvider router={router} />
      </AppProviders>
    </AppErrorBoundary>
  );
}
