type deps
type installedBinding = {
  packageName: string,
  packageRange: string,
  rescriptRange: string,
  blockStart: int,
  blockEnd: int,
}
type updatePlan = {
  binding: installedBinding,
  release: RegistryAdd.releaseSummary,
}

type fetchImpl = RegistryAdd.fetchImpl
type logImpl = RegistryAdd.logImpl
type confirmUpdateImpl = (array<updatePlan>, string) => promise<bool>

@module("node:process") external cwd: unit => string = "cwd"
@val @scope("globalThis") external globalFetch: option<fetchImpl> = "fetch"
@obj external emptyDeps: unit => deps = ""
@obj
external deps: (
  ~cwd: string=?,
  ~fetch: fetchImpl=?,
  ~log: logImpl=?,
  ~confirmUpdate: confirmUpdateImpl=?,
  unit,
) => deps = ""
@get external depCwd: deps => option<string> = "cwd"
@get external depFetch: deps => option<fetchImpl> = "fetch"
@get external depLog: deps => option<logImpl> = "log"
@get external depConfirmUpdate: deps => option<confirmUpdateImpl> = "confirmUpdate"
@get external fileContent: 'file => string = "content"
@new external makeJsError: string => exn = "Error"
@send external trim: string => string = "trim"
@send external includesString: (string, string) => bool = "includes"
@send external indexOfFrom: (string, string, int) => int = "indexOf"
@send external indexOf: (string, string) => int = "indexOf"
@send external sliceFromTo: (string, int, int) => string = "slice"
@send external sliceFrom: (string, int) => string = "slice"
@send external charAt: (string, int) => string = "charAt"
@send external toLowerCase: string => string = "toLowerCase"
@send external split: (string, string) => array<string> = "split"
@send external startsWith: (string, string) => bool = "startsWith"
@send external trimEnd: string => string = "trimEnd"

let fail = message => throw(makeJsError(message))

let requireFetch = (fetchImpl: option<fetchImpl>) =>
  switch fetchImpl {
  | Some(fetchImpl) => fetchImpl
  | None => fail("update requires a fetch implementation")
  }

let bindingsFilePath = projectCwd => NodePath.join3(projectCwd, "src", "Bindings.res")

let packageNameFromLabel = label => {
  let source = if label->startsWith("Binding") {
    label->sliceFrom(7)
  } else {
    label
  }
  let output = ref("")
  let previous = ref("")

  for index in 0 to source->String.length - 1 {
    let char = source->charAt(index)
    let next = if index + 1 < source->String.length {
      source->charAt(index + 1)
    } else {
      ""
    }
    let isUpper = char != char->toLowerCase
    let previousIsLowerOrDigit =
      previous.contents != "" && previous.contents == previous.contents->toLowerCase
    let nextIsLower = next != "" && next == next->toLowerCase

    if index > 0 && isUpper && (previousIsLowerOrDigit || nextIsLower) {
      output := output.contents ++ "-"
    }
    output := output.contents ++ char->toLowerCase
    previous := char
  }

  output.contents
}

let commentLineValue = (~comment, ~prefix) => {
  let lines = comment->split("\n")
  let result = ref(None)

  for index in 0 to lines->Array.length - 1 {
    switch lines[index] {
    | Some(line) =>
      let line = line->trim
      let line = if line->startsWith("*") {
        line->sliceFrom(1)->trim
      } else {
        line
      }
      if result.contents == None && line->startsWith(prefix) {
        result := Some(line->sliceFrom(prefix->String.length)->trim)
      }
    | None => ()
    }
  }

  result.contents
}

let parseInstalledBindings = content => {
  let matches: array<(int, string)> = []
  let cursor = ref(0)
  let keepScanning = ref(true)

  while keepScanning.contents {
    let start = content->indexOfFrom("/**", cursor.contents)
    if start < 0 {
      keepScanning := false
    } else {
      let end_ = content->indexOfFrom("*/", start + 3)
      if end_ < 0 {
        keepScanning := false
      } else {
        let comment = content->sliceFromTo(start, end_ + 2)
        if comment->includesString("Fetched from @jvlk/rescript-bindings") {
          matches->Array.push((start, comment))->ignore
        }
        cursor := end_ + 2
      }
    }
  }

  let bindings: array<installedBinding> = []
  for index in 0 to matches->Array.length - 1 {
    switch matches[index] {
    | Some((blockStart, comment)) =>
      let version = commentLineValue(~comment, ~prefix="version:")
      let rescriptRange = commentLineValue(~comment, ~prefix="Rescript version:")
      switch (version, rescriptRange) {
      | (Some(versionLine), Some(rescriptRange)) =>
        let versionSeparator = versionLine->indexOf(" version:")
        if versionSeparator >= 0 {
          let label = versionLine->sliceFromTo(0, versionSeparator)->trim
          let packageRange = versionLine->sliceFrom(versionSeparator + 9)->trim
          let packageName = switch commentLineValue(~comment, ~prefix="Package:") {
          | Some(packageName) => packageName
          | None => packageNameFromLabel(label)
          }
          let blockEnd = switch matches[index + 1] {
          | Some((nextBlockStart, _)) => nextBlockStart
          | None => content->String.length
          }
          bindings->Array.push({
            packageName,
            packageRange,
            rescriptRange,
            blockStart,
            blockEnd,
          })->ignore
        }
      | _ => ()
      }
    | None => ()
    }
  }

  bindings
}

let isUpdatedRelease = (~binding: installedBinding, ~release: RegistryAdd.releaseSummary) =>
  release.peerPackageRange != binding.packageRange || release.rescriptRange != binding.rescriptRange

let findUpdatePlans = async (~bindings, ~fetchImpl) => {
  let plans: array<updatePlan> = []

  for index in 0 to bindings->Array.length - 1 {
    switch bindings[index] {
    | Some(binding) =>
      let releases = await RegistryAdd.listPackageReleases(
        ~packageName=binding.packageName,
        ~packageVersion=Some(binding.packageRange),
        ~rescriptVersion=Some(binding.rescriptRange),
        ~fetchImpl,
      )
      switch releases[0] {
      | Some(release) if isUpdatedRelease(~binding, ~release) =>
        plans->Array.push({binding, release})->ignore
      | _ => ()
      }
    | None => ()
    }
  }

  plans
}

let defaultConfirmUpdate = async (plans, _targetPath) => {
  plans->Array.length > 0
}

let replacementFor = async (~plan, ~fetchImpl) => {
  let release = await RegistryAdd.fetchRelease(~releaseId=plan.release.id, ~fetchImpl)
  switch release.files[0] {
  | Some(file) if release.files->Array.length == 1 =>
    Some(RegistryAdd.contentWithInstallHeader(~release, ~content=file->fileContent))
  | _ => None
  }
}

let applyReplacements = (content, replacements: array<(installedBinding, string)>) => {
  let output = ref("")
  let cursor = ref(0)

  for index in 0 to replacements->Array.length - 1 {
    switch replacements[index] {
    | Some((binding, replacement)) =>
      output := output.contents ++ content->sliceFromTo(cursor.contents, binding.blockStart)
      output := output.contents ++ replacement->trimEnd ++ "\n"
      cursor := binding.blockEnd
    | None => ()
    }
  }

  output.contents ++ content->sliceFrom(cursor.contents)
}

let runUpdateWithDeps = async deps => {
  let fetchImpl = depFetch(deps)->Belt.Option.orElse(globalFetch)->requireFetch
  let projectCwd = depCwd(deps)->Belt.Option.getWithDefault(cwd())
  let log = depLog(deps)->Belt.Option.getWithDefault(message => Console.log(message))
  let confirmUpdate = depConfirmUpdate(deps)->Belt.Option.getWithDefault(defaultConfirmUpdate)
  let targetPath = bindingsFilePath(projectCwd)
  let content = try {
    await NodeFs.readFileUtf8(targetPath, "utf8")
  } catch {
  | _ => fail("Could not read " ++ targetPath)
  }
  let bindings = parseInstalledBindings(content)

  if bindings->Array.length == 0 {
    log("No installed bindings found in " ++ targetPath)
  } else {
    let plans = await findUpdatePlans(~bindings, ~fetchImpl)
    if plans->Array.length == 0 {
      log("All bindings are up to date.")
    } else if await confirmUpdate(plans, targetPath) {
      let replacements: array<(installedBinding, string)> = []
      for index in 0 to plans->Array.length - 1 {
        switch plans[index] {
        | Some(plan) =>
          switch await replacementFor(~plan, ~fetchImpl) {
          | Some(content) => replacements->Array.push((plan.binding, content))->ignore
          | None => log("Skipping " ++ plan.binding.packageName ++ ": update contains multiple files")
          }
        | None => ()
        }
      }

      if replacements->Array.length == 0 {
        log("No bindings were updated.")
      } else {
        await NodeFs.writeFileUtf8(targetPath, applyReplacements(content, replacements), "utf8")
        replacements->Array.forEach(((binding, _content)) => log("Updated " ++ binding.packageName))
      }
    } else {
      log("Update cancelled.")
    }
  }
}

let runUpdate = async () => await runUpdateWithDeps(emptyDeps())
