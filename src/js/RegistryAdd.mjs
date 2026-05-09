import { mkdir, readFile, writeFile } from "node:fs/promises"
import path from "node:path"
import { emitKeypressEvents } from "node:readline"
import { createInterface } from "node:readline/promises"

export const registryApiBaseUrl = "https://rescript-binding-registry.josh-401.workers.dev/api"

const readJson = async response => {
  if (response.ok) {
    return response.json()
  }

  const contentType = response.headers.get("content-type") ?? ""

  if (contentType.includes("application/json")) {
    const payload = await response.json()
    if (response.status === 401 && payload?.error === "invalid_token") {
      throw new Error(
        "Registry read API is protected by Cloudflare Access. Configure Access to protect /api/publish/* only and leave /api/v1/* public."
      )
    }

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

const releaseLine = release => {
  const packageMark =
    release.isPackageCompatible === true
      ? "package match"
      : release.isPackageCompatible === false
        ? "package mismatch"
        : "package unknown"
  const rescriptMark =
    release.isRescriptCompatible === true
      ? "ReScript match"
      : release.isRescriptCompatible === false
        ? "ReScript mismatch"
        : "ReScript unknown"

  return `${release.variantLabel} by ${release.publisherLogin} (${release.peerPackageRange}, ${release.rescriptRange}; ${packageMark}, ${rescriptMark})`
}

const askWithReadline = async ({ stdin, stdout }, question) => {
  const readline = createInterface({ input: stdin, output: stdout })
  try {
    return await readline.question(question)
  } finally {
    readline.close()
  }
}

const renderReleaseOptions = ({ releases, selectedIndex, stdout }) => {
  releases.forEach((release, index) => {
    const prefix = index === selectedIndex ? "\x1b[36m›\x1b[0m" : " "
    const label = index === selectedIndex ? `\x1b[1m${releaseLine(release)}\x1b[0m` : releaseLine(release)
    stdout.write(`${prefix} ${label}\n`)
  })
}

const selectReleaseWithKeys = (releases, { stdin, stdout }) =>
  new Promise((resolve, reject) => {
    let selectedIndex = 0
    const wasRaw = stdin.isRaw

    const cleanup = () => {
      stdin.off("keypress", onKeypress)
      if (stdin.setRawMode) {
        stdin.setRawMode(wasRaw)
      }
      stdin.pause()
      stdout.write("\x1b[?25h")
    }

    const finish = value => {
      cleanup()
      resolve(value)
    }

    const fail = error => {
      cleanup()
      reject(error)
    }

    const rerender = () => {
      stdout.write(`\x1b[${releases.length}A\x1b[0J`)
      renderReleaseOptions({ releases, selectedIndex, stdout })
    }

    const onKeypress = (_, key = {}) => {
      if (key.ctrl && key.name === "c") {
        stdout.write("\n")
        fail(new Error("Aborted with Ctrl+C"))
        return
      }

      if (key.name === "up" || key.name === "k") {
        selectedIndex = (selectedIndex - 1 + releases.length) % releases.length
        rerender()
        return
      }

      if (key.name === "down" || key.name === "j") {
        selectedIndex = (selectedIndex + 1) % releases.length
        rerender()
        return
      }

      if (key.name === "return" || key.name === "enter") {
        stdout.write("\n")
        finish(releases[selectedIndex])
      }
    }

    emitKeypressEvents(stdin)
    if (stdin.setRawMode) {
      stdin.setRawMode(true)
    }
    stdout.write("\x1b[?25l")
    renderReleaseOptions({ releases, selectedIndex, stdout })
    stdin.on("keypress", onKeypress)
    stdin.resume()
  })

const defaultSelectRelease = async (releases, { stdin = process.stdin, stdout = process.stdout, log = console.log } = {}) => {
  if (!stdin.isTTY || !stdout.isTTY) {
    throw new Error("binding add requires an interactive terminal when multiple releases are available")
  }

  log("Available binding releases:")
  log("Use ↑/↓ or j/k, then Enter.")
  return selectReleaseWithKeys(releases, { stdin, stdout })
}

const defaultConfirmOverwrite = async (files, { stdin = process.stdin, stdout = process.stdout, log = console.log } = {}) => {
  if (!stdin.isTTY || !stdout.isTTY) {
    throw new Error("binding add requires an interactive terminal before overwriting files")
  }

  log("The following files already exist:")
  files.forEach(file => log(`  ${file}`))

  const answer = (await askWithReadline({ stdin, stdout }, "Overwrite these files? [y/N]: "))
    .trim()
    .toLowerCase()
  return answer === "y" || answer === "yes"
}

export const defaultInstallFolderFor = ({ cwd, packageName, variantSlug }) =>
  path.join(cwd, "src", "bindings", packageName, variantSlug)

const listPackageReleases = async ({ packageName, packageVersion, rescriptVersion, fetchImpl }) => {
  const url = new URL(`${registryApiBaseUrl}/v1/packages/${encodeURIComponent(packageName)}/releases`)

  if (packageVersion) {
    url.searchParams.set("packageVersion", packageVersion)
  }

  if (rescriptVersion) {
    url.searchParams.set("rescriptVersion", rescriptVersion)
  }

  const payload = await readJson(await fetchImpl(url.toString()))
  return payload.releases ?? []
}

const fetchRelease = async ({ releaseId, fetchImpl }) =>
  readJson(await fetchImpl(`${registryApiBaseUrl}/v1/releases/${encodeURIComponent(releaseId)}`))

const targetRootFor = ({ cwd, folder, release }) =>
  folder
    ? path.resolve(cwd, folder)
    : defaultInstallFolderFor({
        cwd,
        packageName: release.packageName,
        variantSlug: release.variantSlug,
      })

const targetPathFor = ({ root, relativePath }) => {
  const rootPath = path.resolve(root)
  const targetPath = path.resolve(rootPath, relativePath)
  const rootPrefix = rootPath.endsWith(path.sep) ? rootPath : `${rootPath}${path.sep}`

  if (targetPath !== rootPath && !targetPath.startsWith(rootPrefix)) {
    throw new Error(`Release file escapes install folder: ${relativePath}`)
  }

  return targetPath
}

const existingFilesFrom = async targetFiles => {
  const existingFiles = []

  for (const file of targetFiles) {
    try {
      await readFile(file.targetPath, "utf8")
      existingFiles.push(file.targetPath)
    } catch (error) {
      if (error?.code !== "ENOENT") {
        throw error
      }
    }
  }

  return existingFiles
}

const writeReleaseFiles = async targetFiles => {
  for (const file of targetFiles) {
    await mkdir(path.dirname(file.targetPath), { recursive: true })
    await writeFile(file.targetPath, file.content)
  }
}

export const runAdd = async (packageName, folder, { deps = {} } = {}) => {
  const fetchImpl = deps.fetch ?? globalThis.fetch
  const cwd = deps.cwd ?? process.cwd()
  const log = deps.log ?? console.log
  const stdin = deps.stdin ?? process.stdin
  const stdout = deps.stdout ?? process.stdout
  const selectRelease = deps.selectRelease ?? defaultSelectRelease
  const confirmOverwrite = deps.confirmOverwrite ?? defaultConfirmOverwrite

  if (!fetchImpl) {
    throw new Error("binding add requires a fetch implementation")
  }

  if (typeof packageName !== "string" || packageName.trim() === "") {
    throw new Error("Package name is required")
  }

  const normalizedPackageName = packageName.trim()
  const packageJson = await readProjectPackageJson(cwd)
  const packageVersion = dependencyVersionFrom(packageJson, normalizedPackageName)
  const rescriptVersion = dependencyVersionFrom(packageJson, "rescript")
  const releases = await listPackageReleases({
    packageName: normalizedPackageName,
    packageVersion,
    rescriptVersion,
    fetchImpl,
  })

  if (releases.length === 0) {
    log(`No bindings found for ${normalizedPackageName}.`)
    return
  }

  const selectedRelease = await selectRelease(releases, { stdin, stdout, log })
  const release = await fetchRelease({ releaseId: selectedRelease.id, fetchImpl })
  const targetRoot = targetRootFor({ cwd, folder, release })
  const targetFiles = release.files.map(file => ({
    targetPath: targetPathFor({ root: targetRoot, relativePath: file.relativePath }),
    content: file.content,
  }))
  const existingFiles = await existingFilesFrom(targetFiles)

  if (existingFiles.length > 0) {
    const shouldOverwrite = await confirmOverwrite(existingFiles, { stdin, stdout, log })
    if (!shouldOverwrite) {
      log("Install cancelled.")
      return
    }
  }

  await writeReleaseFiles(targetFiles)

  log(
    `Installed ${release.packageName}/${release.variantLabel} to ${path.relative(cwd, targetRoot) || "."}`
  )
}
