import { test, expect } from "@playwright/test";
import { config } from "../lib/config";

/**
 * Langfuse is up and the headless-initialized user + project exist. Langfuse is
 * a DIFFERENT origin from LibreChat, so the shared storage state doesn't apply —
 * we sign in through Langfuse's own form using the seeded init-user credentials,
 * then confirm the Default Project's dashboard and Traces view load.
 *
 * We navigate with absolute Langfuse URLs rather than overriding `baseURL` via
 * top-level `test.use()`: that override is brittle across Playwright loader
 * setups (it throws "did not expect test.use() to be called here" in some
 * environments), and being explicit about the cross-origin target is clearer.
 */

const LF = config.langfuseBaseUrl;

test.describe("Langfuse UI", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`${LF}/auth/sign-in`);
    await page.locator('input[name="email"]').fill(config.login.email);
    await page.locator('input[name="password"]').fill(config.login.password);
    await page.getByRole("button", { name: /sign in/i }).click();
    // A successful sign-in leaves the auth pages for a /project/... route.
    await page.waitForURL(/\/(project|organization|onboarding|setup)\b/, { timeout: 30_000 });
  });

  test("Default Project dashboard loads", async ({ page }) => {
    await page.goto(`${LF}/project/${config.langfuse.projectId}`);
    await expect(page.getByText(config.langfuse.projectName, { exact: false }).first()).toBeVisible();
  });

  test("Traces view loads", async ({ page }) => {
    await page.goto(`${LF}/project/${config.langfuse.projectId}/traces`);
    await expect(page.getByRole("heading", { name: /traces/i })).toBeVisible();
  });
});
