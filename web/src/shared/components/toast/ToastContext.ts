import { createContext, useContext } from 'react';

export type ToastTone = 'success' | 'info' | 'warning' | 'danger';

export interface ToastOptions {
  tone?: ToastTone;
  title: string;
  description?: string;
}

export interface ToastApi {
  show: (options: ToastOptions) => void;
  dismiss: (id: number) => void;
}

export const ToastContext = createContext<ToastApi | null>(null);

export function useToast(): ToastApi {
  const api = useContext(ToastContext);
  if (!api) throw new Error('useToast must be used inside <ToastProvider>');
  return api;
}
