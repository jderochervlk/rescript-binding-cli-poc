let run = async (): unit => {
  switch Cli.parse(NodeProcess.argv) {
  | Some(("add", packageName, folder)) => {
      switch folder {
      | Some(path) => Console.log("Install package " ++ packageName ++ " to " ++ path)
      | None => Console.log("Install package " ++ packageName)
      }
    }
  | Some(("publish", _, _)) => await Cli.runPublishAuthCheck()
  | _ => Cli.usage()
  }
}

let () = {
  run()
  ->Promise.catch(err => {
    let message =
      switch JsExn.fromException(err) {
      | Some(jsError) => jsError->JsExn.message->Belt.Option.getWithDefault("Publish auth failed")
      | None => "Publish auth failed"
      }
    Console.log(message)
    NodeProcess.exit(1)
  })
  ->ignore
}
