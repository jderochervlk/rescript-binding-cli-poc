let assertTrue = (cond: bool, label: string) => {
  if !cond {
    throw(Failure("Assertion failed: " ++ label))
  }
}

let () = {
  assertTrue(
    RegistryConfig.registryApiBaseUrl ==
      "https://rescript-binding-registry.josh-401.workers.dev/api",
    "registry API base URL is centralized",
  )
  assertTrue(
    RegistryConfig.oauthResource ==
      "https://rescript-binding-registry.josh-401.workers.dev/api/publish/v1/me",
    "OAuth resource uses the publish API",
  )

  assertTrue(
    PublishSource.toPosixPath("src\\bindings\\IsEven.res") ==
      "src/bindings/IsEven.res",
    "source paths normalize to POSIX form",
  )
  assertTrue(
    PublishSource.deriveVariantLabel("src/bindings/isEven.res") == "isEven",
    "variant labels strip .res extensions",
  )
  assertTrue(
    PublishSource.deriveVariantLabel("src\\bindings\\types.resi") == "types",
    "variant labels strip .resi extensions from Windows-style paths",
  )
  assertTrue(PublishSource.isBindingFilePath("foo.res"), ".res files are publishable")
  assertTrue(PublishSource.isBindingFilePath("foo.resi"), ".resi files are publishable")
  assertTrue(!PublishSource.isBindingFilePath("foo.js"), "non-ReScript files are ignored")
  assertTrue(PublishSource.shouldSkipDirectory("node_modules"), "node_modules is skipped")
  assertTrue(PublishSource.shouldSkipDirectory(".git"), "hidden folders are skipped")
  assertTrue(!PublishSource.shouldSkipDirectory("bindings"), "normal folders are walked")

  assertTrue(
    Validation.normalizeMinimumRange("12") == "^12.0.0",
    "major-only minimum versions normalize to a caret range",
  )
  assertTrue(
    Validation.normalizeMinimumRange("12.1.3") == "^12.1.3",
    "full minimum versions normalize to a caret range",
  )
  assertTrue(
    Validation.normalizeMinimumRange("^12.1.3") == "^12.1.3",
    "existing caret ranges remain normalized",
  )
  assertTrue(
    Validation.rangesAreCloseCompatible("^12.1.0", "^12.0.0"),
    "ReScript ranges on the same major line are close-compatible",
  )
  assertTrue(
    Validation.rangesAreCloseCompatible("^7.1.0", "^7.0.10"),
    "package ranges on the same major line are close-compatible",
  )
  assertTrue(
    !Validation.rangesAreCloseCompatible("^7.1.0", "^8.0.0"),
    "different major ranges are not close-compatible",
  )

  assertTrue(
    PublishTokenStrategy.isAccessTokenUsable(
      ~hasAccessToken=true,
      ~expiresAt=Some(120_001.0),
      ~now=60_000.0,
    ),
    "access tokens with more than one minute remaining are usable",
  )
  assertTrue(
    !PublishTokenStrategy.isAccessTokenUsable(
      ~hasAccessToken=true,
      ~expiresAt=120_000.0->Some,
      ~now=60_000.0,
    ),
    "access tokens at the safety window are refreshed",
  )
  assertTrue(
    PublishTokenStrategy.selectName(~hasUsableAccessToken=true, ~hasRefreshToken=false) ==
      "reuse",
    "usable access tokens are reused",
  )
  assertTrue(
    PublishTokenStrategy.selectName(~hasUsableAccessToken=false, ~hasRefreshToken=true) ==
      "refresh",
    "refresh tokens are used when access tokens are expired",
  )
  assertTrue(
    PublishTokenStrategy.selectName(~hasUsableAccessToken=false, ~hasRefreshToken=false) ==
      "interactive",
    "auth falls back to interactive login when no token is usable",
  )

  Console.log("PublishCore_test.res passed")
}
