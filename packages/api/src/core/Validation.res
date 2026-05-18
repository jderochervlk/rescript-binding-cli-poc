open RegistryTypes

exception ValidationError(string)

let maxFiles = 200
let maxFileBytes = 200 * 1024
let maxTotalBytes = 2 * 1024 * 1024

@send external trim: string => string = "trim"
@send external startsWith: (string, string) => bool = "startsWith"
@send external endsWith: (string, string) => bool = "endsWith"
@send external includes: (string, string) => bool = "includes"
@send external split: (string, string) => array<string> = "split"
@send external sliceToEnd: (string, int) => string = "slice"
@send external sliceRange: (string, int, int) => string = "slice"
@send external replaceAll: (string, string, string) => string = "replaceAll"
@send external toLowerCase: string => string = "toLowerCase"
@new external makeRegExp: string => RegExp.t = "RegExp"

let semverRangePattern = makeRegExp(
  "^(?:(?:\\^|~|=|>=|<=|>|<)?\\d+(?:\\.\\d+){0,2})(?:\\s+(?:\\^|~|=|>=|<=|>|<)?\\d+(?:\\.\\d+){0,2})*$",
)

let versionRangeSchema =
  S.string
  ->S.trim
  ->S.pattern(semverRangePattern, ~message="Expected a semver version or range")

type semverCore = {
  major: int,
  minor: int,
  patch: int,
}

let stripRangePrefix = value => {
  let value = value->trim
  if value->startsWith(">=") || value->startsWith("<=") {
    value->sliceToEnd(2)->trim
  } else if value->startsWith("^") || value->startsWith("~") || value->startsWith("=") {
    value->sliceToEnd(1)->trim
  } else {
    value
  }
}

let parseSemverCore = value => {
  let parts = value->stripRangePrefix->split(".")
  switch parts[0] {
  | Some(majorText) =>
    switch majorText->Int.fromString {
    | Some(major) =>
      let minor = switch parts[1] {
      | Some(minorText) => minorText->Int.fromString->Belt.Option.getWithDefault(0)
      | None => 0
      }
      let patch = switch parts[2] {
      | Some(patchText) => patchText->Int.fromString->Belt.Option.getWithDefault(0)
      | None => 0
      }
      Some({major, minor, patch})
    | None => None
    }
  | None => None
  }
}

let normalizeMinimumRange = value => {
  let trimmed = value->trim
  switch parseSemverCore(trimmed) {
  | Some(version) =>
    "^" ++
    version.major->Int.toString ++
    "." ++
    version.minor->Int.toString ++ "." ++ version.patch->Int.toString
  | None => trimmed
  }
}

let versionTextFromParts = parts => {
  switch parts[0] {
  | Some(major) =>
    let minor = parts[1]->Belt.Option.getWithDefault("0")
    let patch = parts[2]->Belt.Option.getWithDefault("0")
    major ++ "." ++ minor ++ "." ++ patch
  | None => throw(ValidationError("Invalid semver range fields"))
  }
}

let normalizeVersionRangeToken = value => {
  let trimmed = value->trim
  let (prefix, versionText) = if trimmed->startsWith(">=") || trimmed->startsWith("<=") {
    (trimmed->sliceRange(0, 2), trimmed->sliceToEnd(2)->trim)
  } else if (
    trimmed->startsWith("^") ||
    trimmed->startsWith("~") ||
    trimmed->startsWith("=") ||
    trimmed->startsWith(">") ||
    trimmed->startsWith("<")
  ) {
    (trimmed->sliceRange(0, 1), trimmed->sliceToEnd(1)->trim)
  } else {
    ("", trimmed)
  }

  prefix ++ versionText->split(".")->versionTextFromParts
}

let normalizeVersionRange = value => {
  let trimmed =
    try {
      value->S.parseOrThrow(~to=versionRangeSchema)
    } catch {
    | _ => throw(ValidationError("Invalid semver range fields"))
    }

  trimmed
  ->split(" ")
  ->Array.filter(part => part != "")
  ->Array.map(normalizeVersionRangeToken)
  ->Array.join(" ")
}

let rangesAreCloseCompatible = (left, right) => {
  let left = left->trim
  let right = right->trim
  if left == right {
    true
  } else {
    switch (parseSemverCore(left), parseSemverCore(right)) {
    | (Some(leftVersion), Some(rightVersion)) => leftVersion.major == rightVersion.major
    | _ => false
    }
  }
}

let normalizeRelativePath = (inputPath: string): string => {
  let windowsNormalized = replaceAll(inputPath, "\\", "/")
  let raw = trim(windowsNormalized)
  let withoutPrefix = if startsWith(raw, "/") {
    sliceToEnd(raw, 1)
  } else {
    raw
  }

  if withoutPrefix == "" || withoutPrefix == "." {
    throw(ValidationError("Path must not be empty"))
  }

  if includes(withoutPrefix, "../") || withoutPrefix == ".." {
    throw(ValidationError("Path escapes root: " ++ inputPath))
  }

  let parts = split(withoutPrefix, "/")->Array.filter(part => part != "")
  let hasHidden = parts->Array.some(part => startsWith(part, "."))
  if hasHidden {
    throw(ValidationError("Hidden files/directories are not allowed: " ++ inputPath))
  }

  withoutPrefix
}

let hasAllowedExt = (path: string) => endsWith(path, ".res") || endsWith(path, ".resi")

let rangeLooksValid = (range: string): bool =>
  try {
    let _ = normalizeVersionRange(range)
    true
  } catch {
  | ValidationError(_) => false
  }

let safeSlug = (value: string): string => {
  let base = value->toLowerCase->trim
  let parts = split(base, " ")->Array.filter(part => part != "")
  let slug = parts->Array.join("-")
  sliceRange(slug, 0, 80)
}

let validateFileEntries = (files: array<fileEntry>): array<normalizedFileEntry> => {
  let count = files->Array.length
  if count == 0 {
    throw(ValidationError("Upload must contain at least one file"))
  }
  if count > maxFiles {
    throw(ValidationError("Upload exceeds max file count"))
  }

  let seenPaths: ref<array<string>> = ref([])
  let totalBytes = ref(0)

  files
  ->Array.map(file => {
    let normalizedPath = normalizeRelativePath(file.relativePath)
    if !hasAllowedExt(normalizedPath) {
      throw(ValidationError("Invalid file extension: " ++ normalizedPath))
    }

    if seenPaths.contents->Array.some(path => path == normalizedPath) {
      throw(ValidationError("Duplicate path: " ++ normalizedPath))
    }

    seenPaths := [...seenPaths.contents, normalizedPath]
    let bytes = String.length(file.content)
    if bytes > maxFileBytes {
      throw(ValidationError("File too large: " ++ normalizedPath))
    }

    totalBytes := totalBytes.contents + bytes

    {
      relativePath: normalizedPath,
      content: file.content,
      bytes,
    }
  })
  ->(
    normalized => {
      if totalBytes.contents > maxTotalBytes {
        throw(ValidationError("Upload exceeds max total size"))
      }
      normalized
    }
  )
}
