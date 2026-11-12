import { Fragment } from 'react';

/** Escapes RegExp syntax characters (valid in unicode mode). */
function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Marks where the search text appears in a value, ignoring case. Renders
 * text nodes only (user content is never parsed as HTML).
 */
export function Highlight({ text, query }: { text: string; query: string }) {
  if (!query) return text;
  const parts = text.split(new RegExp(`(${escapeRegExp(query)})`, 'giu'));
  if (parts.length === 1) return text;
  return parts.map((part, index) =>
    // split() with a capture group puts the matches at odd positions.
    index % 2 === 1 ? (
      <mark key={index} className="rounded-sm bg-accent-soft px-0.5 text-fg">
        {part}
      </mark>
    ) : (
      <Fragment key={index}>{part}</Fragment>
    ),
  );
}
