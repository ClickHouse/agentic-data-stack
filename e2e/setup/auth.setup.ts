import { test as setup, expect } from "@playwright/test";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { config } from "../lib/config";
import { STORAGE_STATE } from "../lib/paths";

/**
 * Requirement: every authed spec starts already logged in as the seeded admin.
 *
 * We log in ONCE here via the API (`POST /api/auth/login`) rather than driving
 * the form in every spec — faster and less brittle. The response sets LibreChat's
 * refresh-token cookie; saving the request context's storage state hands that
 * cookie to each spec's browser, which the app exchanges for an access token on
 * load. librechat.spec.ts separately covers the login FORM itself.
 */
setup("authenticate via API", async ({ request }) => {
  const res = await request.post("/api/auth/login", {
    data: { email: config.login.email, password: config.login.password },
  });
  expect(res.ok(), `login failed for ${config.login.email}: HTTP ${res.status()} ${await res.text()}`).toBeTruthy();

  mkdirSync(dirname(STORAGE_STATE), { recursive: true });
  await request.storageState({ path: STORAGE_STATE });
});
