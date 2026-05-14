open TestSupport

@obj
external discoveryDeps: (
  ~fetch: RegistryDiscovery.fetchImpl=?,
  ~log: RegistryDiscovery.logImpl=?,
  unit,
) => RegistryDiscovery.deps = ""

let entry: RegistryDiscovery.bindingEntry = {
  packageName: "@rescript/react",
  author: "josh",
  authorDisplayName: "Josh",
  libraryVersions: ["^19.0.0"],
  rescriptVersions: ["^12.0.0"],
  latestCreatedAt: "2026-05-10T13:00:00.000Z",
  releases: [{
    id: "react-josh-1",
    packageName: "@rescript/react",
    variantLabel: "default",
    variantSlug: "default",
    peerPackageRange: "^19.0.0",
    rescriptRange: "^12.0.0",
    description: Some("React bindings"),
    createdAt: "2026-05-10T13:00:00.000Z",
  }],
}

let detail: RegistryDiscovery.bindingDetail = {
  packageName: "@rescript/react",
  author: "josh",
  authorDisplayName: "Josh",
  libraryVersions: ["^19.0.0"],
  rescriptVersions: ["^12.0.0"],
  latestCreatedAt: "2026-05-10T13:00:00.000Z",
  releases: [{
    id: "react-josh-1",
    packageName: "@rescript/react",
    variantLabel: "default",
    variantSlug: "default",
    peerPackageRange: "^19.0.0",
    rescriptRange: "^12.0.0",
    description: Some("React bindings"),
    createdAt: "2026-05-10T13:00:00.000Z",
    files: [{
      relativePath: "React.res",
      content: "let ready = true\n",
      sha256: "file-sha",
      bytes: 17,
    }],
  }],
}

let makeFetch = requests => async url => {
  requests->push(url)->ignore

  if url == RegistryDiscovery.registryApiBaseUrl ++ "/v1/bindings/recent" {
    jsonResponse({"entries": [entry]})
  } else if url == RegistryDiscovery.registryApiBaseUrl ++ "/v1/bindings/search?q=react" {
    jsonResponse({"entries": [entry]})
  } else if url == RegistryDiscovery.registryApiBaseUrl ++ "/v1/bindings/%40rescript%2Freact/authors/josh" {
    jsonResponse(detail)
  } else {
    throw(Failure("Unexpected URL: " ++ url))
  }
}

let run = async () => {
  let requests = []
  let logs = []
  let deps = discoveryDeps(
    ~fetch=makeFetch(requests),
    ~log=message => logs->push(message)->ignore,
    (),
  )

  await RegistryDiscovery.runListWithDeps(deps)
  await RegistryDiscovery.runSearchWithDeps(" react ", deps)
  await RegistryDiscovery.runGetWithDeps("@rescript/react", "josh", deps)

  assertTrue(
    requests->some(url => url == RegistryDiscovery.registryApiBaseUrl ++ "/v1/bindings/recent"),
    "list calls recent endpoint",
  )
  assertTrue(
    requests->some(url => url == RegistryDiscovery.registryApiBaseUrl ++ "/v1/bindings/search?q=react"),
    "search trims and encodes query",
  )
  assertTrue(
    requests->some(url =>
      url == RegistryDiscovery.registryApiBaseUrl ++ "/v1/bindings/%40rescript%2Freact/authors/josh"
    ),
    "get encodes scoped package names",
  )
  assertTrue(logs->some(message => message == "Recently updated bindings:"), "list prints heading")
  assertTrue(logs->some(message => message == "Search results:"), "search prints heading")
  assertTrue(
    logs->some(message =>
      message->includes("Package") &&
      message->includes("Author") &&
      message->includes("Library version") &&
      message->includes("ReScript version") &&
      message->includes("Updated")
    ),
    "list prints a table header",
  )
  assertTrue(logs->some(message => message->includes("-------")), "list prints a table divider")
  assertTrue(
    logs->some(message =>
      message->includes("@rescript/react") &&
      message->includes("^19.0.0") &&
      message->includes("^12.0.0") &&
      message->includes("2026-05-10")
    ),
    "list prints binding rows as table data",
  )
  assertTrue(logs->some(message => message == "Binding:"), "get prints binding table heading")
  assertTrue(logs->some(message => message == "Releases:"), "get prints releases table heading")
  assertTrue(logs->some(message => message->includes("React.res")), "get prints release files")

  let missingQueryMessage = ref("")
  try {
    await RegistryDiscovery.runSearchWithDeps(" ", deps)
  } catch {
  | error => missingQueryMessage := messageFromError(error)
  }
  assertTrue(missingQueryMessage.contents->includes("Search query is required"), "search rejects blank query")

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
