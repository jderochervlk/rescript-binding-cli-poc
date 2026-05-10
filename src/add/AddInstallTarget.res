/** Computes where registry files should land inside the user's project. */

@send external endsWith: (string, string) => bool = "endsWith"

let join = (left, right) =>
  if left == "" {
    right
  } else if endsWith(left, "/") {
    left ++ right
  } else {
    left ++ "/" ++ right
  }

let defaultFolder = (~packageName) =>
  join("src/bindings", AddPackageName.toModuleName(packageName))

let defaultSingleFilePath = (~packageName, ~extension) =>
  defaultFolder(~packageName) ++ extension

let resolveInsideRoot = (~root, ~relativePath) =>
  join(root, AddModuleFilename.normalizePath(relativePath))
