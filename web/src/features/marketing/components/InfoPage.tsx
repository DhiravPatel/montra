import type { ReactNode } from 'react';
import { PageHeader } from '@/shared/components/PageHeader';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';

interface InfoPageProps {
  title: string;
  intro: ReactNode;
  meta?: ReactNode;
  children: ReactNode;
}

/** Long-form public page with a readable measure. */
export function InfoPage({ title, intro, meta, children }: InfoPageProps) {
  useDocumentTitle(title);
  return (
    <article className="mx-auto max-w-3xl px-4 py-10 sm:px-6 lg:py-16">
      <PageHeader title={title} description={intro} />
      {meta ? <p className="-mt-3 mb-8 text-sm text-fg-muted">{meta}</p> : null}
      <div className="space-y-10">{children}</div>
    </article>
  );
}

export function InfoSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="space-y-3">
      <h2 className="text-xl font-semibold text-fg">{title}</h2>
      <div className="space-y-3 leading-relaxed text-fg-muted [&_strong]:text-fg">{children}</div>
    </section>
  );
}

export function InfoList({ items }: { items: readonly ReactNode[] }) {
  return (
    <ul className="list-disc space-y-2 ps-6 marker:text-fg-muted">
      {items.map((item, index) => (
        <li key={index}>{item}</li>
      ))}
    </ul>
  );
}
