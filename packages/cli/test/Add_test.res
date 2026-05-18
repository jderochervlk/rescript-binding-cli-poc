open TestSupport

@obj
external addDeps: (
  ~cwd: string=?,
  ~fetch: RegistryAdd.fetchImpl=?,
  ~selectRelease: RegistryAdd.selectReleaseImpl=?,
  ~confirmOverwrite: RegistryAdd.confirmOverwriteImpl=?,
  ~log: RegistryAdd.logImpl=?,
  ~stdin: RegistryAdd.input=?,
  ~stdout: RegistryAdd.output=?,
  unit,
) => RegistryAdd.deps = ""

let nonTtyInput: RegistryAdd.input = %raw(`({ isTTY: false })`)
let nonTtyOutput: RegistryAdd.output = %raw(`({ isTTY: false })`)

let releaseSummary: RegistryAdd.releaseSummary = {
  id: "release-1",
  packageName: "is-even",
  publisherLogin: "dev@example.com",
  peerPackageRange: "1.0.0",
  rescriptRange: "^12.0.0",
  isPackageCompatible: Some(true),
  isRescriptCompatible: Some(true),
}

let releasePayload: RegistryAdd.releasePayload = {
  id: "release-1",
  packageName: "is-even",
  publisherLogin: "dev@example.com",
  publisherDisplayName: Some("Dev Example"),
  peerPackageRange: "1.0.0",
  rescriptRange: "^12.0.0",
  createdAt: "2026-05-03T12:00:00.000Z",
  files: [{
    relativePath: "isEven.res",
    content: "@module(\"is-even\")\nexternal isEven: int => bool = \"default\"\n",
  }],
}

let makeProject = async () => {
  let projectCwd = await NodeFs.mkdtemp(NodePath.join2(NodeOs.tmpdir(), "rescript-binding-add-"))
  await NodeFs.writeFileUtf8(
    NodePath.join2(projectCwd, "package.json"),
    stringify({
      "dependencies": {"is-even": "1.0.0"},
      "devDependencies": {"rescript": "^12.0.0"},
    }),
    "utf8",
  )
  projectCwd
}

let cleanup = async projectCwd =>
  await NodeFs.rm(projectCwd, {"recursive": true, "force": true})

let withProject = async test => {
  let projectCwd = await makeProject()
  try {
    await test(projectCwd)
    await cleanup(projectCwd)
  } catch {
  | error =>
    await cleanup(projectCwd)
    throw(error)
  }
}

let jsonReleaseList = releases => jsonResponse({"releases": releases})

let makeFetch = requests => async url => {
  requests->push(url)->ignore

  if url->startsWith(RegistryAdd.registryApiBaseUrl ++ "/v1/packages/is-even/releases?") {
    jsonReleaseList([releaseSummary])
  } else if url == RegistryAdd.registryApiBaseUrl ++ "/v1/releases/release-1" {
    jsonResponse(releasePayload)
  } else {
    throw(Failure("Unexpected URL: " ++ url))
  }
}

let makePackageFetch = (~packageName, ~releases, ~releasePayloads) => async url => {
  let releasesUrl =
    RegistryAdd.registryApiBaseUrl ++
    "/v1/packages/" ++ encodeURIComponent(packageName) ++ "/releases?"
  if url->startsWith(releasesUrl) {
    jsonReleaseList(releases)
  } else {
    let found = ref(None)
    for index in 0 to releasePayloads->Array.length - 1 {
      switch releasePayloads[index] {
      | Some((releaseId, payload)) =>
        if url == RegistryAdd.registryApiBaseUrl ++ "/v1/releases/" ++ releaseId {
          found := Some(payload)
        }
      | None => ()
      }
    }

    switch found.contents {
    | Some(payload) => jsonResponse(payload)
    | None => throw(Failure("Unexpected URL: " ++ url))
    }
  }
}

let firstRelease = async (releases, _options) => releases[0]->Belt.Option.getExn
let ignoreLog = _message => ()
let firstFileContent = (payload: RegistryAdd.releasePayload) => {
  let file: RegistryTypes.fileEntry = payload.files[0]->Belt.Option.getExn
  RegistryAdd.contentWithInstallHeader(~release=payload, ~content=file.content)
}

let run = async () => {
  await withProject(async installCwd => {
    let requests = []
    let logs = []

    await RegistryAdd.runAddWithDeps(
      Some("is-even"),
      None,
      addDeps(
        ~cwd=installCwd,
        ~fetch=makeFetch(requests),
        ~selectRelease=firstRelease,
        ~log=message => logs->push(message)->ignore,
        (),
      ),
    )

    let installed = await NodeFs.readFileUtf8(
      NodePath.join4(installCwd, "src", "bindings", "IsEven.res"),
      "utf8",
    )

    assertStringEquals(installed, firstFileContent(releasePayload), "add writes release files")
    assertTrue(
      requests->some(url => url->includes("packageVersion=1.0.0")),
      "add sends detected package version",
    )
    assertTrue(
      requests->some(url => url->includes("rescriptVersion=%5E12.0.0")),
      "add sends detected ReScript version",
    )
    assertTrue(logs->some(message => message->includes("Installed is-even to")), "add prints install summary")
  })

  await withProject(async customFolderCwd => {
    await RegistryAdd.runAddWithDeps(
      Some("is-even"),
      Some("vendor/bindings"),
      addDeps(
        ~cwd=customFolderCwd,
        ~fetch=makeFetch([]),
        ~selectRelease=firstRelease,
        ~log=ignoreLog,
        (),
      ),
    )

    let installed = await NodeFs.readFileUtf8(
      NodePath.join4(customFolderCwd, "vendor", "bindings", "IsEven.res"),
      "utf8",
    )

    assertStringEquals(
      installed,
      firstFileContent(releasePayload),
      "add normalizes release filename inside --folder",
    )
  })

  let scopedCwd = await NodeFs.mkdtemp(NodePath.join2(NodeOs.tmpdir(), "rescript-binding-add-scoped-"))
  try {
    await NodeFs.writeFileUtf8(
      NodePath.join2(scopedCwd, "package.json"),
      stringify({
        "dependencies": {"@inquirer/prompts": "^8.4.2"},
        "devDependencies": {"rescript": "^12.0.0"},
      }),
      "utf8",
    )
    let scopedRelease: RegistryAdd.releaseSummary = {
      ...releaseSummary,
      id: "scoped-release",
      packageName: "@inquirer/prompts",
      peerPackageRange: "^8.4.2",
    }
    let scopedPayload: RegistryAdd.releasePayload = {
      id: "scoped-release",
      packageName: "@inquirer/prompts",
      publisherLogin: "dev@example.com",
      publisherDisplayName: Some("Dev Example"),
      peerPackageRange: "^8.4.2",
      rescriptRange: "^12.0.0",
      createdAt: "2026-05-03T12:00:00.000Z",
      files: [{relativePath: "prompts.res", content: "let prompts = true\n"}],
    }

    await RegistryAdd.runAddWithDeps(
      Some("@inquirer/prompts"),
      None,
      addDeps(
        ~cwd=scopedCwd,
        ~fetch=makePackageFetch(
          ~packageName="@inquirer/prompts",
          ~releases=[scopedRelease],
          ~releasePayloads=[("scoped-release", scopedPayload)],
        ),
        ~selectRelease=firstRelease,
        ~log=ignoreLog,
        (),
      ),
    )

    let installed = await NodeFs.readFileUtf8(
      NodePath.join4(scopedCwd, "src", "bindings", "InquirerPrompts.res"),
      "utf8",
    )
    assertStringEquals(
      installed,
      firstFileContent(scopedPayload),
      "add defaults scoped packages to PascalCase module filename",
    )
    await cleanup(scopedCwd)
  } catch {
  | error =>
    await cleanup(scopedCwd)
    throw(error)
  }

  await withProject(async multiFileCwd => {
    let multiRelease: RegistryAdd.releaseSummary = {...releaseSummary, id: "multi-release"}
    let multiPayload: RegistryAdd.releasePayload = {
      id: "multi-release",
      packageName: "is-even",
      publisherLogin: "dev@example.com",
      publisherDisplayName: Some("Dev Example"),
      peerPackageRange: "1.0.0",
      rescriptRange: "^12.0.0",
      createdAt: "2026-05-03T12:00:00.000Z",
      files: [
        {relativePath: "nested/fooBinding.res", content: "let foo = true\n"},
        {relativePath: "types/barBinding.resi", content: "let bar: bool\n"},
      ],
    }

    await RegistryAdd.runAddWithDeps(
      Some("is-even"),
      None,
      addDeps(
        ~cwd=multiFileCwd,
        ~fetch=makePackageFetch(
          ~packageName="is-even",
          ~releases=[multiRelease],
          ~releasePayloads=[("multi-release", multiPayload)],
        ),
        ~selectRelease=firstRelease,
        ~log=ignoreLog,
        (),
      ),
    )

    assertStringEquals(
      await NodeFs.readFileUtf8(
        NodePath.join4(multiFileCwd, "src", "bindings", "IsEven/nested/FooBinding.res"),
        "utf8",
      ),
      RegistryAdd.contentWithInstallHeader(~release=multiPayload, ~content="let foo = true\n"),
      "add normalizes nested .res filenames",
    )
    assertStringEquals(
      await NodeFs.readFileUtf8(
        NodePath.join4(multiFileCwd, "src", "bindings", "IsEven/types/BarBinding.resi"),
        "utf8",
      ),
      RegistryAdd.contentWithInstallHeader(~release=multiPayload, ~content="let bar: bool\n"),
      "add normalizes nested .resi filenames",
    )
  })

  await withProject(async invalidFileCwd => {
    let invalidRelease: RegistryAdd.releaseSummary = {...releaseSummary, id: "invalid-release"}
    let invalidPayload: RegistryAdd.releasePayload = {
      id: "invalid-release",
      packageName: "is-even",
      publisherLogin: "dev@example.com",
      publisherDisplayName: Some("Dev Example"),
      peerPackageRange: "1.0.0",
      rescriptRange: "^12.0.0",
      createdAt: "2026-05-03T12:00:00.000Z",
      files: [{relativePath: "bad-name.res", content: "let bad = true\n"}],
    }
    let invalidMessage = ref("")
    try {
      await RegistryAdd.runAddWithDeps(
        Some("is-even"),
        Some("vendor/bindings"),
        addDeps(
          ~cwd=invalidFileCwd,
          ~fetch=makePackageFetch(
            ~packageName="is-even",
            ~releases=[invalidRelease],
            ~releasePayloads=[("invalid-release", invalidPayload)],
          ),
          ~selectRelease=firstRelease,
          ~log=ignoreLog,
          (),
        ),
      )
    } catch {
    | error => invalidMessage := messageFromError(error)
    }
    assertTrue(
      invalidMessage.contents->includes("valid ReScript module filename"),
      "add rejects release files that cannot normalize to ReScript module filenames",
    )
  })

  await withProject(async traversalCwd => {
    let traversalRelease: RegistryAdd.releaseSummary = {...releaseSummary, id: "traversal-release"}
    let traversalPayload: RegistryAdd.releasePayload = {
      id: "traversal-release",
      packageName: "is-even",
      publisherLogin: "dev@example.com",
      publisherDisplayName: Some("Dev Example"),
      peerPackageRange: "1.0.0",
      rescriptRange: "^12.0.0",
      createdAt: "2026-05-03T12:00:00.000Z",
      files: [{relativePath: "../evil.res", content: "let evil = true\n"}],
    }
    let traversalMessage = ref("")
    try {
      await RegistryAdd.runAddWithDeps(
        Some("is-even"),
        Some("vendor/bindings"),
        addDeps(
          ~cwd=traversalCwd,
          ~fetch=makePackageFetch(
            ~packageName="is-even",
            ~releases=[traversalRelease],
            ~releasePayloads=[("traversal-release", traversalPayload)],
          ),
          ~selectRelease=firstRelease,
          ~log=ignoreLog,
          (),
        ),
      )
    } catch {
    | error => traversalMessage := messageFromError(error)
    }
    assertTrue(traversalMessage.contents->includes("escapes install folder"), "add rejects release files that escape the install folder")
  })

  await withProject(async missingPackageCwd => {
    let missingPackageMessage = ref("")
    try {
      await RegistryAdd.runAddWithDeps(
        None,
        None,
        addDeps(
          ~cwd=missingPackageCwd,
          ~stdin=nonTtyInput,
          ~stdout=nonTtyOutput,
          ~fetch=async _url => throw(Failure("missing package should fail before fetching")),
          (),
        ),
      )
    } catch {
    | error => missingPackageMessage := messageFromError(error)
    }
    assertTrue(
      missingPackageMessage.contents->includes("requires a package argument"),
      "add without package requires interactivity before fetching",
    )
  })

  await withProject(async collisionCwd => {
    let targetDir = NodePath.join4(collisionCwd, "src", "bindings", "")
    let targetFile = NodePath.join2(targetDir, "IsEven.res")
    await NodeFs.mkdirRecursive(targetDir, {"recursive": true})
    await NodeFs.writeFileUtf8(targetFile, "let existing = true\n", "utf8")

    await RegistryAdd.runAddWithDeps(
      Some("is-even"),
      None,
      addDeps(
        ~cwd=collisionCwd,
        ~fetch=makeFetch([]),
        ~selectRelease=firstRelease,
        ~confirmOverwrite=async (_files, _options) => false,
        ~log=ignoreLog,
        (),
      ),
    )

    assertStringEquals(
      await NodeFs.readFileUtf8(targetFile, "utf8"),
      "let existing = true\n",
      "add cancel leaves existing files unchanged",
    )
  })

  Console.log("Add_test.res passed")
}

let () = {
  run()
  ->Promise.catch(async error => {
    Console.error(messageFromError(error))
    NodeProcess.exit(1)
  })
  ->ignore
}
