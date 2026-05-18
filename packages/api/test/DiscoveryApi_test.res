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
@get external releaseId: release => string = "id"
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
  {
    id: "react-dev-1",
    package_name: "react",
    variant_label: "default",
    variant_slug: "default",
    publisher_login: "dev",
    publisher_display_name: "Dev",
    peer_package_range: "^19.0.0",
    rescript_range: "^12.0.0",
    description: "React bindings by another author",
    file_count: 1,
    manifest_sha256: "manifest-4",
    status: "published",
    created_at: "2026-05-10T10:00:00.000Z",
  },
]`)

let filesByReleaseId = %raw(`({
  "react-josh-2": [
    {
      relative_path: "React19.res",
      content: '@module("react")\\nexternal createRoot: string => unit = "createRoot"\\n',
      sha256: "file-2",
      bytes: 64,
    },
  ],
  "react-josh-1": [
    {
      relative_path: "React18.res",
      content: '@module("react")\\nexternal legacyRoot: unit => unit = "legacyRoot"\\n',
      sha256: "file-1",
      bytes: 70,
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
  "react-dev-1": [
    {
      relative_path: "ReactDev.res",
      content: '@module("react")\\nexternal devOnly: unit => unit = "devOnly"\\n',
      sha256: "file-4",
      bytes: 62,
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
          first: async () => {
            if (sql.includes("FROM binding_releases") && params[0] === "react" && params[1] === "josh") {
              return rows.find(row => row.package_name === "react" && row.publisher_login === "josh") || null;
            }

            if (sql.includes("FROM binding_releases") && params[0] === "missing" && params[1] === "josh") {
              return null;
            }

            if (sql.includes("FROM binding_releases") && typeof params[0] === "string") {
              const needle = params[0].replaceAll("%", "").toLowerCase();
              return rows.find(row => row.package_name.toLowerCase().includes(needle)) || null;
            }

            return null;
          },
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

let findEntry = (entries, expectedPackageName, expectedAuthor) =>
  entries
  ->Array.find(entry =>
    entry->packageName == expectedPackageName && entry->author == expectedAuthor
  )
  ->Belt.Option.getExn

let findRelease = (releases, expectedId) =>
  releases->Array.find(release => release->releaseId == expectedId)->Belt.Option.getExn

let run = async () => {
  let recent = await Worker.fetch(makeRequest(publicApiBaseUrl ++ "/v1/bindings/recent"), fakeDb, ctx)
  TestSupport.assertTrue(responseStatus(recent) == 200, "recent bindings endpoint returns success")
  let recentBody: jsonBody = await recent->responseJson
  let recentEntries = recentBody->entries
  TestSupport.assertTrue(recentEntries->Array.length == 3, "recent groups releases by package and author")
  TestSupport.assertTrue(
    recentEntries->Array.some(entry => entry->packageName == "react" && entry->author == "dev"),
    "recent keeps same package with different author separate",
  )
  let reactEntry = recentEntries->findEntry("react", "josh")
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
  let newestFiles = detailBody->releases->findRelease("react-josh-2")->releaseFiles
  TestSupport.assertTrue(newestFiles->Array.length == 1, "detail includes files for newest release")
  TestSupport.assertStringEquals(newestFiles->first->relativePath, "React19.res", "detail maps newest file path")
  TestSupport.assertTrue(
    newestFiles->first->content->TestSupport.includes("createRoot"),
    "detail maps newest file content",
  )
  let legacyFiles = detailBody->releases->findRelease("react-josh-1")->releaseFiles
  TestSupport.assertTrue(legacyFiles->Array.length == 1, "detail includes files for legacy release")
  TestSupport.assertStringEquals(legacyFiles->first->relativePath, "React18.res", "detail maps legacy file path")
  TestSupport.assertTrue(
    legacyFiles->first->content->TestSupport.includes("legacyRoot"),
    "detail maps legacy file content",
  )

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
