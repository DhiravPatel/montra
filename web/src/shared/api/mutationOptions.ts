/**
 * Spread into useMutation() options when variables or results contain
 * secrets (passwords, codes, MFA secrets, recovery codes): the mutation is
 * dropped from the in-memory cache as soon as its component unmounts, and
 * is never retried automatically.
 */
export const sensitiveMutation = { gcTime: 0, retry: false } as const;
