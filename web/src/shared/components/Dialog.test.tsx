import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { describe, expect, it } from 'vitest';
import { I18nProvider } from '@/shared/i18n/I18nProvider';
import { Dialog } from './Dialog';

function Opener() {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button
        type="button"
        onClick={() => {
          setOpen(true);
        }}
      >
        New report
      </button>
      <Dialog open={open} onOpenChange={setOpen} title="New report">
        <button type="button">Inside</button>
      </Dialog>
    </>
  );
}

describe('Dialog', () => {
  it('returns focus to the control that opened it when it closes', async () => {
    const user = userEvent.setup();
    render(
      <I18nProvider language="en">
        <Opener />
      </I18nProvider>,
    );
    const opener = screen.getByRole('button', { name: 'New report' });
    await user.click(opener);
    const dialog = await screen.findByRole('dialog', { name: 'New report' });
    expect(dialog).toContainElement(document.activeElement as HTMLElement);

    await user.keyboard('{Escape}');
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    expect(opener).toHaveFocus();
  });
});
