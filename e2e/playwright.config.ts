import { defineConfig, devices } from "@playwright/test";
import { config } from "./lib/config";
import { STORAGE_STATE } from "./lib/paths";

/**
 * Chromium-only, host-driven config. There is NO `webServer`: the stack is
 * brought up out of band by docker compose (locally or in CI) before the tests
 * run, so Playwright only drives the browser against the already-running app.
 *
 * The `setup` project logs in once and writes storage state; every other spec
 * depends on it and starts authenticated. CI is stricter (retries, forbidOnly).
 */
export default defineConfig({
  testDir: "./specs",
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: [["html", { open: "never" }], ["list"]],
  timeout: 90_000,
  expect: { timeout: 15_000 },

  use: {
    baseURL: config.librechatBaseUrl,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },

  projects: [
    { name: "setup", testMatch: /.*\.setup\.ts/ },
    {
      name: "chromium",
      testMatch: /.*\.spec\.ts/,
      use: { ...devices["Desktop Chrome"], storageState: STORAGE_STATE },
      dependencies: ["setup"],
    },
  ],
});
