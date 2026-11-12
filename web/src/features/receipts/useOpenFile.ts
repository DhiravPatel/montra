import { useState } from 'react';
import { useToast } from '@/shared/components/toast/ToastContext';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { receiptsApi } from './api';

/**
 * Opens a stored file in a new tab through a fresh short-lived link (links
 * are never kept). Images open in the browser; PDFs download.
 */
export function useOpenFile() {
  const t = useT();
  const toast = useToast();
  const [opening, setOpening] = useState<string | null>(null);

  const open = async (fileId: string) => {
    if (opening) return;
    // Open the tab inside the click so pop-up blockers allow it; point it at the file once the link is issued.
    const tab = window.open('', '_blank');
    if (tab) tab.opener = null;
    setOpening(fileId);
    try {
      const access = await receiptsApi.fileAccess(fileId);
      if (tab) tab.location.href = access.url;
      else window.location.assign(access.url);
    } catch (error) {
      tab?.close();
      toast.show({
        tone: 'danger',
        title: t('receipts.preview.openFailed'),
        description: describeError(error, t),
      });
    } finally {
      setOpening(null);
    }
  };

  return { open, opening };
}
