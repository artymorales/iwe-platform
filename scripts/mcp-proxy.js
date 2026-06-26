#!/usr/bin/env node
/**
 * MCP stdio proxy — Aisystant MCP gateway
 *
 * Translates stdio JSON-RPC (Aethon's format) to HTTP POST JSON-RPC
 * against the remote MCP gateway. Handles OAuth token refresh.
 *
 * REQUIRED: Valid OAuth tokens stored in ~/.aethon/.secrets/mcp-aisystant.json
 *
 * Config:
 *   ~/.aethon/.secrets/mcp-aisystant.json:
 *     { access_token, refresh_token, client_id, client_secret, expires_at }
 *   OR env: AETHON_AISYSTANT_TOKEN (static token, no auto-refresh)
 */

const https = require("https");
const fs = require("fs");
const path = require("path");
const readline = require("readline");

const MCP_HOST = "mcp.aisystant.com";
const MCP_PATH = "/mcp";
const SECRETS_FILE = path.join(
  process.env.HOME || process.env.USERPROFILE,
  ".aethon",
  ".secrets",
  "mcp-aisystant.json"
);

let pendingToken = null; // { access_token, expires_at }

function readSecrets() {
  try {
    return JSON.parse(fs.readFileSync(SECRETS_FILE, "utf-8"));
  } catch {
    return null;
  }
}

function saveSecrets(secrets) {
  try {
    fs.writeFileSync(SECRETS_FILE, JSON.stringify(secrets, null, 2), "utf-8");
  } catch (e) {
    console.error(`[mcp-proxy] Warning: could not persist token: ${e.message}`);
  }
}

async function getAccessToken() {
  // 1. Cached token still valid?
  if (pendingToken && pendingToken.expires_at > Math.floor(Date.now() / 1000) + 60) {
    return pendingToken.access_token;
  }

  // 2. Static env token
  const envToken = process.env.AETHON_AISYSTANT_TOKEN || process.env.IWE_AISYSTANT_TOKEN;
  if (envToken) return envToken;

  // 3. Secrets file
  const secrets = readSecrets();
  if (!secrets) {
    throw new Error("No token. Set AETHON_AISYSTANT_TOKEN env or create " + SECRETS_FILE);
  }

  // 4. Access token still valid?
  if (secrets.access_token && (secrets.expires_at || 0) > Math.floor(Date.now() / 1000) + 60) {
    pendingToken = { access_token: secrets.access_token, expires_at: secrets.expires_at };
    return secrets.access_token;
  }

  // 5. Refresh
  if (!secrets.refresh_token) {
    throw new Error("Access token expired, no refresh_token. Re-authenticate via OAuth.");
  }

  const newToken = await doRefresh(secrets);
  pendingToken = { access_token: newToken.access_token, expires_at: newToken.expires_at };
  secrets.access_token = newToken.access_token;
  secrets.expires_at = newToken.expires_at;
  if (newToken.refresh_token) secrets.refresh_token = newToken.refresh_token;
  saveSecrets(secrets);
  return newToken.access_token;
}

function doRefresh(secrets) {
  return new Promise((resolve, reject) => {
    const body = new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: secrets.refresh_token,
      client_id: secrets.client_id || "gateway-mcp",
      client_secret: secrets.client_secret || "",
    }).toString();

    const req = https.request(
      { hostname: MCP_HOST, path: "/token", method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded",
                   "Content-Length": Buffer.byteLength(body) } },
      (res) => {
        let data = "";
        res.on("data", (c) => (data += c));
        res.on("end", () => {
          try {
            const p = JSON.parse(data);
            if (p.error) return reject(new Error(`Refresh failed: ${p.error}`));
            resolve({
              access_token: p.access_token,
              refresh_token: p.refresh_token || secrets.refresh_token,
              expires_at: Math.floor(Date.now() / 1000) + (p.expires_in || 3600),
            });
          } catch (e) {
            reject(new Error(`Refresh parse error: ${e.message}`));
          }
        });
      }
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

function mcpRequest(token, jsonRpcLine) {
  return new Promise((resolve, reject) => {
    const data = Buffer.from(jsonRpcLine, "utf-8");
    const req = https.request(
      { hostname: MCP_HOST, path: MCP_PATH, method: "POST",
        headers: { "Content-Type": "application/json",
                   "Accept": "application/json, text/event-stream",
                   "Authorization": "Bearer " + token,
                   "Content-Length": data.length } },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
      }
    );
    req.on("error", reject);
    req.write(data);
    req.end();
  });
}

function jsonError(msg, id) {
  return JSON.stringify({
    jsonrpc: "2.0",
    error: { code: -32000, message: msg },
    id: id !== undefined ? id : null,
  });
}

// ───────────────────────────────────────────────
// Persistent stdio loop — stays alive for multiple messages
// ───────────────────────────────────────────────
const rl = readline.createInterface({ input: process.stdin });
rl.on("line", async (line) => {
  line = line.trim();
  if (!line) return;

  try {
    // Extract id before async to track across errors
    let reqId;
    try {
      const parsed = JSON.parse(line);
      reqId = parsed.id;
    } catch {}

    const token = await getAccessToken();
    const response = await mcpRequest(token, line);
    process.stdout.write(response + "\n");
  } catch (e) {
    process.stdout.write(jsonError(e.message, reqId) + "\n");
  }
});

rl.on("close", () => process.exit(0));

// Send 'started' notification on connect (handshake for Aethon)
process.stdout.write(
  JSON.stringify({
    jsonrpc: "2.0",
    method: "notifications/initialized",
    params: {},
  }) + "\n"
);
