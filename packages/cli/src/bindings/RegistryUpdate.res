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

let fail = message => throw(makeJsError(message))

let requireFetch = (fetchImpl: option<fetchImpl>) =>
  switch fetchImpl {
  | Some(fetchImpl) => fetchImpl
  | None => fail("update requires a fetch implementation")
  }

let bindingsFilePath = projectCwd => NodePath.join3(projectCwd, "src", "Bindings.res")

let packageNameFromLabel = label => {
  let _ = label
  %raw(`label
    .replace(/^Binding/, "")
    .replace(/([a-z0-9])([A-Z])/g, "$1-$2")
    .replace(/([A-Z])([A-Z][a-z])/g, "$1-$2")
    .toLowerCase()`)
}

let parseInstalledBindings = content => {
  let _ = (content, packageNameFromLabel)
  %raw(`(() => {
    const commentPattern = new RegExp("/[*][*][^]*?Fetched from @jvlk/rescript-bindings[^]*?[*]/", "g");
    const packagePattern = new RegExp("^[ \\t]*[*][ \\t]*Package:[ \\t]*(.+?)[ \\t]*$", "m");
    const versionPattern = new RegExp("^[ \\t]*[*][ \\t]*(.+?)[ \\t]+version:[ \\t]*(.+?)[ \\t]*$", "m");
    const rescriptPattern = new RegExp("^[ \\t]*[*][ \\t]*Rescript version:[ \\t]*(.+?)[ \\t]*$", "m");
    const matches = [...content.matchAll(commentPattern)];
    return matches.flatMap((match, index) => {
      const comment = match[0];
      const packageLine = comment.match(packagePattern);
      const versionLine = comment.match(versionPattern);
      const rescriptLine = comment.match(rescriptPattern);
      if (!versionLine || !rescriptLine) {
        return [];
      }
      const label = versionLine[1].trim();
      const packageName = packageLine ? packageLine[1].trim() : packageNameFromLabel(label);
      const next = matches[index + 1];
      return [{
        packageName,
        packageRange: versionLine[2].trim(),
        rescriptRange: rescriptLine[1].trim(),
        blockStart: match.index,
        blockEnd: next ? next.index : content.length,
      }];
    });
  })()`)
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
  let _ = (content, replacements)
  %raw(`(() => {
    let output = "";
    let cursor = 0;
    for (const [binding, replacement] of replacements) {
      output += content.slice(cursor, binding.blockStart);
      output += replacement.trimEnd() + "\\n";
      cursor = binding.blockEnd;
    }
    output += content.slice(cursor);
    return output;
  })()`)
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
