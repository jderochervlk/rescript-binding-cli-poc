import { EventEmitter } from "node:events"
import {
  cacheFilePathFor,
  defaultOpenBrowser,
  isAccessTokenUsable,
  publishBaseUrl,
  readOAuthCallback,
  runPublish,
  runPublishAuth,
  selectAuthStrategy,
} from "../src/bindings/PublishOAuth.res.mjs"

const authorizationServerMetadataUrl =
  "https://team.cloudflareaccess.com/.well-known/oauth-authorization-server"
const resourceMetadataUrl =
  "https://rescript-binding-registry.josh-401.workers.dev/.well-known/cloudflare-access-protected-resource/api/publish/v1/me"
const authorizationServerMetadata = {
  authorization_endpoint: "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/authorization",
  token_endpoint: "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/token",
  registration_endpoint: "https://team.cloudflareaccess.com/cdn-cgi/access/oauth/registration",
}
const resourceMetadata = {
  resource: `${publishBaseUrl}/v1/me`,
  protected: true,
  team_domain: "team.cloudflareaccess.com",
  authorization_servers: ["https://team.cloudflareaccess.com"],
}

const assert = (condition, label) => {
  if (!condition) {
    throw new Error(`Assertion failed: ${label}`)
  }
}

const jsonResponse = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  })

const discoveryResponseFor = (url, init = {}) => {
  if (url === `${publishBaseUrl}/v1/me` && init.redirect === "manual") {
    return new Response(null, {
      status: 302,
      headers: {
        "www-authenticate": `Cloudflare-Access resource_metadata="${resourceMetadataUrl}"`,
      },
    })
  }

  if (url === resourceMetadataUrl) {
    return jsonResponse(resourceMetadata)
  }

  if (url === authorizationServerMetadataUrl) {
    return jsonResponse(authorizationServerMetadata)
  }

  return null
}

const now = 1_716_000_000_000

assert(
  cacheFilePathFor({
    platform: "linux",
    homeDir: "/home/josh",
    hostname: "rescript-binding-registry.josh-401.workers.dev",
  }) ===
    "/home/josh/.local/state/rescript-bindings/oauth/rescript-binding-registry.josh-401.workers.dev.json",
  "linux cache path uses XDG state directory"
)

assert(
  cacheFilePathFor({
    platform: "darwin",
    homeDir: "/Users/josh",
    hostname: "rescript-binding-registry.josh-401.workers.dev",
  }) ===
    "/Users/josh/Library/Application Support/rescript-bindings/oauth/rescript-binding-registry.josh-401.workers.dev.json",
  "macOS cache path uses Application Support"
)

assert(
  cacheFilePathFor({
    platform: "win32",
    homeDir: "C:/Users/josh/AppData/Roaming",
    hostname: "rescript-binding-registry.josh-401.workers.dev",
  }) ===
    "C:/Users/josh/AppData/Roaming/rescript-bindings/oauth/rescript-binding-registry.josh-401.workers.dev.json",
  "windows cache path uses roaming app data"
)

assert(
  cacheFilePathFor({
    platform: "win32",
    homeDir: "C:\\Users\\josh\\AppData\\Roaming",
    hostname: "rescript-binding-registry.josh-401.workers.dev",
  }) ===
    "C:/Users/josh/AppData/Roaming/rescript-bindings/oauth/rescript-binding-registry.josh-401.workers.dev.json",
  "windows cache path normalizes backslash base paths"
)

assert(
  isAccessTokenUsable({ accessToken: "token", expiresAt: now + 120_000 }, now),
  "access token with more than one minute remaining is reusable"
)

assert(
  !isAccessTokenUsable({ accessToken: "token", expiresAt: now + 10_000 }, now),
  "nearly expired access token is not reusable"
)

assert(
  selectAuthStrategy({ accessToken: "token", expiresAt: now + 120_000 }, now) === "reuse",
  "valid access token uses reuse path"
)

assert(
  selectAuthStrategy(
    { accessToken: "token", expiresAt: now - 1_000, refreshToken: "refresh" },
    now
  ) === "refresh",
  "expired access token with refresh token uses refresh path"
)

assert(selectAuthStrategy(null, now) === "interactive", "missing bundle uses interactive path")

const missingBrowserLogs = []

await defaultOpenBrowser("https://example.com/auth", {
  platform: "linux",
  spawn: () => {
    const child = new EventEmitter()
    queueMicrotask(() => {
      const error = new Error("spawn xdg-open ENOENT")
      error.code = "ENOENT"
      child.emit("error", error)
    })
    return child
  },
  log: message => {
    missingBrowserLogs.push(message)
  },
})

assert(
  missingBrowserLogs.some(message => message.includes("https://example.com/auth")),
  "missing browser opener prints the auth URL instead of failing"
)

try {
  readOAuthCallback({
    callbackUrl: new URL("http://127.0.0.1:43123/callback"),
    expectedState: "expected-state",
  })
} catch (error) {
  assert(
    error.message.includes("Callback query was empty"),
    "missing callback query reports that the query was empty"
  )
}

try {
  readOAuthCallback({
    callbackUrl: new URL(
      "http://127.0.0.1:43123/callback?error=access_denied&error_description=Denied"
    ),
    expectedState: "expected-state",
  })
} catch (error) {
  assert(
    error.message.includes("OAuth callback error: access_denied: Denied"),
    "OAuth callback error query is surfaced"
  )
}

assert(
  readOAuthCallback({
    callbackUrl: new URL("http://127.0.0.1:43123/callback?code=auth-code&state=expected-state"),
    expectedState: "expected-state",
  }).code === "auth-code",
  "valid OAuth callback returns the authorization code"
)

let reuseMeAuth = null

const reuseResult = await runPublishAuth({
  deps: {
    now: () => now,
    platform: "linux",
    homeDir: "/home/josh",
    readCache: async () => ({
      accessToken: "cached-token",
      refreshToken: "oauth:refresh-token",
      expiresAt: now + 120_000,
      clientId: "registered-client",
    }),
    writeCache: async () => {
      throw new Error("reuse flow should not persist cache")
    },
    fetch: async (url, init = {}) => {
      if (url === `${publishBaseUrl}/v1/me`) {
        reuseMeAuth = init.headers.Authorization
        return jsonResponse({
          githubLogin: "cached-dev",
          displayName: null,
          email: "cached@example.com",
          access: { authenticated: true },
        })
      }

      throw new Error(`Unexpected URL in reuse flow: ${url}`)
    },
    openBrowser: async () => {
      throw new Error("reuse flow should not open a browser")
    },
    createLoopbackServer: async () => {
      throw new Error("reuse flow should not start loopback server")
    },
  },
})

assert(reuseMeAuth === "Bearer cached-token", "reuse flow uses cached bearer token for /v1/me")
assert(reuseResult.githubLogin === "cached-dev", "reuse flow returns cached identity result")

let refreshTokenBody = null
let refreshWrite = null
let refreshMeAuth = null

const refreshResult = await runPublishAuth({
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
      refreshWrite = { cachePath, bundle }
    },
    fetch: async (url, init = {}) => {
      const discoveryResponse = discoveryResponseFor(url, init)
      if (discoveryResponse) {
        return discoveryResponse
      }

      if (url === authorizationServerMetadata.token_endpoint) {
        refreshTokenBody = init.body
        return jsonResponse({
          access_token: "fresh-token",
          refresh_token: "oauth:new-refresh-token",
          expires_in: 300,
        })
      }

      if (url === `${publishBaseUrl}/v1/me`) {
        refreshMeAuth = init.headers.Authorization
        return jsonResponse({
          githubLogin: null,
          displayName: null,
          email: "dev@example.com",
          access: { authenticated: true },
        })
      }

      throw new Error(`Unexpected URL in refresh flow: ${url}`)
    },
    openBrowser: async () => {
      throw new Error("refresh flow should not open a browser")
    },
    createLoopbackServer: async () => {
      throw new Error("refresh flow should not start loopback server")
    },
  },
})

assert(
  refreshTokenBody.includes("grant_type=refresh_token"),
  "refresh token request uses refresh_token grant"
)
assert(
  refreshTokenBody.includes("client_id=registered-client"),
  "refresh token request includes client_id"
)
assert(refreshMeAuth === "Bearer fresh-token", "refresh flow uses bearer token for /v1/me")
assert(refreshResult.email === "dev@example.com", "refresh flow returns authenticated identity")
assert(refreshWrite.bundle.accessToken === "fresh-token", "refresh flow persists updated access token")

let refreshFailureMessage = null

try {
  await runPublishAuth({
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
      writeCache: async () => {
        throw new Error("refresh failure should not persist cache")
      },
      fetch: async (url, init = {}) => {
        const discoveryResponse = discoveryResponseFor(url, init)
        if (discoveryResponse) {
          return discoveryResponse
        }

        if (url === authorizationServerMetadata.token_endpoint) {
          return jsonResponse({ message: "Bad refresh request" }, 400)
        }

        throw new Error(`Unexpected URL in refresh failure flow: ${url}`)
      },
      openBrowser: async () => {
        throw new Error("non-auth refresh failure should not fall back to browser auth")
      },
      createLoopbackServer: async () => {
        throw new Error("non-auth refresh failure should not start loopback server")
      },
    },
  })
} catch (error) {
  refreshFailureMessage = error.message
}

assert(
  refreshFailureMessage === "Bad refresh request",
  "generic bad refresh requests are surfaced instead of falling back to interactive auth"
)

let invalidGrantOpenedUrl = null
const invalidGrantTokenBodies = []
let invalidGrantWrite = null

const invalidGrantResult = await runPublishAuth({
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
      invalidGrantWrite = { cachePath, bundle }
    },
    randomString: () => "invalid-grant-state",
    codeVerifier: () => "invalid-grant-verifier",
    codeChallengeFromVerifier: () => "invalid-grant-challenge",
    fetch: async (url, init = {}) => {
      const discoveryResponse = discoveryResponseFor(url, init)
      if (discoveryResponse) {
        return discoveryResponse
      }

      if (url === authorizationServerMetadata.registration_endpoint) {
        return jsonResponse({
          client_id: "interactive-after-invalid-grant-client",
          redirect_uris: ["http://127.0.0.1:43125/callback"],
        })
      }

      if (url === authorizationServerMetadata.token_endpoint) {
        invalidGrantTokenBodies.push(init.body)

        if (invalidGrantTokenBodies.length === 1) {
          return jsonResponse({ error: "invalid_grant" }, 400)
        }

        return jsonResponse({
          access_token: "interactive-after-invalid-grant",
          refresh_token: "oauth:interactive-after-invalid-grant",
          expires_in: 300,
        })
      }

      if (url === `${publishBaseUrl}/v1/me`) {
        return jsonResponse({
          githubLogin: null,
          displayName: "Invalid Grant Recovery Dev",
          email: "invalid-grant@example.com",
          access: { authenticated: true },
        })
      }

      throw new Error(`Unexpected URL in invalid-grant recovery flow: ${url}`)
    },
    createLoopbackServer: async ({ expectedState }) => {
      assert(expectedState === "invalid-grant-state", "invalid grant recovery uses expected state")
      return {
        redirectUri: "http://127.0.0.1:43125/callback",
        waitForCode: async () => ({
          code: "invalid-grant-auth-code",
          state: "invalid-grant-state",
        }),
        close: async () => {},
      }
    },
    openBrowser: async url => {
      invalidGrantOpenedUrl = url
    },
  },
})

assert(
  invalidGrantTokenBodies[0].includes("grant_type=refresh_token"),
  "invalid_grant first fails on refresh token exchange"
)
assert(
  invalidGrantTokenBodies[1].includes("grant_type=authorization_code"),
  "invalid_grant falls back to interactive code exchange"
)
assert(invalidGrantOpenedUrl !== null, "invalid_grant falls back to browser auth")
assert(
  invalidGrantWrite.bundle.refreshToken === "oauth:interactive-after-invalid-grant",
  "invalid_grant fallback persists the interactive refresh token"
)
assert(
  invalidGrantResult.displayName === "Invalid Grant Recovery Dev",
  "invalid_grant fallback returns the interactive identity"
)

let revokedTokenBody = null
let revokedWrite = null
const revokedMeAuth = []

const revokedResult = await runPublishAuth({
  deps: {
    now: () => now,
    platform: "linux",
    homeDir: "/home/josh",
    readCache: async () => ({
      accessToken: "cached-token",
      refreshToken: "oauth:refresh-token",
      expiresAt: now + 120_000,
      clientId: "registered-client",
    }),
    writeCache: async (cachePath, bundle) => {
      revokedWrite = { cachePath, bundle }
    },
    fetch: async (url, init = {}) => {
      const discoveryResponse = discoveryResponseFor(url, init)
      if (discoveryResponse) {
        return discoveryResponse
      }

      if (url === authorizationServerMetadata.token_endpoint) {
        revokedTokenBody = init.body
        return jsonResponse({
          access_token: "recovered-token",
          refresh_token: "oauth:recovered-refresh",
          expires_in: 300,
        })
      }

      if (url === `${publishBaseUrl}/v1/me`) {
        revokedMeAuth.push(init.headers.Authorization)

        if (revokedMeAuth.length === 1) {
          return new Response("Unauthorized", { status: 401 })
        }

        return jsonResponse({
          githubLogin: null,
          displayName: "Recovered Dev",
          email: "recovered@example.com",
          access: { authenticated: true },
        })
      }

      throw new Error(`Unexpected URL in revoked-token flow: ${url}`)
    },
    openBrowser: async () => {
      throw new Error("revoked-token recovery should not open a browser")
    },
    createLoopbackServer: async () => {
      throw new Error("revoked-token recovery should not start loopback server")
    },
  },
})

assert(revokedMeAuth[0] === "Bearer cached-token", "revoked flow first tries the cached access token")
assert(revokedTokenBody.includes("grant_type=refresh_token"), "revoked flow falls back to refresh")
assert(revokedMeAuth[1] === "Bearer recovered-token", "revoked flow retries /v1/me with refreshed token")
assert(
  revokedWrite.bundle.refreshToken === "oauth:recovered-refresh",
  "revoked flow persists the recovered refresh token"
)
assert(revokedResult.displayName === "Recovered Dev", "revoked flow returns the recovered identity")

let openedRecoveryUrl = null
let recoveryWrite = null
let recoveryTokenBody = null

const recoveryResult = await runPublishAuth({
  deps: {
    now: () => now,
    platform: "linux",
    homeDir: "/home/josh",
    readCache: async () => ({
      accessToken: "expired-token",
      refreshToken: "oauth:refresh-token",
      expiresAt: now - 1_000,
    }),
    writeCache: async (cachePath, bundle) => {
      recoveryWrite = { cachePath, bundle }
    },
    randomString: () => "fixed-recovery-state",
    codeVerifier: () => "fixed-recovery-verifier",
    codeChallengeFromVerifier: () => "fixed-recovery-challenge",
    fetch: async (url, init = {}) => {
      const discoveryResponse = discoveryResponseFor(url, init)
      if (discoveryResponse) {
        return discoveryResponse
      }

      if (url === authorizationServerMetadata.registration_endpoint) {
        return jsonResponse({
          client_id: "interactive-client",
          redirect_uris: ["http://127.0.0.1:43124/callback"],
        })
      }

      if (url === authorizationServerMetadata.token_endpoint) {
        recoveryTokenBody = init.body
        return jsonResponse({
          access_token: "interactive-after-incomplete",
          refresh_token: "oauth:interactive-recovery",
          expires_in: 300,
        })
      }

      if (url === `${publishBaseUrl}/v1/me`) {
        return jsonResponse({
          githubLogin: null,
          displayName: "Recovered Interactive Dev",
          email: "recovery@example.com",
          access: { authenticated: true },
        })
      }

      throw new Error(`Unexpected URL in incomplete-refresh recovery flow: ${url}`)
    },
    createLoopbackServer: async ({ expectedState }) => {
      assert(
        expectedState === "fixed-recovery-state",
        "recovery loopback server receives expected OAuth state"
      )
      return {
        redirectUri: "http://127.0.0.1:43124/callback",
        waitForCode: async () => ({
          code: "recovery-auth-code",
          state: "fixed-recovery-state",
        }),
        close: async () => {},
      }
    },
    openBrowser: async url => {
      openedRecoveryUrl = url
    },
  },
})

assert(
  recoveryTokenBody.includes("grant_type=authorization_code"),
  "missing clientId falls back to interactive code exchange"
)
assert(openedRecoveryUrl !== null, "missing clientId falls back to browser auth")
assert(
  recoveryWrite.bundle.refreshToken === "oauth:interactive-recovery",
  "interactive recovery persists the refresh token"
)
assert(
  recoveryResult.displayName === "Recovered Interactive Dev",
  "missing clientId falls back to the interactive identity flow"
)

let openedUrl = null
let savedInteractiveBundle = null
let interactiveMeAuth = null

const interactiveResult = await runPublishAuth({
  deps: {
    now: () => now,
    platform: "linux",
    homeDir: "/home/josh",
    readCache: async () => null,
    writeCache: async (cachePath, bundle) => {
      savedInteractiveBundle = { cachePath, bundle }
    },
    randomString: () => "fixed-state-token",
    codeVerifier: () => "fixed-code-verifier",
    codeChallengeFromVerifier: () => "fixed-code-challenge",
    fetch: async (url, init = {}) => {
      const discoveryResponse = discoveryResponseFor(url, init)
      if (discoveryResponse) {
        return discoveryResponse
      }

      if (url === authorizationServerMetadata.registration_endpoint) {
        return jsonResponse({
          client_id: "dynamic-client",
          redirect_uris: ["http://127.0.0.1:43123/callback"],
        })
      }

      if (url === authorizationServerMetadata.token_endpoint) {
        return jsonResponse({
          access_token: "interactive-token",
          refresh_token: "oauth:interactive-refresh",
          expires_in: 300,
        })
      }

      if (url === `${publishBaseUrl}/v1/me`) {
        interactiveMeAuth = init.headers.Authorization
        return jsonResponse({
          githubLogin: null,
          displayName: "Interactive Dev",
          email: "interactive@example.com",
          access: { authenticated: true },
        })
      }

      throw new Error(`Unexpected URL in interactive flow: ${url}`)
    },
    createLoopbackServer: async ({ expectedState }) => {
      assert(expectedState === "fixed-state-token", "loopback server receives expected OAuth state")
      return {
        redirectUri: "http://127.0.0.1:43123/callback",
        waitForCode: async () => ({
          code: "auth-code",
          state: "fixed-state-token",
        }),
        close: async () => {},
      }
    },
    openBrowser: async url => {
      openedUrl = url
    },
  },
})

const interactiveAuthorizationUrl = new URL(openedUrl)

assert(
  interactiveAuthorizationUrl.searchParams.get("client_id") === "dynamic-client",
  "interactive flow opens browser with registered client_id"
)
assert(
  interactiveAuthorizationUrl.searchParams.get("code_challenge") === "fixed-code-challenge",
  "interactive flow uses PKCE challenge"
)
assert(
  interactiveAuthorizationUrl.searchParams.get("resource") === `${publishBaseUrl}/v1/me`,
  "interactive flow sends resource indicator"
)
assert(
  interactiveAuthorizationUrl.searchParams.get("code_challenge_method") === "S256",
  "interactive flow sets the PKCE challenge method"
)
assert(
  interactiveAuthorizationUrl.searchParams.get("state") === "fixed-state-token",
  "interactive flow sets the OAuth state"
)
assert(
  interactiveMeAuth === "Bearer interactive-token",
  "interactive flow uses bearer token for /v1/me"
)
assert(
  interactiveResult.displayName === "Interactive Dev",
  "interactive flow returns authenticated identity"
)
assert(
  savedInteractiveBundle.bundle.refreshToken === "oauth:interactive-refresh",
  "interactive flow persists refresh token"
)

const publishCancelLogs = []
const originalLogForCancel = console.log
console.log = message => {
  publishCancelLogs.push(String(message))
}

try {
  await runPublish({
    deps: {
      fetch: async () => {
        throw new Error("cancelled publish should not call fetch")
      },
      promptForPublishInput: async () => null,
    },
  })
} finally {
  console.log = originalLogForCancel
}

assert(
  publishCancelLogs.includes("Publish cancelled."),
  "publish cancellation returns before authentication"
)

let publishPostAuth = null
let publishPostBody = null
const publishLogs = []
const originalLogForPublish = console.log
console.log = message => {
  publishLogs.push(String(message))
}

try {
  await runPublish({
    deps: {
      now: () => now,
      platform: "linux",
      homeDir: "/home/josh",
      readCache: async () => ({
        accessToken: "publish-token",
        refreshToken: "oauth:publish-refresh",
        expiresAt: now + 120_000,
        clientId: "publish-client",
      }),
      writeCache: async () => {
        throw new Error("publish with reusable token should not persist cache")
      },
      fetch: async (url, init = {}) => {
        if (url === `${publishBaseUrl}/v1/me`) {
          return jsonResponse({
            githubLogin: null,
            displayName: "Publish Dev",
            email: "publish@example.com",
            access: { authenticated: true },
          })
        }

        if (url === `${publishBaseUrl}/v1/releases`) {
          publishPostAuth = init.headers.Authorization
          publishPostBody = JSON.parse(init.body)
          return jsonResponse(
            {
              releaseId: "published-release",
              packageName: "@inquirer/prompts",
              variantLabel: "isEven",
              fileCount: 1,
              duplicate: false,
            },
            201
          )
        }

        throw new Error(`Unexpected URL in publish flow: ${url}`)
      },
      openBrowser: async () => {
        throw new Error("publish with reusable token should not open browser")
      },
      createLoopbackServer: async () => {
        throw new Error("publish with reusable token should not create loopback server")
      },
      promptForPublishInput: async () => ({
        packageName: "@inquirer/prompts",
        variantLabel: "isEven",
        peerPackageRange: "^8.4.2",
        rescriptRange: "^12.0.0",
        files: [{ relativePath: "isEven.res", content: "let x = 1\n" }],
      }),
    },
  })
} finally {
  console.log = originalLogForPublish
}

assert(publishPostAuth === "Bearer publish-token", "publish sends the cached bearer token")
assert(
  publishPostBody.packageName === "@inquirer/prompts",
  "publish posts the prompted package name"
)
assert(
  publishPostBody.files[0].relativePath === "isEven.res",
  "publish posts prompted file entries"
)
assert(
  publishLogs.includes("Published release: published-release"),
  "publish prints the release id"
)
assert(
  publishLogs.includes("@inquirer/prompts (1 file)"),
  "publish prints a package-only success summary"
)
assert(
  !publishLogs.some(message => message.includes("@inquirer/prompts/isEven")),
  "publish success summary does not include variant or source filename"
)

console.log("PublishOAuth_test.mjs passed")
