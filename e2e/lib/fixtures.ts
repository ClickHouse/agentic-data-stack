import { writeFileSync } from "node:fs";
import { test as base } from "@playwright/test";
import { config } from "./config";
import { STORAGE_STATE } from "./paths";

const librechatOrigin = new URL(config.librechatBaseUrl).origin;

/**
 * NextAuth's own cookie names (Langfuse's auth stack), used to strip its
 * session out of the shared snapshot below. Cookies aren't port-scoped, so on
 * a localhost dev stack LibreChat (:3080) and Langfuse (:3000) share the same
 * cookie jar under `domain: "localhost"` — filtering by domain/origin can't
 * tell them apart. Filtering by name can.
 */
const NEXT_AUTH_COOKIE_RE = /^(__Secure-)?next-auth\./;

/**
 * LibreChat rotates the refresh-token cookie on every successful
 * `/api/auth/refresh` call, and the SPA fires that refresh unconditionally on
 * every page mount. auth.setup.ts captures storage state only ONCE; the first
 * spec to load an authenticated page rotates that token out from under the
 * static snapshot, and every later spec replaying the stale cookie gets
 * bounced to /login. Re-saving storage state after each test carries the
 * rotated cookie forward so the next spec's fresh context stays authenticated.
 *
 * Specs also visit Langfuse in the same browser context, and langfuse.spec.ts
 * relies on each test starting with NO Langfuse session so its own sign-in
 * form renders. Persisting the full state would leak a signed-in Langfuse
 * session into the shared snapshot and break that assumption, so Langfuse's
 * NextAuth cookies are stripped and only the LibreChat origin's localStorage
 * is kept.
 */
export const test = base.extend({
  page: async ({ page }, use) => {
    await use(page);
    const state = await page.context().storageState();
    writeFileSync(
      STORAGE_STATE,
      JSON.stringify({
        cookies: state.cookies.filter((c) => !NEXT_AUTH_COOKIE_RE.test(c.name)),
        origins: state.origins.filter((o) => o.origin === librechatOrigin),
      }),
    );
  },
});

export { expect } from "@playwright/test";
