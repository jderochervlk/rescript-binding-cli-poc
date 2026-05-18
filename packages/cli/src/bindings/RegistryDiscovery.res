type errorPayload = {
  error: option<string>,
  message: option<string>,
}

type fetchImpl = string => promise<WebFetch.response>
type logImpl = string => unit
type deps

type bindingEntryRelease = {
  id: string,
  packageName: string,
  variantLabel: string,
  variantSlug: string,
  peerPackageRange: string,
  rescriptRange: string,
  description: option<string>,
  createdAt: string,
}

type bindingEntry = {
  packageName: string,
  author: string,
  authorDisplayName: string,
  libraryVersions: array<string>,
  rescriptVersions: array<string>,
  latestCreatedAt: string,
  releases: array<bindingEntryRelease>,
}

type releaseFile = {
  relativePath: string,
  content: string,
  sha256: string,
  bytes: int,
}

type bindingDetailRelease = {
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

type bindingDetail = {
  packageName: string,
  author: string,
  authorDisplayName: string,
  libraryVersions: array<string>,
  rescriptVersions: array<string>,
  latestCreatedAt: string,
  releases: array<bindingDetailRelease>,
}

type bindingEntriesPayload = {entries: option<array<bindingEntry>>}

@obj external emptyDeps: unit => deps = ""
@get external depFetch: deps => option<fetchImpl> = "fetch"
@get external depLog: deps => option<logImpl> = "log"
@send external includesContentType: (string, string) => bool = "includes"
@send external join: (array<string>, string) => string = "join"
@send external padEnd: (string, int) => string = "padEnd"
@send external repeat: (string, int) => string = "repeat"
@send external trim: string => string = "trim"
@val external encodeURIComponent: string => string = "encodeURIComponent"
@send external responseJsonAs: WebFetch.response => promise<'payload> = "json"
@val @scope("globalThis") external globalFetch: option<fetchImpl> = "fetch"
@new external makeJsError: string => exn = "Error"

let registryApiBaseUrl = RegistryConfig.registryApiBaseUrl

let fail = message => throw(makeJsError(message))

let requireFetch = (fetchImpl: option<fetchImpl>) =>
  switch fetchImpl {
  | Some(fetchImpl) => fetchImpl
  | None => fail("registry discovery requires a fetch implementation")
  }

let readJson = async (response: WebFetch.response): 'payload => {
  if response->WebFetch.ok {
    await response->responseJsonAs
  } else {
    let contentType =
      response->WebFetch.headers->WebFetch.getHeader("content-type")->Belt.Option.getWithDefault("")

    if contentType->includesContentType("application/json") {
      let payload: errorPayload = await response->responseJsonAs
      fail(
        switch payload.error {
        | Some(error) => error
        | None =>
          switch payload.message {
          | Some(message) => message
          | None => "HTTP " ++ response->WebFetch.status->Int.toString
          }
        },
      )
    } else {
      let body = await response->WebFetch.text
      fail(
        if body == "" {
          "HTTP " ++ response->WebFetch.status->Int.toString
        } else {
          body
        },
      )
    }
  }
}

let recentBindings = async (~fetchImpl) => {
  let payload: bindingEntriesPayload = await readJson(
    await fetchImpl(registryApiBaseUrl ++ "/v1/bindings/recent"),
  )
  payload.entries->Belt.Option.getWithDefault([])
}

let searchBindings = async (~query, ~fetchImpl) => {
  let trimmed = query->trim
  if trimmed == "" {
    fail("Search query is required")
  }

  let payload: bindingEntriesPayload = await readJson(
    await fetchImpl(registryApiBaseUrl ++ "/v1/bindings/search?q=" ++ encodeURIComponent(trimmed)),
  )
  payload.entries->Belt.Option.getWithDefault([])
}

let getBinding = async (~packageName, ~author, ~fetchImpl) => {
  let trimmedPackageName = packageName->trim
  let trimmedAuthor = author->trim
  if trimmedPackageName == "" {
    fail("Package name is required")
  }
  if trimmedAuthor == "" {
    fail("Author is required")
  }

  let payload: bindingDetail = await readJson(
    await fetchImpl(
      registryApiBaseUrl ++
      "/v1/bindings/" ++
      encodeURIComponent(trimmedPackageName) ++
      "/authors/" ++
      encodeURIComponent(trimmedAuthor),
    ),
  )
  payload
}

let authorLabel = (entry: bindingEntry) =>
  if entry.authorDisplayName == entry.author {
    entry.author
  } else {
    entry.authorDisplayName ++ " (" ++ entry.author ++ ")"
  }

let rangeLabel = (ranges: array<string>) => ranges->join(", ")

let dateLabel = value =>
  switch value->String.split("T")->Array.get(0) {
  | Some(date) => date
  | None => value
  }

let widthFor = (~label, ~items, ~value) =>
  items->Array.reduce(label->String.length, (width, item) => max(width, value(item)->String.length))

let row = values => "  " ++ values->Array.join("  ")

let divider = widths => row(widths->Array.map(width => "-"->repeat(width)))

let printTable = (~headers: array<string>, ~rows: array<array<string>>, ~log) => {
  let widths = headers->Array.mapWithIndex((header, index) =>
    rows->Array.reduce(header->String.length, (width, row) =>
      switch row[index] {
      | Some(value) => max(width, value->String.length)
      | None => width
      }
    )
  )

  log(row(headers->Array.mapWithIndex((header, index) =>
    switch widths[index] {
    | Some(width) => header->padEnd(width)
    | None => header
    }
  )))
  log(divider(widths))
  rows->Array.forEach(values =>
    log(row(values->Array.mapWithIndex((value, index) =>
      switch widths[index] {
      | Some(width) => value->padEnd(width)
      | None => value
      }
    )))
  )
}

let printEntries = (~title, ~entries, ~log) => {
  log(title)
  if entries->Array.length == 0 {
    log("No bindings found.")
  } else {
    printTable(
      ~headers=["Package", "Author", "Library version", "ReScript version", "Updated"],
      ~rows=entries->Array.map((entry: bindingEntry) => [
        entry.packageName,
        authorLabel(entry),
        rangeLabel(entry.libraryVersions),
        rangeLabel(entry.rescriptVersions),
        dateLabel(entry.latestCreatedAt),
      ]),
      ~log,
    )
  }
}

let printDetail = (~detail: bindingDetail, ~log) => {
  let entry: bindingEntry = {
    packageName: detail.packageName,
    author: detail.author,
    authorDisplayName: detail.authorDisplayName,
    libraryVersions: detail.libraryVersions,
    rescriptVersions: detail.rescriptVersions,
    latestCreatedAt: detail.latestCreatedAt,
    releases: [],
  }
  log("Binding:")
  printTable(
    ~headers=["Package", "Author", "Library version", "ReScript version", "Updated"],
    ~rows=[[
      detail.packageName,
      authorLabel(entry),
      rangeLabel(detail.libraryVersions),
      rangeLabel(detail.rescriptVersions),
      dateLabel(detail.latestCreatedAt),
    ]],
    ~log,
  )
  log("")
  log("Releases:")
  printTable(
    ~headers=["Release", "Variant", "Library version", "ReScript version", "Updated", "Files"],
    ~rows=detail.releases->Array.map((release: bindingDetailRelease) => [
      release.id,
      release.variantLabel,
      release.peerPackageRange,
      release.rescriptRange,
      dateLabel(release.createdAt),
      release.files->Array.map(file => file.relativePath)->join(", "),
    ]),
    ~log,
  )
}

let runListWithDeps = async deps => {
  let fetchImpl = depFetch(deps)->Belt.Option.orElse(globalFetch)->requireFetch
  let log = depLog(deps)->Belt.Option.getWithDefault(message => Console.log(message))
  let entries = await recentBindings(~fetchImpl)
  printEntries(~title="Recently updated bindings:", ~entries, ~log)
}

let runRecentWithDeps = runListWithDeps

let runSearchWithDeps = async (query, deps) => {
  let fetchImpl = depFetch(deps)->Belt.Option.orElse(globalFetch)->requireFetch
  let log = depLog(deps)->Belt.Option.getWithDefault(message => Console.log(message))
  let entries = await searchBindings(~query, ~fetchImpl)
  printEntries(~title="Search results:", ~entries, ~log)
}

let runGetWithDeps = async (packageName, author, deps) => {
  let fetchImpl = depFetch(deps)->Belt.Option.orElse(globalFetch)->requireFetch
  let log = depLog(deps)->Belt.Option.getWithDefault(message => Console.log(message))
  let detail = await getBinding(~packageName, ~author, ~fetchImpl)
  printDetail(~detail, ~log)
}

let runList = async () => await runListWithDeps(emptyDeps())
let runRecent = async () => await runRecentWithDeps(emptyDeps())
let runSearch = async query => await runSearchWithDeps(query, emptyDeps())
let runGet = async (~packageName, ~author) => await runGetWithDeps(packageName, author, emptyDeps())
