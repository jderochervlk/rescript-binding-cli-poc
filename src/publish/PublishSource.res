/** Pure rules for recognizing and naming local binding source files. */

@send external replaceAll: (string, string, string) => string = "replaceAll"
@send external startsWith: (string, string) => bool = "startsWith"
@send external endsWith: (string, string) => bool = "endsWith"
@send external lastIndexOf: (string, string) => int = "lastIndexOf"
@send external sliceFrom: (string, int) => string = "slice"
@send external sliceRange: (string, int, int) => string = "slice"

let toPosixPath = path => path->replaceAll("\\", "/")

let basename = path => {
  let normalized = toPosixPath(path)
  let slashIndex = normalized->lastIndexOf("/")

  if slashIndex < 0 {
    normalized
  } else {
    normalized->sliceFrom(slashIndex + 1)
  }
}

let stripReScriptExtension = filename => {
  if filename->endsWith(".resi") {
    filename->sliceRange(0, String.length(filename) - 5)
  } else if filename->endsWith(".res") {
    filename->sliceRange(0, String.length(filename) - 4)
  } else {
    filename
  }
}

let deriveVariantLabel = sourcePath => sourcePath->basename->stripReScriptExtension

let isBindingFilePath = path => path->endsWith(".res") || path->endsWith(".resi")

let shouldSkipDirectory = name =>
  name->startsWith(".") ||
  name == "node_modules" ||
  name == "lib" ||
  name == "dist" ||
  name == "build" ||
  name == "coverage"
