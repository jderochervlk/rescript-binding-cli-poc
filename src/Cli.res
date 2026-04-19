open RegistryTypes

let usage = () => {
  Console.log("Usage:")
  Console.log("  rescript binding add <package> [--folder <path>]")
  Console.log("  rescript binding publish")
}

let defaultInstallFolder = (~cwd: string, ~packageName: string, ~variantSlug: string): string =>
  NodePath.join4(cwd, "src", "bindings", NodePath.join2(packageName, variantSlug))

let ensureUploadReady = (files: array<fileEntry>): array<normalizedFileEntry> =>
  Validation.validateFileEntries(files)

let parse = (argv: array<string>): option<(string, string, option<string>)> => {
  switch argv {
  | [_, _, "binding", "add", packageName] => Some(("add", packageName, None))
  | [_, _, "binding", "add", packageName, "--folder", folder] => Some(("add", packageName, Some(folder)))
  | [_, _, "binding", "publish"] => Some(("publish", "", None))
  | _ => None
  }
}
