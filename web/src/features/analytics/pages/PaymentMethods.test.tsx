import { screen, within } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { createTranslator } from '@/shared/i18n/translate';
import { makePaymentMethodReport, NOVEMBER, PAYMENT_CARD } from '@/tests/analyticsFixtures';
import { expectNoAxeViolations } from '@/tests/axe';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { renderRoute } from '@/tests/render';
import { drillDownLink, paymentMethodName } from '../paymentMethods';

const returning = () => makeUser({ onboarding_completed: true });

function serve(body: unknown, record: URL[] = []) {
  return http.get(`${API}/analytics/payment-methods`, ({ request }) => {
    record.push(new URL(request.url));
    return HttpResponse.json(envelope(body));
  });
}

describe('payment method names', () => {
  const [card, unspecified, wallet] = makePaymentMethodReport().payment_methods;

  it('names the bucket without a payment method by its key, in English and Hindi', () => {
    expect(paymentMethodName(unspecified!, createTranslator('en', 'en'))).toBe('No payment method');
    expect(paymentMethodName(unspecified!, createTranslator('hi', 'hi-IN'))).toBe(
      'भुगतान का तरीका नहीं चुना गया',
    );
  });

  it('adds the last digits and the archived state', () => {
    const t = createTranslator('en', 'en');
    expect(paymentMethodName(card!, t)).toBe('HDFC Card ending 4321');
    expect(paymentMethodName(wallet!, t)).toBe('Travel wallet (archived)');
  });

  it('follows the API drill-down path only when it is a transactions link', () => {
    expect(drillDownLink(unspecified!, () => 'fallback')).toBe(
      '/transactions?from=2026-11-01&to=2026-11-30&currency=INR&payment_method_id=none',
    );
    expect(drillDownLink(wallet!, () => 'fallback')).toBe('fallback');
  });
});

describe('AnalyticsPage — payment methods', () => {
  it('ranks payment methods per currency with shares, and drills down to their transactions', async () => {
    const requests: URL[] = [];
    server.use(serve(makePaymentMethodReport(), requests));
    renderRoute('/analytics?view=payment-methods&range=this_month', { user: returning() });
    const card = await screen.findByRole('region', { name: 'Payment methods' });
    expect(
      screen.getByRole('link', { name: 'Payment methods', current: 'page' }),
    ).toBeInTheDocument();

    const inr = within(card).getByRole('region', { name: 'In INR' });
    expect(
      within(inr).getByRole('figure', { name: 'Spending by payment method in INR' }),
    ).toHaveAccessibleDescription(
      'You paid the most with HDFC Card ending 4321: ₹300.00 (59.9% of spending) across 1 transaction.',
    );
    expect(within(inr).getByRole('link', { name: 'HDFC Card ending 4321' })).toHaveAttribute(
      'href',
      `/transactions?from=2026-11-01&to=2026-11-30&currency=INR&payment_method_id=${PAYMENT_CARD}`,
    );
    expect(within(inr).getByRole('link', { name: 'No payment method' })).toHaveAttribute(
      'href',
      '/transactions?from=2026-11-01&to=2026-11-30&currency=INR&payment_method_id=none',
    );
    expect(within(inr).queryByText('Unspecified')).not.toBeInTheDocument();

    // USD is its own ranking: nothing is added across currencies.
    const usd = within(card).getByRole('region', { name: 'In USD' });
    expect(within(usd).getByRole('link', { name: 'Travel wallet (archived)' })).toHaveAttribute(
      'href',
      `/transactions?from=${NOVEMBER.from}&to=${NOVEMBER.to}&status=posted&payment_method_id=eeeeeeee-1111-4111-8111-000000000002&type=expense%2Cgroup_expense%2Crefund%2Creimbursement`,
    );
    expect(within(inr).queryByText(/42\.10/)).not.toBeInTheDocument();
    expect(card).toHaveTextContent('“No payment method” is spending recorded without one.');
    expect(requests[0]?.searchParams.get('range')).toBe('this_month');
    await expectNoAxeViolations();
  });

  it('says when there is no spending', async () => {
    server.use(serve(makePaymentMethodReport({ payment_methods: [] })));
    renderRoute('/analytics?view=payment-methods', { user: returning() });
    expect(await screen.findByText('No spending in this period')).toBeInTheDocument();
  });

  it('explains a temporarily unavailable service and offers a retry', async () => {
    server.use(
      http.get(`${API}/analytics/payment-methods`, () =>
        HttpResponse.json(errorBody({ code: 'PROVIDER_UNAVAILABLE' }), { status: 503 }),
      ),
    );
    renderRoute('/analytics?view=payment-methods', { user: returning() });
    expect(
      await screen.findByText(/temporarily unavailable\. Try again shortly\./),
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument();
  });
});
