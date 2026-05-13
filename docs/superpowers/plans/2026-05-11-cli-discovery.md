# CLI Discovery Commands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add top-level `list`, `search`, `recent`, and `get` commands to the ReScript bindings CLI, backed by the registry discovery API and the existing install path.

**Architecture:** Add one capped all-bindings Worker endpoint, then add focused CLI discovery modules for fetching grouped entries, formatting tables, and orchestrating dependency-based `get`. Reuse `RegistryAdd` for release fetching, target planning, collision detection, and file writes by extracting a public install helper.

**Tech Stack:** ReScript v12, Commander, `@inquirer/prompts`, Cloudflare Worker, D1, Node filesystem bindings, existing script-style ReScript tests.

---

## File Map

- Modify `packages/cli/src/Worker.res`: add `GET /api/v1/bindings?limit=50`, route type, limit parsing, SQL query, and JSON response.
- Create `packages/cli/src/discovery/RegistryDiscovery.res`: fetch and format `list`, `search`, and `recent` grouped entries.
- Create `packages/cli/src/discovery/RegistryGet.res`: scan `package.json`, fetch exact package releases, prompt per dependency, show final plan, and install approved releases.
- Modify `packages/cli/src/bindings/RegistryAdd.res`: expose helpers for fetching releases and installing a known release payload so `get` can reuse the add path.
- Modify `packages/cli/src/bindings/Commander.res`: add externals for new action shapes and `--limit`.
- Modify `packages/cli/src/Command.res`: wire top-level `list`, `search`, `recent`, and `get`.
- Modify `packages/cli/src/Cli.res`: update manual parse/usage helpers used by tests.
- Modify `packages/cli/test/DiscoveryApi_test.res`: cover `GET /api/v1/bindings?limit=50`.
- Create `packages/cli/test/RegistryDiscovery_test.res`: cover discovery URL construction, table formatting, empty search handling, and response parsing.
- Create `packages/cli/test/RegistryGet_test.res`: cover dependency matching, per-dependency selection, approval cancel, and approved install.
- Modify `packages/cli/test/Bin_test.res`: cover help output for the new top-level commands.
- Modify `packages/cli/test/Cli_test.res`: cover manual parse/usage helpers for the new top-level commands.
- Modify `packages/cli/package.json`: add the two new test files to the `test` script.
- Modify `README.md` and `packages/cli/README.md`: document the new commands.

Do not commit during plan execution unless the user explicitly asks for commits.

---

### Task 1: Worker List Endpoint

**Files:**
- Modify: `packages/cli/src/Worker.res`
- Test: `packages/cli/test/DiscoveryApi_test.res`

- [ ] **Step 1: Write the failing Worker API test**

Add this assertion block in `packages/cli/test/DiscoveryApi_test.res` near the start of `run`, before the recent endpoint assertions:

```rescript
let list = await Worker.fetch(makeRequest(publicApiBaseUrl ++ "/v1/bindings?limit=2"), fakeDb, ctx)
TestSupport.assertTrue(responseStatus(list) == 200, "list bindings endpoint returns success")
let listBody: jsonBody = await list->responseJson
let listEntries = listBody->entries
TestSupport.assertTrue(listEntries->Array.length == 3, "list groups all returned releases by package and author")
TestSupport.assertTrue(
  listEntries->Array.some(entry => entry->packageName == "react" && entry->author == "josh"),
  "list includes grouped react entry",
)
TestSupport.assertTrue(
  listEntries->Array.some(entry => entry->packageName == "@rescript/react" && entry->author == "dev"),
  "list includes scoped package entry",
)
```

Also update the fake DB `statement.all` branch so the current test fixture can distinguish the new list query:

```rescript
all: async () => {
  if (sql.includes("FROM binding_releases") && sql.includes("LIMIT ?")) {
    return { results: rows };
  }

  if (sql.includes("FROM binding_releases")) {
    return { results: rows };
  }
  return { results: [] };
},
```

- [ ] **Step 2: Run the API test and verify it fails**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings build:res && pnpm --filter @jvlk/rescript-bindings exec node test/DiscoveryApi_test.res.mjs
```

Expected: the command fails because `/api/v1/bindings` currently routes to `NotFound`, so the new assertion sees a non-200 response.

- [ ] **Step 3: Add the Worker route and limit binding**

In `packages/cli/src/Worker.res`, add an integer D1 bind external near the existing `bind*` externals:

```rescript
@send external bindInt1: (statement, int) => boundStatement = "bind"
```

Add `ListBindings` to the `route` variant:

```rescript
type route =
  | ListPackageReleases(string)
  | GetRelease(string)
  | ListBindings
  | RecentBindings
  | SearchBindings
  | GetBindingAuthorDetail(string, string)
  | Me
  | Publish
  | AdminPublishers
  | NotFound
```

Update `routeFrom` before the recent/search checks:

```rescript
if method_ == "GET" && pathname == "/api/v1/bindings" {
  ListBindings
} else if method_ == "GET" && pathname == "/api/v1/bindings/recent" {
  RecentBindings
```

Update `isProtectedRoute` so `ListBindings` is public:

```rescript
| ListPackageReleases(_)
| GetRelease(_)
| ListBindings
| RecentBindings
| SearchBindings
| GetBindingAuthorDetail(_, _)
| NotFound => false
```

- [ ] **Step 4: Add limit parsing and handler**

In `packages/cli/src/Worker.res`, add this helper near `escapeLikePattern`:

```rescript
let defaultListLimit = 50
let maxListLimit = 200

let listLimitFrom = url => {
  switch url->urlSearchParams->searchParamGet("limit") {
  | None => defaultListLimit
  | Some(rawLimit) =>
    let parsed: int = %raw(`Number.parseInt(rawLimit, 10)`)
    if parsed > 0 && parsed <= maxListLimit {
      parsed
    } else {
      defaultListLimit
    }
  }
}
```

Add the handler near `handleRecentBindings`:

```rescript
let handleListBindings = async (~env, ~url) =>
  switch requireDb(env) {
  | Error(response) => response
  | Ok(db) =>
    let limit = listLimitFrom(url)
    let result: queryResult<releaseRow> = await db
    ->prepare(`SELECT
      id,
      package_name,
      variant_label,
      variant_slug,
      publisher_login,
      publisher_display_name,
      peer_package_range,
      rescript_range,
      description,
      created_at
    FROM binding_releases
    WHERE status = 'published'
    ORDER BY created_at DESC
    LIMIT ?`)
    ->bindInt1(limit)
    ->all

    json({"entries": groupReleaseRows(result.results)})
  }
```

Wire it in the main route switch:

```rescript
| ListBindings => await handleListBindings(~env, ~url)
```

- [ ] **Step 5: Run the API test and verify it passes**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings build:res && pnpm --filter @jvlk/rescript-bindings exec node test/DiscoveryApi_test.res.mjs
```

Expected: `DiscoveryApi_test.res passed`.

---

### Task 2: Discovery Client and Table Output

**Files:**
- Create: `packages/cli/src/discovery/RegistryDiscovery.res`
- Create: `packages/cli/test/RegistryDiscovery_test.res`
- Modify: `packages/cli/package.json`

- [ ] **Step 1: Write the failing discovery client test**

Create `packages/cli/test/RegistryDiscovery_test.res`:

```rescript
open TestSupport

let fetchUrls: array<string> = []

let entry = {
  "packageName": "react",
  "author": "josh",
  "authorDisplayName": "Josh",
  "libraryVersions": ["^19.0.0", "^18.0.0"],
  "rescriptVersions": ["^12.0.0"],
  "latestCreatedAt": "2026-05-10T13:00:00.000Z",
  "releases": [
    {
      "id": "react-josh-1",
      "packageName": "react",
      "variantLabel": "default",
      "variantSlug": "default",
      "peerPackageRange": "^19.0.0",
      "rescriptRange": "^12.0.0",
      "description": "React bindings",
      "createdAt": "2026-05-10T13:00:00.000Z",
    },
  ],
}

let fetcher = async url => {
  fetchUrls->push(url)->ignore
  if url->includes("/v1/bindings?limit=50") {
    jsonResponse({"entries": [entry]})
  } else if url->includes("/v1/bindings/search?q=react") {
    jsonResponse({"entries": [entry]})
  } else if url->includes("/v1/bindings/recent") {
    jsonResponse({"entries": [entry]})
  } else {
    throw(Failure("Unexpected URL: " ++ url))
  }
}

let run = async () => {
  let listed = await RegistryDiscovery.listEntries(
    ~fetchImpl=fetcher,
    ~apiBaseUrl=RegistryDiscovery.registryApiBaseUrl,
    ~limit=Some("50"),
  )
  assertTrue(listed->Array.length == 1, "list parses grouped entries")
  assertTrue(
    fetchUrls->some(url => url == RegistryDiscovery.registryApiBaseUrl ++ "/v1/bindings?limit=50"),
    "list uses capped bindings endpoint",
  )

  let searched = await RegistryDiscovery.searchEntries(
    ~fetchImpl=fetcher,
    ~apiBaseUrl=RegistryDiscovery.registryApiBaseUrl,
    ~query="react",
  )
  assertTrue(searched->Array.length == 1, "search parses grouped entries")
  assertTrue(
    fetchUrls->some(url => url == RegistryDiscovery.registryApiBaseUrl ++ "/v1/bindings/search?q=react"),
    "search encodes query URL",
  )

  let recent = await RegistryDiscovery.recentEntries(
    ~fetchImpl=fetcher,
    ~apiBaseUrl=RegistryDiscovery.registryApiBaseUrl,
  )
  assertTrue(recent->Array.length == 1, "recent parses grouped entries")

  let rows = RegistryDiscovery.tableRows(listed)
  assertTrue(rows->Array.length == 2, "table rows include header and one entry")
  assertTrue(rows[0]->Belt.Option.getExn->includes("Package"), "table header includes Package")
  assertTrue(rows[1]->Belt.Option.getExn->includes("react"), "table row includes package name")
  assertTrue(rows[1]->Belt.Option.getExn->includes("Josh"), "table row includes author display name")

  let emptySearchMessage = ref("")
  try {
    let _ = await RegistryDiscovery.searchEntries(
      ~fetchImpl=fetcher,
      ~apiBaseUrl=RegistryDiscovery.registryApiBaseUrl,
      ~query="  ",
    )
  } catch {
  | error => emptySearchMessage := messageFromError(error)
  }
  assertTrue(emptySearchMessage.contents->includes("Search query is required"), "empty search fails locally")

  Console.log("RegistryDiscovery_test.res passed")
}

let () = {
  run()
  ->Promise.catch(async error => {
    Console.error(messageFromError(error))
    NodeProcess.exit(1)
  })
  ->ignore
}
```

Add the test to `packages/cli/package.json` after `DiscoveryApi_test.res.mjs`:

```json
"test": "pnpm run build && node test/Validation_test.res.mjs && node test/Cli_test.res.mjs && node test/AddCore_test.res.mjs && node test/PublishCore_test.res.mjs && node test/PackageJson_test.res.mjs && node test/Add_test.res.mjs && node test/PublishOAuth_test.res.mjs && node test/Worker_test.res.mjs && node test/DiscoveryApi_test.res.mjs && node test/RegistryDiscovery_test.res.mjs && node test/Bin_test.res.mjs && node test/D1_test.res.mjs"
```

- [ ] **Step 2: Run the discovery test and verify it fails**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings build:res && pnpm --filter @jvlk/rescript-bindings exec node test/RegistryDiscovery_test.res.mjs
```

Expected: ReScript build fails because `RegistryDiscovery` does not exist.

- [ ] **Step 3: Implement `RegistryDiscovery.res`**

Create `packages/cli/src/discovery/RegistryDiscovery.res`:

```rescript
type releaseSummary = {
  id: string,
  packageName: string,
  variantLabel: string,
  variantSlug: string,
  peerPackageRange: string,
  rescriptRange: string,
  description: option<string>,
  createdAt: string,
}

type entry = {
  packageName: string,
  author: string,
  authorDisplayName: string,
  libraryVersions: array<string>,
  rescriptVersions: array<string>,
  latestCreatedAt: string,
  releases: array<releaseSummary>,
}

type entriesPayload = {entries: option<array<entry>>}
type fetchImpl = string => promise<WebFetch.response>
type errorPayload = {error: option<string>, message: option<string>}

@send external trim: string => string = "trim"
@send external includesContentType: (string, string) => bool = "includes"
@send external padEnd: (string, int) => string = "padEnd"
@val external encodeURIComponent: string => string = "encodeURIComponent"
@new external makeJsError: string => exn = "Error"
external jsonAs: WebFetch.jsonValue => 'a = "%identity"

let registryApiBaseUrl = RegistryConfig.registryApiBaseUrl

let fail = message => throw(makeJsError(message))

let readJson = async (response: WebFetch.response): 'payload => {
  if response->WebFetch.ok {
    (await response->WebFetch.json)->jsonAs
  } else {
    let contentType = response->WebFetch.headers->WebFetch.getHeader("content-type")->Belt.Option.getWithDefault("")
    if contentType->includesContentType("application/json") {
      let payload: errorPayload = (await response->WebFetch.json)->jsonAs
      fail(switch payload.error {
      | Some(error) => error
      | None =>
        switch payload.message {
        | Some(message) => message
        | None => "HTTP " ++ response->WebFetch.status->Int.toString
        }
      })
    } else {
      let body = await response->WebFetch.text
      fail(if body == "" {"HTTP " ++ response->WebFetch.status->Int.toString} else {body})
    }
  }
}

let entriesFrom = async (response: WebFetch.response): array<entry> => {
  let payload: entriesPayload = await readJson(response)
  payload.entries->Belt.Option.getWithDefault([])
}

let listEntries = async (~fetchImpl, ~apiBaseUrl, ~limit: option<string>) => {
  let limitValue = switch limit {
  | Some(limit) if limit->trim != "" => limit->trim
  | _ => "50"
  }
  await entriesFrom(await fetchImpl(apiBaseUrl ++ "/v1/bindings?limit=" ++ encodeURIComponent(limitValue)))
}

let searchEntries = async (~fetchImpl, ~apiBaseUrl, ~query) => {
  let trimmed = query->trim
  if trimmed == "" {
    fail("Search query is required")
  }
  await entriesFrom(await fetchImpl(apiBaseUrl ++ "/v1/bindings/search?q=" ++ encodeURIComponent(trimmed)))
}

let recentEntries = async (~fetchImpl, ~apiBaseUrl) =>
  await entriesFrom(await fetchImpl(apiBaseUrl ++ "/v1/bindings/recent"))

let width = (rows, label, value) =>
  rows->Array.reduce(label->String.length, (maxWidth, row) => max(maxWidth, value(row)->String.length))

let tableRows = entries => {
  let packageWidth = width(entries, "Package", entry => entry.packageName)
  let authorWidth = width(entries, "Author", entry => entry.authorDisplayName)
  let libraryWidth = width(entries, "Library", entry => entry.libraryVersions->Array.join(", "))
  let rescriptWidth = width(entries, "ReScript", entry => entry.rescriptVersions->Array.join(", "))

  Array.concat(
    [
      "Package"->padEnd(packageWidth) ++
      "  " ++ "Author"->padEnd(authorWidth) ++
      "  " ++ "Library"->padEnd(libraryWidth) ++
      "  " ++ "ReScript"->padEnd(rescriptWidth) ++
      "  Latest",
    ],
    entries->Array.map(entry =>
      entry.packageName->padEnd(packageWidth) ++
      "  " ++ entry.authorDisplayName->padEnd(authorWidth) ++
      "  " ++ entry.libraryVersions->Array.join(", ")->padEnd(libraryWidth) ++
      "  " ++ entry.rescriptVersions->Array.join(", ")->padEnd(rescriptWidth) ++
      "  " ++ entry.latestCreatedAt
    ),
  )
}

let printEntries = (~log, ~emptyMessage, entries) => {
  if entries->Array.length == 0 {
    log(emptyMessage)
  } else {
    tableRows(entries)->Array.forEach(log)
  }
}
```

- [ ] **Step 4: Run the discovery test and verify it passes**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings build:res && pnpm --filter @jvlk/rescript-bindings exec node test/RegistryDiscovery_test.res.mjs
```

Expected: `RegistryDiscovery_test.res passed`.

---

### Task 3: Extract Shared Install Helper From `add`

**Files:**
- Modify: `packages/cli/src/bindings/RegistryAdd.res`
- Modify: `packages/cli/test/Add_test.res`

- [ ] **Step 1: Add a failing test for installing a known release id**

In `packages/cli/test/Add_test.res`, add this case after the first `withProject` add install case:

```rescript
await withProject(async installKnownReleaseCwd => {
  let requests = []
  let logs = []

  await RegistryAdd.installReleaseIdWithDeps(
    ~releaseId="release-1",
    ~folder=None,
    ~deps=addDeps(
      ~cwd=installKnownReleaseCwd,
      ~fetch=makeFetch(requests),
      ~log=message => logs->push(message)->ignore,
      (),
    ),
  )

  let installed = await NodeFs.readFileUtf8(
    NodePath.join4(installKnownReleaseCwd, "src", "bindings", "IsEven.res"),
    "utf8",
  )

  assertStringEquals(installed, firstFileContent(releasePayload), "known release install writes release files")
  assertTrue(
    requests->some(url => url == RegistryAdd.registryApiBaseUrl ++ "/v1/releases/release-1"),
    "known release install fetches selected release payload",
  )
  assertTrue(logs->some(message => message->includes("Installed is-even to")), "known release install prints summary")
})
```

- [ ] **Step 2: Run the add test and verify it fails**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings build:res && pnpm --filter @jvlk/rescript-bindings exec node test/Add_test.res.mjs
```

Expected: ReScript build fails because `RegistryAdd.installReleaseIdWithDeps` does not exist.

- [ ] **Step 3: Extract the helper in `RegistryAdd.res`**

In `packages/cli/src/bindings/RegistryAdd.res`, add this helper after `writeReleaseFiles`:

```rescript
let installReleasePayloadWithDeps = async (
  ~release: releasePayload,
  ~folder: option<string>,
  ~deps: deps,
): unit => {
  let projectCwd = depCwd(deps)->Belt.Option.getWithDefault(cwd())
  let log = depLog(deps)->Belt.Option.getWithDefault(message => Console.log(message))
  let promptStdin = depStdin(deps)->Belt.Option.getWithDefault(stdin)
  let promptStdout = depStdout(deps)->Belt.Option.getWithDefault(stdout)
  let confirmOverwrite = depConfirmOverwrite(deps)->Belt.Option.getWithDefault(defaultConfirmOverwrite)
  let options = promptOptions(~stdin=promptStdin, ~stdout=promptStdout, ~log, ())
  let targetPlan = await targetPlanFor(
    ~cwd=projectCwd,
    ~folder,
    ~release,
    ~stdin=promptStdin,
    ~stdout=promptStdout,
  )
  let targetFiles = release.files->Array.map(file => {
    targetPath: targetPlan.targetPathForFile(file),
    content: file.content,
  })
  let existingFiles = await existingFilesFrom(targetFiles)

  if existingFiles->Array.length > 0 {
    let shouldOverwrite = await confirmOverwrite(existingFiles, options)
    if shouldOverwrite {
      await writeReleaseFiles(targetFiles)
      log("Installed " ++ release.packageName ++ " to " ++ targetPlan.summaryPath)
    } else {
      log("Install cancelled.")
    }
  } else {
    await writeReleaseFiles(targetFiles)
    log("Installed " ++ release.packageName ++ " to " ++ targetPlan.summaryPath)
  }
}

let installReleaseIdWithDeps = async (~releaseId, ~folder, ~deps): unit => {
  let fetchImpl = depFetch(deps)->Belt.Option.orElse(globalFetch)->requireFetch
  let release = await fetchRelease(~releaseId, ~fetchImpl)
  await installReleasePayloadWithDeps(~release, ~folder, ~deps)
}
```

Then simplify the install section of `runAddWithDeps` after `let selectedRelease = await selectRelease(releases, options)`:

```rescript
let release = await fetchRelease(~releaseId=selectedRelease.id, ~fetchImpl)
await installReleasePayloadWithDeps(~release, ~folder, ~deps)
```

Remove the now-duplicated target planning/write block from `runAddWithDeps`.

- [ ] **Step 4: Run the add test and verify it passes**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings build:res && pnpm --filter @jvlk/rescript-bindings exec node test/Add_test.res.mjs
```

Expected: `Add_test.res passed`.

---

### Task 4: Implement `get` Dependency Matching and Approval

**Files:**
- Create: `packages/cli/src/discovery/RegistryGet.res`
- Create: `packages/cli/test/RegistryGet_test.res`
- Modify: `packages/cli/package.json`

- [ ] **Step 1: Write the failing `get` test**

Create `packages/cli/test/RegistryGet_test.res`:

```rescript
open TestSupport

@obj
external getDeps: (
  ~cwd: string=?,
  ~fetch: RegistryGet.fetchImpl=?,
  ~selectRelease: RegistryGet.selectReleaseImpl=?,
  ~confirmPlan: RegistryGet.confirmPlanImpl=?,
  ~log: RegistryGet.logImpl=?,
  ~stdin: RegistryGet.input=?,
  ~stdout: RegistryGet.output=?,
  unit,
) => RegistryGet.deps = ""

let nonTtyInput: RegistryGet.input = %raw(`({ isTTY: false })`)
let nonTtyOutput: RegistryGet.output = %raw(`({ isTTY: false })`)

let reactRelease: RegistryAdd.releaseSummary = {
  id: "react-release",
  packageName: "react",
  publisherLogin: "josh",
  peerPackageRange: "^19.0.0",
  rescriptRange: "^12.0.0",
  isPackageCompatible: Some(true),
  isRescriptCompatible: Some(true),
}

let jotaiRelease: RegistryAdd.releaseSummary = {
  id: "jotai-release",
  packageName: "jotai",
  publisherLogin: "dev",
  peerPackageRange: "^2.0.0",
  rescriptRange: "^12.0.0",
  isPackageCompatible: Some(true),
  isRescriptCompatible: Some(true),
}

let makeProject = async () => {
  let projectCwd = await NodeFs.mkdtemp(NodePath.join2(NodeOs.tmpdir(), "rescript-binding-get-"))
  await NodeFs.writeFileUtf8(
    NodePath.join2(projectCwd, "package.json"),
    stringify({
      "dependencies": {"react": "^19.0.0", "missing-lib": "1.0.0"},
      "devDependencies": {"jotai": "^2.0.0", "rescript": "^12.0.0"},
    }),
    "utf8",
  )
  projectCwd
}

let cleanup = async projectCwd =>
  await NodeFs.rm(projectCwd, {"recursive": true, "force": true})

let withProject = async test => {
  let projectCwd = await makeProject()
  try {
    await test(projectCwd)
    await cleanup(projectCwd)
  } catch {
  | error =>
    await cleanup(projectCwd)
    throw(error)
  }
}

let releasePayload = (~id, ~packageName, ~relativePath, ~content): RegistryAdd.releasePayload => {
  id,
  packageName,
  files: [{relativePath, content}],
}

let fetcher = requests => async url => {
  requests->push(url)->ignore
  if url->includes("/v1/packages/react/releases?") {
    jsonResponse({"releases": [reactRelease]})
  } else if url->includes("/v1/packages/jotai/releases?") {
    jsonResponse({"releases": [jotaiRelease]})
  } else if url->includes("/v1/packages/missing-lib/releases?") {
    jsonResponse({"releases": []})
  } else if url->includes("/v1/releases/react-release") {
    jsonResponse(releasePayload(
      ~id="react-release",
      ~packageName="react",
      ~relativePath="React.res",
      ~content="let react = true\n",
    ))
  } else if url->includes("/v1/releases/jotai-release") {
    jsonResponse(releasePayload(
      ~id="jotai-release",
      ~packageName="jotai",
      ~relativePath="Jotai.res",
      ~content="let jotai = true\n",
    ))
  } else {
    throw(Failure("Unexpected URL: " ++ url))
  }
}

let selectFirst = async (_dependencyName, releases, _options) => releases[0]->Belt.Option.getExn

let run = async () => {
  await withProject(async projectCwd => {
    let requests = []
    let logs = []

    await RegistryGet.runGetWithDeps(getDeps(
      ~cwd=projectCwd,
      ~fetch=fetcher(requests),
      ~selectRelease=selectFirst,
      ~confirmPlan=async (_plan, _options) => false,
      ~log=message => logs->push(message)->ignore,
      (),
    ))

    assertTrue(
      requests->some(url => url->includes("/v1/packages/react/releases?")),
      "get checks exact react releases",
    )
    assertTrue(
      requests->some(url => url->includes("/v1/packages/jotai/releases?")),
      "get checks exact jotai releases",
    )
    assertTrue(
      requests->some(url => url->includes("packageVersion=%5E19.0.0")),
      "get sends dependency version",
    )
    assertTrue(
      requests->some(url => url->includes("rescriptVersion=%5E12.0.0")),
      "get sends ReScript version",
    )
    assertTrue(
      !(NodeFs.existsSync(NodePath.join4(projectCwd, "src", "bindings", "React.res"))),
      "get approval cancel prevents react install",
    )
    assertTrue(logs->some(message => message->includes("Install cancelled.")), "get logs cancelled plan")
  })

  await withProject(async projectCwd => {
    let requests = []
    await RegistryGet.runGetWithDeps(getDeps(
      ~cwd=projectCwd,
      ~fetch=fetcher(requests),
      ~selectRelease=selectFirst,
      ~confirmPlan=async (_plan, _options) => true,
      ~log=_message => (),
      (),
    ))

    assertStringEquals(
      await NodeFs.readFileUtf8(NodePath.join4(projectCwd, "src", "bindings", "React.res"), "utf8"),
      "let react = true\n",
      "get approved plan installs selected react release",
    )
    assertStringEquals(
      await NodeFs.readFileUtf8(NodePath.join4(projectCwd, "src", "bindings", "Jotai.res"), "utf8"),
      "let jotai = true\n",
      "get approved plan installs selected jotai release",
    )
  })

  await withProject(async projectCwd => {
    let nonInteractiveMessage = ref("")
    try {
      await RegistryGet.runGetWithDeps(getDeps(
        ~cwd=projectCwd,
        ~fetch=fetcher([]),
        ~stdin=nonTtyInput,
        ~stdout=nonTtyOutput,
        ~log=_message => (),
        (),
      ))
    } catch {
    | error => nonInteractiveMessage := messageFromError(error)
    }
    assertTrue(
      nonInteractiveMessage.contents->includes("interactive terminal"),
      "get requires interactivity for release selection",
    )
  })

  Console.log("RegistryGet_test.res passed")
}

let () = {
  run()
  ->Promise.catch(async error => {
    Console.error(messageFromError(error))
    NodeProcess.exit(1)
  })
  ->ignore
}
```

Add the test to `packages/cli/package.json` immediately after `RegistryDiscovery_test.res.mjs`:

```json
"test": "pnpm run build && node test/Validation_test.res.mjs && node test/Cli_test.res.mjs && node test/AddCore_test.res.mjs && node test/PublishCore_test.res.mjs && node test/PackageJson_test.res.mjs && node test/Add_test.res.mjs && node test/PublishOAuth_test.res.mjs && node test/Worker_test.res.mjs && node test/DiscoveryApi_test.res.mjs && node test/RegistryDiscovery_test.res.mjs && node test/RegistryGet_test.res.mjs && node test/Bin_test.res.mjs && node test/D1_test.res.mjs"
```

- [ ] **Step 2: Run the `get` test and verify it fails**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings build:res && pnpm --filter @jvlk/rescript-bindings exec node test/RegistryGet_test.res.mjs
```

Expected: ReScript build fails because `RegistryGet` does not exist.

- [ ] **Step 3: Implement `RegistryGet.res` types and dependency scanning**

Create `packages/cli/src/discovery/RegistryGet.res` with these foundations:

```rescript
type input = RegistryAdd.input
type output = RegistryAdd.output
type deps
type promptOptions = RegistryAdd.promptOptions
type promptContext
type selectConfig
type releaseChoice
type readline
type fetchImpl = RegistryAdd.fetchImpl
type logImpl = RegistryAdd.logImpl
type selectReleaseImpl = (string, array<RegistryAdd.releaseSummary>, promptOptions) => promise<RegistryAdd.releaseSummary>
type installPlanItem = {
  dependencyName: string,
  release: RegistryAdd.releaseSummary,
}
type confirmPlanImpl = (array<installPlanItem>, promptOptions) => promise<bool>

@module("node:process") external stdin: input = "stdin"
@module("node:process") external stdout: output = "stdout"
@module("node:process") external cwd: unit => string = "cwd"
@send external trim: string => string = "trim"
@send external toLowerCase: string => string = "toLowerCase"
@get external isInputTty: input => option<bool> = "isTTY"
@get external isOutputTty: output => option<bool> = "isTTY"
@get external errorCode: JsExn.t => option<string> = "code"
@new external makeJsError: string => exn = "Error"
@send external question: (readline, string) => promise<string> = "question"
@send external close: readline => unit = "close"

@obj external emptyDeps: unit => deps = ""
@obj external promptOptions: (~stdin: input, ~stdout: output, ~log: logImpl, unit) => promptOptions = ""
@obj external promptContext: (~input: input, ~output: output, unit) => promptContext = ""
@obj external releaseChoice: (~name: string, ~value: RegistryAdd.releaseSummary, unit) => releaseChoice = ""
@obj
external selectConfig: (
  ~message: string,
  ~pageSize: int,
  ~loop: bool,
  ~choices: array<releaseChoice>,
  unit,
) => selectConfig = ""
@get external depFetch: deps => option<fetchImpl> = "fetch"
@get external depCwd: deps => option<string> = "cwd"
@get external depLog: deps => option<logImpl> = "log"
@get external depStdin: deps => option<input> = "stdin"
@get external depStdout: deps => option<output> = "stdout"
@get external depSelectRelease: deps => option<selectReleaseImpl> = "selectRelease"
@get external depConfirmPlan: deps => option<confirmPlanImpl> = "confirmPlan"
@get external promptStdin: promptOptions => input = "stdin"
@get external promptStdout: promptOptions => output = "stdout"
@get external promptLog: promptOptions => logImpl = "log"

@scope("JSON") @val external parsePackageJson: string => PackageJson.packageJson = "parse"
@val @scope("globalThis") external globalFetch: option<fetchImpl> = "fetch"
@module("@inquirer/prompts") external select: (selectConfig, promptContext) => promise<RegistryAdd.releaseSummary> = "select"
@module("node:readline/promises") external createInterface: {. "input": input, "output": output} => readline = "createInterface"
external asAddDeps: deps => RegistryAdd.deps = "%identity"

let fail = message => throw(makeJsError(message))

let isTty = streamTty => streamTty->Belt.Option.getWithDefault(false)

let requireFetch = fetchImpl =>
  switch fetchImpl {
  | Some(fetchImpl) => fetchImpl
  | None => fail("get requires a fetch implementation")
  }

let readProjectPackageJson = async projectCwd => {
  let packageJsonPath = NodePath.join2(projectCwd, "package.json")
  try {
    (await NodeFs.readFileUtf8(packageJsonPath, "utf8"))->parsePackageJson
  } catch {
  | error =>
    switch error->JsExn.fromException {
    | Some(jsError) if errorCode(jsError) == Some("ENOENT") =>
      fail("get requires a package.json in the current project")
    | _ => fail("Could not parse " ++ packageJsonPath)
    }
  }
}
```

- [ ] **Step 4: Implement interactive prompts and plan formatting**

Continue `RegistryGet.res` with:

```rescript
let releaseChoiceLabel = (release: RegistryAdd.releaseSummary) =>
  release.packageName ++
  "  " ++ release.publisherLogin ++
  "  " ++ release.peerPackageRange ++
  "  " ++ release.rescriptRange ++
  "  " ++ release.id

let defaultSelectRelease = async (dependencyName, releases, options) => {
  let promptInput = promptStdin(options)
  let promptOutput = promptStdout(options)

  if !isTty(isInputTty(promptInput)) || !isTty(isOutputTty(promptOutput)) {
    fail("get requires an interactive terminal for release selection")
  }

  await select(
    selectConfig(
      ~message="Select binding for " ++ dependencyName,
      ~pageSize=8,
      ~loop=true,
      ~choices=releases->Array.map(release =>
        releaseChoice(~name=releaseChoiceLabel(release), ~value=release, ())
      ),
      (),
    ),
    promptContext(~input=promptInput, ~output=promptOutput, ()),
  )
}

let planRows = plan =>
  plan->Array.map(item => item.dependencyName ++ " -> " ++ releaseChoiceLabel(item.release))

let defaultConfirmPlan = async (plan, options) => {
  let log = promptLog(options)
  let promptInput = promptStdin(options)
  let promptOutput = promptStdout(options)
  log("Binding install plan:")
  planRows(plan)->Array.forEach(row => log("  " ++ row))

  if !isTty(isInputTty(promptInput)) || !isTty(isOutputTty(promptOutput)) {
    fail("get requires an interactive terminal for final approval")
  }

  let readline = createInterface({"input": promptInput, "output": promptOutput})
  let answer = (await readline->question("Install these bindings? [y/N]: "))->trim->toLowerCase
  readline->close
  answer == "y" || answer == "yes"
}
```

- [ ] **Step 5: Implement release lookup and installation orchestration**

Finish `RegistryGet.res` with:

```rescript
let releasesForDependency = async (~fetchImpl, ~packageJson, ~dependencyName) => {
  let packageVersion = PackageJson.dependencyVersionFrom(packageJson, dependencyName)
  let rescriptVersion = PackageJson.dependencyVersionFrom(packageJson, "rescript")
  await RegistryAdd.listPackageReleases(
    ~packageName=dependencyName,
    ~packageVersion,
    ~rescriptVersion,
    ~fetchImpl,
  )
}

let runGetWithDeps = async (deps: deps): unit => {
  let fetchImpl = depFetch(deps)->Belt.Option.orElse(globalFetch)->requireFetch
  let projectCwd = depCwd(deps)->Belt.Option.getWithDefault(cwd())
  let log = depLog(deps)->Belt.Option.getWithDefault(message => Console.log(message))
  let promptStdin = depStdin(deps)->Belt.Option.getWithDefault(stdin)
  let promptStdout = depStdout(deps)->Belt.Option.getWithDefault(stdout)
  let selectRelease = depSelectRelease(deps)->Belt.Option.getWithDefault(defaultSelectRelease)
  let confirmPlan = depConfirmPlan(deps)->Belt.Option.getWithDefault(defaultConfirmPlan)
  let options = promptOptions(~stdin=promptStdin, ~stdout=promptStdout, ~log, ())
  let packageJson = await readProjectPackageJson(projectCwd)
  let dependencyNames = PackageJson.dependencyNamesFrom(packageJson)
  let plan: array<installPlanItem> = []

  for index in 0 to dependencyNames->Array.length - 1 {
    switch dependencyNames[index] {
    | Some(dependencyName) =>
      let releases = await releasesForDependency(~fetchImpl, ~packageJson, ~dependencyName)
      if releases->Array.length > 0 {
        let release = await selectRelease(dependencyName, releases, options)
        plan->Array.push({dependencyName, release})->ignore
      }
    | None => ()
    }
  }

  if plan->Array.length == 0 {
    log("No matching bindings found for dependencies in package.json.")
  } else {
    let approved = await confirmPlan(plan, options)
    if approved {
      for index in 0 to plan->Array.length - 1 {
        switch plan[index] {
        | Some(item) =>
          await RegistryAdd.installReleaseIdWithDeps(
            ~releaseId=item.release.id,
            ~folder=None,
            ~deps=asAddDeps(deps),
          )
        | None => ()
        }
      }
    } else {
      log("Install cancelled.")
    }
  }
}

let runGet = async () => await runGetWithDeps(emptyDeps())
```

- [ ] **Step 6: Run the `get` test and verify it passes**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings build:res && pnpm --filter @jvlk/rescript-bindings exec node test/RegistryGet_test.res.mjs
```

Expected: `RegistryGet_test.res passed`.

---

### Task 5: Wire CLI Commands

**Files:**
- Modify: `packages/cli/src/bindings/Commander.res`
- Modify: `packages/cli/src/Command.res`
- Modify: `packages/cli/src/Cli.res`
- Modify: `packages/cli/test/Cli_test.res`
- Modify: `packages/cli/test/Bin_test.res`

- [ ] **Step 1: Write failing CLI parse/helper tests**

In `packages/cli/test/Cli_test.res`, add these assertions after the existing `publish` parse:

```rescript
assertParse(
  ["node", "src/Main.res.mjs", "list"],
  Some(("list", "", None)),
  "parse list command",
)

assertParse(
  ["node", "src/Main.res.mjs", "list", "--limit", "25"],
  Some(("list", "", Some("25"))),
  "parse list command with limit",
)

assertParse(
  ["node", "src/Main.res.mjs", "search", "react"],
  Some(("search", "react", None)),
  "parse search command",
)

assertParse(
  ["node", "src/Main.res.mjs", "recent"],
  Some(("recent", "", None)),
  "parse recent command",
)

assertParse(
  ["node", "src/Main.res.mjs", "get"],
  Some(("get", "", None)),
  "parse get command",
)
```

In `packages/cli/test/Bin_test.res`, add after `addHelp`:

```rescript
let listHelp = await importBinWithArgs(["list", "--help"], "bin-test-list-help", wrapperPath, wrapperHref)
TestSupport.assertTrue(listHelp->runExitCode == None || listHelp->runExitCode == Some(0), "list help exits successfully")
TestSupport.assertTrue(listHelp->runStdout->TestSupport.includes("--limit <n>"), "list help documents limit")

let searchHelp = await importBinWithArgs(["search", "--help"], "bin-test-search-help", wrapperPath, wrapperHref)
TestSupport.assertTrue(searchHelp->runExitCode == None || searchHelp->runExitCode == Some(0), "search help exits successfully")
TestSupport.assertTrue(searchHelp->runStdout->TestSupport.includes("<query>"), "search help documents query")

let recentHelp = await importBinWithArgs(["recent", "--help"], "bin-test-recent-help", wrapperPath, wrapperHref)
TestSupport.assertTrue(recentHelp->runExitCode == None || recentHelp->runExitCode == Some(0), "recent help exits successfully")

let getHelp = await importBinWithArgs(["get", "--help"], "bin-test-get-help", wrapperPath, wrapperHref)
TestSupport.assertTrue(getHelp->runExitCode == None || getHelp->runExitCode == Some(0), "get help exits successfully")
```

- [ ] **Step 2: Run CLI tests and verify they fail**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings build:res && pnpm --filter @jvlk/rescript-bindings exec node test/Cli_test.res.mjs && pnpm --filter @jvlk/rescript-bindings exec node test/Bin_test.res.mjs
```

Expected: `Cli_test` fails because parse does not recognize new commands, and `Bin_test` fails because Commander has no new subcommands.

- [ ] **Step 3: Add Commander externals**

In `packages/cli/src/bindings/Commander.res`, add:

```rescript
type listOptions

@send external actionList: (program, listOptions => promise<unit>) => program = "action"
@send external actionSearch: (program, string => promise<unit>) => program = "action"
@send external actionNoArgs: (program, unit => promise<unit>) => program = "action"

@get external limit: listOptions => option<string> = "limit"
```

- [ ] **Step 4: Wire commands in `Command.res`**

In `packages/cli/src/Command.res`, add command builders after `addPublishCommand`:

```rescript
let addListCommand = program => {
  program
  ->Commander.command("list")
  ->Commander.description("List available ReScript bindings")
  ->Commander.option("-l, --limit <n>", "maximum number of binding groups to show")
  ->Commander.actionList(async options =>
    await RegistryDiscovery.runList(Commander.limit(options))
  )
  ->ignore
}

let addSearchCommand = program => {
  program
  ->Commander.command("search")
  ->Commander.description("Search available ReScript bindings")
  ->Commander.argument("<query>", "package name search query")
  ->Commander.actionSearch(async query => await RegistryDiscovery.runSearch(query))
  ->ignore
}

let addRecentCommand = program => {
  program
  ->Commander.command("recent")
  ->Commander.description("Show recently updated ReScript bindings")
  ->Commander.actionNoArgs(async () => await RegistryDiscovery.runRecent())
  ->ignore
}

let addGetCommand = program => {
  program
  ->Commander.command("get")
  ->Commander.description("Install bindings matching dependencies in package.json")
  ->Commander.actionNoArgs(async () => await RegistryGet.runGet())
  ->ignore
}
```

Update `makeProgram`:

```rescript
let makeProgram = () => {
  let program = Commander.make()->configureBaseProgram
  addAddCommand(program)
  addPublishCommand(program)
  addListCommand(program)
  addSearchCommand(program)
  addRecentCommand(program)
  addGetCommand(program)
  program
}
```

- [ ] **Step 5: Add command runners to `RegistryDiscovery.res`**

Append:

```rescript
let defaultFetch = url => WebFetch.fetch(url, %raw(`undefined`))

let runList = async limit => {
  let entries = await listEntries(~fetchImpl=defaultFetch, ~apiBaseUrl=registryApiBaseUrl, ~limit)
  printEntries(~log=message => Console.log(message), ~emptyMessage="No bindings found.", entries)
}

let runSearch = async query => {
  let entries = await searchEntries(~fetchImpl=defaultFetch, ~apiBaseUrl=registryApiBaseUrl, ~query)
  printEntries(~log=message => Console.log(message), ~emptyMessage="No bindings found.", entries)
}

let runRecent = async () => {
  let entries = await recentEntries(~fetchImpl=defaultFetch, ~apiBaseUrl=registryApiBaseUrl)
  printEntries(~log=message => Console.log(message), ~emptyMessage="No recent bindings found.", entries)
}
```

- [ ] **Step 6: Update manual parse and usage helpers**

In `packages/cli/src/Cli.res`, update `usage`:

```rescript
let usage = () => {
  Console.log("Usage:")
  Console.log("  rescript-bindings add <package> [--folder <path>]")
  Console.log("  rescript-bindings publish")
  Console.log("  rescript-bindings list [--limit <n>]")
  Console.log("  rescript-bindings search <query>")
  Console.log("  rescript-bindings recent")
  Console.log("  rescript-bindings get")
}
```

Update `parse`:

```rescript
let parse = (argv: array<string>): option<(string, string, option<string>)> => {
  switch argv {
  | [_, _, "add", packageName] => Some(("add", packageName, None))
  | [_, _, "add", packageName, "--folder", folder] => Some(("add", packageName, Some(folder)))
  | [_, _, "publish"] => Some(("publish", "", None))
  | [_, _, "list"] => Some(("list", "", None))
  | [_, _, "list", "--limit", limit] => Some(("list", "", Some(limit)))
  | [_, _, "search", query] => Some(("search", query, None))
  | [_, _, "recent"] => Some(("recent", "", None))
  | [_, _, "get"] => Some(("get", "", None))
  | _ => None
  }
}
```

- [ ] **Step 7: Run CLI tests and verify they pass**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings build:res && pnpm --filter @jvlk/rescript-bindings exec node test/Cli_test.res.mjs && pnpm --filter @jvlk/rescript-bindings exec node test/Bin_test.res.mjs
```

Expected: both tests pass.

---

### Task 6: Documentation and Full Verification

**Files:**
- Modify: `README.md`
- Modify: `packages/cli/README.md`

- [ ] **Step 1: Update root README command examples**

In `README.md`, replace the CLI examples section with:

````markdown
## Use The CLI

Browse published bindings:

```bash
pnpx @jvlk/rescript-bindings list
pnpx @jvlk/rescript-bindings search react
pnpx @jvlk/rescript-bindings recent
```

Install published bindings into a ReScript project:

```bash
pnpx @jvlk/rescript-bindings add jotai
pnpx @jvlk/rescript-bindings get
```

Publish local bindings:

```bash
pnpx @jvlk/rescript-bindings publish
```
````

Add this paragraph after the existing `add` behavior paragraph:

```markdown
`list` shows up to 50 grouped binding entries by default. `search <query>` filters
bindings by package name, and `recent` shows recently updated bindings. `get`
scans the current project's dependencies, prompts for matching releases, shows a
single install plan, and writes files only after approval.
```

- [ ] **Step 2: Update package README CLI examples**

In `packages/cli/README.md`, replace the CLI block with:

````markdown
```bash
node ./bin/index.mjs list
node ./bin/index.mjs search react
node ./bin/index.mjs recent
node ./bin/index.mjs get
node ./bin/index.mjs add
node ./bin/index.mjs publish
```
````

- [ ] **Step 3: Run format/build/test verification**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings test
```

Expected: the package builds and every listed test prints its pass message.

- [ ] **Step 4: Run root test if package test passes**

Run:

```bash
pnpm test
```

Expected: CLI and web package tests pass. If this fails because of a web package issue unrelated to CLI discovery, capture the exact failing command and output before reporting.

- [ ] **Step 5: Check git diff**

Run:

```bash
git diff --stat
git diff --check
git status --short
```

Expected: no whitespace errors, and changed files are limited to the planned CLI, Worker, test, and README files plus the approved spec/plan artifacts.
