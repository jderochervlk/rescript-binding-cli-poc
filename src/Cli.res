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

let defaultPublishBaseUrl = "https://rescript-binding-registry.josh-401.workers.dev/api/publish"

let publishBaseUrlFrom = (override_: option<string>): string =>
  switch override_ {
  | Some(url) if url != "" => url
  | _ => defaultPublishBaseUrl
  }

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
  ~publishBaseUrlOverride: option<string>,
  ~runAuth: string => promise<PublishAuthTypes.authIdentity>,
): unit => {
  let publishBaseUrl = publishBaseUrlFrom(publishBaseUrlOverride)
  let identity = await runAuth(publishBaseUrl)
  let label =
    authDisplayName(
      ~githubLogin=identity.githubLogin,
      ~email=identity.email,
      ~displayName=identity.displayName,
    )
  Console.log("Authenticated as " ++ label)
}

let runPublishAuthCheck = async (): unit => {
  await runPublishAuthCheckWith(
    ~publishBaseUrlOverride=NodeProcess.envGet("RESCRIPT_BINDINGS_PUBLISH_BASE_URL"),
    ~runAuth=(publishBaseUrl =>
      PublishOAuth.runPublishAuth(PublishOAuth.makeConfig(~publishBaseUrl))
    ),
  )
}

let parse = (argv: array<string>): option<(string, string, option<string>)> => {
  switch argv {
  | [_, _, "binding", "add", packageName] => Some(("add", packageName, None))
  | [_, _, "binding", "add", packageName, "--folder", folder] => Some(("add", packageName, Some(folder)))
  | [_, _, "binding", "publish"] => Some(("publish", "", None))
  | _ => None
  }
}
