import { test as setup, expect } from "@playwright/test";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { config } from "../lib/config";
import { STORAGE_STATE } from "../lib/paths";

/**
 * Requirement: every authed spec starts already logged in as the seeded admin.
 *
 * We log in ONCE here through the UI and save the resulting storage state.
 * An API-only login (POST /api/auth/login) captures the refresh cookie but NOT
 * the localStorage the LibreChat SPA also relies on, so a browser restored from
 * it bounces back to /login. Driving the real form captures cookies AND
 * localStorage — the canonical Playwright auth recipe — so specs load
 * authenticated.
 */
setup("authenticate", async ({ page }) => {
  await page.goto("/login");
  await page.getByRole("textbox", { name: "Email", exact: true }).fill(config.login.email);
  await page.getByRole("textbox", { name: "Password", exact: true }).fill(config.login.password);
  await page.getByRole("button", { name: /continue|log ?in|sign ?in/i }).click();

  // The new-chat button only renders inside the authenticated app shell, so its
  // visibility proves the login succeeded before we snapshot the session.
  await expect(page.getByTestId("new-chat-button")).toBeVisible({ timeout: 30_000 });

  mkdirSync(dirname(STORAGE_STATE), { recursive: true });
  await page.context().storageState({ path: STORAGE_STATE });
});
