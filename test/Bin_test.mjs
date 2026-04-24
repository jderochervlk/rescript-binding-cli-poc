import { existsSync, readFileSync, statSync } from "node:fs"
import { fileURLToPath } from "node:url"

const assert = (condition, label) => {
  if (!condition) {
    throw new Error(`Assertion failed: ${label}`)
  }
}

const packageJsonPath = new URL("../package.json", import.meta.url)
const wrapperUrl = new URL("../bin/rescript-bindings.mjs", import.meta.url)
const wrapperPath = fileURLToPath(wrapperUrl)
const packageJson = JSON.parse(readFileSync(packageJsonPath, "utf8"))

assert(
  packageJson.bin?.["rescript-bindings"] === "./bin/rescript-bindings.mjs",
  "package.json points the CLI bin at the wrapper"
)

assert(existsSync(wrapperPath), "CLI wrapper exists")

const wrapperSource = readFileSync(wrapperPath, "utf8")
assert(wrapperSource.startsWith("#!/usr/bin/env node\n"), "CLI wrapper starts with a Node shebang")

const wrapperMode = statSync(wrapperPath).mode
assert((wrapperMode & 0o111) !== 0, "CLI wrapper is executable")

const originalArgv = process.argv
const originalLog = console.log
const loggedLines = []

console.log = (...args) => {
  loggedLines.push(args.join(" "))
}

process.argv = [process.execPath, wrapperPath, "binding", "publish"]

try {
  await import(`${wrapperUrl.href}?bin-test`)
} finally {
  process.argv = originalArgv
  console.log = originalLog
}

assert(
  loggedLines.includes("Publish flow scaffold is wired in ReScript"),
  "CLI wrapper launches the publish command"
)

console.log("Bin_test.mjs passed")
