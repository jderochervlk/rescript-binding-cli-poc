let assertTrue = (cond: bool, label: string) => {
  if !cond {
    throw(Failure("Assertion failed: " ++ label))
  }
}

let assertParse = (argv, expected, label) => {
  assertTrue(Cli.parse(argv) == expected, label)
}

let () = {
  assertParse(
    ["node", "src/Main.res.mjs", "binding", "add", "@scope/pkg"],
    Some(("add", "@scope/pkg", None)),
    "parse add command",
  )

  assertParse(
    [
      "node",
      "src/Main.res.mjs",
      "binding",
      "add",
      "@scope/pkg",
      "--folder",
      "vendor/bindings",
    ],
    Some(("add", "@scope/pkg", Some("vendor/bindings"))),
    "parse add command with explicit folder",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "binding", "publish"],
    Some(("publish", "", None)),
    "parse publish command",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "binding", "install", "pkg"],
    None,
    "reject unknown command",
  )

  let defaultFolder =
    Cli.defaultInstallFolder(~cwd="/tmp/project", ~packageName="@scope/pkg", ~variantSlug="web")
  assertTrue(
    defaultFolder == "/tmp/project/src/bindings/@scope/pkg/web",
    "default install folder is derived from cwd/package/variant",
  )

  assertTrue(
    Cli.publishBaseUrlFrom(None) == "https://publish.bindings.rescript-lang.org",
    "publish base url defaults to production hostname",
  )

  assertTrue(
    Cli.publishBaseUrlFrom(Some("https://staging.example.com")) == "https://staging.example.com",
    "publish base url honors env override",
  )

  assertTrue(
    Cli.authDisplayName(~githubLogin=Some("octocat"), ~email=None, ~displayName=None) == "octocat",
    "github login is the preferred identity label",
  )

  assertTrue(
    Cli.authDisplayName(~githubLogin=None, ~email=Some("dev@example.com"), ~displayName=None) ==
      "dev@example.com",
    "email is the fallback identity label",
  )

  assertTrue(
    Cli.authDisplayName(~githubLogin=None, ~email=None, ~displayName=Some("Dev")) == "Dev",
    "display name is used when login and email are absent",
  )

  Console.log("Cli_test.res passed")
}
