let packageJson: PackageJson.packageJson = %raw(`({
  peerDependencies: {
    react: "^19.0.0",
  },
  dependencies: {
    "@inquirer/prompts": "^8.4.2",
    react: "^18.0.0",
  },
  devDependencies: {
    rescript: "^12.0.0",
    vitest: "^4.0.0",
  },
})`)

let () = {
  TestSupport.assertTrue(
    PackageJson.dependencyVersionFrom(packageJson, "react") == Some("^19.0.0"),
    "peer dependencies win when a package appears in multiple groups",
  )

  TestSupport.assertTrue(
    PackageJson.dependencyVersionFrom(packageJson, "rescript") == Some("^12.0.0"),
    "dependency lookup includes dev dependencies",
  )

  TestSupport.assertTrue(
    PackageJson.dependencyVersionFrom(packageJson, "missing") == None,
    "missing dependency versions return undefined",
  )

  TestSupport.assertJsonEquals(
    PackageJson.dependencyNamesFrom(packageJson),
    ["@inquirer/prompts", "react", "vitest"],
    "dependency names are unique, sorted, and exclude rescript",
  )

  Console.log("PackageJson_test.res passed")
}
