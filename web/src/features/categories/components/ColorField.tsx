import { useId } from 'react';
import { FieldHelp } from '@/shared/components/FieldParts';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { COLOR_PALETTE, isHexColor } from '../labels';

/** A small color swatch beside a name (decorative: the name always carries the meaning). */
export function ColorDot({ color, className }: { color?: string | null; className?: string }) {
  return (
    <span
      aria-hidden="true"
      className={cx(
        'inline-block size-3 shrink-0 rounded-full border border-line-strong',
        className,
      )}
      style={isHexColor(color) ? { backgroundColor: color } : undefined}
    />
  );
}

interface ColorFieldProps {
  value: string;
  /** '' means no color (an edit then removes a saved color). */
  onChange: (value: string) => void;
  /** The saved color, kept as a choice when it is not in the palette. */
  saved?: string | null;
  disabled?: boolean;
}

/** Color choice as named radio buttons (keyboard: arrow keys between colors). */
export function ColorField({ value, onChange, saved, disabled = false }: ColorFieldProps) {
  const t = useT();
  const name = useId();
  const helpId = `${name}-help`;
  const savedColor = isHexColor(saved) ? saved.toUpperCase() : null;
  const inPalette = COLOR_PALETTE.some((option) => option.value === savedColor);
  const options: { value: string; label: string }[] = [
    { value: '', label: t('organize.color.none') },
    ...(savedColor && !inPalette
      ? [{ value: savedColor, label: t('organize.color.current') }]
      : []),
    ...COLOR_PALETTE.map((option) => ({ value: option.value, label: t(option.labelKey) })),
  ];
  const current = value.toUpperCase();
  return (
    <fieldset className="space-y-2" aria-describedby={helpId} disabled={disabled}>
      <legend className="mb-1.5 text-sm font-medium text-fg">{t('organize.color.label')}</legend>
      <div className="flex flex-wrap gap-2">
        {options.map((option) => {
          const checked = option.value === current;
          return (
            <label
              key={option.value || 'none'}
              className={cx(
                'flex min-h-11 cursor-pointer items-center gap-2 rounded-md border px-3 py-2 text-sm',
                'has-[:focus-visible]:outline-3 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-focus',
                checked
                  ? 'border-accent bg-accent-soft font-semibold text-fg'
                  : 'border-line-strong bg-surface text-fg hover:bg-surface-muted',
              )}
            >
              <input
                type="radio"
                name={name}
                value={option.value}
                checked={checked}
                onChange={() => {
                  onChange(option.value);
                }}
                className="size-4 shrink-0 cursor-pointer accent-accent focus-visible:outline-none"
              />
              <ColorDot color={option.value} className="size-4" />
              {option.label}
            </label>
          );
        })}
      </div>
      <FieldHelp id={helpId}>{t('organize.color.help')}</FieldHelp>
    </fieldset>
  );
}
