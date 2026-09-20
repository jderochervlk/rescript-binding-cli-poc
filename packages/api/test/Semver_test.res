let assertTrue = (condition, label) => {
  if !condition {
    throw(Failure("Assertion failed: " ++ label))
  }
}

let assertIntersects = (left, right, label) =>
  assertTrue(Semver.rangesIntersect(left, right), label)

let assertDisjoint = (left, right, label) =>
  assertTrue(!Semver.rangesIntersect(left, right), label)

let () = {
  assertIntersects("^1.0.0", "1.5.0", "caret range contains a matching concrete version")
  assertDisjoint("^1.0.0", "2.0.0", "caret range excludes the next major")
  assertIntersects("^0.2.3", "0.2.9", "zero-major caret range contains the same minor")
  assertDisjoint("^0.2.3", "0.3.0", "zero-major caret range excludes the next minor")
  assertIntersects("~2.4.0", ">=2.4.5 <2.5.0", "tilde and comparator ranges overlap")
  assertDisjoint("~2.4.0", ">=2.5.0", "tilde range excludes the next minor")
  assertIntersects(">=7.1.0 <8.0.0", "^7.5.0", "compound comparator and caret ranges overlap")
  assertDisjoint(">=7.1.0 <8.0.0", "^8.0.0", "compound comparator excludes its upper bound")
  assertIntersects(">=1.0.0 <=1.0.0", "1.0.0", "inclusive bounds meet at one version")
  assertDisjoint(">1.0.0 <=1.0.0", "1.0.0", "exclusive lower bound creates an empty range")
  assertDisjoint("workspace:^1.0.0", "^1.0.0", "unsupported project ranges are incompatible")

  let compatibleRelease: RegistryTypes.release = {
    id: "compatible",
    packageName: "example",
    variantLabel: "Compatible",
    variantSlug: "compatible",
    publisherLogin: "publisher",
    peerPackageRange: "^1.0.0",
    rescriptRange: "^12.0.0",
    description: None,
    createdAt: "2026-09-20T00:00:00.000Z",
  }
  let incompatibleRelease: RegistryTypes.release = {
    ...compatibleRelease,
    id: "incompatible",
    variantLabel: "Incompatible",
    variantSlug: "incompatible",
    peerPackageRange: "^2.0.0",
    rescriptRange: "^11.0.0",
  }
  let ranked = Worker.sortByCompatibility([
    Worker.computeCompatibility(incompatibleRelease, Some("^1.4.0"), Some("12.1.0")),
    Worker.computeCompatibility(compatibleRelease, Some("^1.4.0"), Some("12.1.0")),
  ])
  switch ranked->Array.get(0) {
  | Some(first) => {
      assertTrue(first.release.id == "compatible", "compatible releases sort before incompatible releases")
      assertTrue(first.compatibilityRank == 3, "matching package and ReScript ranges receive full rank")
    }
  | None => throw(Failure("Expected ranked releases"))
  }

  Console.log("Semver_test.res passed")
}
