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

let rangeLooksValid = (range: string): bool => trim(range) != ""

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
