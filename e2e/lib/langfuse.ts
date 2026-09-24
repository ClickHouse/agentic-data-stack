import { config } from "./config";

/**
 * Thin client for the Langfuse public API, used to assert that a chat produced
 * real observability data. Auth is HTTP Basic with base64(publicKey:secretKey),
 * exactly as Langfuse's public API expects.
 *
 * Ingestion is ASYNCHRONOUS — traces and scores land in ClickHouse seconds after
 * the HTTP round-trip finishes. Every read here therefore POLLS to a deadline
 * instead of asserting once; a single fetch would be racy and flaky by design.
 */

const authHeader = "Basic " + Buffer.from(`${config.langfuse.publicKey}:${config.langfuse.secretKey}`).toString("base64");

type Trace = { id: string; name?: string; timestamp?: string };
type Observation = {
  id: string;
  traceId: string;
  startTime: string;
  type?: string;
  name?: string;
  isRootObservation?: boolean;
};
type Score = { id: string; name?: string; value?: number | string | boolean };

const get = async <T>(path: string): Promise<T> => {
  const res = await fetch(`${config.langfuseBaseUrl}/api/public${path}`, {
    headers: { Authorization: authHeader, Accept: "application/json" },
  });
  if (!res.ok) throw new Error(`Langfuse GET ${path} -> HTTP ${res.status}`);
  return (await res.json()) as T;
};

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const observationsPath = (params: Record<string, string>): string => {
  const query = new URLSearchParams({ fields: "core,basic", ...params });
  return `/v2/observations?${query.toString()}`;
};

const recentWindow = (): Pick<Record<string, string>, "fromStartTime" | "toStartTime"> => ({
  fromStartTime: new Date(Date.now() - 15 * 60_000).toISOString(),
  // Leave a little clock-skew headroom while keeping the v4 query bounded.
  toStartTime: new Date(Date.now() + 60_000).toISOString(),
});

/**
 * Poll `read` until `done` accepts its result or the deadline passes.
 * Throws with the last-seen value on timeout so failures are diagnosable.
 */
const poll = async <T>(read: () => Promise<T>, done: (value: T) => boolean, label: string, timeoutMs = 60_000, intervalMs = 2_000): Promise<T> => {
  const deadline = Date.now() + timeoutMs;
  let last: T | undefined;
  let lastError: unknown;
  for (;;) {
    try {
      last = await read();
      lastError = undefined;
    } catch (error) {
      lastError = error;
    }
    if (last !== undefined && done(last)) return last;
    if (Date.now() >= deadline) {
      const errorDetail = lastError instanceof Error ? lastError.message : String(lastError ?? "none");
      throw new Error(
        `Timed out after ${timeoutMs}ms waiting for ${label}. Last value: ${JSON.stringify(last)}. Last error: ${errorDetail}`,
      );
    }
    await sleep(intervalMs);
  }
};

/**
 * Wait for a trace created at/after `sinceIso`.
 *
 * Langfuse v4 removed the legacy traces read endpoint. A root observation is
 * the v4 representation of the trace entry point, so discover it through the
 * Observations API v2 and return its trace ID to the callers below.
 */
export const waitForTrace = (sinceIso: string, opts: { timeoutMs?: number } = {}): Promise<Trace> =>
  poll(
    () =>
      get<{ data: Observation[] }>(
        observationsPath({
          fromStartTime: sinceIso,
          toStartTime: new Date(Date.now() + 60_000).toISOString(),
          isRootObservation: "true",
          limit: "50",
        }),
      ).then((r) => r.data),
    (observations) => observations.length > 0,
    `a Langfuse trace since ${sinceIso}`,
    opts.timeoutMs,
  ).then((observations) => ({
    id: observations[0].traceId,
    name: observations[0].name,
    timestamp: observations[0].startTime,
  }));

/** Wait until a trace's observations include one matching `predicate`. */
export const waitForObservation = (traceId: string, predicate: (o: Observation) => boolean, label: string, opts: { timeoutMs?: number } = {}): Promise<Observation> =>
  poll(
    () =>
      get<{ data: Observation[] }>(
        observationsPath({ traceId, limit: "100", ...recentWindow() }),
      ).then((r) => r.data),
    (obs) => obs.some(predicate),
    `observation (${label}) on trace ${traceId}`,
    opts.timeoutMs,
  ).then((obs) => obs.find(predicate)!);

/** Wait until at least one score is attached to `traceId`. */
export const waitForScore = (traceId: string, opts: { timeoutMs?: number } = {}): Promise<Score> =>
  poll(
    () =>
      get<{ data: Score[] }>(
        `/v3/scores?${new URLSearchParams({ traceId, limit: "50", fields: "subject" }).toString()}`,
      ).then((r) => r.data),
    (scores) => scores.length > 0,
    `a score on trace ${traceId}`,
    opts.timeoutMs,
  ).then((scores) => scores[0]);

export type { Trace, Observation, Score };
