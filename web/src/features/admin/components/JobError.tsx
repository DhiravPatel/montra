import { useT } from '@/shared/i18n/I18nContext';
import { jobErrorText } from '../jobLabels';

/** A job's failure code, with words for the codes this client knows (never the message). */
export function JobError({ code }: { code: string | undefined }) {
  const t = useT();
  if (!code) return <span className="text-fg-muted">{t('adminJobs.none')}</span>;
  const words = jobErrorText(code, t);
  return (
    <span className="block min-w-0">
      <code className="break-all">{code}</code>
      {words ? <span className="block text-fg-muted">{words}</span> : null}
    </span>
  );
}
