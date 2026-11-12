import { Navigate, useParams } from 'react-router';

/**
 * Redirects an older or app-neutral link (e.g. a notification's deep link
 * such as /bills/{id}) to the page that shows it. Only route params (opaque
 * IDs) are carried over.
 */
export function LegacyRedirect({
  to,
}: {
  to: (params: Readonly<Record<string, string>>) => string;
}) {
  const params = useParams();
  const clean: Record<string, string> = {};
  for (const [key, value] of Object.entries(params)) {
    if (value) clean[key] = encodeURIComponent(value);
  }
  return <Navigate to={to(clean)} replace />;
}
