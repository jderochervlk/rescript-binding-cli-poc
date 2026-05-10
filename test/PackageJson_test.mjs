import * as PackageJson from "../src/core/PackageJson.res.mjs"

const assert = (condition, label) => {
  if (!condition) {
    throw new Error(`Assertion failed: ${label}`)
  }
}

const packageJson = {
  peerDependencies: {
    react: "^19.0.0",
  },
  dependencies: {
    "@inquirer/prompts": "^8.4.2",
    react: "^18.0.0",
  },
  devDependencies: {
    rescript: "^12.0.0",
    vitest: "^4.0.0",
  },
}

assert(
  PackageJson.dependencyVersionFrom(packageJson, "react") === "^19.0.0",
  "peer dependencies win when a package appears in multiple groups"
)

assert(
  PackageJson.dependencyVersionFrom(packageJson, "rescript") === "^12.0.0",
  "dependency lookup includes dev dependencies"
)

assert(
  PackageJson.dependencyVersionFrom(packageJson, "missing") === undefined,
  "missing dependency versions return undefined"
)

assert(
  JSON.stringify(PackageJson.dependencyNamesFrom(packageJson)) ===
    JSON.stringify(["@inquirer/prompts", "react", "vitest"]),
  "dependency names are unique, sorted, and exclude rescript"
)

console.log("PackageJson_test.mjs passed")
