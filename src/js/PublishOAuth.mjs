import { spawn } from "node:child_process"
import { createHash, randomBytes } from "node:crypto"
import { mkdir, readFile, writeFile } from "node:fs/promises"
import { createServer } from "node:http"
import { homedir } from "node:os"
import path from "node:path"

const joinPath = path.posix.join
const dirnamePath = path.posix.dirname
const normalizeBasePath = homeDir => homeDir.replaceAll("\\", "/")

export const cacheFilePathFor = ({
  platform = process.platform,
  homeDir = homedir(),
  hostname,
}) => {
  if (!hostname) {
    throw new Error("cacheFilePathFor requires a hostname")
  }

  const normalizedHomeDir = normalizeBasePath(homeDir)

  if (platform === "darwin") {
    return joinPath(
      normalizedHomeDir,
      "Library",
      "Application Support",
      "rescript-bindings",
      "oauth",
      `${hostname}.json`
    )
  }

  if (platform === "win32") {
    return joinPath(normalizedHomeDir, "rescript-bindings", "oauth", `${hostname}.json`)
  }

  return joinPath(
    normalizedHomeDir,
    ".local",
    "state",
    "rescript-bindings",
    "oauth",
    `${hostname}.json`
  )
}

export const isAccessTokenUsable = (bundle, now = Date.now()) => {
  if (!bundle?.accessToken || typeof bundle.expiresAt !== "number") {
    return false
  }

  return bundle.expiresAt - now > 60_000
}

export const selectAuthStrategy = (bundle, now = Date.now()) => {
  if (isAccessTokenUsable(bundle, now)) {
    return "reuse"
  }

  if (bundle?.refreshToken) {
    return "refresh"
  }

  return "interactive"
}

export const codeChallengeFromVerifier = verifier =>
  createHash("sha256").update(verifier).digest("base64url")

const defaultRandomString = () => randomBytes(24).toString("hex")
const defaultCodeVerifier = () => randomBytes(48).toString("base64url")

const defaultReadCache = async cachePath => {
  try {
    const contents = await readFile(cachePath, "utf8")
    return JSON.parse(contents)
  } catch (error) {
    if (error?.code === "ENOENT") {
      return null
    }

    if (error instanceof SyntaxError) {
      return null
    }

    throw error
  }
}

const defaultWriteCache = async (cachePath, bundle) => {
  await mkdir(dirnamePath(cachePath), { recursive: true })
  await writeFile(cachePath, JSON.stringify(bundle, null, 2), { mode: 0o600 })
}

const defaultOpenBrowser = async url => {
  const command =
    process.platform === "darwin"
      ? ["open", [url]]
      : process.platform === "win32"
        ? ["cmd", ["/c", "start", "", url]]
        : ["xdg-open", [url]]

  await new Promise((resolve, reject) => {
    const child = spawn(command[0], command[1], { stdio: "ignore" })
    child.once("error", reject)
    child.once("close", code => {
      if (code === 0) {
        resolve()
      } else {
        reject(new Error(`Browser command exited with code ${code}`))
      }
    })
  })
}

const defaultCreateLoopbackServer = async ({ expectedState }) => {
  let resolveCode
  let rejectCode
  const result = new Promise((resolve, reject) => {
    resolveCode = resolve
    rejectCode = reject
  })

  const server = createServer((request, response) => {
    const callbackUrl = new URL(request.url, "http://127.0.0.1")

    if (callbackUrl.pathname !== "/callback") {
      response.statusCode = 404
      response.end("Not found")
      return
    }

    const code = callbackUrl.searchParams.get("code")
    const state = callbackUrl.searchParams.get("state")

    if (!code || !state) {
      response.statusCode = 400
      response.end("Missing code or state")
      rejectCode(new Error("OAuth callback missing code or state"))
      return
    }

    if (state !== expectedState) {
      response.statusCode = 400
      response.end("State mismatch")
      rejectCode(new Error("OAuth state validation failed"))
      return
    }

    response.statusCode = 200
    response.end("Authentication complete. You can return to the terminal.")
    resolveCode({ code, state })
  })

  await new Promise((resolve, reject) => {
    server.once("error", reject)
    server.listen(0, "127.0.0.1", resolve)
  })

  const address = server.address()
  if (!address || typeof address === "string") {
    throw new Error("Failed to allocate loopback callback port")
  }

  return {
    redirectUri: `http://127.0.0.1:${address.port}/callback`,
    waitForCode: async () => result,
    close: async () =>
      new Promise((resolve, reject) => {
        server.close(error => {
          if (error) {
            reject(error)
          } else {
            resolve()
          }
        })
      }),
  }
}

const readJson = async response => {
  if (response.ok) {
    return response.json()
  }

  const contentType = response.headers.get("content-type") ?? ""

  if (contentType.includes("application/json")) {
    const payload = await response.json()
    const error = new Error(payload?.error || payload?.message || `HTTP ${response.status}`)
    error.status = response.status
    error.payload = payload
    throw error
  }

  const body = await response.text()
  const error = new Error(body || `HTTP ${response.status}`)
  error.status = response.status
  throw error
}

const canRefreshFromBundle = bundle => Boolean(bundle?.refreshToken && bundle?.clientId)
const isAuthFailure = error => error?.status === 401 || error?.status === 403
const isInteractiveRecoveryError = error =>
  isAuthFailure(error) ||
  error?.payload?.error === "invalid_grant" ||
  error?.payload?.error === "invalid_client"

const discoverAuthorizationServer = async ({ publishBaseUrl, fetchImpl }) => {
  const metadataUrl = new URL("/.well-known/oauth-authorization-server", publishBaseUrl)
  const response = await fetchImpl(metadataUrl.toString(), {})
  return readJson(response)
}

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
  })

  return readJson(response)
}

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
  })

  const response = await fetchImpl(metadata.token_endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  })

  return readJson(response)
}

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
  })

  const response = await fetchImpl(metadata.token_endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  })

  return readJson(response)
}

const buildTokenBundle = ({ tokenResponse, metadata, clientId, publishBaseUrl, now, previous }) => ({
  accessToken: tokenResponse.access_token,
  refreshToken: tokenResponse.refresh_token ?? previous?.refreshToken ?? null,
  expiresAt: now + tokenResponse.expires_in * 1000,
  tokenEndpoint: metadata.token_endpoint,
  authorizationEndpoint: metadata.authorization_endpoint,
  registrationEndpoint: metadata.registration_endpoint,
  clientId,
  resource: publishBaseUrl,
  publishBaseUrl,
})

const fetchCurrentIdentity = async ({ publishBaseUrl, accessToken, fetchImpl }) => {
  const response = await fetchImpl(`${publishBaseUrl}/v1/me`, {
    method: "GET",
    headers: { Authorization: `Bearer ${accessToken}` },
  })

  return readJson(response)
}

export const runPublishAuth = async ({ publishBaseUrl, deps = {} }) => {
  const fetchImpl = deps.fetch ?? globalThis.fetch
  const now = deps.now ?? Date.now
  const platform = deps.platform ?? process.platform
  const homeDir =
    deps.homeDir ??
    (platform === "win32" ? process.env.APPDATA ?? homedir() : homedir())
  const readCache = deps.readCache ?? defaultReadCache
  const writeCache = deps.writeCache ?? defaultWriteCache
  const openBrowser = deps.openBrowser ?? defaultOpenBrowser
  const createLoopbackServer = deps.createLoopbackServer ?? defaultCreateLoopbackServer
  const randomString = deps.randomString ?? defaultRandomString
  const makeCodeVerifier = deps.codeVerifier ?? defaultCodeVerifier
  const createCodeChallenge = deps.codeChallengeFromVerifier ?? codeChallengeFromVerifier

  if (!fetchImpl) {
    throw new Error("OAuth helper requires a fetch implementation")
  }

  const hostname = new URL(publishBaseUrl).hostname
  const cachePath = cacheFilePathFor({ platform, homeDir, hostname })
  const cachedBundle = await readCache(cachePath)
  const strategy = selectAuthStrategy(cachedBundle, now())
  let metadataPromise = null

  const loadMetadata = async () => {
    if (metadataPromise === null) {
      metadataPromise = discoverAuthorizationServer({ publishBaseUrl, fetchImpl })
    }

    return metadataPromise
  }

  const runRefreshFlow = async bundle => {
    const metadata = await loadMetadata()
    const refreshed = await refreshTokenBundle({
      metadata,
      clientId: bundle.clientId,
      refreshToken: bundle.refreshToken,
      publishBaseUrl,
      fetchImpl,
    })

    const nextBundle = buildTokenBundle({
      tokenResponse: refreshed,
      metadata,
      clientId: bundle.clientId,
      publishBaseUrl,
      now: now(),
      previous: bundle,
    })

    await writeCache(cachePath, nextBundle)

    return fetchCurrentIdentity({
      publishBaseUrl,
      accessToken: nextBundle.accessToken,
      fetchImpl,
    })
  }

  const runInteractiveFlow = async () => {
    const metadata = await loadMetadata()
    const expectedState = randomString()
    const codeVerifier = makeCodeVerifier()
    const codeChallenge = createCodeChallenge(codeVerifier)
    const loopback = await createLoopbackServer({ expectedState })

    try {
      const client = await registerPublicClient({
        metadata,
        redirectUri: loopback.redirectUri,
        publishBaseUrl,
        fetchImpl,
      })

      const authorizationUrl = new URL(metadata.authorization_endpoint)
      authorizationUrl.searchParams.set("client_id", client.client_id)
      authorizationUrl.searchParams.set("redirect_uri", loopback.redirectUri)
      authorizationUrl.searchParams.set("response_type", "code")
      authorizationUrl.searchParams.set("resource", publishBaseUrl)
      authorizationUrl.searchParams.set("code_challenge", codeChallenge)
      authorizationUrl.searchParams.set("code_challenge_method", "S256")
      authorizationUrl.searchParams.set("state", expectedState)

      await openBrowser(authorizationUrl.toString())

      const { code } = await loopback.waitForCode()
      const tokenResponse = await exchangeCodeForToken({
        metadata,
        clientId: client.client_id,
        redirectUri: loopback.redirectUri,
        code,
        codeVerifier,
        publishBaseUrl,
        fetchImpl,
      })

      const nextBundle = buildTokenBundle({
        tokenResponse,
        metadata,
        clientId: client.client_id,
        publishBaseUrl,
        now: now(),
        previous: null,
      })

      await writeCache(cachePath, nextBundle)

      return fetchCurrentIdentity({
        publishBaseUrl,
        accessToken: nextBundle.accessToken,
        fetchImpl,
      })
    } finally {
      await loopback.close()
    }
  }

  if (strategy === "reuse") {
    try {
      return await fetchCurrentIdentity({
        publishBaseUrl,
        accessToken: cachedBundle.accessToken,
        fetchImpl,
      })
    } catch (error) {
      if (!isAuthFailure(error)) {
        throw error
      }

      if (canRefreshFromBundle(cachedBundle)) {
        try {
          return await runRefreshFlow(cachedBundle)
        } catch (refreshError) {
          if (!isInteractiveRecoveryError(refreshError)) {
            throw refreshError
          }

          return runInteractiveFlow()
        }
      }

      return runInteractiveFlow()
    }
  }

  if (strategy === "refresh") {
    if (canRefreshFromBundle(cachedBundle)) {
      try {
        return await runRefreshFlow(cachedBundle)
      } catch (refreshError) {
        if (!isInteractiveRecoveryError(refreshError)) {
          throw refreshError
        }

        return runInteractiveFlow()
      }
    }

    return runInteractiveFlow()
  }

  return runInteractiveFlow()
}
