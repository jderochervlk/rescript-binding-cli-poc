open RegistryTypes

@send external startsWith: (string, string) => bool = "startsWith"
@send external endsWith: (string, string) => bool = "endsWith"
@send external split: (string, string) => array<string> = "split"
@send external arraySliceFrom: (array<'a>, int) => array<'a> = "slice"
@send external sortInPlaceWith: (array<'a>, ('a, 'a) => int) => unit = "sort"

let getAt = (items: array<'a>, index: int): option<'a> =>
  if index < 0 || index >= items->Array.length {
    None
  } else {
    Some(items[index])
  }

let computeCompatibility = (
  release: release,
  packageVersion: option<string>,
  rescriptVersion: option<string>,
): releaseWithCompatibility => {
  let isPackageCompatible =
    switch packageVersion {
    | None => None
    | Some(version) => Some(version == release.peerPackageRange)
    }

  let isRescriptCompatible =
    switch rescriptVersion {
    | None => None
    | Some(version) => Some(version == release.rescriptRange)
    }

  let packageScore = switch isPackageCompatible { | Some(true) => 2 | _ => 0 }
  let rescriptScore = switch isRescriptCompatible { | Some(true) => 1 | _ => 0 }

  {
    release,
    isPackageCompatible,
    isRescriptCompatible,
    compatibilityRank: packageScore + rescriptScore,
  }
}

let sortByCompatibility = (items: array<releaseWithCompatibility>): array<releaseWithCompatibility> => {
  let sorted = arraySliceFrom(items, 0)
  sortInPlaceWith(sorted, (a, b) => b.compatibilityRank - a.compatibilityRank)
  sorted
}

type route =
  | ListPackageReleases(string)
  | GetRelease(string)
  | Me
  | Publish
  | AdminPublishers
  | NotFound

let routeFrom = (method_: string, pathname: string): route => {
  if method_ == "GET" && startsWith(pathname, "/v1/packages/") && endsWith(pathname, "/releases") {
    let parts = split(pathname, "/")
    switch getAt(parts, 3) {
    | Some(packageName) => ListPackageReleases(packageName)
    | None => NotFound
    }
  } else if method_ == "GET" && startsWith(pathname, "/v1/releases/") {
    let parts = split(pathname, "/")
    switch getAt(parts, 3) {
    | Some(releaseId) => GetRelease(releaseId)
    | None => NotFound
    }
  } else if method_ == "GET" && pathname == "/v1/me" {
    Me
  } else if method_ == "POST" && pathname == "/v1/releases" {
    Publish
  } else if method_ == "POST" && pathname == "/v1/admin/publishers" {
    AdminPublishers
  } else {
    NotFound
  }
}

let validatePublishInput = (input: publishInput): array<normalizedFileEntry> => {
  if input.packageName == "" || input.variantLabel == "" {
    raise(Validation.ValidationError("Missing required publish fields"))
  }

  if !Validation.rangeLooksValid(input.peerPackageRange) || !Validation.rangeLooksValid(input.rescriptRange) {
    raise(Validation.ValidationError("Invalid semver range fields"))
  }

  Validation.validateFileEntries(input.files)
}
