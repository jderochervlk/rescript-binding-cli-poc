# Publish OAuth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build browser-based Cloudflare Access Managed OAuth for `rescript binding publish`, cache tokens per user, and validate the authenticated session by calling protected `GET /v1/me`.

**Architecture:** Keep ReScript responsible for CLI parsing, publish entrypoint selection, and success/error messaging. Implement the OAuth protocol, dynamic client registration, loopback callback handling, token cache, refresh flow, and authenticated `/v1/me` fetch in a narrow JavaScript helper. Add a small Worker runtime shim that makes `wrangler.toml` valid and serves `GET /v1/me` by decoding the Access JWT payload.

**Tech Stack:** ReScript 12, Node.js ESM, Cloudflare Workers, Cloudflare Access Managed OAuth, Wrangler, plain Node test files

## Execution Status

Last synced: `2026-04-25`

- active implementation branch: `codex/publish-oauth`
- implementation has been moved back into the main repo working tree at `/home/josh/Dev/rescript-binding-cli-poc`
- previous worktree snapshot: `/home/josh/.config/superpowers/worktrees/rescript-binding-cli-poc/publish-oauth`
- Task 1 is complete and committed in worktree commit `d0e200e` (`test: add oauth helper utility coverage`)
- Task 2 is in progress in the main repo and currently uncommitted
- Tasks 3 and 4 have not started yet

Current Task 2 state:

- `src/js/PublishOAuth.mjs` has been moved into the main repo with the expanded discovery, registration, refresh, loopback, cache IO, and authenticated `/v1/me` fetch logic from the worktree
- `package.json` in the main repo now includes `node test/PublishOAuth_test.mjs` in `npm test`
- `test/PublishOAuth_test.mjs` has been restored in the main repo to the last passing Task 1 helper coverage so the moved baseline stays runnable
- spec review for Task 2 passed once against that helper shape
- code-quality review found follow-up issues worth fixing before proceeding:
  - cached-token reuse should not require authorization-server discovery
  - a revoked but locally unexpired access token should fall back to refresh before failing
  - refresh should degrade to interactive auth when the cache lacks `clientId`
  - helper tests should cover reuse, revoked-token recovery, incomplete refresh state, and parsed authorization URL assertions
- the interrupted worktree deletion of `test/PublishOAuth_test.mjs` was not carried forward; the main repo is now the source of truth
- sanity check after the move: `node test/PublishOAuth_test.mjs` passes in the main repo

Recommended resume point:

1. Extend `test/PublishOAuth_test.mjs` in the main repo with the stronger Task 2 coverage for reuse, revoked-token fallback, incomplete refresh state, and parsed authorization URL checks.
2. Update `src/js/PublishOAuth.mjs` so reuse does not depend on discovery, revoked reuse falls back to refresh, and refresh without `clientId` falls back to interactive auth.
3. Re-run `node test/PublishOAuth_test.mjs`.
4. Re-run Task 2 code-quality review.
5. Commit Task 2 from the main repo once the review passes.

---

## Cloudflare Preflight

Before manual verification, configure the publish Access app with these settings:

- self-hosted app on the publish hostname
- GitHub as the allowed IdP
- Managed OAuth enabled
- dynamic client registration enabled
- `Allow localhost clients` enabled
- `Allow loopback clients` enabled
- access token lifetime `15m`
- session duration `30d`

The plan assumes the authorization server metadata for the publish hostname includes:

- `authorization_endpoint`
- `token_endpoint`
- `registration_endpoint`
- `code_challenge_methods_supported` containing `S256`
- `token_endpoint_auth_methods_supported` containing `none`

## File Structure

- Create: `src/core/PublishAuthTypes.res`
  - typed shape for the identity returned to ReScript after successful auth
- Create: `src/bindings/PublishOAuth.res`
  - thin external binding from ReScript to the JavaScript OAuth helper
- Modify: `src/bindings/NodeProcess.res`
  - expose `process.exit`
- Modify: `src/Cli.res`
  - add publish base URL resolution, identity label selection, and async publish auth runner
- Modify: `src/Main.res`
  - await publish auth and exit non-zero on failure
- Create: `src/js/PublishOAuth.mjs`
  - dependency-injected OAuth implementation with pure helpers and a single `runPublishAuth` entrypoint
- Modify: `src/Worker.res`
  - add `isProtectedRoute` so the Worker shim can centralize which routes require Access identity
- Create: `src/Worker.mjs`
  - actual Worker `fetch` entrypoint referenced by `wrangler.toml`
- Modify: `test/Cli_test.res`
  - cover publish base URL and identity label fallback logic
- Modify: `test/Bin_test.mjs`
  - keep wrapper coverage without forcing a real OAuth run
- Create: `test/PublishOAuth_test.mjs`
  - unit tests for cache path, strategy selection, refresh flow, and interactive flow
- Create: `test/Worker_test.mjs`
  - endpoint tests for protected `/v1/me`
- Modify: `package.json`
  - run the new JS tests under `npm test`

### Task 1: Pure OAuth Helper Utilities

**Files:**

- Create: `src/js/PublishOAuth.mjs`
- Test: `test/PublishOAuth_test.mjs`

- [x] **Step 1: Write the failing JS helper test**

```js
import {
  cacheFilePathFor,
  isAccessTokenUsable,
  selectAuthStrategy,
} from "../src/js/PublishOAuth.mjs";

const assert = (condition, label) => {
  if (!condition) {
    throw new Error(`Assertion failed: ${label}`);
  }
};

const now = Date.now();

assert(
  cacheFilePathFor({
    platform: "linux",
    homeDir: "/home/josh",
    hostname: "publish.bindings.rescript-lang.org",
  }) === "/home/josh/.local/state/rescript-bindings/oauth/publish.bindings.rescript-lang.org.json",
  "linux cache path uses XDG state directory",
);

assert(
  cacheFilePathFor({
    platform: "darwin",
    homeDir: "/Users/josh",
    hostname: "publish.bindings.rescript-lang.org",
  }) ===
    "/Users/josh/Library/Application Support/rescript-bindings/oauth/publish.bindings.rescript-lang.org.json",
  "macOS cache path uses Application Support",
);

assert(
  cacheFilePathFor({
    platform: "win32",
    homeDir: "C:/Users/josh/AppData/Roaming",
    hostname: "publish.bindings.rescript-lang.org",
  }) ===
    "C:/Users/josh/AppData/Roaming/rescript-bindings/oauth/publish.bindings.rescript-lang.org.json",
  "windows cache path uses roaming app data",
);

assert(
  isAccessTokenUsable({ accessToken: "token", expiresAt: now + 120_000 }, now),
  "access token with more than one minute remaining is reusable",
);

assert(
  !isAccessTokenUsable({ accessToken: "token", expiresAt: now + 10_000 }, now),
  "nearly expired access token is not reusable",
);

assert(
  selectAuthStrategy({ accessToken: "token", expiresAt: now + 120_000 }, now) === "reuse",
  "valid access token uses reuse path",
);

assert(
  selectAuthStrategy(
    { accessToken: "token", expiresAt: now - 1_000, refreshToken: "refresh" },
    now,
  ) === "refresh",
  "expired access token with refresh token uses refresh path",
);

assert(selectAuthStrategy(null, now) === "interactive", "missing bundle uses interactive path");

console.log("PublishOAuth_test.mjs passed");
```

- [x] **Step 2: Run the helper test to verify it fails**

Run: `node test/PublishOAuth_test.mjs`
Expected: FAIL with `ERR_MODULE_NOT_FOUND` because `src/js/PublishOAuth.mjs` does not exist yet.

- [x] **Step 3: Write the minimal pure helper implementation**

```js
import path from "node:path";
import { homedir } from "node:os";

export const cacheFilePathFor = ({
  platform = process.platform,
  homeDir = homedir(),
  hostname,
}) => {
  if (!hostname) {
    throw new Error("cacheFilePathFor requires a hostname");
  }

  if (platform === "darwin") {
    return path.join(
      homeDir,
      "Library",
      "Application Support",
      "rescript-bindings",
      "oauth",
      `${hostname}.json`,
    );
  }

  if (platform === "win32") {
    return path.join(homeDir, "rescript-bindings", "oauth", `${hostname}.json`);
  }

  return path.join(homeDir, ".local", "state", "rescript-bindings", "oauth", `${hostname}.json`);
};

export const isAccessTokenUsable = (bundle, now = Date.now()) => {
  if (!bundle?.accessToken || typeof bundle.expiresAt !== "number") {
    return false;
  }

  return bundle.expiresAt - now > 60_000;
};

export const selectAuthStrategy = (bundle, now = Date.now()) => {
  if (isAccessTokenUsable(bundle, now)) {
    return "reuse";
  }

  if (bundle?.refreshToken) {
    return "refresh";
  }

  return "interactive";
};
```

- [x] **Step 4: Run the helper test to verify it passes**

Run: `node test/PublishOAuth_test.mjs`
Expected: PASS with final line `PublishOAuth_test.mjs passed`

- [x] **Step 5: Commit**

```bash
git add src/js/PublishOAuth.mjs test/PublishOAuth_test.mjs
git commit -m "test: add oauth helper utility coverage"
```

### Task 2: Interactive OAuth Flow And Cached `/v1/me`

**Files:**

- Modify: `src/js/PublishOAuth.mjs`
- Modify: `test/PublishOAuth_test.mjs`
- Modify: `package.json`

- [ ] **Step 1: Extend the helper test with refresh and interactive flow cases**

```js
import {
  cacheFilePathFor,
  isAccessTokenUsable,
  selectAuthStrategy,
  runPublishAuth,
} from "../src/js/PublishOAuth.mjs";

const assert = (condition, label) => {
  if (!condition) {
    throw new Error(`Assertion failed: ${label}`);
  }
};

const jsonResponse = (body) =>
  new Response(JSON.stringify(body), {
    status: 200,
    headers: { "content-type": "application/json" },
  });

const now = 1_716_000_000_000;

assert(
  cacheFilePathFor({
    platform: "linux",
    homeDir: "/home/josh",
    hostname: "publish.bindings.rescript-lang.org",
  }) === "/home/josh/.local/state/rescript-bindings/oauth/publish.bindings.rescript-lang.org.json",
  "linux cache path uses XDG state directory",
);

assert(
  isAccessTokenUsable({ accessToken: "token", expiresAt: now + 120_000 }, now),
  "access token with more than one minute remaining is reusable",
);

assert(
  selectAuthStrategy({ accessToken: "token", expiresAt: now + 120_000 }, now) === "reuse",
  "valid access token uses reuse path",
);

let refreshTokenBody = null;
let refreshWrite = null;
let refreshMeAuth = null;

const refreshResult = await runPublishAuth({
  publishBaseUrl: "https://publish.example.com",
  deps: {
    now: () => now,
    platform: "linux",
    homeDir: "/home/josh",
    readCache: async () => ({
      accessToken: "expired-token",
      refreshToken: "oauth:refresh-token",
      expiresAt: now - 1_000,
      clientId: "registered-client",
    }),
    writeCache: async (cachePath, bundle) => {
      refreshWrite = { cachePath, bundle };
    },
    fetch: async (url, init = {}) => {
      if (url === "https://publish.example.com/.well-known/oauth-authorization-server") {
        return jsonResponse({
          authorization_endpoint:
            "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/authorization",
          token_endpoint: "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/token",
          registration_endpoint:
            "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/registration",
        });
      }

      if (url === "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/token") {
        refreshTokenBody = init.body;
        return jsonResponse({
          access_token: "fresh-token",
          refresh_token: "oauth:new-refresh-token",
          expires_in: 300,
        });
      }

      if (url === "https://publish.example.com/v1/me") {
        refreshMeAuth = init.headers.Authorization;
        return jsonResponse({
          githubLogin: null,
          displayName: null,
          email: "dev@example.com",
          access: { authenticated: true },
        });
      }

      throw new Error(`Unexpected URL in refresh flow: ${url}`);
    },
    openBrowser: async () => {
      throw new Error("refresh flow should not open a browser");
    },
    createLoopbackServer: async () => {
      throw new Error("refresh flow should not start loopback server");
    },
  },
});

assert(
  refreshTokenBody.includes("grant_type=refresh_token"),
  "refresh token request uses refresh_token grant",
);
assert(
  refreshTokenBody.includes("client_id=registered-client"),
  "refresh token request includes client_id",
);
assert(refreshMeAuth === "Bearer fresh-token", "refresh flow uses bearer token for /v1/me");
assert(refreshResult.email === "dev@example.com", "refresh flow returns authenticated identity");
assert(
  refreshWrite.bundle.accessToken === "fresh-token",
  "refresh flow persists updated access token",
);

let openedUrl = null;
let savedInteractiveBundle = null;
let interactiveMeAuth = null;

const interactiveResult = await runPublishAuth({
  publishBaseUrl: "https://publish.example.com",
  deps: {
    now: () => now,
    platform: "linux",
    homeDir: "/home/josh",
    readCache: async () => null,
    writeCache: async (cachePath, bundle) => {
      savedInteractiveBundle = { cachePath, bundle };
    },
    randomString: () => "fixed-state-token",
    codeVerifier: () => "fixed-code-verifier",
    codeChallengeFromVerifier: () => "fixed-code-challenge",
    fetch: async (url, init = {}) => {
      if (url === "https://publish.example.com/.well-known/oauth-authorization-server") {
        return jsonResponse({
          authorization_endpoint:
            "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/authorization",
          token_endpoint: "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/token",
          registration_endpoint:
            "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/registration",
        });
      }

      if (url === "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/registration") {
        return jsonResponse({
          client_id: "dynamic-client",
          redirect_uris: ["http://127.0.0.1:43123/callback"],
        });
      }

      if (url === "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/token") {
        return jsonResponse({
          access_token: "interactive-token",
          refresh_token: "oauth:interactive-refresh",
          expires_in: 300,
        });
      }

      if (url === "https://publish.example.com/v1/me") {
        interactiveMeAuth = init.headers.Authorization;
        return jsonResponse({
          githubLogin: null,
          displayName: "Interactive Dev",
          email: "interactive@example.com",
          access: { authenticated: true },
        });
      }

      throw new Error(`Unexpected URL in interactive flow: ${url}`);
    },
    createLoopbackServer: async ({ expectedState }) => {
      assert(
        expectedState === "fixed-state-token",
        "loopback server receives expected OAuth state",
      );
      return {
        redirectUri: "http://127.0.0.1:43123/callback",
        waitForCode: async () => ({
          code: "auth-code",
          state: "fixed-state-token",
        }),
        close: async () => {},
      };
    },
    openBrowser: async (url) => {
      openedUrl = url;
    },
  },
});

assert(
  openedUrl.includes("client_id=dynamic-client"),
  "interactive flow opens browser with registered client_id",
);
assert(
  openedUrl.includes("code_challenge=fixed-code-challenge"),
  "interactive flow uses PKCE challenge",
);
assert(
  openedUrl.includes("resource=https%3A%2F%2Fpublish.example.com"),
  "interactive flow sends resource indicator",
);
assert(
  interactiveMeAuth === "Bearer interactive-token",
  "interactive flow uses bearer token for /v1/me",
);
assert(
  interactiveResult.displayName === "Interactive Dev",
  "interactive flow returns authenticated identity",
);
assert(
  savedInteractiveBundle.bundle.refreshToken === "oauth:interactive-refresh",
  "interactive flow persists refresh token",
);

console.log("PublishOAuth_test.mjs passed");
```

- [ ] **Step 2: Run the expanded helper test to verify it fails**

Run: `node test/PublishOAuth_test.mjs`
Expected: FAIL with `SyntaxError` or `TypeError` because `runPublishAuth` is not exported yet.

- [ ] **Step 3: Implement dynamic client registration, PKCE, refresh, and `/v1/me` fetch**

```js
import path from "node:path";
import { homedir } from "node:os";
import { createHash, randomBytes } from "node:crypto";
import { createServer } from "node:http";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { spawn } from "node:child_process";

export const cacheFilePathFor = ({
  platform = process.platform,
  homeDir = homedir(),
  hostname,
}) => {
  if (!hostname) {
    throw new Error("cacheFilePathFor requires a hostname");
  }

  if (platform === "darwin") {
    return path.join(
      homeDir,
      "Library",
      "Application Support",
      "rescript-bindings",
      "oauth",
      `${hostname}.json`,
    );
  }

  if (platform === "win32") {
    return path.join(homeDir, "rescript-bindings", "oauth", `${hostname}.json`);
  }

  return path.join(homeDir, ".local", "state", "rescript-bindings", "oauth", `${hostname}.json`);
};

export const isAccessTokenUsable = (bundle, now = Date.now()) => {
  if (!bundle?.accessToken || typeof bundle.expiresAt !== "number") {
    return false;
  }

  return bundle.expiresAt - now > 60_000;
};

export const selectAuthStrategy = (bundle, now = Date.now()) => {
  if (isAccessTokenUsable(bundle, now)) {
    return "reuse";
  }

  if (bundle?.refreshToken) {
    return "refresh";
  }

  return "interactive";
};

export const codeChallengeFromVerifier = (verifier) =>
  createHash("sha256").update(verifier).digest("base64url");

const defaultRandomString = () => randomBytes(24).toString("hex");
const defaultCodeVerifier = () => randomBytes(48).toString("base64url");

const defaultReadCache = async (cachePath) => {
  try {
    return JSON.parse(await readFile(cachePath, "utf8"));
  } catch (error) {
    if (error?.code === "ENOENT") {
      return null;
    }

    return null;
  }
};

const defaultWriteCache = async (cachePath, bundle) => {
  await mkdir(path.dirname(cachePath), { recursive: true });
  await writeFile(cachePath, JSON.stringify(bundle, null, 2), { mode: 0o600 });
};

const defaultOpenBrowser = async (url) => {
  const platform = process.platform;
  const command =
    platform === "darwin"
      ? ["open", [url]]
      : platform === "win32"
        ? ["cmd", ["/c", "start", "", url]]
        : ["xdg-open", [url]];

  await new Promise((resolve, reject) => {
    const child = spawn(command[0], command[1], { stdio: "ignore" });
    child.once("error", reject);
    child.once("close", (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`Browser command exited with code ${code}`));
      }
    });
  });
};

const defaultCreateLoopbackServer = async ({ expectedState }) => {
  let resolveCode;
  let rejectCode;
  const result = new Promise((resolve, reject) => {
    resolveCode = resolve;
    rejectCode = reject;
  });

  const server = createServer((req, res) => {
    const callbackUrl = new URL(req.url, "http://127.0.0.1");
    const code = callbackUrl.searchParams.get("code");
    const state = callbackUrl.searchParams.get("state");

    if (!code || !state) {
      res.statusCode = 400;
      res.end("Missing code or state");
      rejectCode(new Error("OAuth callback missing code or state"));
      return;
    }

    if (state !== expectedState) {
      res.statusCode = 400;
      res.end("State mismatch");
      rejectCode(new Error("OAuth state validation failed"));
      return;
    }

    res.statusCode = 200;
    res.end("Authentication complete. You can return to the terminal.");
    resolveCode({ code, state });
  });

  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });

  const address = server.address();
  if (!address || typeof address === "string") {
    throw new Error("Failed to allocate loopback callback port");
  }

  return {
    redirectUri: `http://127.0.0.1:${address.port}/callback`,
    waitForCode: () => result,
    close: () =>
      new Promise((resolve, reject) => {
        server.close((error) => {
          if (error) {
            reject(error);
          } else {
            resolve();
          }
        });
      }),
  };
};

const readJson = async (response) => {
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload?.error || payload?.message || `HTTP ${response.status}`);
  }

  return payload;
};

const discoverAuthorizationServer = async ({ publishBaseUrl, fetchImpl }) => {
  const response = await fetchImpl(`${publishBaseUrl}/.well-known/oauth-authorization-server`, {});

  return readJson(response);
};

const registerPublicClient = async ({ metadata, redirectUri, publishBaseUrl, fetchImpl }) => {
  const response = await fetchImpl(metadata.registration_endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      redirect_uris: [redirectUri],
      token_endpoint_auth_method: "none",
      grant_types: ["authorization_code", "refresh_token"],
      response_types: ["code"],
      resource: publishBaseUrl,
    }),
  });

  return readJson(response);
};

const exchangeCodeForToken = async ({
  metadata,
  clientId,
  redirectUri,
  code,
  codeVerifier,
  publishBaseUrl,
  fetchImpl,
}) => {
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: clientId,
    code,
    code_verifier: codeVerifier,
    redirect_uri: redirectUri,
    resource: publishBaseUrl,
  });

  const response = await fetchImpl(metadata.token_endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });

  return readJson(response);
};

const refreshTokenBundle = async ({
  metadata,
  clientId,
  refreshToken,
  publishBaseUrl,
  fetchImpl,
}) => {
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    client_id: clientId,
    resource: publishBaseUrl,
  });

  const response = await fetchImpl(metadata.token_endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });

  return readJson(response);
};

const buildTokenBundle = ({
  tokenResponse,
  metadata,
  clientId,
  publishBaseUrl,
  now,
  previous,
}) => ({
  accessToken: tokenResponse.access_token,
  refreshToken: tokenResponse.refresh_token ?? previous?.refreshToken ?? null,
  expiresAt: now + tokenResponse.expires_in * 1000,
  tokenEndpoint: metadata.token_endpoint,
  authorizationEndpoint: metadata.authorization_endpoint,
  registrationEndpoint: metadata.registration_endpoint,
  clientId,
  resource: publishBaseUrl,
  publishBaseUrl,
});

const fetchCurrentIdentity = async ({ publishBaseUrl, accessToken, fetchImpl }) => {
  const response = await fetchImpl(`${publishBaseUrl}/v1/me`, {
    method: "GET",
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  return readJson(response);
};

export const runPublishAuth = async ({ publishBaseUrl, deps = {} }) => {
  const fetchImpl = deps.fetch ?? globalThis.fetch;
  const now = deps.now ?? Date.now;
  const platform = deps.platform ?? process.platform;
  const homeDir =
    deps.homeDir ?? (platform === "win32" ? (process.env.APPDATA ?? homedir()) : homedir());
  const readCache = deps.readCache ?? defaultReadCache;
  const writeCache = deps.writeCache ?? defaultWriteCache;
  const openBrowser = deps.openBrowser ?? defaultOpenBrowser;
  const createLoopbackServer = deps.createLoopbackServer ?? defaultCreateLoopbackServer;
  const randomString = deps.randomString ?? defaultRandomString;
  const makeCodeVerifier = deps.codeVerifier ?? defaultCodeVerifier;
  const createCodeChallenge = deps.codeChallengeFromVerifier ?? codeChallengeFromVerifier;

  if (!fetchImpl) {
    throw new Error("OAuth helper requires a fetch implementation");
  }

  const hostname = new URL(publishBaseUrl).hostname;
  const cachePath = cacheFilePathFor({ platform, homeDir, hostname });
  const metadata = await discoverAuthorizationServer({ publishBaseUrl, fetchImpl });
  const cachedBundle = await readCache(cachePath);
  const strategy = selectAuthStrategy(cachedBundle, now());

  if (strategy === "reuse") {
    return fetchCurrentIdentity({
      publishBaseUrl,
      accessToken: cachedBundle.accessToken,
      fetchImpl,
    });
  }

  if (strategy === "refresh") {
    const refreshed = await refreshTokenBundle({
      metadata,
      clientId: cachedBundle.clientId,
      refreshToken: cachedBundle.refreshToken,
      publishBaseUrl,
      fetchImpl,
    });
    const nextBundle = buildTokenBundle({
      tokenResponse: refreshed,
      metadata,
      clientId: cachedBundle.clientId,
      publishBaseUrl,
      now: now(),
      previous: cachedBundle,
    });
    await writeCache(cachePath, nextBundle);
    return fetchCurrentIdentity({
      publishBaseUrl,
      accessToken: nextBundle.accessToken,
      fetchImpl,
    });
  }

  const expectedState = randomString();
  const codeVerifier = makeCodeVerifier();
  const codeChallenge = createCodeChallenge(codeVerifier);
  const loopback = await createLoopbackServer({ expectedState });

  try {
    const client = await registerPublicClient({
      metadata,
      redirectUri: loopback.redirectUri,
      publishBaseUrl,
      fetchImpl,
    });

    const authorizationUrl = new URL(metadata.authorization_endpoint);
    authorizationUrl.searchParams.set("client_id", client.client_id);
    authorizationUrl.searchParams.set("redirect_uri", loopback.redirectUri);
    authorizationUrl.searchParams.set("response_type", "code");
    authorizationUrl.searchParams.set("resource", publishBaseUrl);
    authorizationUrl.searchParams.set("code_challenge", codeChallenge);
    authorizationUrl.searchParams.set("code_challenge_method", "S256");
    authorizationUrl.searchParams.set("state", expectedState);

    await openBrowser(authorizationUrl.toString());

    const { code } = await loopback.waitForCode();
    const tokenResponse = await exchangeCodeForToken({
      metadata,
      clientId: client.client_id,
      redirectUri: loopback.redirectUri,
      code,
      codeVerifier,
      publishBaseUrl,
      fetchImpl,
    });

    const nextBundle = buildTokenBundle({
      tokenResponse,
      metadata,
      clientId: client.client_id,
      publishBaseUrl,
      now: now(),
      previous: null,
    });

    await writeCache(cachePath, nextBundle);

    return fetchCurrentIdentity({
      publishBaseUrl,
      accessToken: nextBundle.accessToken,
      fetchImpl,
    });
  } finally {
    await loopback.close();
  }
};
```

Also update the `test` script in `package.json`:

```json
{
  "scripts": {
    "build": "rescript build",
    "clean": "rescript clean",
    "test": "rescript build && node test/Validation_test.res.mjs && node test/Cli_test.res.mjs && node test/PublishOAuth_test.mjs && node test/Bin_test.mjs && node test/D1_test.mjs"
  }
}
```

- [ ] **Step 4: Run the helper test to verify it passes**

Run: `node test/PublishOAuth_test.mjs`
Expected: PASS with final line `PublishOAuth_test.mjs passed`

- [ ] **Step 5: Commit**

```bash
git add src/js/PublishOAuth.mjs test/PublishOAuth_test.mjs package.json
git commit -m "feat: implement publish oauth helper"
```

### Task 3: ReScript CLI Integration

**Files:**

- Create: `src/core/PublishAuthTypes.res`
- Create: `src/bindings/PublishOAuth.res`
- Modify: `src/bindings/NodeProcess.res`
- Modify: `src/Cli.res`
- Modify: `src/Main.res`
- Modify: `test/Cli_test.res`
- Modify: `test/Bin_test.mjs`

- [ ] **Step 1: Write the failing ReScript CLI tests**

```rescript
let assertTrue = (cond: bool, label: string) => {
  if !cond {
    throw(Failure("Assertion failed: " ++ label))
  }
}

let assertParse = (argv, expected, label) => {
  assertTrue(Cli.parse(argv) == expected, label)
}

let () = {
  assertParse(
    ["node", "src/Main.res.mjs", "binding", "add", "@scope/pkg"],
    Some(("add", "@scope/pkg", None)),
    "parse add command",
  )

  assertParse(
    [
      "node",
      "src/Main.res.mjs",
      "binding",
      "add",
      "@scope/pkg",
      "--folder",
      "vendor/bindings",
    ],
    Some(("add", "@scope/pkg", Some("vendor/bindings"))),
    "parse add command with explicit folder",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "binding", "publish"],
    Some(("publish", "", None)),
    "parse publish command",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "binding", "install", "pkg"],
    None,
    "reject unknown command",
  )

  let defaultFolder =
    Cli.defaultInstallFolder(~cwd="/tmp/project", ~packageName="@scope/pkg", ~variantSlug="web")
  assertTrue(
    defaultFolder == "/tmp/project/src/bindings/@scope/pkg/web",
    "default install folder is derived from cwd/package/variant",
  )

  assertTrue(
    Cli.publishBaseUrlFrom(None) == "https://publish.bindings.rescript-lang.org",
    "publish base url defaults to production hostname",
  )

  assertTrue(
    Cli.publishBaseUrlFrom(Some("https://staging.example.com")) == "https://staging.example.com",
    "publish base url honors env override",
  )

  assertTrue(
    Cli.authDisplayName(~githubLogin=Some("octocat"), ~email=None, ~displayName=None) == "octocat",
    "github login is the preferred identity label",
  )

  assertTrue(
    Cli.authDisplayName(~githubLogin=None, ~email=Some("dev@example.com"), ~displayName=None) ==
      "dev@example.com",
    "email is the fallback identity label",
  )

  assertTrue(
    Cli.authDisplayName(~githubLogin=None, ~email=None, ~displayName=Some("Dev")) == "Dev",
    "display name is used when login and email are absent",
  )

  Console.log("Cli_test.res passed")
}
```

Update `test/Bin_test.mjs` so it still covers the wrapper without invoking a real OAuth run:

```js
import { existsSync, readFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";

const assert = (condition, label) => {
  if (!condition) {
    throw new Error(`Assertion failed: ${label}`);
  }
};

const packageJsonPath = new URL("../package.json", import.meta.url);
const wrapperUrl = new URL("../bin/rescript-bindings.mjs", import.meta.url);
const wrapperPath = fileURLToPath(wrapperUrl);
const packageJson = JSON.parse(readFileSync(packageJsonPath, "utf8"));

assert(
  packageJson.bin?.["rescript-bindings"] === "./bin/rescript-bindings.mjs",
  "package.json points the CLI bin at the wrapper",
);

assert(existsSync(wrapperPath), "CLI wrapper exists");

const wrapperSource = readFileSync(wrapperPath, "utf8");
assert(wrapperSource.startsWith("#!/usr/bin/env node\n"), "CLI wrapper starts with a Node shebang");

const wrapperMode = statSync(wrapperPath).mode;
assert((wrapperMode & 0o111) !== 0, "CLI wrapper is executable");

const originalArgv = process.argv;
const originalLog = console.log;
const loggedLines = [];

console.log = (...args) => {
  loggedLines.push(args.join(" "));
};

process.argv = [process.execPath, wrapperPath, "binding", "add", "is-even"];

try {
  await import(`${wrapperUrl.href}?bin-test`);
} finally {
  process.argv = originalArgv;
  console.log = originalLog;
}

assert(
  loggedLines.includes("Install package is-even"),
  "CLI wrapper launches the compiled add command",
);

console.log("Bin_test.mjs passed");
```

- [ ] **Step 2: Run the CLI tests to verify they fail**

Run: `npm run build && node test/Cli_test.res.mjs`
Expected: FAIL during ReScript compilation because `Cli.publishBaseUrlFrom` and `Cli.authDisplayName` do not exist yet.

- [ ] **Step 3: Implement typed auth interop and async publish command execution**

Create `src/core/PublishAuthTypes.res`:

```rescript
type authIdentity = {
  githubLogin: option<string>,
  displayName: option<string>,
  email: option<string>,
}
```

Create `src/bindings/PublishOAuth.res`:

```rescript
type config

@obj external makeConfig: (~publishBaseUrl: string) => config = ""

@module("../js/PublishOAuth.mjs")
external runPublishAuth: config => promise<PublishAuthTypes.authIdentity> = "runPublishAuth"
```

Modify `src/bindings/NodeProcess.res`:

```rescript
@module("node:process") external argv: array<string> = "argv"
@module("node:process") external cwd: unit => string = "cwd"
@module("node:process") external envGet: string => option<string> = "env"
@module("node:process") external exit: int => 'a = "exit"
```

Modify `src/Cli.res`:

```rescript
open RegistryTypes

let usage = () => {
  Console.log("Usage:")
  Console.log("  rescript binding add <package> [--folder <path>]")
  Console.log("  rescript binding publish")
}

let defaultInstallFolder = (~cwd: string, ~packageName: string, ~variantSlug: string): string =>
  NodePath.join4(cwd, "src", "bindings", NodePath.join2(packageName, variantSlug))

let ensureUploadReady = (files: array<fileEntry>): array<normalizedFileEntry> =>
  Validation.validateFileEntries(files)

let defaultPublishBaseUrl = "https://publish.bindings.rescript-lang.org"

let publishBaseUrlFrom = (override_: option<string>): string =>
  switch override_ {
  | Some(url) if url != "" => url
  | _ => defaultPublishBaseUrl
  }

let authDisplayName = (
  ~githubLogin: option<string>,
  ~email: option<string>,
  ~displayName: option<string>,
): string =>
  switch githubLogin {
  | Some(login) => login
  | None =>
    switch email {
    | Some(email) => email
    | None =>
      switch displayName {
      | Some(name) => name
      | None => "unknown-user"
      }
    }
  }

let runPublishAuthCheck = async (): unit => {
  let publishBaseUrl = publishBaseUrlFrom(NodeProcess.envGet("RESCRIPT_BINDINGS_PUBLISH_BASE_URL"))
  let identity = await PublishOAuth.runPublishAuth(PublishOAuth.makeConfig(~publishBaseUrl))
  let label =
    authDisplayName(
      ~githubLogin=identity.githubLogin,
      ~email=identity.email,
      ~displayName=identity.displayName,
    )
  Console.log("Authenticated as " ++ label)
}

let parse = (argv: array<string>): option<(string, string, option<string>)> => {
  switch argv {
  | [_, _, "binding", "add", packageName] => Some(("add", packageName, None))
  | [_, _, "binding", "add", packageName, "--folder", folder] => Some(("add", packageName, Some(folder)))
  | [_, _, "binding", "publish"] => Some(("publish", "", None))
  | _ => None
  }
}
```

Modify `src/Main.res`:

```rescript
let run = async (): unit => {
  switch Cli.parse(NodeProcess.argv) {
  | Some(("add", packageName, folder)) => {
      switch folder {
      | Some(path) => Console.log("Install package " ++ packageName ++ " to " ++ path)
      | None => Console.log("Install package " ++ packageName)
      }
    }
  | Some(("publish", _, _)) => await Cli.runPublishAuthCheck()
  | _ => Cli.usage()
  }
}

let () = {
  run()
  ->Promise.catch(err => {
    let message =
      switch err {
      | Exn.Error(jsError) =>
        switch Exn.message(jsError) {
        | Some(text) => text
        | None => "Publish auth failed"
        }
      | _ => "Publish auth failed"
      }
    Console.log(message)
    NodeProcess.exit(1)
  })
  ->ignore
}
```

- [ ] **Step 4: Run the CLI tests to verify they pass**

Run: `npm run build && node test/Cli_test.res.mjs && node test/Bin_test.mjs`
Expected: PASS with final lines `Cli_test.res passed` and `Bin_test.mjs passed`

- [ ] **Step 5: Commit**

```bash
git add src/core/PublishAuthTypes.res src/bindings/PublishOAuth.res src/bindings/NodeProcess.res src/Cli.res src/Main.res test/Cli_test.res test/Bin_test.mjs
git commit -m "feat: wire publish oauth into cli"
```

### Task 4: Worker `/v1/me` Endpoint And Test Suite Wiring

**Files:**

- Modify: `src/Worker.res`
- Create: `src/Worker.mjs`
- Create: `test/Worker_test.mjs`
- Modify: `package.json`

- [ ] **Step 1: Write the failing Worker endpoint test**

```js
import worker from "../src/Worker.mjs";

const assert = (condition, label) => {
  if (!condition) {
    throw new Error(`Assertion failed: ${label}`);
  }
};

const encodeSegment = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");

const makeJwt = (payload) =>
  `${encodeSegment({ alg: "none", typ: "JWT" })}.${encodeSegment(payload)}.signature`;

const unauthorized = await worker.fetch(new Request("https://publish.example.com/v1/me"), {}, {});
assert(unauthorized.status === 401, "missing access identity is rejected");

const authorized = await worker.fetch(
  new Request("https://publish.example.com/v1/me", {
    headers: {
      "Cf-Access-Jwt-Assertion": makeJwt({ email: "dev@example.com" }),
    },
  }),
  {},
  {},
);

assert(authorized.status === 200, "access jwt allows /v1/me");

const body = await authorized.json();
assert(body.email === "dev@example.com", "worker returns the email claim");
assert(body.githubLogin === null, "worker leaves github login null in this slice");
assert(body.access?.authenticated === true, "worker marks response as authenticated");

console.log("Worker_test.mjs passed");
```

- [ ] **Step 2: Run the Worker test to verify it fails**

Run: `npm run build && node test/Worker_test.mjs`
Expected: FAIL with `ERR_MODULE_NOT_FOUND` because `src/Worker.mjs` does not exist yet.

- [ ] **Step 3: Implement the Worker runtime shim and protected `/v1/me`**

Modify `src/Worker.res`:

```rescript
open RegistryTypes

@send external startsWith: (string, string) => bool = "startsWith"
@send external endsWith: (string, string) => bool = "endsWith"
@send external split: (string, string) => array<string> = "split"
@send external arraySliceFrom: (array<'a>, int) => array<'a> = "slice"
@send external sortInPlaceWith: (array<'a>, ('a, 'a) => int) => unit = "sort"

let getAt = (items: array<'a>, index: int): option<'a> =>
  if index < 0 || index >= items->Array.length {
    None
  } else {
    items[index]
  }

let computeCompatibility = (
  release: release,
  packageVersion: option<string>,
  rescriptVersion: option<string>,
): releaseWithCompatibility => {
  let isPackageCompatible =
    switch packageVersion {
    | None => None
    | Some(version) => Some(version == release.peerPackageRange)
    }

  let isRescriptCompatible =
    switch rescriptVersion {
    | None => None
    | Some(version) => Some(version == release.rescriptRange)
    }

  let packageScore = switch isPackageCompatible { | Some(true) => 2 | _ => 0 }
  let rescriptScore = switch isRescriptCompatible { | Some(true) => 1 | _ => 0 }

  {
    release,
    isPackageCompatible,
    isRescriptCompatible,
    compatibilityRank: packageScore + rescriptScore,
  }
}

let sortByCompatibility = (items: array<releaseWithCompatibility>): array<releaseWithCompatibility> => {
  let sorted = arraySliceFrom(items, 0)
  sortInPlaceWith(sorted, (a, b) => b.compatibilityRank - a.compatibilityRank)
  sorted
}

type route =
  | ListPackageReleases(string)
  | GetRelease(string)
  | Me
  | Publish
  | AdminPublishers
  | NotFound

let routeFrom = (method_: string, pathname: string): route => {
  if method_ == "GET" && startsWith(pathname, "/v1/packages/") && endsWith(pathname, "/releases") {
    let parts = split(pathname, "/")
    switch getAt(parts, 3) {
    | Some(packageName) => ListPackageReleases(packageName)
    | None => NotFound
    }
  } else if method_ == "GET" && startsWith(pathname, "/v1/releases/") {
    let parts = split(pathname, "/")
    switch getAt(parts, 3) {
    | Some(releaseId) => GetRelease(releaseId)
    | None => NotFound
    }
  } else if method_ == "GET" && pathname == "/v1/me" {
    Me
  } else if method_ == "POST" && pathname == "/v1/releases" {
    Publish
  } else if method_ == "POST" && pathname == "/v1/admin/publishers" {
    AdminPublishers
  } else {
    NotFound
  }
}

let isProtectedRoute = route =>
  switch route {
  | Me | Publish | AdminPublishers => true
  | ListPackageReleases(_) | GetRelease(_) | NotFound => false
  }

let validatePublishInput = (input: publishInput): array<normalizedFileEntry> => {
  if input.packageName == "" || input.variantLabel == "" {
    throw(Validation.ValidationError("Missing required publish fields"))
  }

  if !Validation.rangeLooksValid(input.peerPackageRange) || !Validation.rangeLooksValid(input.rescriptRange) {
    throw(Validation.ValidationError("Invalid semver range fields"))
  }

  Validation.validateFileEntries(input.files)
}
```

Create `src/Worker.mjs`:

```js
import { isProtectedRoute, routeFrom } from "./Worker.res.mjs";

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });

const decodeJwtPayload = (assertion) => {
  const parts = assertion.split(".");
  if (parts.length < 2) {
    throw new Error("Invalid Access JWT");
  }

  return JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
};

const currentIdentity = (request) => {
  const assertion = request.headers.get("Cf-Access-Jwt-Assertion");
  if (!assertion) {
    return null;
  }

  const payload = decodeJwtPayload(assertion);

  return {
    githubLogin: null,
    displayName: null,
    email: payload.email ?? null,
    access: { authenticated: true },
  };
};

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const route = routeFrom(request.method, url.pathname);

    if (isProtectedRoute(route) && !request.headers.get("Cf-Access-Jwt-Assertion")) {
      return json({ error: "Missing Access identity" }, 401);
    }

    switch (route) {
      case "Me": {
        const identity = currentIdentity(request);
        if (!identity) {
          return json({ error: "Missing Access identity" }, 401);
        }

        return json(identity);
      }

      default:
        return json({ error: "Not found" }, 404);
    }
  },
};
```

Update `package.json` so the full test suite includes the Worker test:

```json
{
  "scripts": {
    "build": "rescript build",
    "clean": "rescript clean",
    "test": "rescript build && node test/Validation_test.res.mjs && node test/Cli_test.res.mjs && node test/PublishOAuth_test.mjs && node test/Worker_test.mjs && node test/Bin_test.mjs && node test/D1_test.mjs"
  }
}
```

- [ ] **Step 4: Run the Worker test and full suite to verify they pass**

Run: `npm test`
Expected:

- `Validation_test.res passed`
- `Cli_test.res passed`
- `PublishOAuth_test.mjs passed`
- `Worker_test.mjs passed`
- `Bin_test.mjs passed`
- `D1_test.mjs passed`

- [ ] **Step 5: Commit**

```bash
git add src/Worker.res src/Worker.mjs test/Worker_test.mjs package.json
git commit -m "feat: add worker me endpoint for publish auth"
```

## Manual Verification

1. In Cloudflare Zero Trust, confirm the publish Access app has Managed OAuth enabled and dynamic client registration enabled for localhost and loopback clients.
2. In Cloudflare Access, verify the publish hostname metadata advertises `registration_endpoint` by opening `https://<publish-hostname>/.well-known/oauth-authorization-server`.
3. Run `npm test`.
4. Deploy the Worker with `npx wrangler deploy`.
5. Run `node ./bin/rescript-bindings.mjs binding publish`.
6. Confirm the browser opens to the GitHub-backed Access login.
7. Complete login and confirm the terminal prints `Authenticated as <value>`.
8. Verify the cache file exists at the expected user-level path for the current OS.
9. Run `node ./bin/rescript-bindings.mjs binding publish` again.
10. Confirm the second run succeeds without reopening the browser while the cached token is still valid.
