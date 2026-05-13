open RegistryTypes

@send external startsWith: (string, string) => bool = "startsWith"
@send external endsWith: (string, string) => bool = "endsWith"
@send external split: (string, string) => array<string> = "split"
@send external arraySliceFrom: (array<'a>, int) => array<'a> = "slice"
@send external sortInPlaceWith: (array<'a>, ('a, 'a) => int) => unit = "sort"
@send external localeCompare: (string, string) => int = "localeCompare"
@send external replaceAll: (string, string, string) => string = "replaceAll"
@send external repeat: (string, int) => string = "repeat"
@send external trim: string => string = "trim"
@send external charAt: (string, int) => string = "charAt"
@val external atob: string => string = "atob"
@val external decodeURIComponent: string => string = "decodeURIComponent"
@scope("JSON") @val external parseJson: string => 'a = "parse"
@scope("JSON") @val external stringify: 'a => string = "stringify"

type headers
type request
type response
type responseInit
type url
type searchParams
type env
type db
type statement
type boundStatement
type accessIdentity
type crypto
type subtleCrypto
type textEncoder
type uint8Array
type arrayBuffer
type date

type queryResult<'row> = {results: array<'row>}

type releaseRow = {
  id: string,
  package_name: string,
  variant_label: string,
  variant_slug: string,
  publisher_login: string,
  publisher_display_name: option<string>,
  peer_package_range: string,
  rescript_range: string,
  description: option<string>,
  created_at: string,
}

type fileRow = {
  relative_path: string,
  content: string,
  sha256: string,
  bytes: int,
}

type idRow = {id: string}

type accessJwtPayload = {email: option<string>}

type publishPayloadFile = {
  relativePath: string,
  content: string,
}

type publishPayload = {
  packageName: option<string>,
  variantLabel: option<string>,
  peerPackageRange: option<string>,
  rescriptRange: option<string>,
  description: option<string>,
  files: option<array<publishPayloadFile>>,
}

type releaseResponse = {
  id: string,
  packageName: string,
  variantLabel: string,
  variantSlug: string,
  publisherLogin: string,
  publisherDisplayName: option<string>,
  peerPackageRange: string,
  rescriptRange: string,
  description: option<string>,
  createdAt: string,
}

type releaseListResponse = {
  id: string,
  packageName: string,
  variantLabel: string,
  variantSlug: string,
  publisherLogin: string,
  publisherDisplayName: option<string>,
  peerPackageRange: string,
  rescriptRange: string,
  description: option<string>,
  createdAt: string,
  isPackageCompatible: option<bool>,
  isRescriptCompatible: option<bool>,
  compatibilityRank: int,
}

type releaseFileResponse = {
  relativePath: string,
  content: string,
  sha256: string,
  bytes: int,
}

type releasePayloadResponse = {
  id: string,
  packageName: string,
  variantLabel: string,
  variantSlug: string,
  publisherLogin: string,
  publisherDisplayName: option<string>,
  peerPackageRange: string,
  rescriptRange: string,
  description: option<string>,
  createdAt: string,
  files: array<releaseFileResponse>,
}

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

type fileWithSha = {
  relativePath: string,
  content: string,
  bytes: int,
  sha256: string,
}

type manifestFile = {
  relativePath: string,
  sha256: string,
  bytes: int,
}

type manifest = {
  packageName: string,
  variantLabel: string,
  variantSlug: string,
  peerPackageRange: string,
  rescriptRange: string,
  files: array<manifestFile>,
}

@get external requestUrl: request => string = "url"
@get external requestMethod: request => string = "method"
@get external requestHeaders: request => headers = "headers"
@send external requestJson: request => promise<'payload> = "json"
@return(nullable) @send external headerGet: (headers, string) => option<string> = "get"
@new external makeResponse: (string, responseInit) => response = "Response"
@obj
external responseInit: (~status: int, ~headers: array<array<string>>, unit) => responseInit = ""
@new external makeUrl: string => url = "URL"
@get external urlPathname: url => string = "pathname"
@get external urlSearchParams: url => searchParams = "searchParams"
@return(nullable) @send external searchParamGet: (searchParams, string) => option<string> = "get"
@get external envDb: env => option<db> = "DB"
@send external prepare: (db, string) => statement = "prepare"
@send external bind1: (statement, string) => boundStatement = "bind"
@send external bindInt1: (statement, int) => boundStatement = "bind"
@send external bind2: (statement, string, string) => boundStatement = "bind"
@send external bind3: (statement, string, string, string) => boundStatement = "bind"
@send
external bind5Strings: (statement, string, string, string, string, string) => boundStatement =
  "bind"
@send external bind5: (statement, string, string, string, string, int) => boundStatement = "bind"
@send
external bind6Strings: (
  statement,
  string,
  string,
  string,
  string,
  string,
  string,
) => boundStatement = "bind"
@send
external bind13: (
  statement,
  string,
  string,
  string,
  string,
  string,
  string,
  string,
  string,
  option<string>,
  int,
  string,
  string,
  string,
) => boundStatement = "bind"
@send external all: boundStatement => promise<queryResult<'row>> = "all"
@send external allStatement: statement => promise<queryResult<'row>> = "all"
@send external firstRaw: boundStatement => promise<'row> = "first"
@send external run: boundStatement => promise<'result> = "run"
@send external batch: (db, array<boundStatement>) => promise<array<'result>> = "batch"
@val @scope("globalThis") external globalCrypto: crypto = "crypto"
@get external subtle: crypto => subtleCrypto = "subtle"
@send external digest: (subtleCrypto, string, uint8Array) => promise<arrayBuffer> = "digest"
@send external randomUUID: crypto => string = "randomUUID"
@new external makeTextEncoder: unit => textEncoder = "TextEncoder"
@send external encode: (textEncoder, string) => uint8Array = "encode"
@new external makeUint8Array: arrayBuffer => uint8Array = "Uint8Array"
@get external byteLength: uint8Array => int = "length"
@get_index external byteAt: (uint8Array, int) => int = ""
@new external makeDate: unit => date = "Date"
@send external toISOString: date => string = "toISOString"
@get external identityGithubLogin: accessIdentity => option<string> = "githubLogin"
@get external identityEmail: accessIdentity => option<string> = "email"
@get external identityDisplayName: accessIdentity => option<string> = "displayName"

let nullableToOption = _value => %raw("_value == null ? undefined : _value")
let first = async statement => nullableToOption(await firstRaw(statement))

let getAt = (items: array<'a>, index: int): option<'a> =>
  if index < 0 || index >= items->Array.length {
    None
  } else {
    items[index]
  }

let computeCompatibility = (
  release: release,
  packageVersion: option<string>,
  rescriptVersion: option<string>,
): releaseWithCompatibility => {
  let isPackageCompatible = switch packageVersion {
  | None => None
  | Some(version) => Some(version == release.peerPackageRange)
  }

  let isRescriptCompatible = switch rescriptVersion {
  | None => None
  | Some(version) => Some(version == release.rescriptRange)
  }

  let packageScore = switch isPackageCompatible {
  | Some(true) => 2
  | _ => 0
  }
  let rescriptScore = switch isRescriptCompatible {
  | Some(true) => 1
  | _ => 0
  }

  {
    release,
    isPackageCompatible,
    isRescriptCompatible,
    compatibilityRank: packageScore + rescriptScore,
  }
}

let sortByCompatibility = (items: array<releaseWithCompatibility>): array<
  releaseWithCompatibility,
> => {
  let sorted = arraySliceFrom(items, 0)
  sortInPlaceWith(sorted, (a, b) => b.compatibilityRank - a.compatibilityRank)
  sorted
}

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

let routeFrom = (method_: string, pathname: string): route => {
  if method_ == "GET" && pathname == "/api/v1/bindings" {
    ListBindings
  } else if method_ == "GET" && pathname == "/api/v1/bindings/recent" {
    RecentBindings
  } else if method_ == "GET" && pathname == "/api/v1/bindings/search" {
    SearchBindings
  } else if method_ == "GET" && startsWith(pathname, "/api/v1/bindings/") {
    let parts = split(pathname, "/")
    switch (getAt(parts, 4), getAt(parts, 5), getAt(parts, 6)) {
    | (Some(packageName), Some("authors"), Some(author)) =>
      GetBindingAuthorDetail(packageName, author)
    | _ => NotFound
    }
  } else if (
    method_ == "GET" && startsWith(pathname, "/api/v1/packages/") && endsWith(pathname, "/releases")
  ) {
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

let isProtectedRoute = route =>
  switch route {
  | Me | Publish | AdminPublishers => true
  | ListPackageReleases(_)
  | GetRelease(_)
  | ListBindings
  | RecentBindings
  | SearchBindings
  | GetBindingAuthorDetail(_, _)
  | NotFound => false
  }

let validatePublishInput = (input: publishInput): array<normalizedFileEntry> => {
  if input.packageName == "" || input.variantLabel == "" {
    throw(Validation.ValidationError("Missing required publish fields"))
  }

  if (
    !Validation.rangeLooksValid(input.peerPackageRange) ||
    !Validation.rangeLooksValid(input.rescriptRange)
  ) {
    throw(Validation.ValidationError("Invalid semver range fields"))
  }

  Validation.validateFileEntries(input.files)
}

let json = (~status=200, body) =>
  makeResponse(
    stringify(body),
    responseInit(~status, ~headers=[["content-type", "application/json; charset=utf-8"]], ()),
  )

let badRequest = message => json(~status=400, {"error": message})

let decodeBase64Url = value => {
  let normalized = value->replaceAll("-", "+")->replaceAll("_", "/")
  let padding = "="->repeat(mod(4 - mod(String.length(normalized), 4), 4))
  atob(normalized ++ padding)
}

let decodeJwtPayload = assertion => {
  let parts = assertion->split(".")
  if parts->Array.length < 2 {
    throw(Failure("Invalid Access JWT"))
  }

  switch parts[1] {
  | Some(payload) => parseJson(decodeBase64Url(payload))
  | None => throw(Failure("Invalid Access JWT"))
  }
}

let currentIdentity = request => {
  switch request->requestHeaders->headerGet("Cf-Access-Jwt-Assertion") {
  | None => None
  | Some(assertion) =>
    try {
      let payload: accessJwtPayload = decodeJwtPayload(assertion)
      switch payload.email {
      | Some(email) =>
        let _ = email
        let identity: accessIdentity = %raw(`({
          githubLogin: null,
          displayName: null,
          email,
          access: { authenticated: true }
        })`)
        Some(identity)
      | None => None
      }
    } catch {
    | _ => None
    }
  }
}

let validationMessageFrom = error =>
  switch error {
  | Validation.ValidationError(message) => message
  | _ =>
    switch error->JsExn.fromException {
    | Some(jsError) => jsError->JsExn.message->Belt.Option.getWithDefault("Invalid publish payload")
    | None => "Invalid publish payload"
    }
  }

let stringField = (value, fieldName) =>
  switch value {
  | Some(value) =>
    let trimmed = value->trim
    if trimmed == "" {
      throw(Failure(fieldName ++ " is required"))
    }
    trimmed
  | None => throw(Failure(fieldName ++ " is required"))
  }

let normalizePublishPayload = (payload: publishPayload): publishInput => {
  let files = switch payload.files {
  | Some(files) => files
  | None => throw(Failure("files is required"))
  }

  {
    packageName: stringField(payload.packageName, "packageName"),
    variantLabel: stringField(payload.variantLabel, "variantLabel"),
    peerPackageRange: stringField(payload.peerPackageRange, "peerPackageRange"),
    rescriptRange: stringField(payload.rescriptRange, "rescriptRange"),
    description: switch payload.description {
    | Some(description) =>
      let trimmed = description->trim
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    | None => None
    },
    files: files->Array.map((file): fileEntry => {
      relativePath: file.relativePath,
      content: file.content,
    }),
  }
}

let sha256Hex = async value => {
  let bytes = makeUint8Array(
    await digest(globalCrypto->subtle, "SHA-256", makeTextEncoder()->encode(value)),
  )
  let hex = "0123456789abcdef"
  let output = ref("")

  for index in 0 to bytes->byteLength - 1 {
    let byte = byteAt(bytes, index)
    output := output.contents ++ hex->charAt(byte / 16) ++ hex->charAt(mod(byte, 16))
  }

  output.contents
}

let publisherLabelFrom = identity => {
  switch identityGithubLogin(identity) {
  | Some(login) => login
  | None =>
    switch identityEmail(identity) {
    | Some(email) => email
    | None =>
      switch identityDisplayName(identity) {
      | Some(name) => name
      | None => "unknown-user"
      }
    }
  }
}

let publisherDisplayNameFrom = (identity, fallback) => {
  identityDisplayName(identity)->Belt.Option.getWithDefault(fallback)
}

let decodePathValue = value =>
  try {
    decodeURIComponent(value)
  } catch {
  | _ => throw(Failure("Invalid encoded path value: " ++ value))
  }

let releaseFromRow = (row: releaseRow): releaseResponse => {
  id: row.id,
  packageName: row.package_name,
  variantLabel: row.variant_label,
  variantSlug: row.variant_slug,
  publisherLogin: row.publisher_login,
  publisherDisplayName: row.publisher_display_name,
  peerPackageRange: row.peer_package_range,
  rescriptRange: row.rescript_range,
  description: row.description,
  createdAt: row.created_at,
}

let releaseWithCompatibility = (~row: releaseRow, ~packageVersion, ~rescriptVersion) => {
  let release = releaseFromRow(row)
  let isPackageCompatible =
    packageVersion->Belt.Option.map(version => version == release.peerPackageRange)
  let isRescriptCompatible =
    rescriptVersion->Belt.Option.map(version => version == release.rescriptRange)
  let compatibilityRank =
    switch isPackageCompatible {
    | Some(true) => 2
    | _ => 0
    } +
    switch isRescriptCompatible {
    | Some(true) => 1
    | _ => 0
    }

  {
    id: release.id,
    packageName: release.packageName,
    variantLabel: release.variantLabel,
    variantSlug: release.variantSlug,
    publisherLogin: release.publisherLogin,
    publisherDisplayName: release.publisherDisplayName,
    peerPackageRange: release.peerPackageRange,
    rescriptRange: release.rescriptRange,
    description: release.description,
    createdAt: release.createdAt,
    isPackageCompatible,
    isRescriptCompatible,
    compatibilityRank,
  }
}

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
  if !(items->Array.some(item => item == value)) {
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
      entries
      ->Array.push({
        packageName: row.package_name,
        author: row.publisher_login,
        authorDisplayName: displayNameFromRow(row),
        libraryVersions: [row.peer_package_range],
        rescriptVersions: [row.rescript_range],
        latestCreatedAt: row.created_at,
        releases: [releaseSummaryFrom(row)],
      })
      ->ignore
    }
  })

  entries
}

let escapeLikePattern = value =>
  value
  ->replaceAll("\\", "\\\\")
  ->replaceAll("%", "\\%")
  ->replaceAll("_", "\\_")

let defaultListLimit = 50
let maxListLimit = 200

let listLimitFrom = url => {
  switch url->urlSearchParams->searchParamGet("limit") {
  | None => defaultListLimit
  | Some(rawLimit) =>
    let parsed: int = %raw(`Number.parseInt(rawLimit, 10)`)
    if parsed > 0 && parsed <= maxListLimit && stringify(parsed) == rawLimit {
      parsed
    } else {
      defaultListLimit
    }
  }
}

let requireDb = env =>
  switch env->envDb {
  | Some(db) => Ok(db)
  | None => Error(json(~status=500, {"error": "D1 binding DB is not configured"}))
  }

let handleListPackageReleases = async (~env, ~packageName, ~url) =>
  switch requireDb(env) {
  | Error(response) => response
  | Ok(db) =>
    try {
      let decodedPackageName = decodePathValue(packageName)
      let packageVersion = url->urlSearchParams->searchParamGet("packageVersion")
      let rescriptVersion = url->urlSearchParams->searchParamGet("rescriptVersion")
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
      WHERE package_name = ?
        AND status = 'published'
      ORDER BY created_at DESC`)
      ->bind1(decodedPackageName)
      ->all

      let releases =
        result.results->Array.map(row =>
          releaseWithCompatibility(~row, ~packageVersion, ~rescriptVersion)
        )
      releases->sortInPlaceWith((left, right) => {
        if right.compatibilityRank != left.compatibilityRank {
          right.compatibilityRank - left.compatibilityRank
        } else {
          right.createdAt->localeCompare(left.createdAt)
        }
      })

      json({"releases": releases})
    } catch {
    | Failure(message) => badRequest(message)
    }
  }

let handleGetRelease = async (~env, ~releaseId) =>
  switch requireDb(env) {
  | Error(response) => response
  | Ok(db) =>
    try {
      let decodedReleaseId = decodePathValue(releaseId)
      let row: option<releaseRow> = await db
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
      WHERE id = ?
        AND status = 'published'`)
      ->bind1(decodedReleaseId)
      ->first

      switch row {
      | None => json(~status=404, {"error": "Release not found"})
      | Some(row) =>
        let filesResult: queryResult<fileRow> = await db
        ->prepare(`SELECT
          relative_path,
          content,
          sha256,
          bytes
        FROM binding_files
        WHERE release_id = ?
        ORDER BY relative_path ASC`)
        ->bind1(decodedReleaseId)
        ->all
        let release = releaseFromRow(row)
        let body: releasePayloadResponse = {
          id: release.id,
          packageName: release.packageName,
          variantLabel: release.variantLabel,
          variantSlug: release.variantSlug,
          publisherLogin: release.publisherLogin,
          publisherDisplayName: release.publisherDisplayName,
          peerPackageRange: release.peerPackageRange,
          rescriptRange: release.rescriptRange,
          description: release.description,
          createdAt: release.createdAt,
          files: filesResult.results->Array.map((file): releaseFileResponse => {
            relativePath: file.relative_path,
            content: file.content,
            sha256: file.sha256,
            bytes: file.bytes,
          }),
        }
        json(body)
      }
    } catch {
    | Failure(message) => badRequest(message)
    }
  }

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

let detailReleaseFrom = (
  ~row: releaseRow,
  ~files: array<releaseFileResponse>,
): bindingDetailReleaseResponse => {
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

            detailReleases
            ->Array.push(
              detailReleaseFrom(
                ~row,
                ~files=fileResult.results->Array.map((file): releaseFileResponse => {
                  relativePath: file.relative_path,
                  content: file.content,
                  sha256: file.sha256,
                  bytes: file.bytes,
                }),
              ),
            )
            ->ignore
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

let filesWithShaFrom = async (files: array<normalizedFileEntry>) => {
  let filesWithSha: array<fileWithSha> = []

  for index in 0 to files->Array.length - 1 {
    switch files[index] {
    | Some(file) =>
      let fileWithSha: fileWithSha = {
        relativePath: file.relativePath,
        content: file.content,
        bytes: file.bytes,
        sha256: await sha256Hex(file.content),
      }
      filesWithSha->Array.push(fileWithSha)->ignore
    | None => ()
    }
  }

  filesWithSha
}

let insertRelease = async (~db, ~input: publishInput, ~files, ~identity) => {
  let variantSlug = Validation.safeSlug(input.variantLabel)
  let filesWithSha = await filesWithShaFrom(files)
  let manifestSha256 = await sha256Hex(
    stringify({
      packageName: input.packageName,
      variantLabel: input.variantLabel,
      variantSlug,
      peerPackageRange: input.peerPackageRange,
      rescriptRange: input.rescriptRange,
      files: filesWithSha->Array.map(file => {
        relativePath: file.relativePath,
        sha256: file.sha256,
        bytes: file.bytes,
      }),
    }),
  )
  let existing: option<idRow> = await db
  ->prepare(`SELECT id
       FROM binding_releases
       WHERE package_name = ?
         AND variant_slug = ?
         AND peer_package_range = ?
         AND rescript_range = ?
         AND manifest_sha256 = ?`)
  ->bind5Strings(
    input.packageName,
    variantSlug,
    input.peerPackageRange,
    input.rescriptRange,
    manifestSha256,
  )
  ->first

  switch existing {
  | Some({id}) => {
      "releaseId": id,
      "packageName": input.packageName,
      "variantLabel": input.variantLabel,
      "variantSlug": variantSlug,
      "fileCount": filesWithSha->Array.length,
      "duplicate": true,
    }
  | None =>
    let releaseId = globalCrypto->randomUUID
    let auditId = globalCrypto->randomUUID
    let createdAt = makeDate()->toISOString
    let publisherLogin = publisherLabelFrom(identity)
    let publisherDisplayName = publisherDisplayNameFrom(identity, publisherLogin)
    let statements: array<boundStatement> = []

    statements
    ->Array.push(
      db
      ->prepare(`INSERT INTO binding_releases (
          id,
          package_name,
          variant_label,
          variant_slug,
          publisher_login,
          publisher_display_name,
          peer_package_range,
          rescript_range,
          description,
          file_count,
          manifest_sha256,
          status,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      ->bind13(
        releaseId,
        input.packageName,
        input.variantLabel,
        variantSlug,
        publisherLogin,
        publisherDisplayName,
        input.peerPackageRange,
        input.rescriptRange,
        input.description,
        filesWithSha->Array.length,
        manifestSha256,
        "published",
        createdAt,
      ),
    )
    ->ignore

    filesWithSha->Array.forEach(file => {
      statements
      ->Array.push(
        db
        ->prepare(`INSERT INTO binding_files (
            release_id,
            relative_path,
            content,
            sha256,
            bytes
          ) VALUES (?, ?, ?, ?, ?)`)
        ->bind5(releaseId, file.relativePath, file.content, file.sha256, file.bytes),
      )
      ->ignore
    })

    statements
    ->Array.push(
      db
      ->prepare(`INSERT INTO publish_audit_log (
          id,
          release_id,
          publisher_login,
          action,
          created_at,
          metadata_json
        ) VALUES (?, ?, ?, ?, ?, ?)`)
      ->bind6Strings(
        auditId,
        releaseId,
        publisherLogin,
        "publish",
        createdAt,
        stringify({
          "packageName": input.packageName,
          "variantSlug": variantSlug,
          "fileCount": filesWithSha->Array.length,
        }),
      ),
    )
    ->ignore

    let _ = await db->batch(statements)

    {
      "releaseId": releaseId,
      "packageName": input.packageName,
      "variantLabel": input.variantLabel,
      "variantSlug": variantSlug,
      "fileCount": filesWithSha->Array.length,
      "duplicate": false,
    }
  }
}

let handlePublish = async (~request, ~env, ~identity) =>
  switch requireDb(env) {
  | Error(response) => response
  | Ok(db) =>
    let payloadResult = try {
      Ok(await request->requestJson)
    } catch {
    | _ => Error("Request body must be JSON")
    }

    switch payloadResult {
    | Error(message) => badRequest(message)
    | Ok(payload) =>
      let inputResult = try {
        let input = normalizePublishPayload(payload)
        let files = validatePublishInput(input)
        Ok((input, files))
      } catch {
      | error => Error(validationMessageFrom(error))
      }

      switch inputResult {
      | Error(message) => badRequest(message)
      | Ok((input, files)) =>
        try {
          let result = await insertRelease(~db, ~input, ~files, ~identity)
          json(
            ~status=if result["duplicate"] {
              200
            } else {
              201
            },
            result,
          )
        } catch {
        | error =>
          let message = switch error->JsExn.fromException {
          | Some(jsError) => jsError->JsExn.message->Belt.Option.getWithDefault("Publish failed")
          | None => "Publish failed"
          }
          json(~status=500, {"error": message})
        }
      }
    }
  }

let fetch = async (request, env, _ctx) => {
  let url = makeUrl(request->requestUrl)
  let route = routeFrom(request->requestMethod, url->urlPathname)
  let identity = currentIdentity(request)

  if isProtectedRoute(route) && identity == None {
    json(~status=401, {"error": "Missing Access identity"})
  } else {
    switch route {
    | ListPackageReleases(packageName) => await handleListPackageReleases(~env, ~packageName, ~url)
    | GetRelease(releaseId) => await handleGetRelease(~env, ~releaseId)
    | ListBindings => await handleListBindings(~env, ~url)
    | RecentBindings => await handleRecentBindings(~env)
    | SearchBindings => await handleSearchBindings(~env, ~url)
    | GetBindingAuthorDetail(packageName, author) =>
      await handleGetBindingAuthorDetail(~env, ~packageName, ~author)
    | Me =>
      switch identity {
      | Some(identity) => json(identity)
      | None => json(~status=401, {"error": "Missing Access identity"})
      }
    | Publish =>
      switch identity {
      | Some(identity) => await handlePublish(~request, ~env, ~identity)
      | None => json(~status=401, {"error": "Missing Access identity"})
      }
    | AdminPublishers | NotFound => json(~status=404, {"error": "Not found"})
    }
  }
}

%%raw("export default { fetch }")
