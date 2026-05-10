let run = async (): unit => {
  switch Cli.parse(NodeProcess.argv) {
  | Some(("add", packageName, folder)) => await Cli.runAdd(~packageName, ~folder)
  | Some(("publish", _, _)) => await Cli.runPublish()
  | _ => Cli.usage()
  }
}

let () = {
  run()
  ->Promise.catch(err => {
    let message = switch JsExn.fromException(err) {
    | Some(jsError) => jsError->JsExn.message->Belt.Option.getWithDefault("Command failed")
    | None => "Command failed"
    }
    Console.log(message)
    NodeProcess.exit(1)
  })
  ->ignore
}
