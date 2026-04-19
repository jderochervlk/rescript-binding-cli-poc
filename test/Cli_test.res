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
    ["node", "src/Main.mjs", "binding", "add", "@scope/pkg"],
    Some(("add", "@scope/pkg", None)),
    "parse add command",
  )

  assertParse(
    [
      "node",
      "src/Main.mjs",
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
    ["node", "src/Main.mjs", "binding", "publish"],
    Some(("publish", "", None)),
    "parse publish command",
  )

  assertParse(
    ["node", "src/Main.mjs", "binding", "install", "pkg"],
    None,
    "reject unknown command",
  )

  let defaultFolder =
    Cli.defaultInstallFolder(~cwd="/tmp/project", ~packageName="@scope/pkg", ~variantSlug="web")
  assertTrue(
    defaultFolder == "/tmp/project/src/bindings/@scope/pkg/web",
    "default install folder is derived from cwd/package/variant",
  )

  Console.log("Cli_test.res passed")
}
