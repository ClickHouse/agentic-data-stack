import { test, expect } from "@playwright/test";
import { config } from "../lib/config";

test("local admin login persists over HTTP", async ({ browser }) => {
  const context = await browser.newContext({ storageState: { cookies: [], origins: [] } });
  const page = await context.newPage();

  await page.goto(`${config.adminPanelBaseUrl}/login`);

  await expect(page.getByRole("button", { name: /sign in/i })).toBeVisible();
  await expect(page.getByRole("button", { name: /sso/i })).toHaveCount(0);

  await page.locator('input:not([type="password"])').first().fill(config.login.email);
  await page.locator('input[type="password"]').first().fill(config.login.password);
  await page.getByRole("button", { name: /sign in/i }).click();

  await page.waitForURL(`${config.adminPanelBaseUrl}/`, { timeout: 30_000 });
  await expect(page.getByRole("navigation")).toBeVisible();

  await page.reload();

  await expect(page).toHaveURL(`${config.adminPanelBaseUrl}/`);
  await expect(page.getByRole("navigation")).toBeVisible();

  await context.close();
});
