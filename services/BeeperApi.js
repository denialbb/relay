// BeeperApi — pure integration boundary (spec §7.1). No UI concerns.
// options is always an object so new API params don't change call sites.

let defaultBaseUrl = "http://127.0.0.1:23373";

export function setDefaultBaseUrl(url) {
  defaultBaseUrl = url;
}

// Canonical response-shape normalization (spec §4.3, §6). Beeper returns
// `{ items: [...] }`; older stubs/fixtures use `{ chats: [...] }` or
// `{ messages: [...] }`; some payloads are already arrays.
import { spawn } from "node:child_process";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

export function extractItems(data, key) {
  if (Array.isArray(data)) return data;
  if (!data) return [];
  if (Array.isArray(data.items)) return data.items;
  if (key && Array.isArray(data[key])) return data[key];
  return [];
}

function resolveBaseUrl(options) {
  if (options && typeof options.baseUrl === "string") return options.baseUrl;
  return defaultBaseUrl;
}

function classifyHttpStatus(status) {
  if (status === 401) return "unauthorized";
  if (status === 429) return "rate-limited";
  if (status >= 500) return "server-error";
  return "unknown";
}

function classifyNetworkError(err) {
  const code = err?.code ?? err?.cause?.code;
  if (
    code === "ECONNREFUSED" ||
    code === "ETIMEDOUT" ||
    err?.name === "TimeoutError"
  ) {
    return "beeper-unavailable";
  }
  return "unknown";
}

async function requestJson(url, init = {}, options = {}) {
  // url is something like http://127.0.0.1:40123/v1/chats/search
  // We extract the path
  let parsedUrl;
  try {
    parsedUrl = new URL(url);
  } catch {
    throw new Error("unknown");
  }
  const path = parsedUrl.pathname + parsedUrl.search;

  // Test harness port: the bridge honors it only with the explicit
  // BEEPER_RELAY_ALLOW_TEST_PORT=1 opt-in (never set outside tests).
  const env = {
    ...process.env,
    BEEPER_RELAY_TEST_PORT: parsedUrl.port,
    BEEPER_RELAY_ALLOW_TEST_PORT: "1",
  };

  const pyPath = join(
    dirname(fileURLToPath(import.meta.url)),
    "beeper_bridge.py",
  );

  let stdout;
  try {
    stdout = await new Promise((resolve, reject) => {
      const child = spawn(
        "python3",
        [pyPath, "request", init.method || "GET", path],
        {
          env,
          stdio: ["pipe", "pipe", "pipe"],
        },
      );

      let out = "";
      let errOut = "";
      const timeoutMs = Number.isFinite(options.timeoutMs) && options.timeoutMs > 0
        ? options.timeoutMs
        : 10000;
      const timer = setTimeout(() => {
        const error = Object.assign(new Error("Request timed out"), { code: "ETIMEDOUT" });
        reject(error);
        child.kill();
      }, timeoutMs);
      child.stdout.on("data", (d) => (out += d));
      child.stderr.on("data", (d) => (errOut += d));

      child.on("close", (code) => {
        clearTimeout(timer);
        if (code !== 0 && !out) {
          reject(new Error(errOut || "Process exited with code " + code));
        } else {
          resolve(out);
        }
      });
      child.on("error", (err) => {
        clearTimeout(timer);
        reject(err);
      });

      const bodyData = init.body
        ? init.body.length.toString() + "\n" + init.body
        : "\n";
      child.stdin.write(bodyData);
      child.stdin.end();
    });
  } catch (err) {
    if (err.code === "ETIMEDOUT" || err.message.includes("ETIMEDOUT")) {
      throw new Error("beeper-unavailable");
    }
    console.error("STDERR:", err.stderr ? err.stderr.toString() : "NONE");
    throw new Error(classifyNetworkError(err));
  }

  let parsed;
  try {
    parsed = JSON.parse(stdout);
  } catch {
    throw new Error("invalid-response");
  }

  if (parsed.error) {
    if (parsed.code === "ECONN") throw new Error("beeper-unavailable");
    if (parsed.code === "ELIMIT") throw new Error("invalid-response");
    throw new Error("beeper-unavailable");
  }

  if (parsed.status >= 200 && parsed.status < 300) {
    return parsed.data;
  }

  throw new Error(classifyHttpStatus(parsed.status));
}

export async function searchUnreadChats(options = {}) {
  const base = resolveBaseUrl(options);
  const url = new URL("/v1/chats/search", base);
  url.searchParams.set("unreadOnly", String(options.unreadOnly ?? true));
  url.searchParams.set("type", options.type ?? "any");
  if (options.limit !== undefined) {
    url.searchParams.set("limit", String(options.limit));
  }
  return requestJson(url.toString(), {}, options);
}

export async function searchChats(query = "", options = {}) {
  const base = resolveBaseUrl(options);
  const url = new URL("/v1/chats/search", base);
  if (query) {
    url.searchParams.set("query", query);
  }
  if (options.limit !== undefined) {
    url.searchParams.set("limit", String(options.limit));
  }
  return requestJson(url.toString(), {}, options);
}

export async function listMessages(chatId, options = {}) {
  const base = resolveBaseUrl(options);
  const encodedChatId = encodeURIComponent(chatId);
  const url = new URL(`/v1/chats/${encodedChatId}/messages`, base);
  if (options.limit !== undefined) {
    url.searchParams.set("limit", String(options.limit));
  }
  if (options.cursor) {
    url.searchParams.set("cursor", options.cursor);
  }
  return requestJson(url.toString(), {}, options);
}

export async function sendText(chatId, text, options = {}) {
  const base = resolveBaseUrl(options);
  const encodedChatId = encodeURIComponent(chatId);
  const url = new URL(`/v1/chats/${encodedChatId}/messages`, base);
  return requestJson(
    url.toString(),
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ text }),
    },
    options,
  );
}

export async function markRead(chatId, messageId = null, options = {}) {
  const base = resolveBaseUrl(options);
  const encodedChatId = encodeURIComponent(chatId);
  const url = new URL(`/v1/chats/${encodedChatId}/read`, base);
  const payload =
    typeof messageId === "string" ? { messageID: messageId, messageId } : {};
  return requestJson(
    url.toString(),
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(payload),
    },
    options,
  );
}
