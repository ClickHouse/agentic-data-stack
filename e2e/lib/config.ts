import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

/**
 * One source of truth for E2E config, resolved explicitly and fail-fast.
 *
 * Values come from the generated repo-root `.env` (written by
 * scripts/generate-env.sh), with `process.env` taking precedence so a run can
 * be pointed at a remote stack without editing files. A required value that is
 * missing throws at load time — never a silent default that hangs a test later.
 *
 * Note the host/container split: `.env`'s LANGFUSE_BASE_URL is the in-container
 * URL (http://langfuse-web:3000). Playwright runs on the host, so it must reach
 * Langfuse and LibreChat via their published localhost ports, not the compose
 * service names. Hence the dedicated *_HOST_URL knobs below.
 */

const ENV_FILE = resolve(__dirname, "../../.env");

const parseEnvFile = (path: string): Record<string, string> => {
  if (!existsSync(path)) return {};
  const out: Record<string, string> = {};
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    out[trimmed.slice(0, eq).trim()] = trimmed.slice(eq + 1).trim();
  }
  return out;
};

const fileEnv = parseEnvFile(ENV_FILE);

/** process.env wins over the .env file; both missing with no default throws. */
const required = (key: string, fallback?: string): string => {
  const value = process.env[key] ?? fileEnv[key] ?? fallback;
  if (value === undefined || value === "") {
    throw new Error(
      `Missing required E2E config '${key}'. Set it in the environment or run scripts/generate-env.sh to write ${ENV_FILE}.`,
    );
  }
  return value;
};

export const config = {
  librechatBaseUrl: required("LIBRECHAT_HOST_URL", "http://localhost:3080"),
  langfuseBaseUrl: required("LANGFUSE_HOST_URL", "http://localhost:3000"),

  login: {
    email: required("LIBRECHAT_USER_EMAIL"),
    password: required("LIBRECHAT_USER_PASSWORD"),
  },

  langfuse: {
    publicKey: required("LANGFUSE_INIT_PROJECT_PUBLIC_KEY"),
    secretKey: required("LANGFUSE_INIT_PROJECT_SECRET_KEY"),
    projectId: required("LANGFUSE_INIT_PROJECT_ID"),
    projectName: required("LANGFUSE_INIT_PROJECT_NAME", "Default Project"),
  },
} as const;
