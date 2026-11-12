import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import type { components } from '@/shared/api/schema';

type Schemas = components['schemas'];
export type RegisterRequest = Schemas['RegisterBody'];
export type MfaVerifyRequest = Schemas['MfaVerifyBody'];

/** Public authentication endpoints (no session required). */
export const authApi = {
  register: (body: RegisterRequest) => apiData(api.POST('/auth/register', { body })),
  login: (body: { email: string; password: string }) => apiData(api.POST('/auth/login', { body })),
  verifyMfa: (body: MfaVerifyRequest) => apiData(api.POST('/auth/mfa/verify', { body })),
  verifyEmail: (token: string) => apiData(api.POST('/auth/email/verify', { body: { token } })),
  resendVerification: (email: string) =>
    apiData(api.POST('/auth/email/resend', { body: { email } })),
  requestPasswordReset: (email: string) =>
    apiData(api.POST('/auth/password/forgot', { body: { email } })),
  resetPassword: (token: string, newPassword: string) =>
    apiData(api.POST('/auth/password/reset', { body: { token, new_password: newPassword } })),
};
