type response
type fetcher = string => promise<response>

type releaseSummary = {
  id: string,
  packageName: string,
  variantLabel: string,
  variantSlug: string,
  peerPackageRange: string,
  rescriptRange: string,
  description: Nullable.t<string>,
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

type file = {
  relativePath: string,
  content: string,
  sha256: string,
  bytes: int,
}

type detailRelease = {
  id: string,
  packageName: string,
  variantLabel: string,
  variantSlug: string,
  peerPackageRange: string,
  rescriptRange: string,
  description: Nullable.t<string>,
  createdAt: string,
  files: array<file>,
}

type detail = {
  packageName: string,
  author: string,
  authorDisplayName: string,
  libraryVersions: array<string>,
  rescriptVersions: array<string>,
  latestCreatedAt: string,
  releases: array<detailRelease>,
}

type entriesResponse = {entries: array<entry>}

type error =
  | NotFound
  | Upstream(string)

@get external responseStatus: response => int = "status"
@send external responseText: response => promise<string> = "text"
@scope("JSON") @val external parseJson: string => 'a = "parse"
@val external encodeURIComponent: string => string = "encodeURIComponent"
@send external endsWith: (string, string) => bool = "endsWith"
@send external sliceTo: (string, int, int) => string = "slice"

let withoutTrailingSlash = value =>
  if value->endsWith("/") {
    value->sliceTo(0, value->String.length - 1)
  } else {
    value
  }

let getJson = async (~fetcher: fetcher, url): result<'payload, error> => {
  try {
    let response = await fetcher(url)
    let status = response->responseStatus
    if status == 404 {
      Error(NotFound)
    } else if status >= 200 && status < 300 {
      try {
        Ok(parseJson(await response->responseText))
      } catch {
      | _ => Error(Upstream("Registry API returned invalid JSON"))
      }
    } else {
      Error(Upstream(`Registry API returned ${status->Int.toString}`))
    }
  } catch {
  | _ => Error(Upstream("Registry API request failed"))
  }
}

let recent = async (~fetcher, ~apiBase): result<array<entry>, error> => {
  switch await getJson(~fetcher, withoutTrailingSlash(apiBase) ++ "/v1/bindings/recent") {
  | Ok(({entries}: entriesResponse)) => Ok(entries)
  | Error(error) => Error(error)
  }
}

let search = async (~fetcher, ~apiBase, ~query): result<array<entry>, error> => {
  switch await getJson(
    ~fetcher,
    withoutTrailingSlash(apiBase) ++ "/v1/bindings/search?q=" ++ encodeURIComponent(query),
  ) {
  | Ok(({entries}: entriesResponse)) => Ok(entries)
  | Error(error) => Error(error)
  }
}

let detail = async (
  ~fetcher,
  ~apiBase,
  ~packageName,
  ~author,
): result<detail, error> => {
  await getJson(
    ~fetcher,
    withoutTrailingSlash(apiBase)
    ++ "/v1/bindings/"
    ++ encodeURIComponent(packageName)
    ++ "/authors/"
    ++ encodeURIComponent(author),
  )
}
