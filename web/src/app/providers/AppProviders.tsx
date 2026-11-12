import { type QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { AnnouncerProvider } from '@/shared/accessibility/AnnouncerProvider';
import { AuthProvider } from '@/shared/auth/AuthProvider';
import { ToastProvider } from '@/shared/components/toast/ToastProvider';
import type { Language } from '@/shared/i18n/languages';
import { I18nProvider } from '@/shared/i18n/I18nProvider';
import { ThemeProvider } from '@/shared/theme/ThemeProvider';

interface AppProvidersProps {
  queryClient: QueryClient;
  children: ReactNode;
  language?: Language;
}

/** Global providers shared by the app and by tests. */
export function AppProviders({ queryClient, children, language }: AppProvidersProps) {
  return (
    <I18nProvider language={language}>
      <ThemeProvider>
        <AnnouncerProvider>
          <ToastProvider>
            <QueryClientProvider client={queryClient}>
              <AuthProvider>{children}</AuthProvider>
            </QueryClientProvider>
          </ToastProvider>
        </AnnouncerProvider>
      </ThemeProvider>
    </I18nProvider>
  );
}
