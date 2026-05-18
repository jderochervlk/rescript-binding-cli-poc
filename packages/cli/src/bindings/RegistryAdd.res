open RegistryTypes

type input
type output
type readline
type searchConfig
type promptContext
type searchChoice
type selectConfig
type releaseChoice
type deps
type promptOptions
type jsError

type releaseSummary = {
  id: string,
  packageName: string,
  publisherLogin: string,
  peerPackageRange: string,
  rescriptRange: string,
  isPackageCompatible: option<bool>,
  isRescriptCompatible: option<bool>,
}

type releaseListPayload = {releases: option<array<releaseSummary>>}

type releasePayload = {
  id: string,
  packageName: string,
  publisherLogin: string,
  publisherDisplayName: option<string>,
  peerPackageRange: string,
  rescriptRange: string,
  createdAt: string,
  files: array<fileEntry>,
}

type errorPayload = {
  error: option<string>,
  message: option<string>,
}

type fetchImpl = string => promise<WebFetch.response>
type logImpl = string => unit
type selectReleaseImpl = (array<releaseSummary>, promptOptions) => promise<releaseSummary>
type confirmOverwriteImpl = (array<string>, promptOptions) => promise<bool>

type targetFile = {
  targetPath: string,
  content: string,
}

type targetPlan = {
  summaryPath: string,
  targetPathForFile: fileEntry => string,
}

@module("node:process") external stdin: input = "stdin"
@module("node:process") external stdout: output = "stdout"
@module("node:process") external cwd: unit => string = "cwd"
@module("node:readline/promises")
external createInterface: {"input": input, "output": output} => readline = "createInterface"
@send external question: (readline, string) => promise<string> = "question"
@send external close: readline => unit = "close"
@send external write: (output, string) => bool = "write"
@send external trim: string => string = "trim"
@send external toLowerCase: string => string = "toLowerCase"
@send external includesString: (string, string) => bool = "includes"
@send external includesContentType: (string, string) => bool = "includes"
@send external padEnd: (string, int) => string = "padEnd"
@send external startsWith: (string, string) => bool = "startsWith"
@val external encodeURIComponent: string => string = "encodeURIComponent"
@scope("JSON") @val external parsePackageJson: string => PackageJson.packageJson = "parse"
external jsonAs: WebFetch.jsonValue => 'a = "%identity"
@val @scope("globalThis") external globalFetch: option<fetchImpl> = "fetch"
@get external isInputTty: input => option<bool> = "isTTY"
@get external isOutputTty: output => option<bool> = "isTTY"
@get external errorCode: JsExn.t => option<string> = "code"
@new external makeJsError: string => exn = "Error"

@obj external emptyDeps: unit => deps = ""
@obj external emptyPackageJson: unit => PackageJson.packageJson = ""
@obj external searchChoice: (~name: string, ~value: string, unit) => searchChoice = ""
@obj external releaseChoice: (~name: string, ~value: releaseSummary, unit) => releaseChoice = ""
@obj external promptContext: (~input: input, ~output: output, unit) => promptContext = ""
@obj
external searchConfig: (
  ~message: string,
  ~pageSize: int,
  ~source: (option<string>, 'context) => promise<array<searchChoice>>,
  unit,
) => searchConfig = ""
@obj
external selectConfig: (
  ~message: string,
  ~pageSize: int,
  ~loop: bool,
  ~choices: array<releaseChoice>,
  unit,
) => selectConfig = ""
@obj
external promptOptions: (~stdin: input, ~stdout: output, ~log: logImpl, unit) => promptOptions = ""

@get external depFetch: deps => option<fetchImpl> = "fetch"
@get external depCwd: deps => option<string> = "cwd"
@get external depLog: deps => option<logImpl> = "log"
@get external depStdin: deps => option<input> = "stdin"
@get external depStdout: deps => option<output> = "stdout"
@get external depSelectRelease: deps => option<selectReleaseImpl> = "selectRelease"
@get external depConfirmOverwrite: deps => option<confirmOverwriteImpl> = "confirmOverwrite"
@get external promptLog: promptOptions => logImpl = "log"

@module("@inquirer/prompts")
external search: (searchConfig, promptContext) => promise<string> = "search"
@module("@inquirer/prompts")
external select: (selectConfig, promptContext) => promise<releaseSummary> = "select"

let registryApiBaseUrl = RegistryConfig.registryApiBaseUrl

let fail = message => throw(makeJsError(message))

let clearConsole = stdout => write(stdout, "\x1b[2J\x1b[3J\x1b[H")->ignore

let clearConsoleOnce = (~cleared, ~stdout) => {
  if !cleared.contents {
    clearConsole(stdout)
    cleared := true
  }
}

let isTty = (streamTty: option<bool>) => streamTty->Belt.Option.getWithDefault(false)

let requireFetch = (fetchImpl: option<fetchImpl>) =>
  switch fetchImpl {
  | Some(fetchImpl) => fetchImpl
  | None => fail("add requires a fetch implementation")
  }

let readJson = async (response: WebFetch.response): 'payload => {
  if response->WebFetch.ok {
    (await response->WebFetch.json)->jsonAs
  } else {
    let contentType =
      response->WebFetch.headers->WebFetch.getHeader("content-type")->Belt.Option.getWithDefault("")

    if contentType->includesContentType("application/json") {
      let payload: errorPayload = (await response->WebFetch.json)->jsonAs
      if response->WebFetch.status == 401 && payload.error == Some("invalid_token") {
        fail(
          "Registry read API is protected by Cloudflare Access. Configure Access to protect /api/publish/* only and leave /api/v1/* public.",
        )
      }

      fail(
        switch payload.error {
        | Some(error) => error
        | None =>
          switch payload.message {
          | Some(message) => message
          | None => "HTTP " ++ response->WebFetch.status->Int.toString
          }
        },
      )
    } else {
      let body = await response->WebFetch.text
      fail(
        if body == "" {
          "HTTP " ++ response->WebFetch.status->Int.toString
        } else {
          body
        },
      )
    }
  }
}

let readProjectPackageJson = async projectCwd => {
  let packageJsonPath = NodePath.join2(projectCwd, "package.json")

  try {
    (await NodeFs.readFileUtf8(packageJsonPath, "utf8"))->parsePackageJson
  } catch {
  | error =>
    switch error->JsExn.fromException {
    | Some(jsError) if errorCode(jsError) == Some("ENOENT") => emptyPackageJson()
    | _ => fail("Could not parse " ++ packageJsonPath)
    }
  }
}

let askWithReadline = async (~stdin, ~stdout, questionText) => {
  let readline = createInterface({"input": stdin, "output": stdout})
  let answer = await readline->question(questionText)
  readline->close
  answer
}

let askRequired = async (~stdin, ~stdout, questionText) => {
  let answer = (await askWithReadline(~stdin, ~stdout, questionText))->trim
  if answer == "" {
    fail("Package name is required")
  }
  answer
}

let askWithDefault = async (~stdin, ~stdout, questionText, defaultValue) => {
  let answer =
    (await askWithReadline(~stdin, ~stdout, questionText ++ " [" ++ defaultValue ++ "]: "))->trim
  if answer == "" {
    defaultValue
  } else {
    answer
  }
}

let normalizeInstallFilePath = filePath => {
  try {
    AddModuleFilename.normalizePath(filePath)
  } catch {
  | AddModuleFilename.InvalidFilename(_) => fail(AddModuleFilename.errorMessage)
  }
}

let selectPackageName = async (~packageNames, ~stdin, ~stdout) => {
  if !isTty(isInputTty(stdin)) || !isTty(isOutputTty(stdout)) {
    fail("add requires a package argument when not running in an interactive terminal")
  }

  if packageNames->Array.length == 0 {
    await askRequired(~stdin, ~stdout, "Foo bar")
  } else {
    await search(
      searchConfig(
        ~message="What package do you want to get bindings for?",
        ~pageSize=8,
        ~source=async (term, _) => {
          let input = term->Belt.Option.getWithDefault("")->trim
          let matches =
            packageNames
            ->Array.filter(packageName => input == "" || packageName->includesString(input))
            ->Array.map(packageName => searchChoice(~name=packageName, ~value=packageName, ()))

          if input != "" && !(packageNames->Array.some(packageName => packageName == input)) {
            Array.concat(
              matches,
              [searchChoice(~name="Use custom package \"" ++ input ++ "\"", ~value=input, ())],
            )
          } else {
            matches
          }
        },
        (),
      ),
      promptContext(~input=stdin, ~output=stdout, ()),
    )
  }
}

let releaseRow = (release: releaseSummary) => {
  AddReleaseTable.row({
    author: release.publisherLogin,
    packageRange: release.peerPackageRange,
    rescriptRange: release.rescriptRange,
    isPackageCompatible: release.isPackageCompatible,
    isRescriptCompatible: release.isRescriptCompatible,
  })
}

let tableWidth = (rows, key, label) =>
  rows->Array.reduce(label->String.length, (width, row) => {
    let value = key(row)
    max(width, value->String.length)
  })

let releaseChoiceName = (~authorWidth, ~packageWidth, ~row: AddReleaseTable.row) =>
  row.author->padEnd(authorWidth) ++
  "  " ++
  row.packageText->padEnd(packageWidth) ++
  "  " ++
  row.rescriptText

let defaultSelectRelease = async (releases, options) => {
  let promptStdout = depStdout(emptyDeps())->Belt.Option.getWithDefault(stdout)
  let promptStdin = depStdin(emptyDeps())->Belt.Option.getWithDefault(stdin)

  if !isTty(isInputTty(promptStdin)) || !isTty(isOutputTty(promptStdout)) {
    fail("add requires an interactive terminal when multiple releases are available")
  }

  let rows = releases->Array.map(releaseRow)
  let authorWidth = tableWidth(rows, row => row.author, "Author")
  let packageWidth = tableWidth(rows, row => row.packageText, "Package")
  let header =
    "  " ++ "Author"->padEnd(authorWidth) ++ "  " ++ "Package"->padEnd(packageWidth) ++ "  ReScript"

  let log = promptLog(options)
  log("Available binding releases:")
  log(header)

  await select(
    selectConfig(
      ~message="Select binding release",
      ~pageSize=8,
      ~loop=true,
      ~choices=releases->Array.mapWithIndex((release, index) => {
        let row = rows[index]->Belt.Option.getExn
        releaseChoice(
          ~name=releaseChoiceName(~authorWidth, ~packageWidth, ~row),
          ~value=release,
          (),
        )
      }),
      (),
    ),
    promptContext(~input=promptStdin, ~output=promptStdout, ()),
  )
}

let defaultConfirmOverwrite = async (files, options) => {
  let promptStdout = depStdout(emptyDeps())->Belt.Option.getWithDefault(stdout)
  let promptStdin = depStdin(emptyDeps())->Belt.Option.getWithDefault(stdin)

  if !isTty(isInputTty(promptStdin)) || !isTty(isOutputTty(promptStdout)) {
    fail("add requires an interactive terminal before overwriting files")
  }

  let log = promptLog(options)
  log("The following files already exist:")
  files->Array.forEach(file => log("  " ++ file))

  let answer =
    (
      await askWithReadline(
        ~stdin=promptStdin,
        ~stdout=promptStdout,
        "Overwrite these files? [y/N]: ",
      )
    )
    ->trim
    ->toLowerCase
  answer == "y" || answer == "yes"
}

let defaultInstallFolderFor = (~cwd, ~packageName) =>
  NodePath.join2(cwd, AddInstallTarget.defaultFolder(~packageName))

let defaultInstallPathFor = (~packageName, ~extension) =>
  AddInstallTarget.defaultSingleFilePath(~packageName, ~extension)

let listPackageReleases = async (~packageName, ~packageVersion, ~rescriptVersion, ~fetchImpl) => {
  let baseUrl =
    registryApiBaseUrl ++ "/v1/packages/" ++ encodeURIComponent(packageName) ++ "/releases"
  let queryItems: array<string> = []
  switch packageVersion {
  | Some(version) =>
    queryItems->Array.push("packageVersion=" ++ encodeURIComponent(version))->ignore
  | None => ()
  }
  switch rescriptVersion {
  | Some(version) =>
    queryItems->Array.push("rescriptVersion=" ++ encodeURIComponent(version))->ignore
  | None => ()
  }
  let url = if queryItems->Array.length == 0 {
    baseUrl
  } else {
    baseUrl ++ "?" ++ queryItems->Array.join("&")
  }
  let payload: releaseListPayload = await readJson(await fetchImpl(url))
  payload.releases->Belt.Option.getWithDefault([])
}

let fetchRelease = async (~releaseId, ~fetchImpl) => {
  let url = registryApiBaseUrl ++ "/v1/releases/" ++ encodeURIComponent(releaseId)
  let payload: releasePayload = await readJson(await fetchImpl(url))
  payload
}

let dateLabel = value =>
  switch value->String.split("T")->Array.get(0) {
  | Some(date) =>
    switch date->String.split("-") {
    | [year, month, day] => month ++ "/" ++ day ++ "/" ++ year
    | _ => date
    }
  | None => value
  }

let authorLabel = (release: releasePayload) =>
  release.publisherDisplayName->Belt.Option.getWithDefault(release.publisherLogin)

let installHeaderFor = (release: releasePayload) =>
  "/**\n" ++
  "* Fetched from @jvlk/rescript-bindings\n" ++
  "* Package: " ++
  release.packageName ++
  "\n" ++
  "* " ++
  AddPackageName.toModuleName(release.packageName) ++
  " version: " ++
  release.peerPackageRange ++
  "\n" ++
  "* Rescript version: " ++
  release.rescriptRange ++
  "\n" ++
  "* Author: " ++
  authorLabel(release) ++
  "\n" ++
  "* Last updated: " ++
  dateLabel(release.createdAt) ++
  "\n" ++
  "*/\n\n"

let contentWithInstallHeader = (~release, ~content) => installHeaderFor(release) ++ content

let askInstallFilePath = async (~stdin, ~stdout, ~defaultValue) => {
  if !isTty(isInputTty(stdin)) || !isTty(isOutputTty(stdout)) {
    defaultValue
  } else {
    let value = ref(defaultValue)
    let accepted = ref(false)

    while !accepted.contents {
      let next = await askWithDefault(~stdin, ~stdout, "Install file", value.contents)
      try {
        value := AddModuleFilename.normalizePath(next)
        accepted := true
      } catch {
      | AddModuleFilename.InvalidFilename(_) =>
        write(stdout, AddModuleFilename.errorMessage ++ "\n")->ignore
      }
    }

    value.contents
  }
}

let targetPathFor = (~root, ~relativePath) => {
  let rootPath = NodePath.resolve1(root)
  let normalizedRelativePath = normalizeInstallFilePath(relativePath)
  let targetPath = NodePath.resolve2(rootPath, normalizedRelativePath)
  let rootPrefix = if rootPath->startsWith(NodePath.sep) && rootPath == NodePath.sep {
    rootPath
  } else if rootPath->String.endsWith(NodePath.sep) {
    rootPath
  } else {
    rootPath ++ NodePath.sep
  }

  if targetPath != rootPath && !(targetPath->startsWith(rootPrefix)) {
    fail("Release file escapes install folder: " ++ normalizedRelativePath)
  }

  targetPath
}

let targetPlanFor = async (
  ~cwd,
  ~folder,
  ~release: releasePayload,
  ~stdin,
  ~stdout,
): targetPlan => {
  switch folder {
  | Some(folder) if folder->trim != "" =>
    let root = NodePath.resolve2(cwd, folder)
    {
      summaryPath: {
        let relative = NodePath.relative(cwd, root)
        if relative == "" {
          "."
        } else {
          relative
        }
      },
      targetPathForFile: file => targetPathFor(~root, ~relativePath=file.relativePath),
    }
  | _ =>
    if release.files->Array.length == 1 {
      let singleFile = release.files[0]->Belt.Option.getExn
      let defaultFile = defaultInstallPathFor(
        ~packageName=release.packageName,
        ~extension=NodePath.extname(singleFile.relativePath),
      )
      let selectedFile = await askInstallFilePath(~stdin, ~stdout, ~defaultValue=defaultFile)
      let targetPath = NodePath.resolve2(cwd, selectedFile)
      {
        summaryPath: {
          let relative = NodePath.relative(cwd, targetPath)
          if relative == "" {
            "."
          } else {
            relative
          }
        },
        targetPathForFile: _ => targetPath,
      }
    } else {
      let root = NodePath.resolve2(
        cwd,
        AddInstallTarget.defaultFolder(~packageName=release.packageName),
      )
      {
        summaryPath: {
          let relative = NodePath.relative(cwd, root)
          if relative == "" {
            "."
          } else {
            relative
          }
        },
        targetPathForFile: file => targetPathFor(~root, ~relativePath=file.relativePath),
      }
    }
  }
}

let existingFilesFrom = async targetFiles => {
  let existingFiles: array<string> = []

  for index in 0 to targetFiles->Array.length - 1 {
    switch targetFiles[index] {
    | Some(file) =>
      try {
        let _ = await NodeFs.readFileUtf8(file.targetPath, "utf8")
        existingFiles->Array.push(file.targetPath)->ignore
      } catch {
      | error =>
        switch error->JsExn.fromException {
        | Some(jsError) if errorCode(jsError) == Some("ENOENT") => ()
        | _ => throw(error)
        }
      }
    | None => ()
    }
  }

  existingFiles
}

let writeReleaseFiles = async targetFiles => {
  for index in 0 to targetFiles->Array.length - 1 {
    switch targetFiles[index] {
    | Some(file) =>
      await NodeFs.mkdirRecursive(NodePath.dirname(file.targetPath), {"recursive": true})
      await NodeFs.writeFileUtf8(file.targetPath, file.content, "utf8")
    | None => ()
    }
  }
}

let runAddWithDeps = async (
  packageName: option<string>,
  folder: option<string>,
  deps: deps,
): unit => {
  let fetchImpl = depFetch(deps)->Belt.Option.orElse(globalFetch)->requireFetch
  let projectCwd = depCwd(deps)->Belt.Option.getWithDefault(cwd())
  let log = depLog(deps)->Belt.Option.getWithDefault(message => Console.log(message))
  let promptStdin = depStdin(deps)->Belt.Option.getWithDefault(stdin)
  let promptStdout = depStdout(deps)->Belt.Option.getWithDefault(stdout)
  let selectRelease = depSelectRelease(deps)->Belt.Option.getWithDefault(defaultSelectRelease)
  let confirmOverwrite =
    depConfirmOverwrite(deps)->Belt.Option.getWithDefault(defaultConfirmOverwrite)
  let didClearConsole = ref(false)
  let packageJson = await readProjectPackageJson(projectCwd)
  let normalizedPackageName = switch packageName {
  | Some(packageName) if packageName->trim != "" => packageName->trim
  | _ =>
    if isTty(isInputTty(promptStdin)) && isTty(isOutputTty(promptStdout)) {
      clearConsoleOnce(~cleared=didClearConsole, ~stdout=promptStdout)
    }
    await selectPackageName(
      ~packageNames=PackageJson.dependencyNamesFrom(packageJson),
      ~stdin=promptStdin,
      ~stdout=promptStdout,
    )
  }
  let packageVersion = PackageJson.dependencyVersionFrom(packageJson, normalizedPackageName)
  let rescriptVersion = PackageJson.dependencyVersionFrom(packageJson, "rescript")
  let releases = await listPackageReleases(
    ~packageName=normalizedPackageName,
    ~packageVersion,
    ~rescriptVersion,
    ~fetchImpl,
  )

  if releases->Array.length == 0 {
    log("No bindings found for " ++ normalizedPackageName ++ ".")
  } else {
    let options = promptOptions(~stdin=promptStdin, ~stdout=promptStdout, ~log, ())
    if isTty(isInputTty(promptStdin)) && isTty(isOutputTty(promptStdout)) {
      clearConsoleOnce(~cleared=didClearConsole, ~stdout=promptStdout)
    }
    let selectedRelease = await selectRelease(releases, options)
    let release = await fetchRelease(~releaseId=selectedRelease.id, ~fetchImpl)
    let targetPlan = await targetPlanFor(
      ~cwd=projectCwd,
      ~folder,
      ~release,
      ~stdin=promptStdin,
      ~stdout=promptStdout,
    )
    let targetFiles = release.files->Array.map(file => {
      targetPath: targetPlan.targetPathForFile(file),
      content: contentWithInstallHeader(~release, ~content=file.content),
    })
    let existingFiles = await existingFilesFrom(targetFiles)

    if existingFiles->Array.length > 0 {
      let shouldOverwrite = await confirmOverwrite(existingFiles, options)
      if shouldOverwrite {
        await writeReleaseFiles(targetFiles)
        log("Installed " ++ release.packageName ++ " to " ++ targetPlan.summaryPath)
      } else {
        log("Install cancelled.")
      }
    } else {
      await writeReleaseFiles(targetFiles)
      log("Installed " ++ release.packageName ++ " to " ++ targetPlan.summaryPath)
    }
  }
}

let runAdd = async (packageName, folder) =>
  await runAddWithDeps(Some(packageName), folder, emptyDeps())
