import { useEffect, useState } from 'react';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { useT } from '@/shared/i18n/I18nContext';
import { copyText } from '@/shared/utils/clipboard';
import { Button } from './Button';
import { Icon } from './Icon';
import { useToast } from './toast/ToastContext';

interface CopyButtonProps {
  /** Text placed on the clipboard (never logged). */
  value: string;
  label: string;
  size?: 'md' | 'sm';
}

export function CopyButton({ value, label, size = 'sm' }: CopyButtonProps) {
  const t = useT();
  const announce = useAnnounce();
  const toast = useToast();
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!copied) return;
    const timer = window.setTimeout(() => {
      setCopied(false);
    }, 2000);
    return () => {
      window.clearTimeout(timer);
    };
  }, [copied]);

  return (
    <Button
      variant="secondary"
      size={size}
      onClick={() => {
        void copyText(value).then((ok) => {
          if (ok) {
            setCopied(true);
            announce(t('common.copied'));
          } else {
            toast.show({ tone: 'warning', title: t('common.copyFailed') });
          }
        });
      }}
    >
      <Icon name={copied ? 'check' : 'copy'} className="size-4" />
      {copied ? t('common.copied') : label}
    </Button>
  );
}
