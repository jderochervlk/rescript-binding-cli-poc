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
@send external replaceAll: (string, string, string) => string = "replaceAll"
@send external toLowerCase: string => string = "toLowerCase"

let stringSliceToEnd = (value: string, from: int): string =>
  %raw(`value.slice(from)`)

let stringSlice = (value: string, from: int, to_: int): string =>
  %raw(`value.slice(from, to_)`)

let normalizeRelativePath = (inputPath: string): string => {
  let windowsNormalized = replaceAll(inputPath, "\\", "/")
  let raw = trim(windowsNormalized)
  let withoutPrefix = if startsWith(raw, "/") { stringSliceToEnd(raw, 1) } else { raw }

  if withoutPrefix == "" || withoutPrefix == "." {
    raise(ValidationError("Path must not be empty"))
  }

  if includes(withoutPrefix, "../") || withoutPrefix == ".." {
    raise(ValidationError("Path escapes root: " ++ inputPath))
  }

  let parts = split(withoutPrefix, "/")->Array.keep(part => part != "")
  let hasHidden = parts->Array.some(part => startsWith(part, "."))
  if hasHidden {
    raise(ValidationError("Hidden files/directories are not allowed: " ++ inputPath))
  }

  withoutPrefix
}

let hasAllowedExt = (path: string) => endsWith(path, ".res") || endsWith(path, ".resi")

let rangeLooksValid = (range: string): bool => trim(range) != ""

let safeSlug = (value: string): string => {
  let base = value->toLowerCase->trim
  let parts = split(base, " ")->Array.keep(part => part != "")
  let slug = parts->Array.joinWith("-")
  stringSlice(slug, 0, 80)
}

let validateFileEntries = (files: array<fileEntry>): array<normalizedFileEntry> => {
  let count = files->Array.length
  if count == 0 {
    raise(ValidationError("Upload must contain at least one file"))
  }
  if count > maxFiles {
    raise(ValidationError("Upload exceeds max file count"))
  }

  let seenPaths: ref<array<string>> = ref([||])
  let totalBytes = ref(0)

  files->Array.map(file => {
    let normalizedPath = normalizeRelativePath(file.relativePath)
    if !hasAllowedExt(normalizedPath) {
      raise(ValidationError("Invalid file extension: " ++ normalizedPath))
    }

    if seenPaths.contents->Array.some(path => path == normalizedPath) {
      raise(ValidationError("Duplicate path: " ++ normalizedPath))
    }

    seenPaths := [...seenPaths.contents, normalizedPath]
    let bytes = String.length(file.content)
    if bytes > maxFileBytes {
      raise(ValidationError("File too large: " ++ normalizedPath))
    }

    totalBytes := totalBytes.contents + bytes

    {
      relativePath: normalizedPath,
      content: file.content,
      bytes: bytes,
    }
  })->(normalized => {
    if totalBytes.contents > maxTotalBytes {
      raise(ValidationError("Upload exceeds max total size"))
    }
    normalized
  })
}
