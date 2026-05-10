import { mkdir, readFile, writeFile } from "node:fs/promises"
import path from "node:path"
import { emitKeypressEvents } from "node:readline"
import { createInterface } from "node:readline/promises"
import { search } from "@inquirer/prompts"

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

const dependencyNamesFrom = packageJson => {
  const names = new Set()

  for (const dependencies of [
    packageJson.peerDependencies,
    packageJson.dependencies,
    packageJson.devDependencies,
  ]) {
    for (const name of Object.keys(dependencies ?? {})) {
      if (name !== "rescript") {
        names.add(name)
      }
    }
  }

  return [...names].sort((a, b) => a.localeCompare(b))
}

const askRequired = async ({ stdin, stdout }, question) => {
  const answer = (await askWithReadline({ stdin, stdout }, question)).trim()
  if (answer === "") {
    throw new Error("Package name is required")
  }

  return answer
}

const askWithDefault = async ({ stdin, stdout }, question, defaultValue) => {
  const answer = (await askWithReadline({ stdin, stdout }, `${question} [${defaultValue}]: `)).trim()
  return answer || defaultValue
}

const moduleFilenameError =
  "Install filename must be a valid ReScript module filename, like InquirerPrompts.res."

const moduleFilenamePattern = /^([A-Za-z][A-Za-z0-9]*)(\.resi?)$/

const normalizeModuleFilename = filename => {
  const match = filename.match(moduleFilenamePattern)
  if (!match) {
    throw new Error(moduleFilenameError)
  }

  return `${match[1][0].toUpperCase()}${match[1].slice(1)}${match[2]}`
}

const normalizeInstallFilePath = filePath => {
  const dirname = path.dirname(filePath)
  const filename = normalizeModuleFilename(path.basename(filePath))

  return dirname === "." ? filename : path.join(dirname, filename)
}

const selectPackageName = async ({ packageNames, stdin, stdout }) => {
  if (!stdin.isTTY || !stdout.isTTY) {
    throw new Error("add requires a package argument when not running in an interactive terminal")
  }

  if (packageNames.length === 0) {
    return askRequired({ stdin, stdout }, "Package name: ")
  }

  return search(
    {
      message: "Package name",
      pageSize: 8,
      source: async term => {
        const input = term?.trim() ?? ""
        const matches = packageNames
          .filter(packageName => input === "" || packageName.includes(input))
          .map(packageName => ({ name: packageName, value: packageName }))

        if (input !== "" && !packageNames.includes(input)) {
          matches.push({
            name: `Use custom package "${input}"`,
            value: input,
          })
        }

        return matches
      },
    },
    { input: stdin, output: stdout }
  )
}

const releaseRow = release => {
  const packageMark =
    release.isPackageCompatible === true
      ? "matches installed"
      : release.isPackageCompatible === false
        ? "does not match installed"
        : "installed version unknown"
  const rescriptMark =
    release.isRescriptCompatible === true
      ? "matches project"
      : release.isRescriptCompatible === false
        ? "does not match project"
        : "project version unknown"

  return {
    author: release.publisherLogin,
    package: `${release.peerPackageRange} - ${packageMark}`,
    rescript: `${release.rescriptRange} - ${rescriptMark}`,
  }
}

const tableWidth = (rows, key, label) =>
  Math.max(label.length, ...rows.map(row => row[key].length))

const padCell = (value, width) => value.padEnd(width)

const askWithReadline = async ({ stdin, stdout }, question) => {
  const readline = createInterface({ input: stdin, output: stdout })
  try {
    return await readline.question(question)
  } finally {
    readline.close()
  }
}

const renderReleaseOptions = ({ releases, selectedIndex, stdout }) => {
  const rows = releases.map(releaseRow)
  const authorWidth = tableWidth(rows, "author", "Author")
  const packageWidth = tableWidth(rows, "package", "Package")
  const rescriptWidth = tableWidth(rows, "rescript", "ReScript")

  stdout.write(
    `  ${padCell("Author", authorWidth)}  ${padCell("Package", packageWidth)}  ReScript\n`
  )

  rows.forEach((row, index) => {
    const prefix = index === selectedIndex ? "\x1b[36m›\x1b[0m" : " "
    const line = `${padCell(row.author, authorWidth)}  ${padCell(row.package, packageWidth)}  ${padCell(row.rescript, rescriptWidth)}`
    const label = index === selectedIndex ? `\x1b[1m${line}\x1b[0m` : line
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
      stdout.write(`\x1b[${releases.length + 1}A\x1b[0J`)
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
    throw new Error("add requires an interactive terminal when multiple releases are available")
  }

  log("Available binding releases:")
  log("Use ↑/↓ or j/k, then Enter.")
  return selectReleaseWithKeys(releases, { stdin, stdout })
}

const defaultConfirmOverwrite = async (files, { stdin = process.stdin, stdout = process.stdout, log = console.log } = {}) => {
  if (!stdin.isTTY || !stdout.isTTY) {
    throw new Error("add requires an interactive terminal before overwriting files")
  }

  log("The following files already exist:")
  files.forEach(file => log(`  ${file}`))

  const answer = (await askWithReadline({ stdin, stdout }, "Overwrite these files? [y/N]: "))
    .trim()
    .toLowerCase()
  return answer === "y" || answer === "yes"
}

const bindingNameFromPackageName = packageName => {
  const parts = packageName.match(/[a-zA-Z0-9]+/g) ?? []
  const name = parts
    .map(part => `${part[0].toUpperCase()}${part.slice(1)}`)
    .join("")

  return /^[A-Z]/.test(name) ? name : `Binding${name}`
}

const defaultInstallPathFor = ({ packageName, extension }) =>
  path.join("src", "bindings", `${bindingNameFromPackageName(packageName)}${extension}`)

const askInstallFilePath = async ({ stdin, stdout, defaultValue }) => {
  if (!stdin.isTTY || !stdout.isTTY) {
    return defaultValue
  }

  while (true) {
    const value = await askWithDefault({ stdin, stdout }, "Install file", defaultValue)
    try {
      return normalizeInstallFilePath(value)
    } catch {
      stdout.write(`${moduleFilenameError}\n`)
    }
  }
}

export const defaultInstallFolderFor = ({ cwd, packageName }) =>
  path.join(cwd, "src", "bindings", bindingNameFromPackageName(packageName))

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

const targetPlanFor = async ({ cwd, folder, release, stdin, stdout }) => {
  if (folder) {
    const root = path.resolve(cwd, folder)
    return {
      summaryPath: path.relative(cwd, root) || ".",
      targetPathForFile: file => targetPathFor({ root, relativePath: file.relativePath }),
    }
  }

  const singleFile = release.files.length === 1 ? release.files[0] : null

  if (singleFile) {
    const defaultFile = defaultInstallPathFor({
      packageName: release.packageName,
      extension: path.extname(singleFile.relativePath),
    })
    const selectedFile = await askInstallFilePath({ stdin, stdout, defaultValue: defaultFile })
    const targetPath = path.resolve(cwd, selectedFile)
    return {
      summaryPath: path.relative(cwd, targetPath) || ".",
      targetPathForFile: () => targetPath,
    }
  }

  const root = path.resolve(cwd, "src", "bindings", bindingNameFromPackageName(release.packageName))
  return {
    summaryPath: path.relative(cwd, root) || ".",
    targetPathForFile: file => targetPathFor({ root, relativePath: file.relativePath }),
  }
}

const targetPathFor = ({ root, relativePath }) => {
  const rootPath = path.resolve(root)
  const normalizedRelativePath = normalizeInstallFilePath(relativePath)
  const targetPath = path.resolve(rootPath, normalizedRelativePath)
  const rootPrefix = rootPath.endsWith(path.sep) ? rootPath : `${rootPath}${path.sep}`

  if (targetPath !== rootPath && !targetPath.startsWith(rootPrefix)) {
    throw new Error(`Release file escapes install folder: ${normalizedRelativePath}`)
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
    throw new Error("add requires a fetch implementation")
  }

  const packageJson = await readProjectPackageJson(cwd)
  const normalizedPackageName =
    typeof packageName === "string" && packageName.trim() !== ""
      ? packageName.trim()
      : await selectPackageName({
          packageNames: dependencyNamesFrom(packageJson),
          stdin,
          stdout,
        })
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
  const targetPlan = await targetPlanFor({ cwd, folder, release, stdin, stdout })
  const targetFiles = release.files.map(file => ({
    targetPath: targetPlan.targetPathForFile(file),
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

  log(`Installed ${release.packageName} to ${targetPlan.summaryPath}`)
}
