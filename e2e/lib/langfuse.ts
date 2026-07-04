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
type Observation = { id: string; type?: string; name?: string };
type Score = { id: string; name?: string; value?: number; stringValue?: string };

const get = async <T>(path: string): Promise<T> => {
  const res = await fetch(`${config.langfuseBaseUrl}/api/public${path}`, {
    headers: { Authorization: authHeader, Accept: "application/json" },
  });
  if (!res.ok) throw new Error(`Langfuse GET ${path} -> HTTP ${res.status}`);
  return (await res.json()) as T;
};

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * Poll `read` until `done` accepts its result or the deadline passes.
 * Throws with the last-seen value on timeout so failures are diagnosable.
 */
const poll = async <T>(read: () => Promise<T>, done: (value: T) => boolean, label: string, timeoutMs = 60_000, intervalMs = 2_000): Promise<T> => {
  const deadline = Date.now() + timeoutMs;
  let last: T | undefined;
  for (;;) {
    last = await read().catch(() => last as T);
    if (last !== undefined && done(last)) return last;
    if (Date.now() >= deadline) throw new Error(`Timed out after ${timeoutMs}ms waiting for ${label}. Last value: ${JSON.stringify(last)}`);
    await sleep(intervalMs);
  }
};

/** Wait for a trace created at/after `sinceIso`, optionally name-filtered. */
export const waitForTrace = (sinceIso: string, opts: { timeoutMs?: number } = {}): Promise<Trace> =>
  poll(
    () => get<{ data: Trace[] }>(`/traces?limit=50&fromTimestamp=${encodeURIComponent(sinceIso)}`).then((r) => r.data),
    (traces) => traces.length > 0,
    `a Langfuse trace since ${sinceIso}`,
    opts.timeoutMs,
  ).then((traces) => traces[0]);

/** Wait until a trace's observations include one matching `predicate`. */
export const waitForObservation = (traceId: string, predicate: (o: Observation) => boolean, label: string, opts: { timeoutMs?: number } = {}): Promise<Observation> =>
  poll(
    () => get<{ data: Observation[] }>(`/observations?traceId=${encodeURIComponent(traceId)}&limit=100`).then((r) => r.data),
    (obs) => obs.some(predicate),
    `observation (${label}) on trace ${traceId}`,
    opts.timeoutMs,
  ).then((obs) => obs.find(predicate)!);

/** Wait until at least one score is attached to `traceId`. */
export const waitForScore = (traceId: string, opts: { timeoutMs?: number } = {}): Promise<Score> =>
  poll(
    () => get<{ data: Score[] }>(`/scores?traceId=${encodeURIComponent(traceId)}&limit=50`).then((r) => r.data),
    (scores) => scores.length > 0,
    `a score on trace ${traceId}`,
    opts.timeoutMs,
  ).then((scores) => scores[0]);

export type { Trace, Observation, Score };
