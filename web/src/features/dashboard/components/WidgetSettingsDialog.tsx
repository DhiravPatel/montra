import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { IconButton } from '@/shared/components/IconButton';
import { useToast } from '@/shared/components/toast/ToastContext';
import { financeKeys } from '@/shared/finance/keys';
import type { Widget, WidgetsPatch } from '@/shared/finance/types';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { dashboardApi } from '../api';
import { isKnownWidget, widgetLabels } from '../registry';

interface WidgetSettingsDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  layout: readonly Widget[];
}

/** Show, hide and reorder dashboard widgets; finance records are never touched. */
export function WidgetSettingsDialog({ open, onOpenChange, layout }: WidgetSettingsDialogProps) {
  const t = useT();
  const [pending, setPending] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('dashboard.settings.title')}
      description={t('dashboard.settings.description')}
      busy={pending}
      size="lg"
    >
      {open ? (
        <WidgetSettingsForm
          layout={layout}
          onPendingChange={setPending}
          onDone={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function WidgetSettingsForm({
  layout,
  onDone,
  onPendingChange,
}: {
  layout: readonly Widget[];
  onDone: () => void;
  onPendingChange: (pending: boolean) => void;
}) {
  const t = useT();
  const toast = useToast();
  const announce = useAnnounce();
  const queryClient = useQueryClient();
  const [items, setItems] = useState<Widget[]>(() =>
    [...layout].sort((a, b) => a.position - b.position),
  );
  const [error, setError] = useState<string | null>(null);
  const mutation = useMutation({
    mutationFn: (body: WidgetsPatch) => dashboardApi.updateWidgets(body),
    onSuccess: (widgets) => {
      queryClient.setQueryData(financeKeys.widgets(), widgets);
    },
  });

  const name = (key: string) =>
    isKnownWidget(key) ? t(widgetLabels[key].title) : t('dashboard.widget.other', { key });

  const move = (index: number, offset: -1 | 1) => {
    const target = index + offset;
    const item = items[index];
    if (!item || target < 0 || target >= items.length) return;
    const next = [...items];
    next.splice(index, 1);
    next.splice(target, 0, item);
    setItems(next);
    announce(
      t('dashboard.settings.moved', {
        name: name(item.key),
        position: target + 1,
        total: next.length,
      }),
    );
  };

  const save = (body: WidgetsPatch, message: string) => {
    if (mutation.isPending) return;
    setError(null);
    onPendingChange(true);
    mutation.mutate(body, {
      onSuccess: () => {
        onPendingChange(false);
        toast.show({ tone: 'success', title: message });
        onDone();
      },
      onError: (failure) => {
        onPendingChange(false);
        setError(describeError(failure, t));
      },
    });
  };

  return (
    <div className="space-y-5">
      {error ? (
        <Alert tone="danger" live="assertive">
          {error}
        </Alert>
      ) : null}
      <ol className="divide-y divide-line rounded-lg border border-line">
        {items.map((item, index) => {
          const label = name(item.key);
          const description = isKnownWidget(item.key)
            ? t(widgetLabels[item.key].description)
            : null;
          return (
            <li key={item.key} className="flex items-center gap-3 p-3">
              <input
                id={`widget-${item.key}`}
                type="checkbox"
                checked={item.visible}
                onChange={(event) => {
                  const visible = event.target.checked;
                  setItems((list) =>
                    list.map((entry) => (entry.key === item.key ? { ...entry, visible } : entry)),
                  );
                }}
                className="size-5 shrink-0 cursor-pointer accent-accent"
                aria-describedby={description ? `widget-${item.key}-help` : undefined}
              />
              <div className="min-w-0 flex-1">
                <label
                  htmlFor={`widget-${item.key}`}
                  className="cursor-pointer font-medium text-fg"
                >
                  {t('dashboard.settings.show', { name: label })}
                </label>
                {description ? (
                  <p id={`widget-${item.key}-help`} className="text-sm text-fg-muted">
                    {description}
                  </p>
                ) : null}
              </div>
              <div className="flex shrink-0">
                <IconButton
                  icon="arrow-up"
                  size="sm"
                  label={t('dashboard.settings.moveUp', { name: label })}
                  disabled={index === 0}
                  onClick={() => {
                    move(index, -1);
                  }}
                />
                <IconButton
                  icon="arrow-down"
                  size="sm"
                  label={t('dashboard.settings.moveDown', { name: label })}
                  disabled={index === items.length - 1}
                  onClick={() => {
                    move(index, 1);
                  }}
                />
              </div>
            </li>
          );
        })}
      </ol>
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:items-center sm:justify-between">
        <Button
          variant="ghost"
          disabled={mutation.isPending}
          onClick={() => {
            save({ reset: true }, t('dashboard.settings.resetDone'));
          }}
        >
          {t('dashboard.settings.reset')}
        </Button>
        <div className="flex flex-col-reverse gap-3 sm:flex-row">
          <Button variant="secondary" disabled={mutation.isPending} onClick={onDone}>
            {t('common.cancel')}
          </Button>
          <Button
            loading={mutation.isPending}
            onClick={() => {
              save(
                {
                  widgets: items.map((item, position) => ({
                    key: item.key,
                    position,
                    visible: item.visible,
                    settings: item.settings,
                  })),
                },
                t('dashboard.settings.saved'),
              );
            }}
          >
            {t('common.save')}
          </Button>
        </div>
      </div>
    </div>
  );
}
