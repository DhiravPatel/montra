import { useEffect, useState } from 'react';

/**
 * Seconds remaining until `deadline` (epoch ms), updated every second;
 * 0 once passed or when there is no deadline.
 */
export function useCountdown(deadline: number | null): number {
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    if (deadline === null) return;
    const tick = () => {
      setNow(Date.now());
    };
    tick();
    const timer = window.setInterval(tick, 1000);
    return () => {
      window.clearInterval(timer);
    };
  }, [deadline]);

  if (deadline === null) return 0;
  return Math.max(0, Math.ceil((deadline - now) / 1000));
}
