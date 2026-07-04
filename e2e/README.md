# E2E tests

Browser-level Playwright tests that verify the stack actually **works** — not
just that it boots (that's the job of the smoke test in
`.github/workflows/smoke-test.yml`). They cover the real user flows: login, an
agent chat that queries **ClickHouse via the real MCP server**, **Langfuse trace
creation**, and the **feedback → Langfuse score** path.

Runs **daily + manual only** (`.github/workflows/e2e.yml`), never on PRs.

## Secret-free by design

A local OpenAI-compatible **mock** (`mock-llm/server.js`) fakes only the
*inference*. The MCP server, ClickHouse, and Langfuse stay **real**, so no
`ANTHROPIC_API_KEY`, no token spend, and no frontier-model flakiness — while
still producing real Langfuse traces (a generation observation plus real
MCP → ClickHouse tool spans) and exercising scoring.

The mock uses **adaptive tool-calling**: it inspects the request's `tools[]`,
finds the ClickHouse query tool by name *pattern* (never a hardcoded name, which
LibreChat rewrites), emits a `tool_calls` delta running `SELECT 1`, then — once
LibreChat sends the tool result back — emits a final answer echoing it.

## Layout

| Path | Purpose |
| --- | --- |
| `mock-llm/server.js` | OpenAI-compatible mock inference server (Node built-ins only). |
| `librechat.e2e.yaml` | LibreChat config = prod config + the `MockLLM` endpoint. Loaded via `CONFIG_PATH`. |
| `playwright.config.ts` | Chromium, `baseURL` `http://localhost:3080`, `setup` auth project, no `webServer`. |
| `lib/config.ts` | Explicit, fail-fast config resolved from the repo-root `.env`. |
| `lib/langfuse.ts` | Langfuse public-API client that **polls** (ingestion is async). |
| `lib/librechat.ts` | Shared chat-driving helpers. |
| `setup/auth.setup.ts` | Logs in once via `POST /api/auth/login`, saves storage state. |
| `specs/*.spec.ts` | `librechat`, `langfuse`, `roundtrip`, `scoring`. |

## Run locally

The suite drives an already-running stack (no `webServer`): bring it up first.

```bash
cd ..                      # repo root
bash scripts/generate-env.sh
docker compose -f docker-compose.yml -f docker-compose.e2e.yml up -d --wait --wait-timeout 600
cd e2e && npm ci && npx playwright install --with-deps chromium
npx playwright test
cd .. && docker compose -f docker-compose.yml -f docker-compose.e2e.yml down -v
```

## Confirming selectors

The endpoint/MCP-picker and 👍/👎 selectors are best-effort (LibreChat markup
drifts). Confirm/refresh them against the live UI with:

```bash
npx playwright codegen --test-id-attribute=data-testid http://localhost:3080/c/new
```

## Troubleshooting

**`Playwright Test did not expect test.describe()/test.use() to be called here`**
(thrown while loading the first spec) means two different `@playwright/test`
versions are resolving — almost always a stale `node_modules` where the
`playwright` binary and the `@playwright/test` library have drifted apart. The
committed lockfile pins both to the same version, so reinstall from it:

```bash
cd e2e
rm -rf node_modules
npm ci
```

Also make sure you're using the local runner, not a globally installed one
(`npx playwright --version` should match `@playwright/test` in package.json). A
global `playwright` on `PATH` can shadow the local binary and reintroduce the
mismatch.
