type process

@val external process: process = "process"
@set external setExitCode: (process, int) => unit = "exitCode"
@get external errorCode: JsExn.t => option<string> = "code"
@get external errorExitCode: JsExn.t => option<int> = "exitCode"
@send external startsWith: (string, string) => bool = "startsWith"
@module("node:process") external stdout: Commander.writable = "stdout"
@module("node:process") external stderr: Commander.writable = "stderr"

let red = value => "\x1b[31m" ++ value ++ "\x1b[0m"

let configureBaseProgram = program =>
  program
  ->Commander.name("rescript-bindings")
  ->Commander.description("Install and publish ReScript source bindings")
  ->Commander.version("0.1.0")
  ->Commander.showHelpAfterError("(run with --help for usage)")
  ->Commander.configureOutput(Commander.outputConfig(
    ~writeOut=value => Commander.write(stdout, value),
    ~writeErr=value => Commander.write(stderr, value),
    ~outputError=(value, write) => {
      write(red(value))->ignore
    },
    (),
  ))
  ->Commander.exitOverride

let addAddCommand = program => {
  program
  ->Commander.command("add")
  ->Commander.description("Install a published binding into the current project")
  ->Commander.argument("[package]", "JavaScript package name to install bindings for")
  ->Commander.option("-f, --folder <path>", "install into this folder instead of prompting for one")
  ->Commander.actionAdd(async (packageName, options) =>
    await RegistryAdd.runAdd(packageName->Belt.Option.getWithDefault(""), Commander.folder(options))
  )
  ->ignore
}

let addPublishCommand = program => {
  program
  ->Commander.command("publish")
  ->Commander.description("Publish local .res/.resi bindings")
  ->Commander.actionPublish(async () => await PublishOAuth.runPublish(None))
  ->ignore
}

let makeProgram = () => {
  let program = Commander.make()->configureBaseProgram
  addAddCommand(program)
  addPublishCommand(program)
  program
}

let setProcessExitCode = code => setExitCode(process, code)

let isCommanderCode = code => code->startsWith("commander.")

let handleCommanderError = error =>
  switch error->JsExn.fromException {
  | Some(jsError) =>
    switch errorCode(jsError) {
    | Some("commander.helpDisplayed") | Some("commander.version") => true
    | Some(code) if isCommanderCode(code) =>
      setProcessExitCode(errorExitCode(jsError)->Belt.Option.getWithDefault(1))
      true
    | _ => false
    }
  | None => false
  }

let run = async (~argv=NodeProcess.argv, ()) => {
  let program = makeProgram()
  try {
    await Commander.parseAsync(program, argv)
  } catch {
  | error =>
    if !handleCommanderError(error) {
      throw(error)
    }
  }
}

let ready =
  run()
  ->Promise.catch(async error => {
    let message = switch error->JsExn.fromException {
    | Some(jsError) => jsError->JsExn.message->Belt.Option.getWithDefault("Command failed")
    | None => "Command failed"
    }
    Console.error(message)
    setProcessExitCode(1)
  })
