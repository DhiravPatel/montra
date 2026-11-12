import { transactionSourceLabel, transactionStatusLabel } from '@/shared/finance/labels';
import type { TransactionSource, TransactionStatus } from '@/shared/finance/types';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type { CandidateItem, MatchItem, MatchKind } from './types';

export const MATCH_KINDS = [
  'statement_to_ledger',
  'pending_to_posted',
  'manual_to_imported',
] as const satisfies readonly MatchKind[];

type MissingKinds = Exclude<MatchKind, (typeof MATCH_KINDS)[number]>;
/** Compile-time check: every contract match kind is listed above. */
export const matchKindsAreListed: [MissingKinds] extends [never] ? true : MissingKinds = true;

export const kindTitle: Readonly<Record<MatchKind, MessageKey>> = {
  statement_to_ledger: 'reconciliation.kind.statement_to_ledger',
  pending_to_posted: 'reconciliation.kind.pending_to_posted',
  manual_to_imported: 'reconciliation.kind.manual_to_imported',
};

/** What confirming a suggestion of this kind does (shown before the user confirms). */
export const kindEffect: Readonly<Record<MatchKind, MessageKey>> = {
  statement_to_ledger: 'reconciliation.effect.statement_to_ledger',
  pending_to_posted: 'reconciliation.effect.pending_to_posted',
  manual_to_imported: 'reconciliation.effect.manual_to_imported',
};

export function isMatchKind(value: string): value is MatchKind {
  return (MATCH_KINDS as readonly string[]).includes(value);
}

/** A match's kind as a label (kinds newer than this client are shown as sent). */
export function matchKindLabel(kind: string, t: Translate): string {
  return isMatchKind(kind) ? t(kindTitle[kind]) : kind;
}

const effectLabels: Readonly<Record<MatchItem['effect'], MessageKey>> = {
  none: 'reconciliation.itemEffect.none',
  voided: 'reconciliation.itemEffect.voided',
  row_skipped: 'reconciliation.itemEffect.row_skipped',
};

export function effectLabel(effect: MatchItem['effect'], t: Translate): string {
  return t(effectLabels[effect]);
}

const rowStatusLabels: Readonly<Record<string, MessageKey>> = {
  ready: 'imports.rowStatus.ready',
  duplicate: 'imports.rowStatus.duplicate',
  skipped: 'imports.rowStatus.skipped',
  failed: 'imports.rowStatus.failed',
  invalid: 'imports.rowStatus.invalid',
  imported: 'imports.rowStatus.imported',
  parsed: 'imports.rowStatus.parsed',
};

function isTransactionStatus(value: string): value is TransactionStatus {
  return value in transactionStatusLabel;
}

function isTransactionSource(value: string): value is TransactionSource {
  return value !== '' && value in transactionSourceLabel;
}

/** A statement row's import status, as a label. */
export function rowStatusLabel(status: string, t: Translate): string {
  const key = rowStatusLabels[status];
  return key ? t(key) : status;
}

/**
 * A candidate or match item's state: a statement row's status, or a
 * transaction's status and how it was recorded ("Posted · Entered by you").
 */
export function itemStatusLabel(
  item: Pick<CandidateItem | MatchItem, 'side' | 'record_status' | 'source'>,
  t: Translate,
): string {
  if (item.side === 'statement') return rowStatusLabel(item.record_status, t);
  const status = item.record_status;
  const source = item.source ?? '';
  const parts = [
    isTransactionStatus(status) ? t(transactionStatusLabel[status]) : status,
    isTransactionSource(source) ? t(transactionSourceLabel[source]) : source,
  ].filter(Boolean);
  return parts.join(' · ');
}
