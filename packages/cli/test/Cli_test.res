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
    ["node", "src/Main.res.mjs", "list"],
    Some(List),
    "parse list command",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "recent"],
    Some(Recent),
    "parse recent command",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "search", "react"],
    Some(Search("react")),
    "parse search command",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "get", "@scope/pkg", "josh"],
    Some(Get("@scope/pkg", "josh")),
    "parse get command",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "add", "@scope/pkg"],
    Some(Add("@scope/pkg", None)),
    "parse add command",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "add", "@scope/pkg", "--folder", "vendor/bindings"],
    Some(Add("@scope/pkg", Some("vendor/bindings"))),
    "parse add command with explicit folder",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "publish"],
    Some(Publish),
    "parse publish command",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "update"],
    Some(Update),
    "parse update command",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "delete"],
    Some(Delete),
    "parse delete command",
  )

  assertParse(
    ["node", "src/Main.res.mjs", "binding", "install", "pkg"],
    None,
    "reject unknown command",
  )

  let defaultFolder = Cli.defaultInstallFolder(
    ~cwd="/tmp/project",
    ~packageName="@scope/pkg",
    ~variantSlug="web",
  )
  assertTrue(
    defaultFolder == "/tmp/project/src/bindings/@scope/pkg/web",
    "default install folder is derived from cwd/package/variant",
  )

  assertTrue(
    Cli.authDisplayName(~githubLogin=Some("octocat"), ~email=None, ~displayName=None) == "octocat",
    "github login is the preferred identity label",
  )

  assertTrue(
    Cli.authDisplayName(
      ~githubLogin=None,
      ~email=Some("dev@example.com"),
      ~displayName=None,
    ) == "dev@example.com",
    "email is the fallback identity label",
  )

  assertTrue(
    Cli.authDisplayName(~githubLogin=None, ~email=None, ~displayName=Some("Dev")) == "Dev",
    "display name is used when login and email are absent",
  )

  Console.log("Cli_test.res passed")
}
