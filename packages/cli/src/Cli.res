open RegistryTypes

let usage = () => {
  Console.log("Usage:")
  Console.log("  rescript-bindings list")
  Console.log("  rescript-bindings recent")
  Console.log("  rescript-bindings search <query>")
  Console.log("  rescript-bindings get <package> <author>")
  Console.log("  rescript-bindings add <package> [--folder <path>]")
  Console.log("  rescript-bindings publish")
}

type command =
  | List
  | Recent
  | Search(string)
  | Get(string, string)
  | Add(string, option<string>)
  | Publish

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
  await runPublishAuthCheckWith(~runAuth=() => PublishOAuth.runPublishAuth(None))
}

let runPublish = async (): unit => await PublishOAuth.runPublish(None)

let runAdd = async (~packageName: string, ~folder: option<string>): unit =>
  await RegistryAdd.runAdd(packageName, folder)

let runList = async (): unit => await RegistryDiscovery.runList()

let runRecent = async (): unit => await RegistryDiscovery.runRecent()

let runSearch = async (~query: string): unit => await RegistryDiscovery.runSearch(query)

let runGet = async (~packageName: string, ~author: string): unit =>
  await RegistryDiscovery.runGet(~packageName, ~author)

let parse = (argv: array<string>): option<command> => {
  switch argv {
  | [_, _, "list"] => Some(List)
  | [_, _, "recent"] => Some(Recent)
  | [_, _, "search", query] => Some(Search(query))
  | [_, _, "get", packageName, author] => Some(Get(packageName, author))
  | [_, _, "add", packageName] => Some(Add(packageName, None))
  | [_, _, "add", packageName, "--folder", folder] => Some(Add(packageName, Some(folder)))
  | [_, _, "publish"] => Some(Publish)
  | _ => None
  }
}
