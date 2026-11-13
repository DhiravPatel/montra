import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { previewHandlers, UPLOAD_FILE } from '@/tests/receiptsFixtures';
import { findPageHeading, renderRoute } from '@/tests/render';

/** The sidebar's trigger (name and email shown) and the small-screen header's (compact). */
function triggers() {
  const [full, compact] = screen.getAllByRole('button', { name: /^Account menu/ });
  return { full: full!, compact: compact! };
}

describe('Account menu avatar', () => {
  it('shows the profile photo in both triggers, keeping their accessible names', async () => {
    const accessed: string[] = [];
    server.use(
      http.get(`${API}/files/:fileId/access`, ({ params }) => {
        accessed.push(String(params.fileId));
        return undefined;
      }),
      ...previewHandlers(),
    );
    renderRoute('/account', {
      user: makeUser({ onboarding_completed: true, avatar_file_id: UPLOAD_FILE }),
    });
    await findPageHeading('Your account');
    const { full, compact } = triggers();
    await waitFor(() => {
      expect(full.querySelector('img')).not.toBeNull();
    });
    for (const trigger of [full, compact]) {
      const image = trigger.querySelector('img')!;
      // Loaded through the signed link into a data: URL (allowed by the CSP).
      expect(image.getAttribute('src')).toMatch(/^data:image\/png;base64,/);
      // Decorative: no alternative text, so the visible text still is the name.
      expect(image).toHaveAttribute('alt', '');
      expect(within(trigger).queryByRole('img')).not.toBeInTheDocument();
      expect(trigger.querySelector('[data-initials]')).toBeNull();
    }
    expect(full).toHaveAccessibleName(/^Account menu:\s*Asha Rao\s*asha@example\.com$/);
    expect(compact).toHaveAccessibleName('Account menu');
    // One download for both triggers (the profile screen shares it too).
    expect(accessed).toEqual([UPLOAD_FILE]);
  });

  it('draws the initials with CSS when there is no photo, without loading any file', async () => {
    const accessed: string[] = [];
    server.use(
      http.get(`${API}/files/:fileId/access`, ({ params }) => {
        accessed.push(String(params.fileId));
        return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
      }),
    );
    renderRoute('/account', { user: makeUser({ onboarding_completed: true }) });
    await findPageHeading('Your account');
    const { full, compact } = triggers();
    for (const trigger of [full, compact]) {
      const initials = trigger.querySelector('[data-initials]')!;
      expect(initials).toHaveAttribute('data-initials', 'AR');
      expect(initials).toHaveAttribute('aria-hidden', 'true');
      // Drawn by CSS (::before), so the initials are not text content.
      expect(initials.textContent).toBe('');
      expect(trigger.querySelector('img')).toBeNull();
    }
    expect(full).toHaveAccessibleName(/^Account menu:\s*Asha Rao\s*asha@example\.com$/);
    expect(compact).toHaveAccessibleName('Account menu');
    expect(accessed).toEqual([]);
  });

  it('falls back to the initials when the photo cannot be loaded', async () => {
    let refused = 0;
    server.use(
      http.get(`${API}/files/:fileId/access`, () => {
        refused += 1;
        return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/account', {
      user: makeUser({ onboarding_completed: true, avatar_file_id: UPLOAD_FILE }),
    });
    await findPageHeading('Your account');
    await waitFor(() => {
      expect(refused).toBeGreaterThan(0);
    });
    const { full } = triggers();
    expect(full.querySelector('[data-initials]')).toHaveAttribute('data-initials', 'AR');
    // Still a working menu.
    await user.click(full);
    expect(await screen.findByRole('menu', { name: /^Account menu/ })).toBeInTheDocument();
    expect(full.querySelector('img')).toBeNull();
    expect(full.querySelector('[data-initials]')).toHaveAttribute('data-initials', 'AR');
  });
});
