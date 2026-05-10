import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import path from "node:path"
import { registryApiBaseUrl, runAdd } from "../src/js/RegistryAdd.mjs"

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

const makeProject = async () => {
  const cwd = await mkdtemp(path.join(tmpdir(), "rescript-binding-add-"))
  await writeFile(
    path.join(cwd, "package.json"),
    JSON.stringify(
      {
        dependencies: { "is-even": "1.0.0" },
        devDependencies: { rescript: "^12.0.0" },
      },
      null,
      2
    )
  )
  return cwd
}

const releaseSummary = {
  id: "release-1",
  packageName: "is-even",
  variantLabel: "isEven",
  variantSlug: "iseven",
  publisherLogin: "dev@example.com",
  peerPackageRange: "1.0.0",
  rescriptRange: "^12.0.0",
  description: null,
  createdAt: "2026-05-09T22:00:00.000Z",
  isPackageCompatible: true,
  isRescriptCompatible: true,
  compatibilityRank: 3,
}

const releasePayload = {
  ...releaseSummary,
  files: [
    {
      relativePath: "isEven.res",
      content: '@module("is-even")\nexternal isEven: int => bool = "default"\n',
    },
  ],
}

const makeFetch = requests => async url => {
  requests.push(url)

  if (url.startsWith(`${registryApiBaseUrl}/v1/packages/is-even/releases?`)) {
    return jsonResponse({ releases: [releaseSummary] })
  }

  if (url === `${registryApiBaseUrl}/v1/releases/release-1`) {
    return jsonResponse(releasePayload)
  }

  throw new Error(`Unexpected URL: ${url}`)
}

const makePackageFetch =
  ({ packageName, releases, releasePayloads }) =>
  async url => {
    if (url.startsWith(`${registryApiBaseUrl}/v1/packages/${encodeURIComponent(packageName)}/releases?`)) {
      return jsonResponse({ releases })
    }

    for (const [releaseId, payload] of Object.entries(releasePayloads)) {
      if (url === `${registryApiBaseUrl}/v1/releases/${releaseId}`) {
        return jsonResponse(payload)
      }
    }

    throw new Error(`Unexpected URL: ${url}`)
  }

const installCwd = await makeProject()
try {
  const requests = []
  const logs = []

  await runAdd("is-even", undefined, {
    deps: {
      cwd: installCwd,
      fetch: makeFetch(requests),
      selectRelease: async releases => releases[0],
      log: message => logs.push(message),
    },
  })

  const installed = await readFile(
    path.join(installCwd, "src", "bindings", "IsEven.res"),
    "utf8"
  )

  assert(installed === releasePayload.files[0].content, "add writes release files")
  assert(
    requests.some(url => url.includes("packageVersion=1.0.0")),
    "add sends detected package version"
  )
  assert(
    requests.some(url => url.includes("rescriptVersion=%5E12.0.0")),
    "add sends detected ReScript version"
  )
  assert(
    logs.some(message => message.includes("Installed is-even to")),
    "add prints install summary"
  )
} finally {
  await rm(installCwd, { recursive: true, force: true })
}

const customFolderCwd = await makeProject()
try {
  await runAdd("is-even", "vendor/bindings", {
    deps: {
      cwd: customFolderCwd,
      fetch: makeFetch([]),
      selectRelease: async releases => releases[0],
      log: () => {},
    },
  })

  const installed = await readFile(
    path.join(customFolderCwd, "vendor", "bindings", "IsEven.res"),
    "utf8"
  )

  assert(installed === releasePayload.files[0].content, "add normalizes release filename inside --folder")
} finally {
  await rm(customFolderCwd, { recursive: true, force: true })
}

const scopedCwd = await mkdtemp(path.join(tmpdir(), "rescript-binding-add-scoped-"))
try {
  await writeFile(
    path.join(scopedCwd, "package.json"),
    JSON.stringify(
      {
        dependencies: { "@inquirer/prompts": "^8.4.2" },
        devDependencies: { rescript: "^12.0.0" },
      },
      null,
      2
    )
  )

  const scopedRelease = {
    ...releaseSummary,
    id: "scoped-release",
    packageName: "@inquirer/prompts",
    peerPackageRange: "^8.4.2",
  }
  const scopedPayload = {
    ...scopedRelease,
    files: [{ relativePath: "prompts.res", content: "let prompts = true\n" }],
  }

  await runAdd("@inquirer/prompts", undefined, {
    deps: {
      cwd: scopedCwd,
      fetch: makePackageFetch({
        packageName: "@inquirer/prompts",
        releases: [scopedRelease],
        releasePayloads: { "scoped-release": scopedPayload },
      }),
      selectRelease: async releases => releases[0],
      log: () => {},
    },
  })

  const installed = await readFile(
    path.join(scopedCwd, "src", "bindings", "InquirerPrompts.res"),
    "utf8"
  )

  assert(installed === "let prompts = true\n", "add defaults scoped packages to PascalCase module filename")
} finally {
  await rm(scopedCwd, { recursive: true, force: true })
}

const multiFileCwd = await makeProject()
try {
  const multiRelease = {
    ...releaseSummary,
    id: "multi-release",
  }
  const multiPayload = {
    ...multiRelease,
    files: [
      { relativePath: "nested/fooBinding.res", content: "let foo = true\n" },
      { relativePath: "types/barBinding.resi", content: "let bar: bool\n" },
    ],
  }

  await runAdd("is-even", undefined, {
    deps: {
      cwd: multiFileCwd,
      fetch: makePackageFetch({
        packageName: "is-even",
        releases: [multiRelease],
        releasePayloads: { "multi-release": multiPayload },
      }),
      selectRelease: async releases => releases[0],
      log: () => {},
    },
  })

  const foo = await readFile(
    path.join(multiFileCwd, "src", "bindings", "IsEven", "nested", "FooBinding.res"),
    "utf8"
  )
  const bar = await readFile(
    path.join(multiFileCwd, "src", "bindings", "IsEven", "types", "BarBinding.resi"),
    "utf8"
  )

  assert(foo === "let foo = true\n", "add normalizes nested .res filenames")
  assert(bar === "let bar: bool\n", "add normalizes nested .resi filenames")
} finally {
  await rm(multiFileCwd, { recursive: true, force: true })
}

const invalidFileCwd = await makeProject()
try {
  const invalidRelease = {
    ...releaseSummary,
    id: "invalid-release",
  }
  const invalidPayload = {
    ...invalidRelease,
    files: [{ relativePath: "bad-name.res", content: "let bad = true\n" }],
  }
  let invalidMessage = null

  try {
    await runAdd("is-even", "vendor/bindings", {
      deps: {
        cwd: invalidFileCwd,
        fetch: makePackageFetch({
          packageName: "is-even",
          releases: [invalidRelease],
          releasePayloads: { "invalid-release": invalidPayload },
        }),
        selectRelease: async releases => releases[0],
        log: () => {},
      },
    })
  } catch (error) {
    invalidMessage = error.message
  }

  assert(
    invalidMessage?.includes("valid ReScript module filename"),
    "add rejects release files that cannot normalize to ReScript module filenames"
  )
} finally {
  await rm(invalidFileCwd, { recursive: true, force: true })
}

const missingPackageCwd = await makeProject()
try {
  let missingPackageMessage = null

  try {
    await runAdd(undefined, undefined, {
      deps: {
        cwd: missingPackageCwd,
        stdin: { isTTY: false },
        stdout: { isTTY: false },
        fetch: async () => {
          throw new Error("missing package should fail before fetching")
        },
      },
    })
  } catch (error) {
    missingPackageMessage = error.message
  }

  assert(
    missingPackageMessage?.includes("requires a package argument"),
    "add without package requires interactivity before fetching"
  )
} finally {
  await rm(missingPackageCwd, { recursive: true, force: true })
}

const collisionCwd = await makeProject()
try {
  const targetDir = path.join(collisionCwd, "src", "bindings")
  const targetFile = path.join(targetDir, "IsEven.res")
  await mkdir(targetDir, { recursive: true })
  await writeFile(targetFile, "let existing = true\n")

  await runAdd("is-even", undefined, {
    deps: {
      cwd: collisionCwd,
      fetch: makeFetch([]),
      selectRelease: async releases => releases[0],
      confirmOverwrite: async () => false,
      log: () => {},
    },
  })

  const unchanged = await readFile(targetFile, "utf8")
  assert(unchanged === "let existing = true\n", "add cancel leaves existing files unchanged")
} finally {
  await rm(collisionCwd, { recursive: true, force: true })
}

console.log("Add_test.mjs passed")
