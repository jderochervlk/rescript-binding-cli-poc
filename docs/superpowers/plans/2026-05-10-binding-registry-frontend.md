# Binding Registry Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a separate Cloudflare Worker frontend for browsing and searching published ReScript bindings.

**Architecture:** Extend the existing registry Worker with public discovery endpoints, then create a separate `packages/web` Worker that calls those endpoints and renders Xote SSR pages. The web Worker does not bind D1 and uses Pico CSS from the CDN. If the Xote SSR smoke test fails in the Worker bundle, stop and replace the web package tasks with a client-rendered Xote shell using the same API contracts.

**Tech Stack:** ReScript 12, Xote, Cloudflare Workers, D1, Wrangler, Rolldown, Pico CSS CDN, pnpm workspaces

---

## File Structure

- Create: `packages/cli/test/DiscoveryApi_test.res`
  - focused registry API tests for recent, search, and package-author detail endpoints
- Modify: `packages/cli/package.json`
  - run the new discovery API test
- Modify: `packages/cli/src/Worker.res`
  - add public discovery routes, response types, D1 queries, grouping helpers, and detail payload handling
- Create: `packages/web/package.json`
  - separate web Worker package scripts and dependencies
- Create: `packages/web/rescript.json`
  - Xote/ReScript config with JSX enabled for future component work
- Create: `packages/web/rolldown.config.mjs`
  - bundle the Worker entrypoint and Xote dependency for Cloudflare Workers
- Create: `packages/web/wrangler.toml`
  - deploy config for the separate web Worker
- Create: `packages/web/src/RegistryClient.res`
  - typed public API client used by the web Worker
- Create: `packages/web/src/Pages.res`
  - Xote SSR page rendering, table rendering, detail tabs, code block formatting
- Create: `packages/web/src/Worker.res`
  - web Worker route parsing, API calls, and response generation
- Create: `packages/web/test/Worker_test.res`
  - web Worker tests with an injected fake registry fetcher
- Modify: `package.json`
  - add root scripts that build and test both workspace packages

## Task 1: Registry Discovery API Tests

**Files:**
- Create: `packages/cli/test/DiscoveryApi_test.res`
- Modify: `packages/cli/package.json`

- [ ] **Step 1: Add the failing discovery API test file**

Create `packages/cli/test/DiscoveryApi_test.res` with this content:

```rescript
type requestInit
type jsonBody
type entry
type release
type releaseFile

@new external makeRequest: string => Worker.request = "Request"
@get external responseStatus: Worker.response => int = "status"
@send external responseJson: Worker.response => promise<'body> = "json"
@get external entries: jsonBody => array<entry> = "entries"
@get external packageName: entry => string = "packageName"
@get external author: entry => string = "author"
@get external authorDisplayName: entry => string = "authorDisplayName"
@get external libraryVersions: entry => array<string> = "libraryVersions"
@get external rescriptVersions: entry => array<string> = "rescriptVersions"
@get external releases: entry => array<release> = "releases"
@get external releaseFiles: release => array<releaseFile> = "files"
@get external relativePath: releaseFile => string = "relativePath"
@get external content: releaseFile => string = "content"

let ctx = %raw(`({})`)
let publicApiBaseUrl = "https://rescript-binding-registry.josh-401.workers.dev/api"

let rows = %raw(`[
  {
    id: "react-josh-2",
    package_name: "react",
    variant_label: "default",
    variant_slug: "default",
    publisher_login: "josh",
    publisher_display_name: "Josh",
    peer_package_range: "^19.0.0",
    rescript_range: "^12.0.0",
    description: "React 19 bindings",
    file_count: 1,
    manifest_sha256: "manifest-2",
    status: "published",
    created_at: "2026-05-10T13:00:00.000Z",
  },
  {
    id: "react-josh-1",
    package_name: "react",
    variant_label: "legacy",
    variant_slug: "legacy",
    publisher_login: "josh",
    publisher_display_name: "Josh",
    peer_package_range: "^18.0.0",
    rescript_range: "^12.0.0",
    description: "React 18 bindings",
    file_count: 1,
    manifest_sha256: "manifest-1",
    status: "published",
    created_at: "2026-05-10T12:00:00.000Z",
  },
  {
    id: "rescript-react-dev-1",
    package_name: "@rescript/react",
    variant_label: "default",
    variant_slug: "default",
    publisher_login: "dev",
    publisher_display_name: "Dev",
    peer_package_range: "^0.11.0",
    rescript_range: "^11.0.0",
    description: "Official package bindings",
    file_count: 1,
    manifest_sha256: "manifest-3",
    status: "published",
    created_at: "2026-05-10T11:00:00.000Z",
  },
]`)

let filesByReleaseId = %raw(`({
  "react-josh-2": [
    {
      relative_path: "React.res",
      content: '@module("react")\\nexternal createElement: string => unit = "createElement"\\n',
      sha256: "file-2",
      bytes: 72,
    },
  ],
  "react-josh-1": [
    {
      relative_path: "React.res",
      content: '@module("react")\\nexternal legacy: unit => unit = "legacy"\\n',
      sha256: "file-1",
      bytes: 58,
    },
  ],
  "rescript-react-dev-1": [
    {
      relative_path: "RescriptReact.res",
      content: "let ready = true\\n",
      sha256: "file-3",
      bytes: 17,
    },
  ],
})`)

let fakeDb: Worker.env = %raw(`({
  DB: {
    prepare: sql => {
      const statement = {
        all: async () => {
          if (sql.includes("FROM binding_releases")) {
            return { results: rows };
          }
          return { results: [] };
        },
        bind: (...params) => ({
          all: async () => {
            if (sql.includes("FROM binding_files")) {
              return { results: filesByReleaseId[params[0]] || [] };
            }

            if (sql.includes("FROM binding_releases") && params[0] === "react" && params[1] === "josh") {
              return { results: rows.filter(row => row.package_name === "react" && row.publisher_login === "josh") };
            }

            if (sql.includes("FROM binding_releases") && params[0] === "missing" && params[1] === "josh") {
              return { results: [] };
            }

            if (sql.includes("FROM binding_releases") && typeof params[0] === "string") {
              const needle = params[0].replaceAll("%", "").toLowerCase();
              return { results: rows.filter(row => row.package_name.toLowerCase().includes(needle)) };
            }

            return { results: [] };
          },
          first: async () => null,
          run: async () => ({ success: true }),
        }),
      };
      return statement;
    },
    batch: async () => [],
  },
})`)

let first = items => items[0]->Belt.Option.getExn

let has = (values, expected) => values->Array.some(value => value == expected)

let run = async () => {
  let recent = await Worker.fetch(makeRequest(publicApiBaseUrl ++ "/v1/bindings/recent"), fakeDb, ctx)
  TestSupport.assertTrue(responseStatus(recent) == 200, "recent bindings endpoint returns success")
  let recentBody: jsonBody = await recent->responseJson
  let recentEntries = recentBody->entries
  TestSupport.assertTrue(recentEntries->Array.length == 2, "recent groups releases by package and author")
  let reactEntry = recentEntries->first
  TestSupport.assertStringEquals(reactEntry->packageName, "react", "recent entry keeps package name")
  TestSupport.assertStringEquals(reactEntry->author, "josh", "recent entry keeps author")
  TestSupport.assertStringEquals(reactEntry->authorDisplayName, "Josh", "recent entry keeps display name")
  TestSupport.assertTrue(reactEntry->libraryVersions->has("^19.0.0"), "recent entry includes newest library range")
  TestSupport.assertTrue(reactEntry->libraryVersions->has("^18.0.0"), "recent entry includes older library range")
  TestSupport.assertTrue(reactEntry->rescriptVersions->Array.length == 1, "recent entry deduplicates ReScript ranges")
  TestSupport.assertTrue(reactEntry->releases->Array.length == 2, "recent entry contains release summaries")

  let search = await Worker.fetch(makeRequest(publicApiBaseUrl ++ "/v1/bindings/search?q=script"), fakeDb, ctx)
  TestSupport.assertTrue(responseStatus(search) == 200, "search endpoint returns success")
  let searchBody: jsonBody = await search->responseJson
  let searchEntries = searchBody->entries
  TestSupport.assertTrue(searchEntries->Array.length == 1, "search returns substring package matches")
  TestSupport.assertStringEquals(searchEntries->first->packageName, "@rescript/react", "search matches scoped package names")

  let detail = await Worker.fetch(
    makeRequest(publicApiBaseUrl ++ "/v1/bindings/react/authors/josh"),
    fakeDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(detail) == 200, "detail endpoint returns success")
  let detailBody: entry = await detail->responseJson
  TestSupport.assertStringEquals(detailBody->packageName, "react", "detail keeps package name")
  TestSupport.assertTrue(detailBody->releases->Array.length == 2, "detail returns selected author releases")
  let files = detailBody->releases->first->releaseFiles
  TestSupport.assertTrue(files->Array.length == 1, "detail includes files")
  TestSupport.assertStringEquals(files->first->relativePath, "React.res", "detail maps file path")
  TestSupport.assertTrue(files->first->content->TestSupport.includes("@module"), "detail maps file content")

  let missing = await Worker.fetch(
    makeRequest(publicApiBaseUrl ++ "/v1/bindings/missing/authors/josh"),
    fakeDb,
    ctx,
  )
  TestSupport.assertTrue(responseStatus(missing) == 404, "missing detail returns 404")

  Console.log("DiscoveryApi_test.res passed")
}

let () = {
  run()
  ->Promise.catch(async error => {
    Console.error(TestSupport.messageFromError(error))
    NodeProcess.exit(1)
  })
  ->ignore
}
```

- [ ] **Step 2: Add the new test to the CLI package script**

Modify `packages/cli/package.json` so the `test` script includes the new test after `Worker_test.res.mjs`:

```json
"test": "pnpm run build && node test/Validation_test.res.mjs && node test/Cli_test.res.mjs && node test/AddCore_test.res.mjs && node test/PublishCore_test.res.mjs && node test/PackageJson_test.res.mjs && node test/Add_test.res.mjs && node test/PublishOAuth_test.res.mjs && node test/Worker_test.res.mjs && node test/DiscoveryApi_test.res.mjs && node test/Bin_test.res.mjs && node test/D1_test.res.mjs"
```

- [ ] **Step 3: Run the new test to verify it fails**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings build:res
node packages/cli/test/DiscoveryApi_test.res.mjs
```

Expected: FAIL because `/api/v1/bindings/recent`, `/api/v1/bindings/search`, and `/api/v1/bindings/:package/authors/:author` return `404`.

- [ ] **Step 4: Commit the failing API test**

```bash
git add packages/cli/package.json packages/cli/test/DiscoveryApi_test.res
git commit -m "test: cover binding discovery api"
```

## Task 2: Registry Discovery API Implementation

**Files:**
- Modify: `packages/cli/src/Worker.res`
- Test: `packages/cli/test/DiscoveryApi_test.res`

- [ ] **Step 1: Add response types and D1 bindings**

In `packages/cli/src/Worker.res`, add these types near the existing release response types:

```rescript
type bindingEntryReleaseResponse = {
  id: string,
  packageName: string,
  variantLabel: string,
  variantSlug: string,
  peerPackageRange: string,
  rescriptRange: string,
  description: option<string>,
  createdAt: string,
}

type bindingEntryResponse = {
  packageName: string,
  author: string,
  authorDisplayName: string,
  libraryVersions: array<string>,
  rescriptVersions: array<string>,
  latestCreatedAt: string,
  releases: array<bindingEntryReleaseResponse>,
}

type bindingDetailReleaseResponse = {
  id: string,
  packageName: string,
  variantLabel: string,
  variantSlug: string,
  peerPackageRange: string,
  rescriptRange: string,
  description: option<string>,
  createdAt: string,
  files: array<releaseFileResponse>,
}

type bindingDetailResponse = {
  packageName: string,
  author: string,
  authorDisplayName: string,
  libraryVersions: array<string>,
  rescriptVersions: array<string>,
  latestCreatedAt: string,
  releases: array<bindingDetailReleaseResponse>,
}
```

Add these externals near the existing D1 statement externals:

```rescript
@send external bind3: (statement, string, string, string) => boundStatement = "bind"
@send external allStatement: statement => promise<queryResult<'row>> = "all"
```

- [ ] **Step 2: Add public discovery routes**

Replace the `route` type with this expanded version:

```rescript
type route =
  | ListPackageReleases(string)
  | GetRelease(string)
  | RecentBindings
  | SearchBindings
  | GetBindingAuthorDetail(string, string)
  | Me
  | Publish
  | AdminPublishers
  | NotFound
```

Update `routeFrom` so the binding discovery routes are checked before the generic package-release routes:

```rescript
let routeFrom = (method_: string, pathname: string): route => {
  if method_ == "GET" && pathname == "/api/v1/bindings/recent" {
    RecentBindings
  } else if method_ == "GET" && pathname == "/api/v1/bindings/search" {
    SearchBindings
  } else if method_ == "GET" && startsWith(pathname, "/api/v1/bindings/") {
    let parts = split(pathname, "/")
    switch (getAt(parts, 4), getAt(parts, 5), getAt(parts, 6)) {
    | (Some(packageName), Some("authors"), Some(author)) => GetBindingAuthorDetail(packageName, author)
    | _ => NotFound
    }
  } else if method_ == "GET" && startsWith(pathname, "/api/v1/packages/") && endsWith(pathname, "/releases") {
    let parts = split(pathname, "/")
    switch getAt(parts, 4) {
    | Some(packageName) => ListPackageReleases(packageName)
    | None => NotFound
    }
  } else if method_ == "GET" && startsWith(pathname, "/api/v1/releases/") {
    let parts = split(pathname, "/")
    switch getAt(parts, 4) {
    | Some(releaseId) => GetRelease(releaseId)
    | None => NotFound
    }
  } else if method_ == "GET" && pathname == "/api/publish/v1/me" {
    Me
  } else if method_ == "POST" && pathname == "/api/publish/v1/releases" {
    Publish
  } else if method_ == "POST" && pathname == "/api/publish/v1/admin/publishers" {
    AdminPublishers
  } else {
    NotFound
  }
}
```

Update `isProtectedRoute`:

```rescript
let isProtectedRoute = route =>
  switch route {
  | Me | Publish | AdminPublishers => true
  | ListPackageReleases(_) | GetRelease(_) | RecentBindings | SearchBindings | GetBindingAuthorDetail(_, _) | NotFound => false
  }
```

- [ ] **Step 3: Add grouping helpers**

Add these helpers after `releaseWithCompatibility`:

```rescript
let releaseSummaryFrom = (row: releaseRow): bindingEntryReleaseResponse => {
  id: row.id,
  packageName: row.package_name,
  variantLabel: row.variant_label,
  variantSlug: row.variant_slug,
  peerPackageRange: row.peer_package_range,
  rescriptRange: row.rescript_range,
  description: row.description,
  createdAt: row.created_at,
}

let pushDistinct = (items: array<string>, value: string) => {
  if !items->Array.some(item => item == value) {
    items->Array.push(value)->ignore
  }
}

let displayNameFromRow = row =>
  row.publisher_display_name->Belt.Option.getWithDefault(row.publisher_login)

let findEntryIndex = (entries: array<bindingEntryResponse>, row: releaseRow) => {
  let found = ref(-1)
  for index in 0 to entries->Array.length - 1 {
    switch entries[index] {
    | Some(entry) if entry.packageName == row.package_name && entry.author == row.publisher_login =>
      found := index
    | _ => ()
    }
  }
  found.contents
}

let groupReleaseRows = (rows: array<releaseRow>): array<bindingEntryResponse> => {
  let entries: array<bindingEntryResponse> = []

  rows->Array.forEach(row => {
    let index = findEntryIndex(entries, row)
    if index >= 0 {
      switch entries[index] {
      | Some(entry) =>
        pushDistinct(entry.libraryVersions, row.peer_package_range)
        pushDistinct(entry.rescriptVersions, row.rescript_range)
        entry.releases->Array.push(releaseSummaryFrom(row))->ignore
      | None => ()
      }
    } else {
      entries->Array.push({
        packageName: row.package_name,
        author: row.publisher_login,
        authorDisplayName: displayNameFromRow(row),
        libraryVersions: [row.peer_package_range],
        rescriptVersions: [row.rescript_range],
        latestCreatedAt: row.created_at,
        releases: [releaseSummaryFrom(row)],
      })->ignore
    }
  })

  entries
}

let escapeLikePattern = value =>
  value
  ->replaceAll("\\", "\\\\")
  ->replaceAll("%", "\\%")
  ->replaceAll("_", "\\_")
```

- [ ] **Step 4: Add recent and search handlers**

Add these handlers after `handleGetRelease`:

```rescript
let handleRecentBindings = async (~env) =>
  switch requireDb(env) {
  | Error(response) => response
  | Ok(db) =>
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
    LIMIT 200`)
    ->allStatement

    json({"entries": groupReleaseRows(result.results)})
  }

let handleSearchBindings = async (~env, ~url) =>
  switch requireDb(env) {
  | Error(response) => response
  | Ok(db) =>
    let query = url->urlSearchParams->searchParamGet("q")->Belt.Option.getWithDefault("")->trim
    if query == "" {
      json({"entries": []})
    } else {
      let pattern = "%" ++ escapeLikePattern(query) ++ "%"
      let prefixPattern = escapeLikePattern(query) ++ "%"
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
        AND package_name LIKE ? ESCAPE '\\'
      ORDER BY
        CASE
          WHEN package_name = ? THEN 0
          WHEN package_name LIKE ? ESCAPE '\\' THEN 1
          ELSE 2
        END,
        created_at DESC
      LIMIT 200`)
      ->bind3(pattern, query, prefixPattern)
      ->all

      json({"entries": groupReleaseRows(result.results)})
    }
  }
```

- [ ] **Step 5: Add package-author detail handler**

Add this helper and handler after `handleSearchBindings`:

```rescript
let detailReleaseFrom = (~row: releaseRow, ~files: array<releaseFileResponse>): bindingDetailReleaseResponse => {
  id: row.id,
  packageName: row.package_name,
  variantLabel: row.variant_label,
  variantSlug: row.variant_slug,
  peerPackageRange: row.peer_package_range,
  rescriptRange: row.rescript_range,
  description: row.description,
  createdAt: row.created_at,
  files,
}

let handleGetBindingAuthorDetail = async (~env, ~packageName, ~author) =>
  switch requireDb(env) {
  | Error(response) => response
  | Ok(db) =>
    try {
      let decodedPackageName = decodePathValue(packageName)
      let decodedAuthor = decodePathValue(author)
      let releaseResult: queryResult<releaseRow> = await db
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
      WHERE package_name = ?
        AND publisher_login = ?
        AND status = 'published'
      ORDER BY created_at DESC`)
      ->bind2(decodedPackageName, decodedAuthor)
      ->all

      if releaseResult.results->Array.length == 0 {
        json(~status=404, {"error": "Binding author detail not found"})
      } else {
        let detailReleases: array<bindingDetailReleaseResponse> = []

        for index in 0 to releaseResult.results->Array.length - 1 {
          switch releaseResult.results[index] {
          | Some(row) =>
            let fileResult: queryResult<fileRow> = await db
            ->prepare(`SELECT
              relative_path,
              content,
              sha256,
              bytes
            FROM binding_files
            WHERE release_id = ?
            ORDER BY relative_path ASC`)
            ->bind1(row.id)
            ->all

            detailReleases->Array.push(detailReleaseFrom(
              ~row,
              ~files=fileResult.results->Array.map((file): releaseFileResponse => {
                relativePath: file.relative_path,
                content: file.content,
                sha256: file.sha256,
                bytes: file.bytes,
              }),
            ))->ignore
          | None => ()
          }
        }

        let firstRow = releaseResult.results[0]->Belt.Option.getExn
        let summaryGroup = groupReleaseRows(releaseResult.results)[0]->Belt.Option.getExn
        let body: bindingDetailResponse = {
          packageName: firstRow.package_name,
          author: firstRow.publisher_login,
          authorDisplayName: displayNameFromRow(firstRow),
          libraryVersions: summaryGroup.libraryVersions,
          rescriptVersions: summaryGroup.rescriptVersions,
          latestCreatedAt: summaryGroup.latestCreatedAt,
          releases: detailReleases,
        }

        json(body)
      }
    } catch {
    | Failure(message) => badRequest(message)
    }
  }
```

- [ ] **Step 6: Wire handlers into `fetch`**

Add these branches to the `switch route` inside `fetch`:

```rescript
| RecentBindings => await handleRecentBindings(~env)
| SearchBindings => await handleSearchBindings(~env, ~url)
| GetBindingAuthorDetail(packageName, author) => await handleGetBindingAuthorDetail(~env, ~packageName, ~author)
```

- [ ] **Step 7: Run the discovery API test**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings build:res
node packages/cli/test/DiscoveryApi_test.res.mjs
```

Expected: PASS with final line `DiscoveryApi_test.res passed`.

- [ ] **Step 8: Run the existing Worker test**

Run:

```bash
node packages/cli/test/Worker_test.res.mjs
```

Expected: PASS with final line `Worker_test.res passed`.

- [ ] **Step 9: Commit the API implementation**

```bash
git add packages/cli/src/Worker.res
git commit -m "feat: add binding discovery api"
```

## Task 3: Web Package Scaffold And Xote SSR Smoke Test

**Files:**
- Create: `packages/web/package.json`
- Create: `packages/web/rescript.json`
- Create: `packages/web/rolldown.config.mjs`
- Create: `packages/web/wrangler.toml`
- Create: `packages/web/src/Pages.res`
- Create: `packages/web/src/Worker.res`
- Create: `packages/web/test/Worker_test.res`

- [ ] **Step 1: Create the web package manifest**

Create `packages/web/package.json`:

```json
{
  "name": "@jvlk/rescript-bindings-web",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "pnpm run build:res && pnpm run build:worker",
    "build:res": "rescript build",
    "build:worker": "rolldown -c",
    "clean": "rescript clean",
    "test": "pnpm run build && node test/Worker_test.res.mjs",
    "dev": "wrangler dev --local",
    "deploy": "wrangler deploy"
  },
  "dependencies": {
    "xote": "^6.2.0"
  },
  "devDependencies": {
    "rescript": "^12.0.0",
    "rolldown": "^1.0.0",
    "wrangler": "^4.90.0"
  }
}
```

- [ ] **Step 2: Install workspace dependencies**

Run:

```bash
pnpm install
```

Expected: installs `xote`, `rescript`, `rolldown`, and `wrangler` for `packages/web` and updates `pnpm-lock.yaml`.

- [ ] **Step 3: Create ReScript, Rolldown, and Wrangler config**

Create `packages/web/rescript.json`:

```json
{
  "name": "@jvlk/rescript-bindings-web",
  "sources": [
    {
      "dir": "src",
      "subdirs": true
    },
    {
      "dir": "test",
      "subdirs": true,
      "type": "dev"
    }
  ],
  "dependencies": ["xote"],
  "jsx": {
    "version": 4,
    "module": "XoteJSX"
  },
  "compiler-flags": ["-open Xote"],
  "package-specs": {
    "module": "esmodule",
    "in-source": true
  },
  "suffix": ".res.mjs",
  "warnings": {
    "number": "+A-44-102",
    "error": "+A"
  }
}
```

Create `packages/web/rolldown.config.mjs`:

```js
import { defineConfig } from "rolldown";

export default defineConfig({
  input: "src/Worker.res.mjs",
  platform: "browser",
  treeshake: true,
  output: {
    file: "dist/worker.mjs",
    format: "esm",
    minify: true,
  },
});
```

Create `packages/web/wrangler.toml`:

```toml
name = "rescript-binding-registry-web"
main = "dist/worker.mjs"
compatibility_date = "2026-05-10"

[vars]
REGISTRY_API_BASE = "https://rescript-binding-registry.josh-401.workers.dev/api"

[observability.logs]
enabled = true
invocation_logs = true
```

- [ ] **Step 4: Write the failing SSR smoke test**

Create `packages/web/test/Worker_test.res`:

```rescript
type request
type response
type responseInit
type textResponse

@new external makeRequest: string => request = "Request"
@get external responseStatus: response => int = "status"
@send external responseText: response => promise<string> = "text"

let emptyEnv: Worker.env = %raw(`({ REGISTRY_API_BASE: "https://registry.test/api" })`)
let ctx = %raw(`({})`)

let fakeFetcher = async _url => {
  let body = `{"entries":[]}`
  Worker.makeResponse(body, Worker.responseInit(
    ~status=200,
    ~headers=[["content-type", "application/json"]],
    (),
  ))
}

let run = async () => {
  let response = await Worker.fetchWith(~fetcher=fakeFetcher, makeRequest("https://web.test/"), emptyEnv, ctx)
  TestSupport.assertTrue(response->responseStatus == 200, "homepage smoke returns success")
  let html = await response->responseText
  TestSupport.assertTrue(html->TestSupport.includes("<!DOCTYPE html>"), "homepage smoke renders a document")
  TestSupport.assertTrue(html->TestSupport.includes("picocss"), "homepage smoke includes Pico CDN")
  TestSupport.assertTrue(html->TestSupport.includes("ReScript Bindings"), "homepage smoke includes heading")

  Console.log("Web Worker_test.res passed")
}

let () = {
  run()
  ->Promise.catch(async error => {
    Console.error(TestSupport.messageFromError(error))
    NodeProcess.exit(1)
  })
  ->ignore
}
```

- [ ] **Step 5: Copy minimal test support into the web package**

Create `packages/web/test/TestSupport.res`:

```rescript
let assertTrue = (condition, label) => {
  if !condition {
    throw(Failure("Assertion failed: " ++ label))
  }
}

@send external includes: (string, string) => bool = "includes"

let messageFromError = error =>
  switch error->JsExn.fromException {
  | Some(jsError) => jsError->JsExn.message->Belt.Option.getWithDefault("")
  | None =>
    let _ = error
    %raw(`error?._1 ?? error?.message ?? String(error)`)
  }
```

Create `packages/web/test/NodeProcess.res`:

```rescript
@module("node:process") external exit: int => unit = "exit"
```

- [ ] **Step 6: Run the smoke test to verify it fails**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings-web build:res
node packages/web/test/Worker_test.res.mjs
```

Expected: FAIL because `packages/web/src/Worker.res` does not exist.

- [ ] **Step 7: Add minimal Xote SSR page and Worker**

Create `packages/web/src/Pages.res`:

```rescript
let picoCdn = "https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css"

let home = () =>
  View.element("main", ~attrs=[View.Attr.string("class", "container")], ~children=[
    View.element("h1", ~children=[View.text("ReScript Bindings")], ()),
    View.element("form", ~attrs=[View.Attr.string("method", "get"), View.Attr.string("action", "/")], ~children=[
      View.element("input", ~attrs=[
        View.Attr.string("type", "search"),
        View.Attr.string("name", "q"),
        View.Attr.string("placeholder", "Search package names"),
      ], ()),
      View.element("button", ~attrs=[View.Attr.string("type", "submit")], ~children=[View.text("Search")], ()),
    ], ()),
    View.element("p", ~children=[View.text("No bindings found.")], ()),
  ], ())

let document = (~title: string, body: unit => View.node) =>
  SSR.renderDocument(
    ~head=`<title>${SSR.Html.escape(title)}</title><meta name="color-scheme" content="light dark" />`,
    ~styles=[picoCdn],
    body,
  )
```

Create `packages/web/src/Worker.res`:

```rescript
type request
type response
type responseInit
type env
type ctx
type url

type fetcher = string => promise<response>

@new external makeUrl: string => url = "URL"
@get external requestUrl: request => string = "url"
@get external urlPathname: url => string = "pathname"
@get external registryApiBase: env => option<string> = "REGISTRY_API_BASE"
@new external makeResponse: (string, responseInit) => response = "Response"
@obj external responseInit: (~status: int, ~headers: array<array<string>>, unit) => responseInit = ""
@val external globalFetch: fetcher = "fetch"

let html = (~status=200, body) =>
  makeResponse(body, responseInit(
    ~status,
    ~headers=[["content-type", "text/html; charset=utf-8"]],
    (),
  ))

let apiBase = env =>
  env->registryApiBase->Belt.Option.getWithDefault("https://rescript-binding-registry.josh-401.workers.dev/api")

let fetchWith = async (~fetcher: fetcher, request, env, _ctx) => {
  let _ = fetcher
  let _ = apiBase(env)
  let url = makeUrl(request->requestUrl)
  switch url->urlPathname {
  | "/" => html(Pages.document(~title="ReScript Bindings", Pages.home))
  | _ => html(~status=404, Pages.document(~title="Not found", () =>
      View.element("main", ~attrs=[View.Attr.string("class", "container")], ~children=[
        View.element("h1", ~children=[View.text("Not found")], ()),
      ], ())
    ))
  }
}

let fetch = async (request, env, ctx) => await fetchWith(~fetcher=globalFetch, request, env, ctx)

%%raw("export { makeResponse, responseInit, fetchWith }")
%%raw("export default { fetch }")
```

- [ ] **Step 8: Run the web package SSR smoke test**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings-web test
```

Expected: PASS with final line `Web Worker_test.res passed`.

- [ ] **Step 9: Bundle the web Worker**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings-web build:worker
```

Expected: PASS and creates `packages/web/dist/worker.mjs`.

If this fails because Xote SSR imports browser-only globals while bundling or evaluating the Worker, stop here and write a replacement client-side web plan against the same registry API endpoints.

- [ ] **Step 10: Commit the web scaffold**

```bash
git add packages/web pnpm-lock.yaml
git commit -m "feat: scaffold binding registry web worker"
```

## Task 4: Web Registry Client And Full Page Rendering

**Files:**
- Create: `packages/web/src/RegistryClient.res`
- Modify: `packages/web/src/Pages.res`
- Modify: `packages/web/src/Worker.res`
- Modify: `packages/web/test/Worker_test.res`

- [ ] **Step 1: Add full web Worker tests**

Replace `packages/web/test/Worker_test.res` with:

```rescript
type request
type response

@new external makeRequest: string => request = "Request"
@get external responseStatus: response => int = "status"
@send external responseText: response => promise<string> = "text"
@send external includes: (string, string) => bool = "includes"

let env: Worker.env = %raw(`({ REGISTRY_API_BASE: "https://registry.test/api" })`)
let ctx = %raw(`({})`)

let jsonResponse = body =>
  Worker.makeResponse(body, Worker.responseInit(
    ~status=200,
    ~headers=[["content-type", "application/json"]],
    (),
  ))

let notFoundResponse = body =>
  Worker.makeResponse(body, Worker.responseInit(
    ~status=404,
    ~headers=[["content-type", "application/json"]],
    (),
  ))

let fakeFetcher = async url => {
  if url == "https://registry.test/api/v1/bindings/recent" {
    jsonResponse(`{"entries":[{"packageName":"react","author":"josh","authorDisplayName":"Josh","libraryVersions":["^18.0.0","^19.0.0"],"rescriptVersions":["^12.0.0"],"latestCreatedAt":"2026-05-10T13:00:00.000Z","releases":[{"id":"react-josh-2","packageName":"react","variantLabel":"default","variantSlug":"default","peerPackageRange":"^19.0.0","rescriptRange":"^12.0.0","description":"React 19 bindings","createdAt":"2026-05-10T13:00:00.000Z"}]}]}`)
  } else if url == "https://registry.test/api/v1/bindings/search?q=react" {
    jsonResponse(`{"entries":[{"packageName":"@rescript/react","author":"dev","authorDisplayName":"Dev","libraryVersions":["^0.11.0"],"rescriptVersions":["^11.0.0"],"latestCreatedAt":"2026-05-10T11:00:00.000Z","releases":[{"id":"rescript-react-dev-1","packageName":"@rescript/react","variantLabel":"default","variantSlug":"default","peerPackageRange":"^0.11.0","rescriptRange":"^11.0.0","description":"Official package bindings","createdAt":"2026-05-10T11:00:00.000Z"}]}]}`)
  } else if url == "https://registry.test/api/v1/bindings/react/authors/josh" {
    jsonResponse(`{"packageName":"react","author":"josh","authorDisplayName":"Josh","libraryVersions":["^18.0.0","^19.0.0"],"rescriptVersions":["^12.0.0"],"latestCreatedAt":"2026-05-10T13:00:00.000Z","releases":[{"id":"react-josh-2","packageName":"react","variantLabel":"default","variantSlug":"default","peerPackageRange":"^19.0.0","rescriptRange":"^12.0.0","description":"React 19 bindings","createdAt":"2026-05-10T13:00:00.000Z","files":[{"relativePath":"React.res","content":"@module(\\"react\\")\\nexternal createElement: string => unit = \\"createElement\\"\\n","sha256":"file-2","bytes":72}]},{"id":"react-josh-1","packageName":"react","variantLabel":"legacy","variantSlug":"legacy","peerPackageRange":"^18.0.0","rescriptRange":"^12.0.0","description":"React 18 bindings","createdAt":"2026-05-10T12:00:00.000Z","files":[{"relativePath":"React.res","content":"let legacy = true\\n","sha256":"file-1","bytes":18}]}]}`)
  } else if url == "https://registry.test/api/v1/bindings/missing/authors/josh" {
    notFoundResponse(`{"error":"Binding author detail not found"}`)
  } else {
    notFoundResponse(`{"error":"Unexpected URL: ${url}"}`)
  }
}

let expectHtml = async (path, assertion) => {
  let response = await Worker.fetchWith(~fetcher=fakeFetcher, makeRequest("https://web.test" ++ path), env, ctx)
  let html = await response->responseText
  assertion(response->responseStatus, html)
}

let run = async () => {
  await expectHtml("/", (status, html) => {
    TestSupport.assertTrue(status == 200, "homepage returns success")
    TestSupport.assertTrue(html->includes("Recently updated"), "homepage labels recent results")
    TestSupport.assertTrue(html->includes("react"), "homepage renders package name")
    TestSupport.assertTrue(html->includes("Josh"), "homepage renders author display name")
    TestSupport.assertTrue(html->includes("^18.0.0, ^19.0.0"), "homepage renders library versions")
    TestSupport.assertTrue(html->includes("^12.0.0"), "homepage renders ReScript versions")
  })

  await expectHtml("/?q=react", (status, html) => {
    TestSupport.assertTrue(status == 200, "search returns success")
    TestSupport.assertTrue(html->includes("Search results"), "search labels results")
    TestSupport.assertTrue(html->includes("@rescript/react"), "search renders matched package")
  })

  await expectHtml("/packages/react/authors/josh", (status, html) => {
    TestSupport.assertTrue(status == 200, "detail returns success")
    TestSupport.assertTrue(html->includes("<h1>react</h1>"), "detail renders package h1")
    TestSupport.assertTrue(html->includes("Josh"), "detail renders author")
    TestSupport.assertTrue(html->includes("^19.0.0 / ^12.0.0"), "detail renders newest release tab")
    TestSupport.assertTrue(html->includes("@module(&quot;react&quot;)"), "detail escapes code content")
    TestSupport.assertTrue(html->includes("React.res"), "detail renders file separator")
  })

  await expectHtml("/packages/react/authors/josh?release=react-josh-1", (status, html) => {
    TestSupport.assertTrue(status == 200, "detail selected release returns success")
    TestSupport.assertTrue(html->includes("let legacy = true"), "detail renders selected release source")
  })

  await expectHtml("/packages/missing/authors/josh", (status, html) => {
    TestSupport.assertTrue(status == 404, "missing detail returns 404")
    TestSupport.assertTrue(html->includes("Binding not found"), "missing detail renders not found page")
  })

  Console.log("Web Worker_test.res passed")
}

let () = {
  run()
  ->Promise.catch(async error => {
    Console.error(TestSupport.messageFromError(error))
    NodeProcess.exit(1)
  })
  ->ignore
}
```

- [ ] **Step 2: Run the web test to verify it fails**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings-web test
```

Expected: FAIL because `Pages.home` still renders only the smoke page and `RegistryClient.res` does not exist.

- [ ] **Step 3: Create the registry API client**

Create `packages/web/src/RegistryClient.res`:

```rescript
type response

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

type releaseFile = {
  relativePath: string,
  content: string,
  sha256: string,
  bytes: int,
}

type releaseDetail = {
  id: string,
  packageName: string,
  variantLabel: string,
  variantSlug: string,
  peerPackageRange: string,
  rescriptRange: string,
  description: option<string>,
  createdAt: string,
  files: array<releaseFile>,
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

type detail = {
  packageName: string,
  author: string,
  authorDisplayName: string,
  libraryVersions: array<string>,
  rescriptVersions: array<string>,
  latestCreatedAt: string,
  releases: array<releaseDetail>,
}

type entriesBody = {entries: array<entry>}

type fetcher = string => promise<response>

@send external responseJson: response => promise<'body> = "json"
@get external responseStatus: response => int = "status"
@val external encodeURIComponent: string => string = "encodeURIComponent"

exception RegistryError(int, string)

let trimTrailingSlash = value =>
  if String.endsWith(value, "/") {
    String.slice(value, ~start=0, ~end=String.length(value) - 1)
  } else {
    value
  }

let requestJson = async (~fetcher, url) => {
  let response = await fetcher(url)
  let status = response->responseStatus
  if status >= 200 && status < 300 {
    Ok(await response->responseJson)
  } else {
    Error(status)
  }
}

let recent = async (~fetcher: fetcher, ~apiBase) => {
  let result: result<entriesBody, int> = await requestJson(
    ~fetcher,
    ~url=trimTrailingSlash(apiBase) ++ "/v1/bindings/recent",
  )
  result
}

let search = async (~fetcher: fetcher, ~apiBase, ~query) => {
  let result: result<entriesBody, int> = await requestJson(
    ~fetcher,
    ~url=trimTrailingSlash(apiBase) ++ "/v1/bindings/search?q=" ++ encodeURIComponent(query),
  )
  result
}

let detail = async (~fetcher: fetcher, ~apiBase, ~packageName, ~author) => {
  let result: result<detail, int> = await requestJson(
    ~fetcher,
    ~url=trimTrailingSlash(apiBase) ++ "/v1/bindings/" ++ encodeURIComponent(packageName) ++ "/authors/" ++ encodeURIComponent(author),
  )
  result
}
```

- [ ] **Step 4: Replace `Pages.res` with full rendering**

Replace `packages/web/src/Pages.res` with:

```rescript
let picoCdn = "https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css"

let attr = View.Attr.string
let text = View.text
let el = (tag, ~attrs=[], ~children=[], ()) => View.element(tag, ~attrs, ~children, ())
@val external encodeURIComponent: string => string = "encodeURIComponent"

let join = (items: array<string>) => items->Array.join(", ")

let detailPath = (entry: RegistryClient.entry) =>
  "/packages/" ++ encodeURIComponent(entry.packageName) ++ "/authors/" ++ encodeURIComponent(entry.author)

let layout = (~title, body) =>
  SSR.renderDocument(
    ~head=`<title>${SSR.Html.escape(title)}</title><meta name="color-scheme" content="light dark" />`,
    ~styles=[picoCdn],
    body,
  )

let searchForm = query =>
  el("form", ~attrs=[attr("method", "get"), attr("action", "/")], ~children=[
    el("input", ~attrs=[
      attr("type", "search"),
      attr("name", "q"),
      attr("value", query),
      attr("placeholder", "Search package names"),
      attr("aria-label", "Search package names"),
    ], ()),
    el("button", ~attrs=[attr("type", "submit")], ~children=[text("Search")], ()),
  ], ())

let entriesTable = entries =>
  if entries->Array.length == 0 {
    el("p", ~children=[text("No bindings found.")], ())
  } else {
    el("table", ~children=[
      el("thead", ~children=[
        el("tr", ~children=[
          el("th", ~attrs=[attr("scope", "col")], ~children=[text("Package name")], ()),
          el("th", ~attrs=[attr("scope", "col")], ~children=[text("Author")], ()),
          el("th", ~attrs=[attr("scope", "col")], ~children=[text("Library versions")], ()),
          el("th", ~attrs=[attr("scope", "col")], ~children=[text("ReScript versions")], ()),
        ], ()),
      ], ()),
      el("tbody", ~children=entries->Array.map((entry: RegistryClient.entry) =>
        el("tr", ~children=[
          el("th", ~attrs=[attr("scope", "row")], ~children=[
            el("a", ~attrs=[attr("href", detailPath(entry))], ~children=[text(entry.packageName)], ()),
          ], ()),
          el("td", ~children=[text(entry.authorDisplayName)], ()),
          el("td", ~children=[text(join(entry.libraryVersions))], ()),
          el("td", ~children=[text(join(entry.rescriptVersions))], ()),
        ], ())
      ), ()),
    ], ())
  }

let home = (~query, ~entries, ~isSearch) =>
  layout(~title="ReScript Bindings", () =>
    el("main", ~attrs=[attr("class", "container")], ~children=[
      el("h1", ~children=[text("ReScript Bindings")], ()),
      searchForm(query),
      el("h2", ~children=[text(if isSearch {"Search results"} else {"Recently updated"})], ()),
      entriesTable(entries),
    ], ())
  )

let releaseLabel = (release: RegistryClient.releaseDetail, duplicateLabel) => {
  let base = release.peerPackageRange ++ " / " ++ release.rescriptRange
  if duplicateLabel {
    base ++ " (" ++ release.variantLabel ++ ")"
  } else {
    base
  }
}

let hasDuplicateVersionLabel = (release: RegistryClient.releaseDetail, releases) =>
  releases->Array.filter((candidate: RegistryClient.releaseDetail) =>
    candidate.peerPackageRange == release.peerPackageRange && candidate.rescriptRange == release.rescriptRange
  )->Array.length > 1

let selectedRelease = (~releases: array<RegistryClient.releaseDetail>, ~releaseId) =>
  switch releaseId {
  | Some(id) =>
    releases->Array.find((release: RegistryClient.releaseDetail) => release.id == id)
    ->Belt.Option.getWithDefault(releases[0]->Belt.Option.getExn)
  | None => releases[0]->Belt.Option.getExn
  }

let sourceForRelease = (release: RegistryClient.releaseDetail) =>
  release.files
  ->Array.map(file => "/* " ++ file.relativePath ++ " */\n" ++ file.content)
  ->Array.join("\n\n")

let tabs = (~detail: RegistryClient.detail, ~selected: RegistryClient.releaseDetail) =>
  el("nav", ~children=[
    el("ul", ~children=detail.releases->Array.map((release: RegistryClient.releaseDetail) =>
      el("li", ~children=[
        el("a", ~attrs=[
          attr("href", detailPath({
            packageName: detail.packageName,
            author: detail.author,
            authorDisplayName: detail.authorDisplayName,
            libraryVersions: detail.libraryVersions,
            rescriptVersions: detail.rescriptVersions,
            latestCreatedAt: detail.latestCreatedAt,
            releases: [],
          }) ++ "?release=" ++ encodeURIComponent(release.id)),
          attr("aria-current", if release.id == selected.id {"page"} else {"false"}),
        ], ~children=[text(releaseLabel(release, hasDuplicateVersionLabel(release, detail.releases)))], ()),
      ], ())
    ), ()),
  ], ())

let detail = (~detail: RegistryClient.detail, ~releaseId) => {
  let selected = selectedRelease(~releases=detail.releases, ~releaseId)
  layout(~title=detail.packageName ++ " bindings", () =>
    el("main", ~attrs=[attr("class", "container")], ~children=[
      el("p", ~children=[el("a", ~attrs=[attr("href", "/")], ~children=[text("Back to bindings")], ())], ()),
      el("h1", ~children=[text(detail.packageName)], ()),
      el("p", ~children=[text("By " ++ detail.authorDisplayName)], ()),
      tabs(~detail, ~selected),
      el("pre", ~children=[
        el("code", ~children=[text(sourceForRelease(selected))], ()),
      ], ()),
    ], ())
  )
}

let notFound = () =>
  layout(~title="Binding not found", () =>
    el("main", ~attrs=[attr("class", "container")], ~children=[
      el("h1", ~children=[text("Binding not found")], ()),
      el("p", ~children=[text("The requested binding entry could not be found.")], ()),
      el("p", ~children=[el("a", ~attrs=[attr("href", "/")], ~children=[text("Back to bindings")], ())], ()),
    ], ())
  )

let registryError = () =>
  layout(~title="Registry unavailable", () =>
    el("main", ~attrs=[attr("class", "container")], ~children=[
      el("h1", ~children=[text("Registry unavailable")], ()),
      el("p", ~children=[text("The binding registry could not be reached.")], ()),
    ], ())
  )
```

- [ ] **Step 5: Replace the web Worker routing**

Replace `packages/web/src/Worker.res` with:

```rescript
type request
type response
type responseInit
type env
type ctx
type url
type searchParams

type fetcher = string => promise<response>

@new external makeUrl: string => url = "URL"
@get external requestUrl: request => string = "url"
@get external urlPathname: url => string = "pathname"
@get external urlSearchParams: url => searchParams = "searchParams"
@return(nullable) @send external searchParamGet: (searchParams, string) => option<string> = "get"
@get external registryApiBase: env => option<string> = "REGISTRY_API_BASE"
@new external makeResponse: (string, responseInit) => response = "Response"
@obj external responseInit: (~status: int, ~headers: array<array<string>>, unit) => responseInit = ""
@val external globalFetch: fetcher = "fetch"
@val external decodeURIComponent: string => string = "decodeURIComponent"
@send external startsWith: (string, string) => bool = "startsWith"
@send external split: (string, string) => array<string> = "split"

let getAt = (items: array<'a>, index: int): option<'a> =>
  if index < 0 || index >= items->Array.length {
    None
  } else {
    items[index]
  }

let html = (~status=200, body) =>
  makeResponse(body, responseInit(
    ~status,
    ~headers=[["content-type", "text/html; charset=utf-8"]],
    (),
  ))

let apiBase = env =>
  env->registryApiBase->Belt.Option.getWithDefault("https://rescript-binding-registry.josh-401.workers.dev/api")

let decodePathValue = value =>
  try {
    decodeURIComponent(value)
  } catch {
  | _ => value
  }

let renderHome = async (~fetcher, ~env, ~url) => {
  let query = url->urlSearchParams->searchParamGet("q")->Belt.Option.getWithDefault("")
  let result = if query->String.trim == "" {
    await RegistryClient.recent(~fetcher, ~apiBase=apiBase(env))
  } else {
    await RegistryClient.search(~fetcher, ~apiBase=apiBase(env), ~query)
  }

  switch result {
  | Ok(body) => html(Pages.home(~query, ~entries=body.entries, ~isSearch=query->String.trim != ""))
  | Error(_) => html(~status=502, Pages.registryError())
  }
}

let renderDetail = async (~fetcher, ~env, ~url, ~packageName, ~author) => {
  let result = await RegistryClient.detail(
    ~fetcher,
    ~apiBase=apiBase(env),
    ~packageName=decodePathValue(packageName),
    ~author=decodePathValue(author),
  )

  switch result {
  | Ok(detail) => html(Pages.detail(
      ~detail,
      ~releaseId=url->urlSearchParams->searchParamGet("release"),
    ))
  | Error(404) => html(~status=404, Pages.notFound())
  | Error(_) => html(~status=502, Pages.registryError())
  }
}

let fetchWith = async (~fetcher: fetcher, request, env, _ctx) => {
  let url = makeUrl(request->requestUrl)
  let pathname = url->urlPathname

  if pathname == "/" {
    await renderHome(~fetcher, ~env, ~url)
  } else if pathname->startsWith("/packages/") {
    let parts = pathname->split("/")
    switch (getAt(parts, 2), getAt(parts, 3), getAt(parts, 4)) {
    | (Some(packageName), Some("authors"), Some(author)) =>
      await renderDetail(~fetcher, ~env, ~url, ~packageName, ~author)
    | _ => html(~status=404, Pages.notFound())
    }
  } else {
    html(~status=404, Pages.notFound())
  }
}

let fetch = async (request, env, ctx) => await fetchWith(~fetcher=globalFetch, request, env, ctx)

%%raw("export { makeResponse, responseInit, fetchWith }")
%%raw("export default { fetch }")
```

- [ ] **Step 6: Run the web Worker tests**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings-web test
```

Expected: PASS with final line `Web Worker_test.res passed`.

- [ ] **Step 7: Commit the web rendering implementation**

```bash
git add packages/web/src packages/web/test
git commit -m "feat: render binding registry frontend"
```

## Task 5: Root Scripts, Full Verification, And Local Worker Check

**Files:**
- Modify: `package.json`
- Verify: `packages/cli/src/Worker.res`
- Verify: `packages/web/src/Worker.res`

- [ ] **Step 1: Update root scripts**

Modify the root `package.json` scripts:

```json
"scripts": {
  "build": "pnpm --filter @jvlk/rescript-bindings build && pnpm --filter @jvlk/rescript-bindings-web build",
  "clean": "pnpm --filter @jvlk/rescript-bindings clean && pnpm --filter @jvlk/rescript-bindings-web clean",
  "test": "pnpm --filter @jvlk/rescript-bindings test && pnpm --filter @jvlk/rescript-bindings-web test"
}
```

- [ ] **Step 2: Run full build**

Run:

```bash
pnpm build
```

Expected: PASS. The CLI package builds `packages/cli/bin/index.mjs`, and the web package builds `packages/web/dist/worker.mjs`.

- [ ] **Step 3: Run full test suite**

Run:

```bash
pnpm test
```

Expected: PASS. The final output includes `D1_test.res passed` from the CLI package and `Web Worker_test.res passed` from the web package.

- [ ] **Step 4: Run API endpoint smoke through the Worker test harness**

Run:

```bash
node packages/cli/test/DiscoveryApi_test.res.mjs
```

Expected: PASS with final line `DiscoveryApi_test.res passed`.

- [ ] **Step 5: Start the web Worker locally**

Run:

```bash
pnpm --filter @jvlk/rescript-bindings-web dev
```

Expected: Wrangler starts a local Worker URL, usually `http://127.0.0.1:8787`.

- [ ] **Step 6: Check the homepage HTML**

In another terminal, run:

```bash
curl -i http://127.0.0.1:8787/
```

Expected: response status `200`, `content-type: text/html; charset=utf-8`, and body text containing `ReScript Bindings`.

- [ ] **Step 7: Check the search page HTML**

Run:

```bash
curl -i 'http://127.0.0.1:8787/?q=react'
```

Expected: response status `200` and body text containing `Search results`. If the production registry has no matching rows yet, the body can contain `No bindings found.`

- [ ] **Step 8: Stop the local Worker**

Stop Wrangler with `Ctrl-C`.

- [ ] **Step 9: Commit root scripts**

```bash
git add package.json
git commit -m "chore: include web package in root scripts"
```

## Self-Review Checklist

- API discovery requirements are covered by Tasks 1 and 2.
- Separate web package and Worker requirements are covered by Tasks 3 and 4.
- Pico CDN requirement is covered by `Pages.picoCdn`.
- SSR-first requirement is covered by the Task 3 smoke and bundle checkpoint.
- Search, recent table, grouped rows, author detail, server-side tabs, and code block requirements are covered by Task 4 tests.
- Full verification and local Worker checks are covered by Task 5.
