let assertTrue = (cond: bool, label: string) => {
  if !cond {
    throw(Failure("Assertion failed: " ++ label))
  }
}

let () = {
  let normalized = Validation.normalizeRelativePath("folder/file.res")
  assertTrue(normalized == "folder/file.res", "normalize keeps valid paths")
  assertTrue(Validation.normalizeVersionRange(" 12 ") == "12.0.0", "normalize expands bare major")
  assertTrue(
    Validation.normalizeVersionRange(">=12 <13") == ">=12.0.0 <13.0.0",
    "normalize expands comparator ranges",
  )
  assertTrue(
    Validation.normalizeVersionRange("^8.4.2") == "^8.4.2",
    "normalize keeps canonical caret ranges",
  )

  let threwTraversal =
    try {
      let _ = Validation.normalizeRelativePath("../oops.res")
      false
    } catch {
    | Validation.ValidationError(_) => true
    }

  assertTrue(threwTraversal, "normalize rejects traversal")
  let threwBadRange =
    try {
      let _ = Validation.normalizeVersionRange("latest")
      false
    } catch {
    | Validation.ValidationError(_) => true
    }

  assertTrue(threwBadRange, "normalize rejects unsupported ranges")
  let threwSpacedOperator =
    try {
      let _ = Validation.normalizeVersionRange(">= 12")
      false
    } catch {
    | Validation.ValidationError(_) => true
    }

  assertTrue(threwSpacedOperator, "normalize rejects separated range operators")

  let files = [
    {RegistryTypes.relativePath: "A.res", content: "let x = 1"},
    {RegistryTypes.relativePath: "B.resi", content: "let x: int"},
  ]

  let normalizedFiles = Validation.validateFileEntries(files)
  assertTrue(normalizedFiles->Array.length == 2, "validate accepts .res and .resi")

  Console.log("Validation_test.res passed")
}
