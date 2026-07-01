import { resolve } from "node:path";

/** Where auth.setup.ts writes the logged-in storage state that specs reuse. */
export const STORAGE_STATE = resolve(__dirname, "../playwright/.auth/user.json");
