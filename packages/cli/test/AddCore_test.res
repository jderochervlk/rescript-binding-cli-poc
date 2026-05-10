let assertTrue = (cond: bool, label: string) => {
  if !cond {
    throw(Failure("Assertion failed: " ++ label))
  }
}

let assertRaises = (run: unit => unit, label: string) => {
  let raised =
    try {
      run()
      false
    } catch {
    | AddModuleFilename.InvalidFilename(_) => true
    }

  assertTrue(raised, label)
}

let () = {
  assertTrue(
    AddPackageName.toModuleName("@inquirer/prompts") == "InquirerPrompts",
    "scoped package names become PascalCase module names",
  )
  assertTrue(
    AddPackageName.toModuleName("2-fast_2-furious") == "Binding2Fast2Furious",
    "module names derived from packages always start uppercase",
  )

  assertTrue(
    AddModuleFilename.normalizePath("nested/fooBinding.res") == "nested/FooBinding.res",
    "nested release filenames are normalized",
  )
  assertTrue(
    AddModuleFilename.normalizePath("custom/path/inquirerPrompts.res") ==
      "custom/path/InquirerPrompts.res",
    "custom install paths keep directories and normalize the basename",
  )
  assertRaises(
    () => {
      AddModuleFilename.normalizePath("src/bindings/@prompts.res")->ignore
    },
    "paths with invalid final module names are rejected",
  )
  assertTrue(
    AddModuleFilename.normalizePath("../evil.res") == "../Evil.res",
    "path normalization leaves root containment to the installer",
  )

  assertTrue(
    AddInstallTarget.defaultSingleFilePath(
      ~packageName="@inquirer/prompts",
      ~extension=".res",
    ) == "src/bindings/InquirerPrompts.res",
    "single-file default uses a PascalCase module filename",
  )
  assertTrue(
    AddInstallTarget.defaultFolder(~packageName="@inquirer/prompts") ==
      "src/bindings/InquirerPrompts",
    "multi-file default uses a PascalCase folder",
  )
  assertTrue(
    AddInstallTarget.resolveInsideRoot(
      ~root="/tmp/project/vendor/bindings",
      ~relativePath="nested/fooBinding.res",
    ) == "/tmp/project/vendor/bindings/nested/FooBinding.res",
    "folder installs normalize final filenames inside the chosen root",
  )

  let row = AddReleaseTable.row({
    AddReleaseTable.author: "dev@example.com",
    packageRange: "^8.4.2",
    rescriptRange: "^12.0.0",
    isPackageCompatible: Some(true),
    isRescriptCompatible: Some(false),
  })

  assertTrue(row.author == "dev@example.com", "release row keeps author explicit")
  assertTrue(
    row.packageText == "^8.4.2 - matches installed",
    "release row labels package compatibility",
  )
  assertTrue(
    row.rescriptText == "^12.0.0 - does not match project",
    "release row labels ReScript compatibility",
  )

  Console.log("AddCore_test.res passed")
}
