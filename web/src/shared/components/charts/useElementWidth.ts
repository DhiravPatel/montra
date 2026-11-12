import { useCallback, useState } from 'react';

/** Width of an element in CSS pixels, kept current with a ResizeObserver. */
export function useElementWidth(): [(node: Element | null) => (() => void) | undefined, number] {
  const [width, setWidth] = useState(0);
  const ref = useCallback((node: Element | null) => {
    if (!node) return undefined;
    setWidth(node.getBoundingClientRect().width);
    const observer = new ResizeObserver((entries) => {
      const entry = entries[0];
      if (entry) setWidth(entry.contentRect.width);
    });
    observer.observe(node);
    return () => {
      observer.disconnect();
    };
  }, []);
  return [ref, width];
}
