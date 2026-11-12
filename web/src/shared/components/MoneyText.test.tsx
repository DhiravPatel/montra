import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { I18nProvider } from '@/shared/i18n/I18nProvider';
import { MoneyText } from './MoneyText';

function renderMoney(ui: React.ReactNode) {
  return render(<I18nProvider language="en">{ui}</I18nProvider>);
}

describe('MoneyText', () => {
  it('renders the exact amount in a data element', () => {
    renderMoney(<MoneyText money={{ amount: '1234.50', currency: 'USD' }} />);
    const value = screen.getByText(/1,234\.50/);
    expect(value.tagName).toBe('DATA');
    expect(value).toHaveAttribute('value', '1234.50');
  });

  it('shows explicit signs, not only color, when emphasising direction', () => {
    renderMoney(
      <>
        <MoneyText money={{ amount: '-25.00', currency: 'USD' }} emphasis="signed" />
        <MoneyText money={{ amount: '25.00', currency: 'USD' }} emphasis="signed" />
        <MoneyText money={{ amount: '0.00', currency: 'USD' }} emphasis="signed" />
      </>,
    );
    expect(screen.getByText('-$25.00')).toHaveClass('text-danger');
    expect(screen.getByText('+$25.00')).toHaveClass('text-success');
    const zero = screen.getByText('$0.00');
    expect(zero).not.toHaveClass('text-danger');
    expect(zero).not.toHaveClass('text-success');
  });

  it('never hides a value it cannot format', () => {
    renderMoney(<MoneyText money={{ amount: 'not-a-number', currency: 'USD' }} />);
    expect(screen.getByText('not-a-number USD')).toBeInTheDocument();
  });
});
