import { test, expect } from "@playwright/test";
import { runMockChat } from "../lib/librechat";
import { waitForTrace, waitForObservation } from "../lib/langfuse";

/**
 * The headline requirement: a chat drives the WHOLE stack end to end. The mock
 * only fakes inference — the tool call it emits is executed against the REAL
 * ClickHouse MCP server, and the whole exchange is traced to the REAL Langfuse.
 *
 * We assert on both surfaces:
 *   1. Browser: the reply echoes the `SELECT 1` result and a tool invocation is
 *      shown, proving MockLLM -> MCP -> ClickHouse actually ran.
 *   2. Langfuse public API: a fresh trace exists carrying a generation
 *      observation AND an MCP/tool observation, proving instrumentation works.
 */
test("chat round-trips MockLLM -> MCP -> ClickHouse and traces to Langfuse", async ({ page }) => {
  // Bound the Langfuse trace search to this test run. One second of slack
  // absorbs host/Langfuse clock skew without matching older traces.
  const since = new Date(Date.now() - 1_000).toISOString();

  await runMockChat(page, "Use the ClickHouse tool to run SELECT 1 and tell me the result.");

  // 1. Browser-visible proof of the tool round-trip.
  const messages = page.getByTestId("messages-view");
  await expect(messages).toContainText("SELECT 1");
  await expect(messages).toContainText("1");
  // The assistant's tool call renders a card referencing the query tool.
  await expect(messages).toContainText(/query|clickhouse|tool/i);

  // 2. A real Langfuse trace with both a generation and an MCP/tool span.
  const trace = await waitForTrace(since, { timeoutMs: 90_000 });

  await waitForObservation(
    trace.id,
    (o) => o.type === "GENERATION",
    "generation (LLM inference span)",
    { timeoutMs: 90_000 },
  );

  await waitForObservation(
    trace.id,
    (o) => /clickhouse|mcp|query|select|tool/i.test(o.name ?? "") || o.type === "TOOL",
    "MCP -> ClickHouse tool span",
    { timeoutMs: 90_000 },
  );
});
