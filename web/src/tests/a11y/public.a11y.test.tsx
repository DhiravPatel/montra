import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { expectNoAxeViolations } from '@/tests/axe';
import { findPageHeading, renderRoute } from '@/tests/render';

describe('axe: public pages', () => {
  it('landing', async () => {
    renderRoute('/');
    await findPageHeading(/Understand your money/);
    await expectNoAxeViolations();
  });

  it('sign in', async () => {
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await expectNoAxeViolations();
  });

  it('sign in with field errors', async () => {
    const user = userEvent.setup();
    renderRoute('/sign-in');
    await findPageHeading('Sign in');
    await user.click(screen.getByRole('button', { name: 'Sign in' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Email')).toHaveAttribute('aria-invalid', 'true');
    });
    await expectNoAxeViolations();
  });

  it('sign up', async () => {
    renderRoute('/sign-up');
    await findPageHeading('Create your account');
    await waitFor(() => {
      expect(screen.getByLabelText('Main currency')).toBeEnabled();
    });
    await expectNoAxeViolations();
  });

  it('sign up with field errors', async () => {
    const user = userEvent.setup();
    renderRoute('/sign-up');
    await findPageHeading('Create your account');
    await waitFor(() => {
      expect(screen.getByLabelText('Main currency')).toBeEnabled();
    });
    await user.click(screen.getByRole('button', { name: 'Create account' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Email')).toHaveAttribute('aria-invalid', 'true');
    });
    await expectNoAxeViolations();
  });
});
