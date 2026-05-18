open TestSupport

@obj
external updateDeps: (
  ~cwd: string=?,
  ~fetch: RegistryUpdate.fetchImpl=?,
  ~log: RegistryUpdate.logImpl=?,
  ~confirmUpdate: RegistryUpdate.confirmUpdateImpl=?,
  unit,
) => RegistryUpdate.deps = ""

let oldRelease: RegistryAdd.releaseSummary = {
  id: "old-release",
  packageName: "is-even",
  publisherLogin: "dev@example.com",
  peerPackageRange: "^1.0.0",
  rescriptRange: "^12.0.0",
  isPackageCompatible: Some(true),
  isRescriptCompatible: Some(true),
}

let updatedRelease: RegistryAdd.releaseSummary = {
  ...oldRelease,
  id: "updated-release",
  peerPackageRange: "^1.1.0",
}

let updatedPayload: RegistryAdd.releasePayload = {
  id: "updated-release",
  packageName: "is-even",
  publisherLogin: "dev@example.com",
  publisherDisplayName: Some("Dev Example"),
  peerPackageRange: "^1.1.0",
  rescriptRange: "^12.0.0",
  createdAt: "2026-05-10T12:00:00.000Z",
  files: [{relativePath: "IsEven.res", content: "let updated = true\n"}],
}

let makeProject = async content => {
  let projectCwd = await NodeFs.mkdtemp(NodePath.join2(NodeOs.tmpdir(), "rescript-binding-update-"))
  await NodeFs.mkdirRecursive(NodePath.join2(projectCwd, "src"), {"recursive": true})
  await NodeFs.writeFileUtf8(NodePath.join3(projectCwd, "src", "Bindings.res"), content, "utf8")
  projectCwd
}

let cleanup = async projectCwd =>
  await NodeFs.rm(projectCwd, {"recursive": true, "force": true})

let run = async () => {
  let parsed = RegistryUpdate.parseInstalledBindings(`/**
* Fetched from @jvlk/rescript-bindings
* IsEven version: ^1.0.0
* Rescript version: ^12.0.0
*/
let old = true
`)
  assertTrue(parsed->Array.length == 1, "update parses installed binding headers")
  let parsedBinding: RegistryUpdate.installedBinding = parsed[0]->Belt.Option.getExn
  assertStringEquals(parsedBinding.packageName, "is-even", "update infers package names from old headers")
  assertStringEquals(parsedBinding.packageRange, "^1.0.0", "update parses package range")

  let projectCwd = await makeProject(`/**
* Fetched from @jvlk/rescript-bindings
* Package: is-even
* IsEven version: ^1.0.0
* Rescript version: ^12.0.0
* Author: Dev Example
* Last updated: 05/03/2026
*/
let old = true
`)
  try {
    let requests = []
    let logs = []
    await RegistryUpdate.runUpdateWithDeps(updateDeps(
      ~cwd=projectCwd,
      ~log=message => logs->push(message)->ignore,
      ~confirmUpdate=async (plans, targetPath) => {
        assertStringEquals(
          targetPath,
          NodePath.join3(projectCwd, "src", "Bindings.res"),
          "update asks before writing the bindings file",
        )
        assertTrue(plans->Array.length == 1, "update prompts with pending updates")
        true
      },
      ~fetch=async url => {
        requests->push(url)->ignore
        if url->startsWith(RegistryAdd.registryApiBaseUrl ++ "/v1/packages/is-even/releases?") {
          jsonResponse({"releases": [updatedRelease]})
        } else if url == RegistryAdd.registryApiBaseUrl ++ "/v1/releases/updated-release" {
          jsonResponse(updatedPayload)
        } else {
          throw(Failure("Unexpected URL: " ++ url))
        }
      },
      (),
    ))

    let updated = await NodeFs.readFileUtf8(
      NodePath.join3(projectCwd, "src", "Bindings.res"),
      "utf8",
    )
    assertTrue(updated->includes("Package: is-even"), "updated bindings include exact package metadata")
    assertTrue(updated->includes("IsEven version: ^1.1.0"), "update writes the newer package range")
    assertTrue(updated->includes("let updated = true"), "update replaces the installed binding content")
    assertTrue(
      requests->some(url => url->includes("packageVersion=%5E1.0.0")),
      "update looks up releases using the installed package range",
    )
    assertTrue(logs->some(message => message == "Updated is-even"), "update logs updated packages")
    await cleanup(projectCwd)
  } catch {
  | error =>
    await cleanup(projectCwd)
    throw(error)
  }

  Console.log("Update_test.res passed")
}

let () = {
  run()
  ->Promise.catch(async error => {
    Console.error(messageFromError(error))
    NodeProcess.exit(1)
  })
  ->ignore
}
