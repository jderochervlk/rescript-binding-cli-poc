open RegistryTypes

let usage = () => {
  Console.log("Usage:")
  Console.log("  rescript-bindings add <package> [--folder <path>]")
  Console.log("  rescript-bindings publish")
}

let defaultInstallFolder = (~cwd: string, ~packageName: string, ~variantSlug: string): string =>
  NodePath.join4(cwd, "src", "bindings", NodePath.join2(packageName, variantSlug))

let ensureUploadReady = (files: array<fileEntry>): array<normalizedFileEntry> =>
  Validation.validateFileEntries(files)

let authDisplayName = (
  ~githubLogin: option<string>,
  ~email: option<string>,
  ~displayName: option<string>,
): string =>
  switch githubLogin {
  | Some(login) => login
  | None =>
    switch email {
    | Some(email) => email
    | None =>
      switch displayName {
      | Some(name) => name
      | None => "unknown-user"
      }
    }
  }

let runPublishAuthCheckWith = async (
  ~runAuth: unit => promise<PublishAuthTypes.authIdentity>,
): unit => {
  let identity = await runAuth()
  let label = authDisplayName(
    ~githubLogin=identity.githubLogin,
    ~email=identity.email,
    ~displayName=identity.displayName,
  )
  Console.log("Authenticated as " ++ label)
}

let runPublishAuthCheck = async (): unit => {
  await runPublishAuthCheckWith(~runAuth=PublishOAuth.runPublishAuth)
}

let runPublish = async (): unit => await PublishOAuth.runPublish()

let runAdd = async (~packageName: string, ~folder: option<string>): unit =>
  await RegistryAdd.runAdd(packageName, folder)

let parse = (argv: array<string>): option<(string, string, option<string>)> => {
  switch argv {
  | [_, _, "add", packageName] => Some(("add", packageName, None))
  | [_, _, "add", packageName, "--folder", folder] => Some(("add", packageName, Some(folder)))
  | [_, _, "publish"] => Some(("publish", "", None))
  | [_, _, "binding", "add", packageName] => Some(("add", packageName, None))
  | [_, _, "binding", "add", packageName, "--folder", folder] =>
    Some(("add", packageName, Some(folder)))
  | [_, _, "binding", "publish"] => Some(("publish", "", None))
  | _ => None
  }
}
