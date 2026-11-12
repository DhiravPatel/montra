import type { ReactNode } from 'react';

interface CountTableProps {
  caption: string;
  columns: readonly string[];
  /** Label cells first, the count last (already formatted). */
  rows: readonly { key: string; cells: readonly ReactNode[] }[];
  empty: string;
}

/** A small aggregate table: label columns, then a right-aligned count. */
export function CountTable({ caption, columns, rows, empty }: CountTableProps) {
  if (rows.length === 0) return <p className="text-sm text-fg-muted">{empty}</p>;
  const last = columns.length - 1;
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-max border-collapse text-sm">
        <caption className="sr-only">{caption}</caption>
        <thead>
          <tr className="border-b border-line">
            {columns.map((column, index) => (
              <th
                key={column}
                scope="col"
                className={`py-2 pe-4 font-medium text-fg-muted ${index === last ? 'text-end' : 'text-start'}`}
              >
                {column}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.key} className="border-b border-line last:border-b-0">
              {row.cells.map((cell, index) =>
                index === 0 ? (
                  <th key={index} scope="row" className="py-2 pe-4 text-start font-normal text-fg">
                    {cell}
                  </th>
                ) : (
                  <td
                    key={index}
                    className={`py-2 pe-4 text-fg ${index === last ? 'text-end tabular-nums' : 'text-start'}`}
                  >
                    {cell}
                  </td>
                ),
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
