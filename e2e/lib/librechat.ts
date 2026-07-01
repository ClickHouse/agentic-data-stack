import { expect, type Page } from "@playwright/test";

/**
 * Shared chat helpers for the round-trip and scoring specs.
 *
 * Selector strategy: the message composer testids (`text-input`, `send-button`,
 * `messages-view`) are stable LibreChat contracts and are asserted strictly. The
 * endpoint/MCP pickers have less stable markup, so selecting them is best-effort
 * (tolerant of label/markup drift) — if a picker interaction silently misses,
 * the mock never runs the tool and the caller's strict outcome assertion (reply
 * echoes `SELECT 1`, tool card shown, Langfuse spans) fails loudly instead.
 *
 * Confirm/refresh the picker selectors with:
 *   npx playwright codegen --test-id-attribute=data-testid http://localhost:3080/c/new
 */

const MOCK_ENDPOINT = "MockLLM";
const MCP_SERVER = "ClickHouse-Local";

/** Best-effort click of the first locator that becomes visible; never throws. */
const tryClick = async (page: Page, candidates: ReturnType<Page["locator"]>[], timeoutMs = 4_000): Promise<boolean> => {
  for (const locator of candidates) {
    try {
      await locator.first().waitFor({ state: "visible", timeout: timeoutMs });
      await locator.first().click();
      return true;
    } catch {
      /* try the next candidate */
    }
  }
  return false;
};

/** Point the new conversation at the secret-free MockLLM endpoint. */
export const selectMockEndpoint = async (page: Page): Promise<void> => {
  await tryClick(page, [
    page.getByTestId("endpoint-menu-button"),
    page.getByRole("button", { name: /select.*(model|endpoint)/i }),
  ]);
  await tryClick(page, [
    page.getByRole("option", { name: MOCK_ENDPOINT }),
    page.getByText(MOCK_ENDPOINT, { exact: false }),
  ]);
};

/** Enable the ClickHouse-Local MCP server for the conversation. */
export const enableClickHouseMcp = async (page: Page): Promise<void> => {
  await tryClick(page, [
    page.getByTestId("mcp-select"),
    page.getByRole("button", { name: /mcp/i }),
    page.getByRole("button", { name: /tools/i }),
  ]);
  await tryClick(page, [
    page.getByRole("option", { name: MCP_SERVER }),
    page.getByRole("menuitemcheckbox", { name: MCP_SERVER }),
    page.getByText(MCP_SERVER, { exact: false }),
  ]);
  // Close the picker so it doesn't overlay the composer.
  await page.keyboard.press("Escape").catch(() => {});
};

/** Type a prompt and send it. */
export const sendPrompt = async (page: Page, prompt: string): Promise<void> => {
  const input = page.getByTestId("text-input");
  await expect(input).toBeVisible();
  await input.click();
  await input.fill(prompt);
  await page.getByTestId("send-button").click();
};

/**
 * Give thumbs-up feedback on the latest assistant message. The controls appear
 * on hover, so we hover the messages view first. Best-effort selection (see the
 * strategy note above): if it misses, the caller's score assertion fails loudly.
 */
export const giveThumbsUp = async (page: Page): Promise<void> => {
  const messages = page.getByTestId("messages-view");
  await messages.hover().catch(() => {});
  await tryClick(page, [
    page.getByTestId("good-response-button"),
    page.getByRole("button", { name: /thumbs.?up|good response|helpful/i }),
    page.locator('button[aria-label*="thumb" i]').first(),
  ]);
};

/**
 * Full drive: open a new chat wired to MockLLM + ClickHouse-Local, send `prompt`,
 * and wait for the assistant's reply to render in the messages view.
 */
export const runMockChat = async (page: Page, prompt: string): Promise<void> => {
  await page.goto("/c/new");
  await expect(page.getByTestId("text-input")).toBeVisible();
  await selectMockEndpoint(page);
  await enableClickHouseMcp(page);
  await sendPrompt(page, prompt);
  // The final answer always contains the query text the mock echoes back.
  await expect(page.getByTestId("messages-view")).toContainText("SELECT 1", { timeout: 60_000 });
};
