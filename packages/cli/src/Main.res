let run = async (): unit => {
  switch Cli.parse(NodeProcess.argv) {
  | Some(command) =>
    switch command {
    | List => await Cli.runList()
    | Recent => await Cli.runRecent()
    | Search(query) => await Cli.runSearch(~query)
    | Get(packageName, author) => await Cli.runGet(~packageName, ~author)
    | Add(packageName, folder) => await Cli.runAdd(~packageName, ~folder)
    | Update => await Cli.runUpdate()
    | Publish => await Cli.runPublish()
    }
  | None => Cli.usage()
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
