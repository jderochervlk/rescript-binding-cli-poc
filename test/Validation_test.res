let assertTrue = (cond: bool, label: string) => {
  if !cond {
    raise(Failure("Assertion failed: " ++ label))
  }
}

let () = {
  let normalized = Validation.normalizeRelativePath("folder/file.res")
  assertTrue(normalized == "folder/file.res", "normalize keeps valid paths")

  let threwTraversal =
    try {
      let _ = Validation.normalizeRelativePath("../oops.res")
      false
    } catch {
    | Validation.ValidationError(_) => true
    }

  assertTrue(threwTraversal, "normalize rejects traversal")

  let files = [
    {RegistryTypes.relativePath: "A.res", content: "let x = 1"},
    {RegistryTypes.relativePath: "B.resi", content: "let x: int"},
  ]

  let normalizedFiles = Validation.validateFileEntries(files)
  assertTrue(normalizedFiles->Array.length == 2, "validate accepts .res and .resi")

  Console.log("Validation_test.res passed")
}
