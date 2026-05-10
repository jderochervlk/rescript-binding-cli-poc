import { existsSync, readFileSync, statSync } from "node:fs"
import { fileURLToPath } from "node:url"

const assert = (condition, label) => {
  if (!condition) {
    throw new Error(`Assertion failed: ${label}`)
  }
}

const packageJsonPath = new URL("../package.json", import.meta.url)
const wrapperUrl = new URL("../bin/index.mjs", import.meta.url)
const cliUrl = new URL("../src/Cli.res.mjs", import.meta.url)
const wrapperPath = fileURLToPath(wrapperUrl)
const packageJson = JSON.parse(readFileSync(packageJsonPath, "utf8"))

assert(
  packageJson.bin?.["rescript-bindings"] === "./bin/index.mjs",
  "package.json points the CLI bin at the bundled entry"
)

assert(existsSync(wrapperPath), "bundled CLI entry exists")

const wrapperSource = readFileSync(wrapperPath, "utf8")
assert(wrapperSource.startsWith("#!/usr/bin/env node\n"), "bundled CLI entry starts with a Node shebang")
assert(
  !wrapperSource.includes("../src/Main.res.mjs"),
  "bundled CLI entry does not import the generated source entry"
)

const wrapperMode = statSync(wrapperPath).mode
assert((wrapperMode & 0o111) !== 0, "CLI wrapper is executable")

const importBinWithArgs = async (args, tag) => {
  const originalArgv = process.argv
  const originalExitCode = process.exitCode
  const originalStdoutWrite = process.stdout.write
  const originalStderrWrite = process.stderr.write
  let stdout = ""
  let stderr = ""

  process.argv = [process.execPath, wrapperPath, ...args]
  process.exitCode = undefined
  process.stdout.write = chunk => {
    stdout += String(chunk)
    return true
  }
  process.stderr.write = chunk => {
    stderr += String(chunk)
    return true
  }

  try {
    await import(`${wrapperUrl.href}?${tag}`)
    await new Promise(resolve => setImmediate(resolve))
    return { stdout, stderr, exitCode: process.exitCode }
  } finally {
    process.argv = originalArgv
    process.exitCode = originalExitCode
    process.stdout.write = originalStdoutWrite
    process.stderr.write = originalStderrWrite
  }
}

const rootHelp = await importBinWithArgs(["--help"], "bin-test-root-help")
assert(rootHelp.exitCode === undefined || rootHelp.exitCode === 0, "bundled CLI help does not fail")
assert(rootHelp.stdout.includes("Commands:"), "bundled CLI help prints command list")

const addHelp = await importBinWithArgs(["add", "--help"], "bin-test-add-help")
assert(addHelp.exitCode === undefined || addHelp.exitCode === 0, "add help exits successfully")
assert(addHelp.stdout.includes("Usage: rescript-bindings add [options] [package]"), "add help shows optional package argument")
assert(addHelp.stdout.includes("--folder <path>"), "add help documents folder override")

const legacyBinding = await importBinWithArgs(["binding", "publish"], "bin-test-legacy-binding")
assert(legacyBinding.exitCode !== undefined && legacyBinding.exitCode !== 0, "legacy binding namespace is rejected")
assert(
  legacyBinding.stderr.includes("unknown command 'binding'"),
  "legacy binding namespace prints an unknown command error"
)

const cliModule = await import(`${cliUrl.href}?publish-auth-test`)
let runAuthCalled = false
const originalLog = console.log
const loggedLines = []

console.log = (...args) => {
  loggedLines.push(args.join(" "))
}

try {
  await cliModule.runPublishAuthCheckWith(() => {
    runAuthCalled = true
    return Promise.resolve({
      githubLogin: "octocat",
      displayName: undefined,
      email: undefined,
    })
  })
} finally {
  console.log = originalLog
}

assert(
  runAuthCalled,
  "publish auth helper calls the auth implementation without URL configuration"
)
assert(
  loggedLines.includes("Authenticated as octocat"),
  "publish auth check logs the authenticated identity label"
)

console.log("Bin_test.mjs passed")
