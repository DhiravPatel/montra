import { Fragment, type ReactNode, useMemo } from 'react';
import { Icon } from '@/shared/components/Icon';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { excerpt, paragraphs, safeHref, tokenizeUserText } from '../text/userText';

const linkClasses =
  'font-medium break-all text-accent underline decoration-1 underline-offset-4 hover:text-accent-hover hover:decoration-2';

/**
 * A link written by a community member. Opens in a new tab without the
 * opener or referrer, and `nofollow` tells search engines not to vouch for
 * it. Only http(s) addresses reach this component.
 */
export function SafeLink({ href, children }: { href: string; children: ReactNode }) {
  const t = useT();
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer nofollow"
      referrerPolicy="no-referrer"
      className={linkClasses}
    >
      {children}
      <Icon name="external-link" className="ms-1 inline size-3.5 align-[-2px]" />
      <span className="sr-only"> {t('common.opensInNewTab')}</span>
    </a>
  );
}

/** A resource link from the API, shown only when it is an http(s) address. */
export function ResourceLink({ url }: { url: string | undefined }) {
  const href = url ? safeHref(url) : null;
  if (!url || !href) return null;
  return (
    <p className="text-sm">
      <SafeLink href={href}>{url}</SafeLink>
    </p>
  );
}

function Tokens({ text, links }: { text: string; links: boolean }) {
  const tokens = useMemo(() => tokenizeUserText(text, { links }), [text, links]);
  return (
    <>
      {tokens.map((token, index) => {
        if (token.kind === 'link') {
          return (
            <SafeLink key={index} href={token.href}>
              {token.text}
            </SafeLink>
          );
        }
        if (token.kind === 'mention') {
          return (
            <span key={index} className="font-semibold text-fg">
              {token.text}
            </span>
          );
        }
        return <Fragment key={index}>{token.text}</Fragment>;
      })}
    </>
  );
}

/**
 * Text written by people, shown as text: paragraphs and line breaks are
 * kept, http(s) addresses become safe links (unless `links` is false) and
 * @mentions are marked. Never HTML.
 */
export function UserText({
  text,
  links = true,
  className,
}: {
  text: string;
  links?: boolean;
  className?: string;
}) {
  const parts = paragraphs(text);
  if (parts.length === 0) return null;
  return (
    <div className={cx('space-y-3 break-words text-fg', className)}>
      {parts.map((part, index) => (
        <p key={index} className="whitespace-pre-line">
          <Tokens text={part} links={links} />
        </p>
      ))}
    </div>
  );
}

/** The start of a text for lists and previews: plain text, no links. */
export function UserTextExcerpt({
  text,
  maxChars = 280,
  className,
}: {
  text: string;
  maxChars?: number;
  className?: string;
}) {
  const short = excerpt(text.replace(/\s+/gu, ' '), maxChars);
  if (!short) return null;
  return (
    <p className={cx('break-words text-fg', className)}>
      <Tokens text={short} links={false} />
    </p>
  );
}
