import { test, expect } from "../lib/fixtures";
import { runMockChat, giveThumbsUp } from "../lib/librechat";
import { waitForTrace, waitForScore } from "../lib/langfuse";

/**
 * The feedback -> Langfuse score bridge works end to end (exercises upstream PR
 * danny-avila/LibreChat#13544, already in librechat:latest). After a chat we
 * click 👍 on the reply and assert a score lands on that chat's Langfuse trace.
 *
 * Scoring is only meaningful once a trace exists, so we resolve the trace first,
 * then submit feedback, then poll for the score (ingestion is async).
 */
test("thumbs-up feedback attaches a score to the chat's Langfuse trace", async ({ page }) => {
  const since = new Date(Date.now() - 1_000).toISOString();

  await runMockChat(page, "Use the ClickHouse tool to run SELECT 1 and tell me the result.");

  const trace = await waitForTrace(since, { timeoutMs: 90_000 });

  await giveThumbsUp(page);

  const score = await waitForScore(trace.id, { timeoutMs: 90_000 });
  expect(score.id, "expected a score attached to the trace after 👍 feedback").toBeTruthy();
});
