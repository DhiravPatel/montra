import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useMemo, useState } from 'react';
import { Controller, useForm, useWatch } from 'react-hook-form';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { RadioGroup } from '@/shared/components/RadioGroup';
import { Select, type SelectOption } from '@/shared/components/Select';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { importsApi, useImportSample } from '../api';
import { importErrorMessage, isStateConflict } from '../errors';
import { importKeys } from '../keys';
import { mappingNotes } from '../reasons';
import {
  DATE_FORMATS,
  type MappingValues,
  mappingSchema,
  mappingToValues,
  valuesToMapping,
} from '../mapping';
import type { ColumnMapping, ImportBatch, ImportRow } from '../types';

interface MappingFormProps {
  batch: ImportBatch;
  /** The server accepted the mapping and is re-reading the rows. */
  onApplied: (batch: ImportBatch) => void;
  /** The detected columns are right: go on without re-reading. */
  onContinue: () => void;
  /** The import changed elsewhere (version conflict or a new status): reload it. */
  onConflict: (message: string | null) => void;
  /** Extra buttons for the action row (e.g. cancel the import). */
  secondaryActions?: ReactNode;
}

/**
 * Which column holds what: header row, date and its format, amounts (one
 * signed column, or money out and money in), descriptions and optional
 * columns, with the first rows of the file to check against.
 */
export function MappingForm(props: MappingFormProps) {
  const { t } = useI18n();
  const sample = useImportSample(props.batch);
  if (sample.isPending) return <LoadingState label={t('imports.mapping.loading')} />;
  if (sample.isError) {
    return (
      <ErrorState
        title={t('imports.mapping.error')}
        error={sample.error}
        retrying={sample.isFetching}
        onRetry={() => {
          void sample.refetch();
        }}
      />
    );
  }
  return <MappingFields {...props} rows={sample.data.rows} />;
}

const roleKeys: readonly [keyof MappingValues, MessageKey][] = [
  ['dateColumn', 'imports.mapping.role.date'],
  ['amountColumn', 'imports.mapping.role.amount'],
  ['debitColumn', 'imports.mapping.role.moneyOut'],
  ['creditColumn', 'imports.mapping.role.moneyIn'],
  ['indicatorColumn', 'imports.mapping.role.indicator'],
  ['referenceColumn', 'imports.mapping.role.reference'],
  ['balanceColumn', 'imports.mapping.role.balance'],
  ['currencyColumn', 'imports.mapping.role.currency'],
  ['externalIdColumn', 'imports.mapping.role.externalId'],
];

function MappingFields({
  batch,
  rows,
  onApplied,
  onContinue,
  onConflict,
  secondaryActions,
}: MappingFormProps & { rows: readonly ImportRow[] }) {
  const { t, formatLocale } = useI18n();
  const queryClient = useQueryClient();
  const [formError, setFormError] = useState<ReactNode>(null);
  const schema = useMemo(() => mappingSchema(t), [t]);
  const form = useForm<MappingValues, unknown, MappingValues>({
    resolver: zodResolver(schema),
    defaultValues: mappingToValues(batch.mapping),
  });
  const values = useWatch({ control: form.control }) as MappingValues;

  const mutation = useMutation({
    mutationFn: (mapping: ColumnMapping) => importsApi.setMapping(batch.id, mapping, batch.version),
  });

  const headerIndex = Number(values.headerRow);
  const headerCells = headerIndex >= 0 ? (rows[headerIndex]?.raw ?? []) : [];
  const width = Math.max(batch.header.length, ...rows.map((row) => row.raw.length), 0);
  const columns = Array.from({ length: width }, (_, index) => {
    const name = headerCells[index]?.trim();
    return {
      value: String(index),
      label: name
        ? t('imports.mapping.columnNamed', { number: index + 1, name })
        : t('imports.mapping.column', { number: index + 1 }),
    };
  });
  const noneOption: SelectOption = { value: '', label: t('imports.mapping.none') };
  const headerOptions: SelectOption[] = [
    { value: '-1', label: t('imports.mapping.noHeader') },
    ...rows.map((row, index) => {
      const preview = row.raw
        .map((cell) => cell.trim())
        .filter(Boolean)
        .slice(0, 3)
        .join(', ');
      return {
        value: String(index),
        label: t('imports.mapping.headerOption', {
          number: row.row_number,
          preview: preview.length > 60 ? `${preview.slice(0, 59)}…` : preview,
        }),
      };
    }),
  ];
  const sampleRows = rows.slice(headerIndex + 1, headerIndex + 9);
  const rolesOf = (index: number): string[] => {
    const key = String(index);
    const roles = roleKeys
      .filter(([field]) => {
        if (field === 'amountColumn' && values.amountMode !== 'single') return false;
        if ((field === 'debitColumn' || field === 'creditColumn') && values.amountMode !== 'split')
          return false;
        return values[field] === key;
      })
      .map(([, label]) => t(label));
    if (values.descriptionColumns.includes(key)) roles.push(t('imports.mapping.role.description'));
    return roles;
  };

  const onSubmit = form.handleSubmit(async (submitted) => {
    if (mutation.isPending) return;
    setFormError(null);
    if (batch.status === 'preview_ready' && !form.formState.isDirty) {
      onContinue();
      return;
    }
    try {
      const updated = await mutation.mutateAsync(valuesToMapping(submitted));
      queryClient.setQueryData(importKeys.batch(batch.id), updated);
      onApplied(updated);
    } catch (error) {
      if (hasErrorCode(error, 'VALIDATION_ERROR') && error.details.length > 0) {
        setFormError(
          <>
            <p>{t('imports.mapping.errors.server')}</p>
            <ul className="list-disc ps-5">
              {error.details.map((detail, index) => (
                <li key={index}>{detail.message}</li>
              ))}
            </ul>
          </>,
        );
      } else if (isStateConflict(error)) {
        onConflict(
          hasErrorCode(error, 'VERSION_CONFLICT')
            ? null
            : importErrorMessage(error, t, formatLocale),
        );
      } else {
        setFormError(importErrorMessage(error, t, formatLocale));
      }
    }
  });

  const { errors } = form.formState;
  const notes = mappingNotes(batch, t);
  const changed = batch.status === 'needs_mapping' || form.formState.isDirty;

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-6">
      <FormAlert message={formError} />
      {notes.length > 0 ? (
        <Alert tone="info" title={t('imports.mapping.notesTitle')}>
          <ul className="list-disc space-y-1 ps-5">
            {notes.map((note) => (
              <li key={note}>{note}</li>
            ))}
          </ul>
        </Alert>
      ) : null}

      <Select
        label={t('imports.mapping.headerRow')}
        help={t('imports.mapping.headerRowHelp')}
        options={headerOptions}
        {...form.register('headerRow')}
      />

      <fieldset className="space-y-4">
        <legend className="text-base font-semibold text-fg">
          {t('imports.mapping.dateSection')}
        </legend>
        <div className="grid gap-4 sm:grid-cols-2">
          <Select
            label={t('imports.mapping.dateColumn')}
            placeholder={t('imports.mapping.choose')}
            options={columns}
            error={errors.dateColumn?.message}
            {...form.register('dateColumn')}
          />
          <Select
            label={t('imports.mapping.dateFormat')}
            placeholder={t('imports.mapping.choose')}
            options={DATE_FORMATS.map((format) => ({ value: format, label: format }))}
            help={t('imports.mapping.dateFormatHelp')}
            error={errors.dateFormat?.message}
            {...form.register('dateFormat')}
          />
        </div>
      </fieldset>

      <fieldset className="space-y-4">
        <legend className="text-base font-semibold text-fg">
          {t('imports.mapping.amountSection')}
        </legend>
        <Controller
          control={form.control}
          name="amountMode"
          render={({ field }) => (
            <RadioGroup
              legend={t('imports.mapping.amountMode')}
              variant="cards"
              value={field.value}
              onChange={field.onChange}
              options={[
                {
                  value: 'single',
                  label: t('imports.mapping.single'),
                  description: t('imports.mapping.singleHelp'),
                },
                {
                  value: 'split',
                  label: t('imports.mapping.split'),
                  description: t('imports.mapping.splitHelp'),
                },
              ]}
            />
          )}
        />
        {values.amountMode === 'single' ? (
          <div className="space-y-4">
            <Select
              label={t('imports.mapping.amountColumn')}
              placeholder={t('imports.mapping.choose')}
              options={columns}
              error={errors.amountColumn?.message}
              {...form.register('amountColumn')}
            />
            <Controller
              control={form.control}
              name="signConvention"
              render={({ field }) => (
                <RadioGroup
                  legend={t('imports.mapping.sign')}
                  value={field.value}
                  onChange={field.onChange}
                  options={[
                    { value: 'negative_is_outflow', label: t('imports.mapping.negativeIsOut') },
                    { value: 'positive_is_outflow', label: t('imports.mapping.positiveIsOut') },
                  ]}
                />
              )}
            />
          </div>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2">
            <Select
              label={t('imports.mapping.debitColumn')}
              placeholder={t('imports.mapping.choose')}
              options={columns}
              error={errors.debitColumn?.message}
              {...form.register('debitColumn')}
            />
            <Select
              label={t('imports.mapping.creditColumn')}
              placeholder={t('imports.mapping.choose')}
              options={columns}
              error={errors.creditColumn?.message}
              {...form.register('creditColumn')}
            />
          </div>
        )}
        <div className="grid gap-4 sm:grid-cols-2">
          <Select
            label={t('imports.mapping.indicatorColumn')}
            optional
            help={t('imports.mapping.indicatorHelp')}
            options={[noneOption, ...columns]}
            {...form.register('indicatorColumn')}
          />
          <Controller
            control={form.control}
            name="decimalSeparator"
            render={({ field }) => (
              <RadioGroup
                legend={t('imports.mapping.decimal')}
                value={field.value}
                onChange={field.onChange}
                options={[
                  { value: '.', label: t('imports.mapping.decimalDot') },
                  { value: ',', label: t('imports.mapping.decimalComma') },
                ]}
              />
            )}
          />
        </div>
      </fieldset>

      <fieldset className="space-y-4">
        <legend className="text-base font-semibold text-fg">
          {t('imports.mapping.detailsSection')}
        </legend>
        <fieldset className="space-y-2" aria-describedby="description-columns-help">
          <legend className="text-sm font-medium text-fg">
            {t('imports.mapping.descriptionColumns')}{' '}
            <span className="font-normal text-fg-muted">({t('common.optional')})</span>
          </legend>
          <p id="description-columns-help" className="text-sm text-fg-muted">
            {t('imports.mapping.descriptionHelp')}
          </p>
          <Controller
            control={form.control}
            name="descriptionColumns"
            render={({ field }) => (
              <div className="grid gap-2 sm:grid-cols-2">
                {columns.map((option) => (
                  <label
                    key={option.value}
                    className="flex min-h-11 cursor-pointer items-center gap-3 rounded-md border border-line-strong px-3 py-2 text-sm text-fg has-[:focus-visible]:outline-3 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-focus"
                  >
                    <input
                      type="checkbox"
                      name={field.name}
                      value={option.value}
                      checked={field.value.includes(option.value)}
                      onBlur={field.onBlur}
                      onChange={(event) => {
                        field.onChange(
                          event.target.checked
                            ? [...field.value, option.value]
                            : field.value.filter((value) => value !== option.value),
                        );
                      }}
                      className="size-4 shrink-0 cursor-pointer accent-accent focus-visible:outline-none"
                    />
                    <span className="min-w-0 break-words">{option.label}</span>
                  </label>
                ))}
              </div>
            )}
          />
        </fieldset>
        <div className="grid gap-4 sm:grid-cols-2">
          <Select
            label={t('imports.mapping.referenceColumn')}
            optional
            options={[noneOption, ...columns]}
            {...form.register('referenceColumn')}
          />
          <Select
            label={t('imports.mapping.balanceColumn')}
            optional
            help={t('imports.mapping.balanceHelp')}
            options={[noneOption, ...columns]}
            {...form.register('balanceColumn')}
          />
          <Select
            label={t('imports.mapping.currencyColumn')}
            optional
            help={t('imports.mapping.currencyHelp', { currency: batch.currency })}
            options={[noneOption, ...columns]}
            {...form.register('currencyColumn')}
          />
          <Select
            label={t('imports.mapping.externalIdColumn')}
            optional
            help={t('imports.mapping.externalIdHelp')}
            options={[noneOption, ...columns]}
            {...form.register('externalIdColumn')}
          />
        </div>
      </fieldset>

      <section aria-labelledby="mapping-sample-title" className="space-y-2">
        <h3 id="mapping-sample-title" className="text-base font-semibold text-fg">
          {t('imports.mapping.sampleTitle')}
        </h3>
        <p className="text-sm text-fg-muted">{t('imports.mapping.sampleHelp')}</p>
        {sampleRows.length === 0 ? (
          <p className="text-sm text-fg-muted">{t('imports.mapping.sampleEmpty')}</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border border-line">
            <table className="w-full min-w-max border-collapse text-sm">
              <caption className="sr-only">{t('imports.mapping.sampleCaption')}</caption>
              <thead>
                <tr className="border-b border-line bg-surface-muted">
                  <th scope="col" className="px-3 py-2 text-start font-medium text-fg-muted">
                    {t('imports.mapping.rowHeader')}
                  </th>
                  {columns.map((option, index) => {
                    const roles = rolesOf(index);
                    return (
                      <th
                        key={option.value}
                        scope="col"
                        className="px-3 py-2 text-start align-top font-medium text-fg"
                      >
                        <span className="block">{option.label}</span>
                        {roles.length > 0 ? (
                          <span className="mt-0.5 block text-xs font-normal text-accent">
                            {roles.join(', ')}
                          </span>
                        ) : null}
                      </th>
                    );
                  })}
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {sampleRows.map((row) => (
                  <tr key={row.id}>
                    <th scope="row" className="px-3 py-2 text-start font-normal text-fg-muted">
                      {row.row_number}
                    </th>
                    {columns.map((option, index) => (
                      <td key={option.value} className="max-w-64 truncate px-3 py-2 text-fg">
                        {row.raw[index] ?? ''}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-between">
        <div className="flex flex-wrap gap-3">{secondaryActions}</div>
        <Button type="submit" loading={mutation.isPending}>
          {changed ? t('imports.mapping.apply') : t('imports.mapping.continue')}
        </Button>
      </div>
    </form>
  );
}
