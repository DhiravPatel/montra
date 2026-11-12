import type { ContentStatus, ModerationActionKind } from './types';

/** Who or what a moderation action applies to. */
export interface ActionTarget {
  type: 'post' | 'comment' | 'member';
  /** Post or comment ID; the user ID for members. */
  id: string;
  /** Shown in the dialog: a post title, a comment excerpt or a member's name. */
  summary: string;
  /** The post to refresh afterwards (for posts and comments). */
  postId?: string;
  /** Current state, when known, to offer only the actions that apply. */
  state?: {
    status?: ContentStatus;
    pinned?: boolean;
    locked?: boolean;
    banned?: boolean;
    /** The moderator's own content: only pinning and locking apply. */
    own?: boolean;
  };
  /** The report this action resolves. */
  reportId?: string;
}

/** The actions that apply to a target in its current state. */
export function actionsFor(target: ActionTarget): ModerationActionKind[] {
  const state = target.state ?? {};
  const report: ModerationActionKind[] = target.reportId ? ['dismiss_report', 'escalate'] : [];
  if (target.type === 'member') {
    return state.banned ? ['unban'] : ['warn', 'restrict', 'ban'];
  }
  const status = state.status;
  const known = status !== undefined;
  const content: ModerationActionKind[] = [];
  if (!state.own) {
    if (!known || status === 'published') content.push('hide');
    if (!known || status === 'published' || status === 'hidden') content.push('remove');
    if (!known || status === 'hidden' || status === 'removed') content.push('restore');
  }
  if (target.type === 'post') {
    if (state.pinned !== undefined) content.push(state.pinned ? 'unpin' : 'pin');
    content.push(state.locked ? 'unlock' : 'lock');
  }
  if (!state.own) content.push('warn');
  return [...content, ...report];
}
