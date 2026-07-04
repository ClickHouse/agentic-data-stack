// OpenAI-compatible mock inference server for the E2E stack.
//
// Purpose: fake ONLY the LLM inference so the heavy E2E suite needs no
// ANTHROPIC_API_KEY, spends no tokens, and never flakes on a frontier model.
// The MCP server, ClickHouse, and Langfuse stay real, so a chat driven by this
// mock still produces a real Langfuse generation observation and real
// MCP -> ClickHouse tool spans.
//
// Two endpoints, both under /v1 to match the OpenAI wire format LibreChat's
// custom endpoints speak:
//   GET  /v1/models            -> advertise the single mock model
//   POST /v1/chat/completions  -> adaptive tool-calling completion
//
// Adaptive tool-calling: on the first turn we inspect the request's tools[],
// find the ClickHouse "run a query" tool by NAME PATTERN (never a hardcoded
// name — LibreChat rewrites MCP tool names, so a pattern survives that), and
// emit a tool_call that runs `SELECT 1`. LibreChat executes it against the real
// MCP server and sends the result back as a tool message; on that second turn
// we emit a final text answer that echoes the tool result so the browser test
// can assert the round-trip end to end.
//
// Built-ins only (node:http) — this file is mounted into a bare node image with
// no npm install step.

const http = require("node:http");

const PORT = Number(process.env.PORT || 8080);
const MODEL = process.env.MOCK_MODEL || "mock-model";

// The query we ask the ClickHouse MCP tool to run. `SELECT 1` returns the single
// value 1, which the round-trip spec asserts on. Kept as a constant so the tool
// arguments and the echoed answer can never drift apart.
const QUERY = "SELECT 1";

// Matches the ClickHouse MCP "run a SELECT query" tool regardless of the exact
// name LibreChat exposes it under (e.g. `run_select_query`, or a namespaced
// variant). Ordered from most to least specific; the first match wins.
const QUERY_TOOL_PATTERNS = [/select.*quer/i, /run.*quer/i, /quer/i, /\bsql\b/i];

/** Find the argument key a query tool expects (usually `query`), else "query". */
const queryArgKey = (tool) => {
  const props = tool?.function?.parameters?.properties;
  if (props && !props.query) {
    const named = Object.keys(props).find((k) => /quer|sql/i.test(k));
    if (named) return named;
  }
  return "query";
};

/** Pick the ClickHouse query tool from an OpenAI tools[] array, or null. */
const findQueryTool = (tools) => {
  const fns = (tools || []).filter((t) => t?.type === "function" && t.function?.name);
  for (const pattern of QUERY_TOOL_PATTERNS) {
    const hit = fns.find((t) => pattern.test(t.function.name));
    if (hit) return hit;
  }
  return null;
};

/** True once LibreChat has run a tool and sent its result back to us. */
const hasToolResult = (messages) => (messages || []).some((m) => m?.role === "tool");

/** Flatten OpenAI message content (string or content-part array) to text. */
const messageText = (message) => {
  const { content } = message || {};
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content.map((p) => (typeof p === "string" ? p : p?.text || "")).join("");
  }
  return "";
};

/** The most recent tool result text, for the final answer to echo. */
const lastToolResult = (messages) => {
  const tools = (messages || []).filter((m) => m?.role === "tool");
  return tools.length ? messageText(tools[tools.length - 1]).trim() : "";
};

// ── Response builders ────────────────────────────────────────────────────────
// A completion is one of two shapes: a tool_call (first turn, a query tool is
// available) or a plain text answer (tool already ran, or no tool to call).

const answerText = (messages) => {
  const result = lastToolResult(messages);
  return result
    ? `The ClickHouse query \`${QUERY}\` returned: ${result}`
    : `The ClickHouse query \`${QUERY}\` returned: 1`;
};

const toolCall = (tool) => ({
  id: "call_mock_1",
  type: "function",
  function: { name: tool.function.name, arguments: JSON.stringify({ [queryArgKey(tool)]: QUERY }) },
});

const chunk = (created, delta, finish_reason = null) =>
  `data: ${JSON.stringify({
    id: "chatcmpl-mock",
    object: "chat.completion.chunk",
    created,
    model: MODEL,
    choices: [{ index: 0, delta, finish_reason }],
  })}\n\n`;

/** Stream either a tool_calls turn or a text turn as OpenAI SSE. */
const streamCompletion = (res, { tool, text }) => {
  const created = Math.floor(Date.now() / 1000);
  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });
  if (tool) {
    res.write(chunk(created, { role: "assistant", tool_calls: [{ index: 0, ...toolCall(tool) }] }));
    res.write(chunk(created, {}, "tool_calls"));
  } else {
    res.write(chunk(created, { role: "assistant", content: text }));
    res.write(chunk(created, {}, "stop"));
  }
  res.write("data: [DONE]\n\n");
  res.end();
};

/** Non-streaming fallback: one completion object. */
const jsonCompletion = (res, { tool, text }) => {
  const message = tool
    ? { role: "assistant", content: null, tool_calls: [toolCall(tool)] }
    : { role: "assistant", content: text };
  send(res, 200, {
    id: "chatcmpl-mock",
    object: "chat.completion",
    created: Math.floor(Date.now() / 1000),
    model: MODEL,
    choices: [{ index: 0, message, finish_reason: tool ? "tool_calls" : "stop" }],
    usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 },
  });
};

const send = (res, code, body) => {
  res.writeHead(code, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
};

const readBody = (req) =>
  new Promise((resolve, reject) => {
    let raw = "";
    req.on("data", (c) => (raw += c));
    req.on("end", () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch (e) {
        reject(e);
      }
    });
    req.on("error", reject);
  });

const server = http.createServer(async (req, res) => {
  const { pathname } = new URL(req.url, "http://localhost");

  if (req.method === "GET" && (pathname === "/v1/models" || pathname === "/models")) {
    return send(res, 200, {
      object: "list",
      data: [{ id: MODEL, object: "model", created: 0, owned_by: "mock-llm" }],
    });
  }

  if (req.method === "POST" && (pathname === "/v1/chat/completions" || pathname === "/chat/completions")) {
    let body;
    try {
      body = await readBody(req);
    } catch {
      return send(res, 400, { error: { message: "invalid JSON body" } });
    }
    // Call the query tool on the first turn; answer once its result is back (or
    // if no query tool was offered at all).
    const tool = hasToolResult(body.messages) ? null : findQueryTool(body.tools);
    const plan = { tool, text: answerText(body.messages) };
    return body.stream === false ? jsonCompletion(res, plan) : streamCompletion(res, plan);
  }

  return send(res, 404, { error: { message: `not found: ${req.method} ${pathname}` } });
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`mock-llm listening on :${PORT} (model=${MODEL})`);
});
