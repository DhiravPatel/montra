import { useQueryClient } from '@tanstack/react-query';
import { useCallback, useEffect, useRef, useState } from 'react';
import { useLocation, useSearchParams } from 'react-router';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { TextLink } from '@/shared/components/TextLink';
import { paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { BatchSteps } from '../components/BatchSteps';
import { StartSteps } from '../components/StartSteps';
import { STEP_HEADING_ID } from '../components/WizardCard';
import { type WizardStep, WizardSteps } from '../components/WizardSteps';
import { importKeys } from '../keys';
import { uuidParam } from '../status';
import type { ImportBatch } from '../types';

/**
 * Moves focus to the new step's heading when the step changes (or a new
 * import starts), never on the first load.
 */
function useFocusStepHeading(step: WizardStep | null, importId: string | null) {
  const previous = useRef<{ step: WizardStep; importId: string | null } | null>(null);
  useEffect(() => {
    if (step === null) return;
    const before = previous.current;
    previous.current = { step, importId };
    if (before && (before.step !== step || before.importId !== importId)) {
      document.getElementById(STEP_HEADING_ID)?.focus();
    }
  }, [step, importId]);
}

/**
 * Statement import wizard (spec §4.10): account → file → columns → review →
 * confirm → result. Once the server has the import, its ID is kept in the
 * URL (IDs only), so a reload or a later visit resumes where it stands.
 */
export function ImportCreatePage() {
  const t = useT();
  useDocumentTitle(t('imports.create.documentTitle'));
  const location = useLocation();
  const queryClient = useQueryClient();
  const [params, setParams] = useSearchParams();
  const importId = uuidParam(params.get('import_id'));
  const presetAccountId = uuidParam(params.get('account_id'));
  const startWithFile = params.get('step') === 'file';
  const [step, setStep] = useState<WizardStep | null>(null);
  useFocusStepHeading(step, importId);

  const onStepChange = useCallback((next: WizardStep | null) => {
    setStep(next);
  }, []);

  const onCreated = useCallback(
    (batch: ImportBatch) => {
      queryClient.setQueryData(importKeys.batch(batch.id), batch);
      void queryClient.invalidateQueries({ queryKey: importKeys.all });
      setParams({ import_id: batch.id }, { replace: true });
    },
    [queryClient, setParams],
  );

  return (
    <>
      <p className="mb-2">
        <TextLink to={paths.imports}>
          <Icon name="arrow-left" className="me-1 inline size-4" />
          {t('imports.backToList')}
        </TextLink>
      </p>
      <PageHeader title={t('imports.create.title')} description={t('imports.create.description')} />
      {step ? <WizardSteps current={step} /> : null}
      {importId ? (
        <BatchSteps key={importId} importId={importId} onStepChange={onStepChange} />
      ) : (
        <StartSteps
          key={location.key}
          presetAccountId={presetAccountId}
          startWithFile={startWithFile}
          onStepChange={onStepChange}
          onCreated={onCreated}
        />
      )}
    </>
  );
}
