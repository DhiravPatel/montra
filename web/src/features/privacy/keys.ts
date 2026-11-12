/** Query keys for privacy settings and fair-use limits (not finance data). */
export const privacyKeys = {
  all: ['privacy'] as const,
  consents: () => ['privacy', 'consents'] as const,
  consentHistory: () => ['privacy', 'consents', 'history'] as const,
  legal: () => ['privacy', 'legal'] as const,
  exports: () => ['privacy', 'exports'] as const,
  exportJob: (id: string) => ['privacy', 'export', id] as const,
  deletion: () => ['privacy', 'deletion'] as const,
  limits: () => ['privacy', 'limits'] as const,
};
