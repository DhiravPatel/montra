import { useEffect, useState } from 'react';
import { clearUrlFragment, readFragmentToken } from '../fragmentToken';

/** Reads `#token=` once, then clears the fragment from the URL. */
export function useFragmentToken(): string | null {
  // Reading is pure, so React's double render in development sees the same token.
  const [token] = useState(() => readFragmentToken(window.location.hash));
  useEffect(() => {
    clearUrlFragment();
  }, []);
  return token;
}
