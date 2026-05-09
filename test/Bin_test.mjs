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

const originalArgv = process.argv

process.argv = [process.execPath, wrapperPath, "--help"]

try {
  await import(`${wrapperUrl.href}?bin-test`)
} finally {
  process.argv = originalArgv
}

assert(process.exitCode === undefined || process.exitCode === 0, "bundled CLI help does not fail")

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
