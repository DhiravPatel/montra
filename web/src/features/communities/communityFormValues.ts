import type { Community, CommunityInput, CommunityPatch, CommunityVisibility } from './types';

/** The community form's values, as typed (topics comma-separated). */
export interface CommunityFormValues {
  name: string;
  slug: string;
  description: string;
  rules: string;
  /** Comma-separated, as typed. */
  topics: string;
  visibility: CommunityVisibility;
}

export const emptyCommunityValues: CommunityFormValues = {
  name: '',
  slug: '',
  description: '',
  rules: '',
  topics: '',
  visibility: 'public',
};

export function communityValues(community: Community): CommunityFormValues {
  return {
    name: community.name,
    slug: community.slug,
    description: community.description ?? '',
    rules: community.rules ?? '',
    topics: community.topics.join(', '),
    visibility: community.visibility,
  };
}

/** Topics as the API stores them: trimmed, lowercase, without repeats. */
export function parseTopics(text: string): string[] {
  const topics: string[] = [];
  for (const part of text.split(',')) {
    const topic = part.trim().toLowerCase().replace(/\s+/gu, ' ');
    if (topic && !topics.includes(topic)) topics.push(topic);
  }
  return topics;
}

/** The create body: every field, plus the web address when one was chosen. */
export function toCommunityInput(values: CommunityFormValues): CommunityInput {
  return {
    name: values.name.trim(),
    description: values.description.trim(),
    rules: values.rules.trim(),
    topics: parseTopics(values.topics),
    visibility: values.visibility,
    ...(values.slug.trim() ? { slug: values.slug.trim().toLowerCase() } : {}),
  };
}

function sameTopics(a: readonly string[], b: readonly string[]): boolean {
  return a.length === b.length && a.every((topic, index) => topic === b[index]);
}

/**
 * The PATCH body for an edit: only what changed since `community`, with its
 * `version` (an empty description or rules clears it; the topics list is
 * replaced as a whole). Only `version` when nothing changed.
 */
export function toCommunityPatch(
  community: Community,
  values: CommunityFormValues,
): CommunityPatch {
  const patch: CommunityPatch = { version: community.version };
  const name = values.name.trim();
  if (name !== community.name) patch.name = name;
  const description = values.description.trim();
  if (description !== (community.description ?? '')) patch.description = description;
  const rules = values.rules.trim();
  if (rules !== (community.rules ?? '')) patch.rules = rules;
  const topics = parseTopics(values.topics);
  if (!sameTopics(topics, community.topics)) patch.topics = topics;
  if (values.visibility !== community.visibility) patch.visibility = values.visibility;
  return patch;
}

/** Whether a patch changes anything beyond its `version`. */
export function hasPatchChanges(patch: CommunityPatch): boolean {
  return Object.keys(patch).some((key) => key !== 'version');
}
