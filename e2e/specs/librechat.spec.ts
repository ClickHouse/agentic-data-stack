import { test, expect } from "@playwright/test";
import { config } from "../lib/config";

/**
 * LibreChat is reachable and usable: the login form renders for anonymous users,
 * and an authenticated session lands on a working new-chat UI. This is the
 * browser-level counterpart to the smoke test's HTTP probe.
 */

test.describe("LibreChat UI", () => {
  test("login form renders for anonymous users", async ({ browser }) => {
    // Fresh context with NO storage state — we must be logged out to see the form.
    const context = await browser.newContext({ storageState: { cookies: [], origins: [] } });
    const page = await context.newPage();
    await page.goto("/login");

    await expect(page.getByLabel("Email")).toBeVisible();
    await expect(page.getByLabel("Password")).toBeVisible();
    await expect(page.getByTestId("login-button")).toBeVisible();

    await context.close();
  });

  test("authenticated session loads the new-chat UI", async ({ page }) => {
    await page.goto("/c/new");

    // The message composer is the definitive "chat is ready" signal.
    await expect(page.getByTestId("text-input")).toBeVisible();
    await expect(page.getByTestId("new-chat-button")).toBeVisible();
    // We are authed, so we must NOT be bounced to the login form.
    await expect(page.getByTestId("login-button")).toHaveCount(0);
  });

  test("seeded admin email is the configured login", async () => {
    // Guards the config contract the whole suite depends on.
    expect(config.login.email).toContain("@");
  });
});
