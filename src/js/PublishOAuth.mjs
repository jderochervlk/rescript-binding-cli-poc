import { spawn } from "node:child_process"
import { createHash, randomBytes } from "node:crypto"
import { mkdir, readFile, readdir, stat, writeFile } from "node:fs/promises"
import { createServer } from "node:http"
import { homedir } from "node:os"
import path from "node:path"
import { createInterface } from "node:readline/promises"

const joinPath = path.posix.join
const dirnamePath = path.posix.dirname
const normalizeBasePath = homeDir => homeDir.replaceAll("\\", "/")
export const publishBaseUrl = "https://rescript-binding-registry.josh-401.workers.dev/api/publish"
const oauthResource = `${publishBaseUrl}/v1/me`

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

const browserOpenCommand = (platform, url) =>
  platform === "darwin"
    ? ["open", [url]]
    : platform === "win32"
      ? ["cmd", ["/c", "start", "", url]]
      : ["xdg-open", [url]]

export const defaultOpenBrowser = async (
  url,
  { platform = process.platform, spawn: spawnImpl = spawn, log = console.log } = {}
) => {
  const command = browserOpenCommand(platform, url)

  const opened = await new Promise(resolve => {
    const child = spawnImpl(command[0], command[1], { stdio: "ignore" })
    child.once("error", () => resolve(false))
    child.once("close", code => {
      resolve(code === 0)
    })
  })

  if (!opened) {
    log("Could not open a browser automatically. Open this URL to continue:")
    log(url)
  }
}

export const readOAuthCallback = ({ callbackUrl, expectedState }) => {
  const code = callbackUrl.searchParams.get("code")
  const state = callbackUrl.searchParams.get("state")
  const error = callbackUrl.searchParams.get("error")
  const errorDescription = callbackUrl.searchParams.get("error_description")

  if (error) {
    throw new Error(
      errorDescription
        ? `OAuth callback error: ${error}: ${errorDescription}`
        : `OAuth callback error: ${error}`
    )
  }

  if (!code || !state) {
    const query = callbackUrl.searchParams.toString()
    throw new Error(
      query
        ? `OAuth callback missing code or state. Callback query: ${query}`
        : "OAuth callback missing code or state. Callback query was empty."
    )
  }

  if (state !== expectedState) {
    throw new Error("OAuth state validation failed")
  }

  return { code, state }
}

export const defaultCreateLoopbackServer = async ({ expectedState }) => {
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

    try {
      const callback = readOAuthCallback({ callbackUrl, expectedState })
      response.statusCode = 200
      response.end("Authentication complete. You can return to the terminal.")
      resolveCode(callback)
    } catch (error) {
      response.statusCode = 400
      response.end(error.message)
      rejectCode(error)
    }
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

const parseResourceMetadataUrl = header => {
  const match = header?.match(/resource_metadata="([^"]+)"/)
  return match?.[1] ?? null
}

const authorizationServerMetadataUrlFrom = authorizationServer => {
  const url = new URL(authorizationServer)
  url.pathname = "/.well-known/oauth-authorization-server"
  url.search = ""
  url.hash = ""
  return url.toString()
}

const discoverAuthorizationServer = async ({ fetchImpl }) => {
  const protectedResponse = await fetchImpl(`${publishBaseUrl}/v1/me`, {
    method: "GET",
    redirect: "manual",
  })
  const resourceMetadataUrl = parseResourceMetadataUrl(
    protectedResponse.headers.get("www-authenticate")
  )

  if (resourceMetadataUrl) {
    const resourceMetadata = await readJson(await fetchImpl(resourceMetadataUrl, {}))
    const authorizationServer = resourceMetadata.authorization_servers?.[0]

    if (!authorizationServer) {
      throw new Error("Cloudflare Access resource metadata did not include authorization_servers")
    }

    return readJson(await fetchImpl(authorizationServerMetadataUrlFrom(authorizationServer), {}))
  }

  const metadataUrl = new URL("/.well-known/oauth-authorization-server", publishBaseUrl)
  const response = await fetchImpl(metadataUrl.toString(), { redirect: "manual" })
  return readJson(response)
}

const registerPublicClient = async ({ metadata, redirectUri, fetchImpl }) => {
  const response = await fetchImpl(metadata.registration_endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      redirect_uris: [redirectUri],
      token_endpoint_auth_method: "none",
      grant_types: ["authorization_code", "refresh_token"],
      response_types: ["code"],
      resource: oauthResource,
    }),
  })

  return readJson(response)
}

const exchangeCodeForToken = async ({ metadata, clientId, redirectUri, code, codeVerifier, fetchImpl }) => {
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: clientId,
    code,
    code_verifier: codeVerifier,
    redirect_uri: redirectUri,
    resource: oauthResource,
  })

  const response = await fetchImpl(metadata.token_endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  })

  return readJson(response)
}

const refreshTokenBundle = async ({ metadata, clientId, refreshToken, fetchImpl }) => {
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    client_id: clientId,
    resource: oauthResource,
  })

  const response = await fetchImpl(metadata.token_endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  })

  return readJson(response)
}

const buildTokenBundle = ({ tokenResponse, metadata, clientId, now, previous }) => ({
  accessToken: tokenResponse.access_token,
  refreshToken: tokenResponse.refresh_token ?? previous?.refreshToken ?? null,
  expiresAt: now + tokenResponse.expires_in * 1000,
  tokenEndpoint: metadata.token_endpoint,
  authorizationEndpoint: metadata.authorization_endpoint,
  registrationEndpoint: metadata.registration_endpoint,
  clientId,
  resource: oauthResource,
  publishBaseUrl,
})

const normalizeIdentity = identity => ({
  githubLogin: identity.githubLogin ?? undefined,
  displayName: identity.displayName ?? undefined,
  email: identity.email ?? undefined,
})

const fetchCurrentIdentity = async ({ accessToken, fetchImpl }) => {
  const response = await fetchImpl(`${publishBaseUrl}/v1/me`, {
    method: "GET",
    headers: { Authorization: `Bearer ${accessToken}` },
  })

  return normalizeIdentity(await readJson(response))
}

const fetchCurrentSession = async ({ accessToken, fetchImpl }) => ({
  identity: await fetchCurrentIdentity({ accessToken, fetchImpl }),
  accessToken,
})

export const runPublishAuthSession = async ({ deps = {} } = {}) => {
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
      metadataPromise = discoverAuthorizationServer({ fetchImpl })
    }

    return metadataPromise
  }

  const runRefreshFlow = async bundle => {
    const metadata = await loadMetadata()
    const refreshed = await refreshTokenBundle({
      metadata,
      clientId: bundle.clientId,
      refreshToken: bundle.refreshToken,
      fetchImpl,
    })

    const nextBundle = buildTokenBundle({
      tokenResponse: refreshed,
      metadata,
      clientId: bundle.clientId,
      now: now(),
      previous: bundle,
    })

    await writeCache(cachePath, nextBundle)

    return fetchCurrentSession({
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
        fetchImpl,
      })

      const authorizationUrl = new URL(metadata.authorization_endpoint)
      authorizationUrl.searchParams.set("client_id", client.client_id)
      authorizationUrl.searchParams.set("redirect_uri", loopback.redirectUri)
      authorizationUrl.searchParams.set("response_type", "code")
      authorizationUrl.searchParams.set("resource", oauthResource)
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
        fetchImpl,
      })

      const nextBundle = buildTokenBundle({
        tokenResponse,
        metadata,
        clientId: client.client_id,
        now: now(),
        previous: null,
      })

      await writeCache(cachePath, nextBundle)

      return fetchCurrentSession({
        accessToken: nextBundle.accessToken,
        fetchImpl,
      })
    } finally {
      await loopback.close()
    }
  }

  if (strategy === "reuse") {
    try {
      return await fetchCurrentSession({
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

export const runPublishAuth = async options => {
  const session = await runPublishAuthSession(options)
  return session.identity
}

const bindingFileExtensions = new Set([".res", ".resi"])
const ignoredDirectoryNames = new Set(["node_modules", "lib", "dist", "build", "coverage"])

const toPosixPath = value => value.replaceAll("\\", "/")

const readProjectPackageJson = async cwd => {
  const packageJsonPath = path.join(cwd, "package.json")

  try {
    return JSON.parse(await readFile(packageJsonPath, "utf8"))
  } catch (error) {
    if (error?.code === "ENOENT") {
      return {}
    }

    if (error instanceof SyntaxError) {
      throw new Error(`Could not parse ${packageJsonPath}`)
    }

    throw error
  }
}

const dependencyVersionFrom = (packageJson, dependencyName) => {
  const dependencyGroups = [
    packageJson.peerDependencies,
    packageJson.dependencies,
    packageJson.devDependencies,
  ]

  for (const dependencies of dependencyGroups) {
    const version = dependencies?.[dependencyName]
    if (typeof version === "string" && version.trim() !== "") {
      return version
    }
  }

  return undefined
}

const promptWithDefault = async (readline, label, defaultValue) => {
  const suffix = defaultValue ? ` [${defaultValue}]` : ""
  const answer = (await readline.question(`${label}${suffix}: `)).trim()
  const value = answer || defaultValue || ""

  if (value === "") {
    throw new Error(`${label} is required`)
  }

  return value
}

const confirmPublish = async readline => {
  const answer = (await readline.question("Publish this release? [y/N]: ")).trim().toLowerCase()
  return answer === "y" || answer === "yes"
}

const deriveVariantLabel = sourcePath => {
  const basename = path.basename(sourcePath)
  const extension = path.extname(basename)
  return extension ? basename.slice(0, -extension.length) : basename
}

const isBindingFilePath = filePath => bindingFileExtensions.has(path.extname(filePath))

const shouldSkipDirectory = name => name.startsWith(".") || ignoredDirectoryNames.has(name)

const collectBindingFilesFrom = async ({ sourcePath, cwd }) => {
  const absoluteSourcePath = path.resolve(cwd, sourcePath)
  const sourceStats = await stat(absoluteSourcePath)

  if (sourceStats.isFile()) {
    if (!isBindingFilePath(absoluteSourcePath)) {
      throw new Error("Binding file must end with .res or .resi")
    }

    return [
      {
        relativePath: path.basename(absoluteSourcePath),
        content: await readFile(absoluteSourcePath, "utf8"),
      },
    ]
  }

  if (!sourceStats.isDirectory()) {
    throw new Error("Binding source must be a file or folder")
  }

  const files = []

  const walk = async (directoryPath, relativeDirectoryPath) => {
    const entries = await readdir(directoryPath, { withFileTypes: true })

    for (const entry of entries) {
      if (entry.isDirectory()) {
        if (shouldSkipDirectory(entry.name)) {
          continue
        }

        await walk(
          path.join(directoryPath, entry.name),
          path.join(relativeDirectoryPath, entry.name)
        )
        continue
      }

      if (!entry.isFile() || entry.name.startsWith(".") || !isBindingFilePath(entry.name)) {
        continue
      }

      const relativePath = toPosixPath(path.join(relativeDirectoryPath, entry.name))
      files.push({
        relativePath,
        content: await readFile(path.join(directoryPath, entry.name), "utf8"),
      })
    }
  }

  await walk(absoluteSourcePath, "")
  files.sort((a, b) => a.relativePath.localeCompare(b.relativePath))

  if (files.length === 0) {
    throw new Error("Binding folder did not contain any .res or .resi files")
  }

  return files
}

const promptForPublishInput = async ({
  cwd,
  stdin = process.stdin,
  stdout = process.stdout,
} = {}) => {
  if (!stdin.isTTY || !stdout.isTTY) {
    throw new Error("binding publish requires an interactive terminal")
  }

  const packageJson = await readProjectPackageJson(cwd)
  const packageNameDefault =
    typeof packageJson.name === "string" ? packageJson.name : undefined
  const packageVersionDefault =
    typeof packageJson.version === "string" ? packageJson.version : undefined
  const rescriptVersionDefault = dependencyVersionFrom(packageJson, "rescript")
  const readline = createInterface({ input: stdin, output: stdout })

  try {
    const packageName = await promptWithDefault(
      readline,
      "Package name",
      packageNameDefault
    )
    const sourcePath = await promptWithDefault(readline, "Binding file or folder")
    const peerPackageRange = await promptWithDefault(
      readline,
      "Package version",
      packageVersionDefault
    )
    const rescriptRange = await promptWithDefault(
      readline,
      "ReScript version",
      rescriptVersionDefault
    )
    const files = await collectBindingFilesFrom({ sourcePath, cwd })
    const variantLabel = deriveVariantLabel(sourcePath)

    console.log("")
    console.log("Publish summary:")
    console.log(`  Package: ${packageName}`)
    console.log(`  Binding source: ${sourcePath}`)
    console.log(`  Variant: ${variantLabel}`)
    console.log(`  Files: ${files.length}`)
    console.log(`  Package version: ${peerPackageRange}`)
    console.log(`  ReScript version: ${rescriptRange}`)
    console.log("")

    if (!(await confirmPublish(readline))) {
      return null
    }

    return {
      packageName,
      variantLabel,
      peerPackageRange,
      rescriptRange,
      files,
    }
  } finally {
    readline.close()
  }
}

const publishRelease = async ({ input, accessToken, fetchImpl }) => {
  const response = await fetchImpl(`${publishBaseUrl}/v1/releases`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(input),
  })

  return readJson(response)
}

export const runPublish = async ({ deps = {} } = {}) => {
  const fetchImpl = deps.fetch ?? globalThis.fetch
  const cwd = deps.cwd ?? process.cwd()
  const prompt = deps.promptForPublishInput ?? promptForPublishInput

  if (!fetchImpl) {
    throw new Error("Publish helper requires a fetch implementation")
  }

  const input = await prompt({
    cwd,
    stdin: deps.stdin ?? process.stdin,
    stdout: deps.stdout ?? process.stdout,
  })

  if (input === null) {
    console.log("Publish cancelled.")
    return
  }

  const session = await runPublishAuthSession({ deps })
  const result = await publishRelease({
    input,
    accessToken: session.accessToken,
    fetchImpl,
  })

  if (result.duplicate) {
    console.log(`Release already exists: ${result.releaseId}`)
  } else {
    console.log(`Published release: ${result.releaseId}`)
  }

  console.log(
    `${result.packageName}/${result.variantLabel} (${result.fileCount} file${
      result.fileCount === 1 ? "" : "s"
    })`
  )
}
