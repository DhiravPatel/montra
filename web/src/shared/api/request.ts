import { ApiError, networkError, toApiError } from './errors';

interface FetchResult<D> {
  data?: D;
  error?: unknown;
  response: Response;
}

function isAbortError(error: unknown): boolean {
  return error instanceof DOMException && error.name === 'AbortError';
}

/**
 * Awaits an openapi-fetch call and returns the success envelope
 * (`{data, meta}`), or throws an ApiError built from the error envelope.
 * Aborts (query cancellation) are rethrown untouched.
 */
export async function apiEnvelope<D>(call: Promise<FetchResult<D>>): Promise<D> {
  let result: FetchResult<D>;
  try {
    result = await call;
  } catch (error) {
    if (isAbortError(error)) throw error;
    if (error instanceof ApiError) throw error;
    if (error instanceof TypeError) throw networkError(error);
    throw new ApiError({
      status: 0,
      code: 'UNKNOWN_ERROR',
      message: 'Unexpected client error.',
      cause: error,
    });
  }
  if (!result.response.ok || result.data === undefined) {
    throw toApiError(result.response, result.error);
  }
  return result.data;
}

/** Like apiEnvelope() but returns only the envelope's `data`. */
export async function apiData<D extends { data: unknown }>(
  call: Promise<FetchResult<D>>,
): Promise<D['data']> {
  const envelope = await apiEnvelope(call);
  return envelope.data;
}
